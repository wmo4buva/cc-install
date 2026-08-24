# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repository.

## What this project is

**cc-install** is a Docker-based installer that gives non-technical users a
working Claude Code environment from one command. It ships Claude Code CLI plus
code-server (VS Code in the browser), with host-side scripts to install, launch,
update and diagnose it.

The audience is the whole point: someone with no Docker knowledge must be able to
install it, sign in, and get working without help. Optimise for that over
elegance.

Full maintainer detail — architecture, gotchas, release process, pre-release
checklist — is in **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**. Read it before
changing scripts. This file is the short version.

## Hard rules

**1. Both platforms, every time.** Every script exists as `.sh` and `.ps1`. If you
change one, change the other. A one-sided fix is a bug, not a partial fix.

**2. `.ps1` files must be CRLF.** `.gitattributes` enforces this. LF endings have
already shipped once and broke every Windows install with "the string is missing
the terminator".

**3. Never break existing installs.** Fixes reach users only through
`scripts/maintenance/update.sh`, which refreshes the host-side files *and*
rebuilds the image. If a change needs a matching update-path change, do both.

**4. `.claude` is a Docker volume, seeded from the image only once.** Anything
written into `~/.claude` in the `Dockerfile` is frozen at the user's first build
forever. Bundled skills therefore live in `/opt/cc-install/skills` and
`scripts/container/entrypoint.sh` copies them in on every start. Don't move them
back.

**5. `.env` is the only source of credentials.** Do not add bare passthrough
entries (`- ANTHROPIC_API_KEY`) to `environment:` in `docker-compose.yml`.
`environment` takes precedence over `env_file`, and a bare entry that's unset on
the host resolves to `null` and *shadows* the `.env` value — silently breaking
`ccauth` entirely. If it's set on the host it overrides `.env` just as silently.
Both behaviours were verified against Docker Compose.

**6. Never commit secrets.** `.env` is gitignored; `.env.example` holds
placeholders only. No AWS keys, account IDs, or personal profile names in the
repo.

**7. Don't weaken the port binding.** `docker-compose.yml` publishes code-server
on `127.0.0.1:8080:8080`. It runs `--auth none`, so a `0.0.0.0` binding hands
anyone on the network a shell in the container.

## Verifying changes without the target OS

Bash syntax:

```bash
for f in $(find scripts -name '*.sh'); do bash -n "$f" || echo "SYNTAX: $f"; done
```

PowerShell parse-check (no Windows needed):

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

On Apple Silicon use the `lts-ubuntu-22.04` tag — `:latest` is a 32-bit
`linux/arm` image that hangs under emulation.

Both `setup-credentials` scripts take a menu option as an argument
(`setup-credentials.sh 3`, `-Choice 3`), so the non-secret paths are testable
non-interactively. Secrets are always prompted for — never accept one as an
argument, it would land in shell history.

Installer, without touching a real install:

```bash
CC_INSTALL_DRY_RUN=1 bash scripts/installers/install.sh
CC_INSTALL_DIR=test-dir bash scripts/installers/install.sh
```

Container:

```bash
docker compose build --progress plain
docker compose up -d
docker compose exec claude-code claude --version
docker compose exec claude-code bash -lc 'command -v claude'   # login shell, as code-server spawns
docker compose exec claude-code sh -c 'ls ~/.claude/skills | wc -l'
docker compose down
```

Build under a throwaway tag (`docker build -t cc-install-test .`) if the user may
have a real install on the machine.

## Language and tone in user-facing output

Error messages and script output are read by people who don't know Docker. Name
the fix, not just the fault. "Docker daemon is not running" is followed by the
steps to start Docker Desktop, and that pattern should hold everywhere.

Documentation avoids "simply", "just" and "obviously". The
[docs/CREDENTIALS.md](docs/CREDENTIALS.md) and
[docs/INSTALL_GUIDE.md](docs/INSTALL_GUIDE.md) voice is the target.

The single most-missed thing by users: **there is no Claude Code button in the
browser IDE** — you open a terminal in it and type `claude`. Any doc or output
touching `ccvscode` should say so.

## Files

```
Dockerfile  docker-compose.yml  docker-compose.override.yml.example  .env.example
VERSION     claude/vscode (+ .cmd)
scripts/container/    entrypoint.sh          (runs inside the image)
scripts/installers/   install, setup-shortcuts, setup-credentials
scripts/launchers/    run_claude, run_vscode
scripts/maintenance/  update, backup, restore, uninstall, check-update, diagnose
docs/                 CREDENTIALS, INSTALL_GUIDE, QUICK_REFERENCE, DEVELOPMENT, installGuides/
README.md  CHANGELOG.md  SECURITY.md  ATTRIBUTION.md  CLAUDE.md
```

Adding a file needs no installer change — the installers download the whole repo
as an archive. Do add new user-facing commands to **both** `setup-shortcuts`
scripts, and document them in `README.md` and `docs/QUICK_REFERENCE.md`.

## Releasing

1. Bump `VERSION` (single source of truth for the update check).
2. Add a `CHANGELOG.md` entry.
3. Work through the pre-release checklist in `docs/DEVELOPMENT.md`.
4. Push to `main` — the one-line installer tracks `main`, so pushing *is* the
   release. Tag with `git tag vX.Y.Z && git push --tags`.

Repo: `wmo4buva/cc-install` (public — the one-line installer needs unauthenticated
`raw.githubusercontent.com` and `codeload.github.com` access).
Remote must be `git@github.com-uva:wmo4buva/cc-install.git`.

## Attribution

Installer patterns follow
[DAAF](https://github.com/DAAF-Contribution-Community/daaf); keep
[ATTRIBUTION.md](ATTRIBUTION.md) accurate when borrowing more.
