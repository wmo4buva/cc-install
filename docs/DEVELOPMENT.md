# Development

For anyone maintaining cc-install. End users want [../README.md](../README.md).

## What this is

A Docker image with Claude Code + code-server, plus host-side scripts that
install, launch and maintain it. Nothing clever — the value is that a
non-technical user runs one command and gets a working environment.

Design constraints, in priority order:

1. **A non-technical user must succeed unattended.** Every error message names
   the fix. No step assumes Docker knowledge.
2. **Two platforms, always in sync.** Every script exists as `.sh` and `.ps1`.
   A fix to one that isn't applied to the other is a bug.
3. **User data is sacred.** `workspace/`, `.env` and the `claude-config` volume
   survive updates, rebuilds and reinstalls.
4. **Fixes must reach existing installs.** See "Update path" below — this is the
   constraint that's easiest to forget and most expensive to get wrong.

## Layout

```
docker-compose.yml                      volumes, loopback port binding, env passthrough
VERSION                                 single source of truth for the version
.env.example                            credential template
docker/Dockerfile                       image: Debian + Node + code-server + Claude Code
docs/docker-compose.override.yml.example  user-editable local overrides
bin/
  claude, vscode, claude.cmd, vscode.cmd  thin wrappers into scripts/launchers/
scripts/
  container/entrypoint.sh               runs INSIDE the image on every start
  lib/workspace.sh, lib/Workspace.ps1   shared workspace-path resolution
  installers/install.{sh,ps1}           one-line installer
  installers/setup-shortcuts.{sh,ps1}   creates the cc* commands
  installers/setup-credentials.{sh,ps1} the ccauth flow
  launchers/run_claude.{sh,ps1}         ccdocker
  launchers/run_vscode.{sh,ps1}         ccvscode
  maintenance/set-workspace.{sh,ps1}    ccpath
  maintenance/{update,backup,restore,uninstall,check-update,diagnose}.{sh,ps1}
```

### Develop in a clone, never in an install

`ccupdate` runs `cp -R extracted/. $INSTALL_DIR/` — it copies the whole repo over
an installed copy, with no backup. Files that exist upstream are overwritten;
locally-created files survive. So editing an installed copy directly means every
change to a tracked file is silently destroyed on the user's next `ccupdate`, and
there is nothing to recover from unless the install happens to be a git clone.

Clone the repo to work on it, and let installs receive changes the normal way
(`ccupdate` after a push to `main`).

### What can and can't move out of the root

`docker-compose.yml` and `VERSION` are pinned there.

- **`docker-compose.yml`** — roughly 130 `docker compose` calls across 14 scripts
  resolve it from the working directory, and `env_file` / `build.context` resolve
  relative to the compose file itself, so moving it shifts those too. Every
  documented `docker compose exec …` a user copy-pastes would also break.
  `COMPOSE_FILE` in `.env` is not a way out: `.env` doesn't exist yet when
  `install.sh` runs its first build.
- **`VERSION`** — `check-update.{sh,ps1}` already shipped to users with
  `raw.githubusercontent.com/.../main/VERSION` baked in. Moving it makes those
  fetches 404, which the script reads as "no update available", so existing
  installs would silently never see another release. That's hard rule 3.
- **`docker-compose.override.yml`** — Compose auto-loads it only from the compose
  file's own directory. The `.example` is pure documentation and does live in `docs/`.

The `bin/` wrappers `cd "$(dirname "$0")/.."` (and `cd /d "%~dp0.."` on Windows)
before calling into `scripts/launchers/`, so the working directory is the repo root
no matter where the user invokes them from.

### The workspace mount is relocatable

`docker-compose.yml` mounts `${CC_WORKSPACE:-./workspace}`, and `ccpath`
(`set-workspace.{sh,ps1}`) writes `CC_WORKSPACE` into `.env`. The container path
never changes, so nothing in the image is aware of any of this.

**Never hardcode `workspace/`.** Resolve through `scripts/lib/workspace.sh`
(`cc_workspace_dir`, `cc_workspace_label`, `cc_workspace_is_relocated`,
`cc_workspace_validate`) or the `Workspace.ps1` equivalents. They mirror Compose's
resolution order exactly — shell environment, then `.env`, then `./workspace` — so
the scripts and the container can't drift apart. Six scripts hardcoded the path
before this existed; the failure mode is `ccbackup` cheerfully archiving an empty
`./workspace` while the real files sit somewhere else.

Three things that bite here:

- **A bind mount is fixed at container creation.** Changing `CC_WORKSPACE` needs
  `docker compose up -d --force-recreate`, not `restart`. `ccpath` does this and
  then reads the mount back out of `docker inspect` to prove it landed.
- **Compose doesn't expand `~`,** and a relative path resolves against the caller's
  cwd. `ccpath` always writes an absolute path; `cc_workspace_validate` catches
  hand-edited `.env` files, and `ccdiagnose` surfaces it.
- **A path Docker Desktop can't share mounts empty, with no error.** macOS shares
  `/Users`, `/Volumes`, `/private`, `/tmp` by default. `ccpath` warns on anything
  outside that, and on UNC paths and non-C: drives on Windows.

Anything that deletes workspace contents must refuse to run on `$HOME` or a
filesystem root — `ccpath ~` followed by `ccrestore` would otherwise wipe the home
directory. See `guard_destructive_path` in `restore.sh` and its `.ps1` counterpart.

## Local development

```bash
docker compose build --progress plain      # plain shows full build output
docker compose up -d
docker compose exec claude-code claude --version
docker compose exec claude-code code-server --version
docker compose exec claude-code bash       # poke around
docker compose logs -f
docker compose down
```

Test the installer without touching your real setup:

```bash
CC_INSTALL_DRY_RUN=1 bash scripts/installers/install.sh     # no changes
CC_INSTALL_VERBOSE=1 bash scripts/installers/install.sh     # every step
CC_INSTALL_DIR=test-dir bash scripts/installers/install.sh  # elsewhere
CC_INSTALL_REF=v1.2.2 bash scripts/installers/install.sh    # a specific tag
```

### Checking scripts without the target OS

Bash:

```bash
for f in $(find scripts -name '*.sh'); do bash -n "$f" || echo "SYNTAX: $f"; done
```

PowerShell, if you're not on Windows — use the official image:

```bash
docker run --rm -v "$PWD/scripts:/s:ro" mcr.microsoft.com/powershell:lts-ubuntu-22.04 \
  pwsh -NoProfile -Command '
    Get-ChildItem /s -Recurse -Filter *.ps1 | ForEach-Object {
      $e = $null
      [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$e) | Out-Null
      if ($e.Count) { Write-Output "FAIL $($_.Name)"; $e | ForEach-Object { $_.Message } }
      else { Write-Output "OK   $($_.Name)" }
    }'
```

On Apple Silicon, request `lts-ubuntu-22.04` rather than `:latest` — `:latest`
resolves to a 32-bit `linux/arm` image that hangs under emulation.

Both `setup-credentials` scripts accept a menu option as an argument
(`setup-credentials.sh 3`, `setup-credentials.ps1 -Choice 3`), which makes the
non-secret paths testable non-interactively. Secrets are always prompted for.

## Update path — read this before changing any script

Claude Code is baked into the image, and `~/.claude` is a Docker **volume**.
Those two facts cause most of the non-obvious bugs in this project.

**A volume is seeded from the image only once, when the volume is first
created.** So anything written into `~/.claude` in the `docker/Dockerfile` is frozen at
whatever the user's very first build produced and can never be updated. That's
why bundled skills live in `/opt/cc-install/skills` and
`scripts/container/entrypoint.sh` copies them into `~/.claude/skills` on every
container start. Don't move them back.

**A named volume mounted where the image has no such directory is created
root-owned.** Docker copies ownership from the image path when it initializes an
empty volume; if the path doesn't exist, the mountpoint is `root:root` and the
container user is locked out. This shipped in 1.3.0 with the `code-server-data`
volume: code-server died with `EACCES: permission denied, mkdir .../coder-logs`
and every extension install failed. Two-part fix — `mkdir -p` the path in the
`docker/Dockerfile` as `claudeuser` (fixes new installs), and repair via `sudo chown` in
`scripts/container/entrypoint.sh` (fixes existing ones, since a non-empty volume
is never re-seeded). **Any new volume mount needs the same treatment.**

**`update.sh` must refresh the host-side files, not just rebuild the image.**
For a long time it only rebuilt, which meant a bug fixed in `run_vscode.sh` could
never reach anyone who had already installed. It now re-downloads the repo
archive over the install directory (leaving `workspace/`, `.env` and
`docker-compose.override.yml` alone) and re-runs `setup-shortcuts` so newly added
commands appear.

**`setup-shortcuts` must be idempotent and must overwrite.** Both versions
rewrite unconditionally. An early-exit "already installed" check meant existing
users never received new shortcuts.

**The installers fetch the whole repo as an archive, not a file list.** The old
hardcoded list drifted every time a file was added — that's how `VERSION` came to
be missing from installs, which made every user permanently see "update
available". Adding a file now requires no installer change.

## Adding a script

1. Write both `.sh` and `.ps1`.
2. `chmod +x` the `.sh`.
3. Use the existing logging helpers (`log_info`/`Write-Info`, etc.).
4. Add a `cc*` shortcut in **both** `setup-shortcuts` files if users need it.
5. Document it in `RUNBOOK.md` (the canonical command list) and
   `docs/QUICK_REFERENCE.md` (the one-page card). `README.md` only carries the
   short everyday-commands teaser — add it there just if it belongs in that set.
6. No installer change needed — the archive picks it up.

### Bash gotchas that have bitten this repo

- `local` outside a function is a hard error and aborts the script under
  `set -e`. It shipped in `diagnose.sh` and silently truncated the report.
- Variables declared `local` are not in scope at the top level. Referencing one
  there aborts under `set -u`. It shipped in `check-update.sh`.
- `df -BG` is GNU-only and fails on macOS. Use `df -k` and divide.
- A quoted heredoc (`<< 'EOF'`) does not expand variables. `setup-shortcuts.sh`
  baked the literal string `$INSTALL_DIR` into the generated macOS app.

### PowerShell gotchas that have bitten this repo

- `.ps1` files **must** be CRLF. `.gitattributes` enforces `*.ps1 text eol=crlf`;
  LF endings caused "the string is missing the terminator" on Windows.
- Don't name a parameter `$Args` or `$Verbose` — they collide with automatic and
  common parameters.
- `switch ($null)` skips every clause, `default` included. Validate input before
  the switch rather than relying on `default` to catch it.
- `Add-Content -Encoding utf8` writes a **BOM** on PowerShell 5.1 when it creates
  the file. Docker Compose doesn't strip BOMs, so the first variable in `.env`
  would be read as `<BOM>NAME` and ignored. Write `.env` via
  `[System.IO.File]::AppendAllText` with `UTF8Encoding($false)`, using LF.
- `[Environment]::GetFolderPath('MyDocuments')` can return an **empty string**
  (Documents redirected to OneDrive, unusual shell contexts). `Join-Path ""`
  throws, which used to abort all shortcut setup and leave the user with no
  commands at all. Guard it, and wrap per-profile writes in `try/catch`.
- `$LASTEXITCODE` reflects the last *external* command, not the script. End
  scripts with an explicit `exit 0` if a caller checks it.

## Versioning

`VERSION` is the single source of truth. `check-update` compares it against
`raw.githubusercontent.com/.../main/VERSION`, caching for 24 hours in
`~/.cache/cc-install-version-check` (`%TEMP%` on Windows).

Releasing:

1. Update `VERSION` and `CHANGELOG.md`.
2. Run the checklist below.
3. `git tag vX.Y.Z && git push --tags`
4. Push to `main` — the one-line installer tracks `main`, so this is the release.

Pinned versions live in the `docker/Dockerfile` as build args (`CODE_SERVER_VERSION`,
`NODE_MAJOR`). Claude Code is deliberately unpinned — the official installer
always fetches the latest.

## Pre-release checklist

- [ ] `docker compose build` succeeds from scratch
- [ ] Container starts; `claude --version` and `code-server --version` both work
- [ ] Bundled skills present in `~/.claude/skills` after start
- [ ] `ccvscode` serves the IDE, and `claude` runs in its terminal
- [ ] Workspace persists across `docker compose down && up -d`
- [ ] All three `ccauth` options write the right `.env` and clear the others
- [ ] `.env` ends up `chmod 600`, no BOM, LF endings
- [ ] `ccdiagnose` runs to completion on macOS and Windows
- [ ] `update.sh` refreshes files *and* rebuilds, keeping `workspace/` and `.env`
- [ ] Port published on `127.0.0.1` only
- [ ] Every bash script passes `bash -n`; every `.ps1` parses
- [ ] `.ps1` files are CRLF in the committed tree
- [ ] `RUNBOOK.md`, `QUICK_REFERENCE.md`, `CHANGELOG.md`, `VERSION` all updated
      (and `README.md` if the change affects install or the overview)

## Bundled skills

Cloned at build time (`--depth 1`, default branch) into `/opt/cc-install/skills`:

| Source | Contents |
|---|---|
| [anthropics/skills](https://github.com/anthropics/skills) | Anthropic's official collection |
| [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) | AI/ML practices and coding patterns |
| [obra/superpowers](https://github.com/obra/superpowers) | Workflow and productivity (Jesse Vincent) |

Each clone is best-effort: a repository that has moved or renamed its `skills/`
directory prints a warning rather than failing the build. Check build output for
`WARNING: could not bundle skills` when bumping.

They're unpinned, so you inherit whatever is on those default branches at build
time. See [../SECURITY.md](../SECURITY.md). To add a source, extend the loop in
the `docker/Dockerfile`; the entrypoint needs no change.

## Regenerating the Visual Guide PDF

Printed from `docs/installGuides/Claude Code Visual Guide.html` with headless
Chrome. **The render is non-deterministic** — the identical HTML produced a 2-page
PDF on one run and a 1-page PDF on the next, apparently depending on whether
layout settled before printing. It is a one-page guide, so always assert the
result rather than assuming:

```bash
python3 -c "
import re,sys; d=open('out.pdf','rb').read()
n=len(re.findall(rb'/Type\s*/Page[^s]',d)); print('pages:',n); sys.exit(0 if n==1 else 1)"
```

Re-run until it yields 1 page, then diff `pdftotext -layout` output against the
previous version before committing. Also confirm the `REV. … vX.Y.Z` line matches
`VERSION` — the guide stamps the version it documents.

The HTML is a bundled artifact (content lives in an escaped payload), so edits are
targeted string replacements against that payload. Verify afterwards that `<div`
and `/div` counts still balance.

Known cosmetic issue: the install command's URL wraps mid-string in the PDF text
layer (`.../cc-install/mai` + `n/scripts/...`) because it sits in a narrow column,
so copying it out of the PDF can introduce a line break. Widening that block, or
adding "type this as one line", would fix it.

## Ideas not yet built

The planned work now lives in [../ROADMAP.md](../ROADMAP.md) — in particular
supporting AWS Bedrock and Anthropic side by side, and running several instances
with different sign-ins. The short list below is what isn't covered there.

Kept short on purpose — a long speculative roadmap ages badly.

- **Batten-specific skills** — course/policy templates bundled alongside the
  public ones.
- **UVA SSO** — the Bedrock path currently needs keys or `aws sso login` on the
  host. Entra ID integration would remove that.
- **Fleet visibility for IT** — which version each machine is on. Needs a
  privacy decision first; nothing is collected today.
- **Pinned skill revisions** — pin to commit SHAs for reproducible builds, at the
  cost of manual bumps.
- **Smaller image** — multi-stage build to get under ~1 GB.
- **UID matching** — the container is UID 1000; hosts with a different UID can
  hit `workspace/` permission friction on Linux.

## Attribution

Structure and installer patterns follow
[DAAF](https://github.com/DAAF-Contribution-Community/daaf). See
[ATTRIBUTION.md](ATTRIBUTION.md).
