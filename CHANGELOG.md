# Changelog

All notable changes to the Claude Code Installer (cc-install) project.

## [1.4.1] - 2026-08-27

### Fixed — `ccvscode` no longer writes into a relocated workspace

`run_vscode.{sh,ps1}` seeds a `START-HERE.md` into the workspace so the browser
IDE's file tree explains the thing it can't prompt for. That was harmless while the
workspace was always the bundled `./workspace`. With `ccpath` it can be a folder
the user already owns — often a git repo, where an unexpected `START-HERE.md`
appears as untracked and can be committed by accident.

It now seeds only the bundled `./workspace`. When the workspace is relocated the
launcher points at `RUNBOOK.md` instead, and the same instructions are still
printed to the terminal either way. Verified both paths: relocated leaves the
folder untouched, default still seeds as before.

## [1.4.0] - 2026-08-27

### Added — `ccpath`, to put your files wherever you want them

`ccpath` repoints the workspace mount at any folder on your computer, so your
files don't have to live inside the install directory.

```bash
ccpath ~/Dev/projects     # point the workspace there
ccpath --show             # where is it now?
ccpath --reset            # back to ./workspace
ccpath                    # show current, then prompt
```

`docker-compose.yml` now mounts `${CC_WORKSPACE:-./workspace}`, and `ccpath`
writes `CC_WORKSPACE` into `.env`. Existing installs are unaffected: with the
variable unset the mount resolves to `./workspace` exactly as before. The
container path is still `/home/claudeuser/workspace`, so nothing moves in the IDE.

It edits `.env` surgically — drops any existing `CC_WORKSPACE` line and appends,
the same approach `setup-credentials.sh` uses — so credentials are untouched.
Verified by diffing `.env` before and after a relocate-and-reset cycle: byte
identical.

What it handles that a hand-edited `.env` doesn't:
- **Recreates the container, not just restarts it.** A bind mount is fixed at
  container creation, so `restart` silently keeps the old folder. Then it reads the
  mount back out of `docker inspect` and tells you if they disagree.
- **Offers to copy your existing files across.** Copy, never move; the originals
  are never deleted.
- **Warns on folders Docker Desktop can't share** (outside `/Users`, `/Volumes`,
  `/private`, `/tmp` on macOS; UNC paths and non-`C:` drives on Windows). These
  mount *empty*, with no error at all — a genuinely awful thing to debug.
- **Warns on cloud-synced folders** (Dropbox, OneDrive, iCloud, Google Drive),
  where the sync client and the container both write the same files.
- **Rejects `~` and relative paths.** Compose expands neither; `~/foo` would mount
  a folder literally named `~`. `ccdiagnose` also flags a hand-edited `.env`.

**Six scripts no longer hardcode `workspace/`.** `backup`, `restore`, `diagnose`,
`run_vscode`, `uninstall` and `set-workspace` resolve the path through new shared
helpers, `scripts/lib/workspace.sh` and `scripts/lib/Workspace.ps1`, which mirror
Compose's own resolution order (shell environment, then `.env`, then the default)
so the scripts and the container cannot drift apart. Without this, `ccbackup`
would have archived an empty `./workspace` while the real files sat elsewhere.

`ccdiagnose` now reports the configured folder, flags it as relocated, and
cross-checks it against what the container actually mounted.

The cross-check normalises Docker Desktop's `/host_mnt` prefix before comparing.
Docker doesn't echo back the path you gave it — on macOS and Windows it reports
bind sources through its VM, so `/Users/you/cc-install/workspace` comes back as
`/host_mnt/Users/you/cc-install/workspace` and `C:\Users\you` as
`/host_mnt/c/Users/you`. A naive compare flagged a mismatch on *every* Docker
Desktop install — worse than no check, since it tells people to recreate a
container that's already correct and trains them to ignore the warning when a
real mismatch happens. Caught by running `ccdiagnose` on a live install.

### Added — RUNBOOK.md

[RUNBOOK.md](RUNBOOK.md) collects the operational procedures: changing the
workspace folder, configuring which models appear in the VS Code picker on
Bedrock, and troubleshooting. Verified Bedrock inference-profile IDs are listed
with their context windows.

Two corrections worth calling out, because the wrong versions circulated first:
current model IDs carry **no date suffix** (`us.anthropic.claude-opus-5`, not
`us.anthropic.claude-opus-5-20251201-v1:0`), and **Haiku 4.5 is 200K, not 1M** —
there is no 1M variant of it to select. Every ID in the runbook was confirmed
present with `list-inference-profiles` and confirmed to return a completion with
`bedrock-runtime converse`.

### Fixed — `ccrestore` on Windows extracted to the wrong folder

Pre-existing. `backup.ps1` archives `workspace\*`, so the zip holds the workspace
*contents* at its root — but `restore.ps1` called
`Expand-Archive -DestinationPath "."`, scattering those files across the install
directory and then reporting "0 files restored" because it counted the
freshly-emptied workspace. It now extracts into the workspace folder. The
macOS/Linux path was never affected.

### Fixed — restore could have deleted your home directory

`restore.{sh,ps1}` clears the workspace before extracting. That was safe while the
path was always `./workspace`; with a user-chosen path, `ccpath ~` followed by
`ccrestore` would have deleted everything in `$HOME`. Both now refuse outright on
a home directory, a filesystem root, a Windows drive root, or a system directory.
Verified against a decoy `$HOME` — the guard fires, exits 1, and the decoy's
contents survive.

Restore also now clears the workspace *contents* rather than removing and
recreating the directory. The folder is a live bind-mount source: deleting it
detaches the running container's mount, and on a relocated path it may carry
file-sharing permissions that can't be recreated.

Backups keep a single top-level directory, and restore strips it with
`--strip-components=1`. Archives made before this change (rooted at `workspace/`)
and after it (rooted at the relocated folder's name) both restore correctly —
verified in both directions.

### Fixed — `.cmd` launchers shipped with LF line endings

`.gitattributes` forced CRLF on `*.ps1` but never on `*.cmd`. `cmd.exe` tolerates
LF for plain one-liners, which is why it never surfaced, but it breaks on labels
and `goto` — and LF in `*.ps1` has already broken a Windows release once.

### Changed — repository root reorganised

The root held five non-documentation files that made it hard to see what matters.
Four moved; the rest are pinned by tooling and the reasons are now recorded in
`CLAUDE.md` and `docs/DEVELOPMENT.md` so this doesn't get re-litigated.

- `Dockerfile` → **`docker/Dockerfile`**. `docker-compose.yml` gained
  `dockerfile: docker/Dockerfile`; `context` stays `.` because the image COPYs
  `scripts/container/entrypoint.sh` from above `docker/`.
- `claude`, `vscode`, `claude.cmd`, `vscode.cmd` → **`bin/`**. The wrappers now
  `cd "$(dirname "$0")/.."` (`cd /d "%~dp0.."` on Windows) so the working directory
  is still the repo root wherever they're invoked from — verified by running
  `bin/claude logs` from `/tmp`. Updated to match: `setup-shortcuts.ps1`, the macOS
  `.app` generator in `setup-shortcuts.sh`, the `chmod +x` lines in `install.sh` and
  `update.sh`, the fallback launch hints in `install.{sh,ps1}` and
  `setup-shortcuts.ps1`, and `.dockerignore`.
- `docker-compose.override.yml.example` → **`docs/`**. Docker never loads it; it's
  documentation. The copy target is still `docker-compose.override.yml` in the
  root, since Compose auto-loads an override only from the compose file's own
  directory — `diagnose.{sh,ps1}`, `README.md`, `docs/CREDENTIALS.md` and
  `docs/QUICK_REFERENCE.md` all now say so explicitly.
- `ATTRIBUTION.md` → **`docs/`**.
- Root now holds only `README`, `CHANGELOG`, `ROADMAP`, `SECURITY`, `RUNBOOK`,
  `CLAUDE.md`, plus `VERSION` and `docker-compose.yml`.

**Deliberately left at the root**, with the reasoning captured in
`docs/DEVELOPMENT.md`:
- `docker-compose.yml` — ~130 `docker compose` calls across 14 scripts resolve it
  from the working directory, and `env_file`/`build.context` resolve relative to
  the compose file, so moving it shifts those too. `COMPOSE_FILE` in `.env` is not
  an escape hatch: `.env` doesn't exist yet when `install.sh` runs its first build.
- `VERSION` — `check-update.{sh,ps1}` already shipped with
  `raw.githubusercontent.com/.../main/VERSION` baked in. Moving it would 404 those
  fetches, which the script reads as "no update available", so existing installs
  would silently stop seeing releases. Hard rule 3.

### Changed — new hard rules in CLAUDE.md

Rule 8: never hardcode `workspace/`; resolve through `scripts/lib/`. Rule 9:
develop in a clone, never inside an install — `ccupdate` copies the repo over an
install with `cp -R` and no backup, so edits to tracked files in an installed copy
are destroyed on the next update with nothing to recover from.

### Housekeeping (previously unreleased)

Planning and archive work that now ships alongside the fix above.

### Added
- **[ROADMAP.md](ROADMAP.md)** covering the two things that actually need
  designing:
  - **Supporting AWS Bedrock and Anthropic side by side.** Today one install
    serves one billing pathway; `ccauth` overwrites `.env` when you switch, so the
    previous configuration is lost. Notes why this isn't a simple toggle — model
    IDs differ between Bedrock and the Anthropic API, Bedrock access is per
    account/region/model, and credential lifetimes differ. Phased plan starting
    with saved profiles.
  - **Running several instances with different sign-ins.** Target design, the
    verified blockers, and a working manual recipe for doing it today.
- **`archive/`** holding the nine documents retired in v1.3.0 plus the dead
  `install-shortcut.sh`, each with a banner marking it superseded, and an index
  explaining why it went and what replaced it. Previously these existed only in
  git history. Excluded from the Docker build context and not fetched by the
  installers.

### Verified while writing the roadmap
Recorded here because it constrains future work:
- `container_name: cc-install` is absolute and **not** namespaced by Compose
  project, so a second instance fails with a name conflict. Confirmed by running
  two projects from one compose file.
- Named volumes **are** namespaced by project automatically (`cc-bedrock_cfg`,
  `cc-anthropic_cfg`), so `claude-config` and `code-server-data` isolate per
  instance for free — sign-ins won't bleed across.
- Three instances coexist once `container_name` is dropped and the port is
  parameterized, sharing one image.
- Two latent hazards for multi-instance use, now documented: `uninstall.{sh,ps1}`
  hardcodes `cc-install:latest` and `cc-install_claude-config`, so it would remove
  the *shared* image and possibly the wrong volume; and `setup-shortcuts` uses
  fixed shortcut names, so a second install silently repoints every `cc*` command
  at itself.

### Changed
- `docs/.DS_Store` removed; `archive/` added to `.dockerignore`.
- README and `docs/DEVELOPMENT.md` link the roadmap; `CLAUDE.md` file map updated.

## [1.3.3] - 2026-08-24

### Changed — the browser IDE now publishes on 8088, not 8080

8080 on the host is heavily contended: local dev servers and local LLM servers
both default to it. A collision there is worse than an inconvenience, because
tooling that decides "is my server running?" by probing the port will misreport,
and some of it then `kill`s whatever holds that port — which would take out this
container's port forward.

The container still listens on 8080 internally; only the host-side publish moved.
`ccvscode` reads the published port back from Compose, so it opens the right URL
with no further change.

**Existing installs:** after `ccupdate`, your IDE moves from
`http://localhost:8080` to `http://localhost:8088`. `ccvscode` opens it for you;
update any bookmark. If you'd rather stay on 8080, see
`docker-compose.override.yml.example` — and note the `!override` tag is required.

`ccdiagnose` no longer hardcodes 8080; it checks whichever port the install
actually publishes.

### Fixed

- `docker-compose.override.yml.example` now documents 8088 as the default, and its
  "change the port" example uses 8090 so it isn't a no-op.

### Documentation

- The Visual Guide (HTML + PDF) is regenerated at 1 page with the new port.
- `docs/DEVELOPMENT.md` records that the PDF render is **non-deterministic** —
  the same HTML produced a 2-page PDF on one run and 1 page on the next. Anyone
  regenerating it must assert the page count, not assume it.

## [1.3.2] - 2026-08-24

### 🐛 Fixed — VS Code extensions could not be installed (regression in 1.3.0)

The `code-server-data` volume added in 1.3.0 was mounted at
`/home/claudeuser/.local/share/code-server`, a path that **did not exist in the
image**. Docker creates such a mountpoint as `root:root`, so `claudeuser` (UID
1000) was locked out of its own data directory. Consequences:

- code-server threw `EACCES: permission denied, mkdir .../coder-logs` on startup
  and failed to create its IPC socket
- **every VS Code extension install failed**, including the Claude Code extension

Fixed in two parts, because one alone is insufficient:

1. **`Dockerfile`** creates the directory as `claudeuser` before any volume mounts
   over it, so Docker seeds new volumes with the right ownership.
2. **`scripts/container/entrypoint.sh`** probes the directory on every start and
   repairs it with `sudo chown` if it isn't writable. Needed because Docker never
   re-seeds a volume that already has content — a rebuild alone does **not** fix an
   existing install. The same check now guards `~/.claude`.

Verified: a fresh volume installs extensions correctly; a deliberately
root-owned non-empty volume is repaired on start, after which code-server starts
with zero `EACCES` and extensions install.

**If you hit this:** `ccrestart` repairs it immediately; `ccupdate` prevents it
recurring.

### ✨ Added

- **`ccdiagnose` checks the browser IDE.** Reports whether the extensions
  directory is writable, how many extensions are installed, and whether the Claude
  Code extension is present — so this class of failure is visible rather than
  mysterious.
- **Optional pre-installed Claude Code extension** for IT/fleet builds:
  `CC_INSTALL_VSCODE_EXTENSION=1` in `.env` then `ccupdate`, or
  `docker compose build --build-arg INSTALL_VSCODE_EXTENSION=1`.

  **Off by default, deliberately:** it adds **~670 MB**. The extension ships its
  own per-platform Claude binary (~326 MB in `resources/native-binary/`), which
  duplicates the CLI this image already installs — both were 2.1.241 when measured.
  It also only reaches installs whose volume is still empty, since Docker seeds a
  volume once. Installing from the Extensions panel takes seconds and works on any
  install, so that's the documented path.

### 📚 Documentation

New extension guidance in `README.md`, `docs/INSTALL_GUIDE.md` and
`docs/QUICK_REFERENCE.md`, covering the thing that surprises people:
**code-server uses [Open VSX](https://open-vsx.org), not the Microsoft
Marketplace**, because Microsoft's terms restrict its marketplace to Microsoft
products. The Claude Code extension *is* on Open VSX as `Anthropic.claude-code`
and installs normally; it's optional, since `claude` in the IDE terminal works
without it.

`docs/DEVELOPMENT.md` gains the volume-ownership trap as a documented gotcha —
any future volume mount needs the same treatment.

### 🗂 Also

- `ROADMAP.md` and `archive/` added (see the previous entry, now folded into this
  release), plus `docs/plans/auth-first-instances.md` — the implementation plan for
  the auth-first, instance-aware installer.

## [1.3.1] - 2026-08-24

Follow-ups from reviewing the new one-page Visual Guide against the shipped code.

### Added
- **`ccbackup`** — back up your workspace from anywhere. Every other maintenance
  task had a `cc*` shortcut; backup was the one that still required `cd cc-install`
  first, which quietly broke the "works from anywhere" promise in the docs.

### Changed
- **Build-time estimates are consistent at 10-15 minutes.** `install.sh`/`.ps1`
  said 5-10 while the README said 10-15, and `update.sh` disagreed with both. A
  `--no-cache` rebuild is the same work as a first build, so both now quote the
  same figure.
- `ccauth` Bedrock instructions in the docs and Visual Guide now mention that key
  input is hidden as you type, and that two further prompts (session token,
  Bedrock model ID) can be skipped with Enter. Following the old wording left
  users staring at unexplained prompts.
- Backup docs lead with `ccbackup`. Restore deliberately stays path-invoked — it
  overwrites files, so it should be run deliberately from the install directory.
- README's guide table pointed at `ClaudeCodeInstallGuide.pdf`/`.html`, which no
  longer exist; it now points at the Visual Guide.

### Documentation
- **New "Working on your own projects" section** (README, INSTALL_GUIDE,
  QUICK_REFERENCE, and the Visual Guide): how to open a folder from your computer
  in Claude Code or the browser editor. Verified against Docker rather than
  assumed — dropping a folder into `workspace/` appears instantly with no restart;
  a second host folder can be mounted read-write via
  `docker-compose.override.yml` and merges with `workspace/`; and **symlinks or
  aliases pointing outside `workspace/` do not work** — the link is visible inside
  the container but its files read as "No such file or directory", which is a
  confusing trap worth naming explicitly.
- Visual Guide (HTML + PDF) regenerated: `ccbackup` added, "Your files" moved into
  "Using it day to day", revision line now tracks the version.

## [1.3.0] - 2026-08-24

Sign-in actually works now, several scripts that were silently broken are fixed,
and updates finally reach existing installs.

### 🔑 Credentials — the headline change

Previously there was **no working way to give the container credentials.** The
README told users to `export AWS_ACCESS_KEY_ID=...` on the host, but
`docker-compose.yml` passed no environment variables through, so those exports
did nothing. Nothing at all explained how someone using `ccvscode` (the browser
IDE) was supposed to sign in.

- **New `ccauth` command** (`scripts/installers/setup-credentials.{sh,ps1}`).
  Interactive, three options: your Claude account, an Anthropic API key, or UVA
  Amazon Bedrock. Writes `.env` (`chmod 600`) and restarts the container.
- **Options are mutually exclusive.** Picking one clears the others. A leftover
  `ANTHROPIC_API_KEY` silently overriding an account login — and billing the
  wrong place — was the most likely way to get confused.
- **`docker-compose.yml` now reads `.env`** via `env_file`, so credentials reach
  both `ccdocker` and `ccvscode`.
- **New [docs/CREDENTIALS.md](docs/CREDENTIALS.md)**, including a dedicated
  section on signing in from inside the browser IDE.
- **`ccvscode` now explains itself.** It prints how to reach Claude Code in the
  IDE (**Terminal → New Terminal**, then `claude`), reports whether you're
  already signed in, and writes a `START-HERE.md` into your workspace.
- **`ccdocker` warns on first run** if no credentials are configured, and points
  at `ccauth` rather than letting you paste a key into a prompt where it won't
  persist.
- `.env.example` and `docker-compose.override.yml.example` added; `.env` was
  already gitignored.

### 🔒 Security

- **The browser IDE is no longer exposed to your network.** The port was
  published on `0.0.0.0:8080` while code-server ran with `--auth none` — anyone
  on the same network had an unauthenticated shell in the container. It's now
  bound to `127.0.0.1:8080`. Verified: reachable on loopback, refused on the LAN
  address.
- Optional `CC_VSCODE_PASSWORD` in `.env` enables `--auth password` for anyone
  who does need to expose the port.
- `ccdiagnose` now reports the port binding and warns if it's exposed without a
  password, plus flags loose `.env` permissions.
- New [SECURITY.md](SECURITY.md) documenting the posture and the deliberate
  trade-offs (passwordless sudo in the container, piped install scripts,
  unpinned third-party skills).

### 🐛 Bug fixes

- **`diagnose.sh` died halfway through.** It used `local` outside a function (a
  hard error that aborts under `set -e`) and GNU-only `df -BG`, which fails on
  macOS. The Workspace, Volumes, Image and Version sections never printed. The
  tool the README tells you to run first was broken.
- **`check-update.sh` exited 1 when run directly**, referencing a `local`
  variable that was out of scope at the top level — an unbound-variable abort
  under `set -u`.
- **Windows `ccdocker` ran `claude claude`.** `run_claude.ps1` passed its
  defaulted `$Command` through unconditionally, so a bare launch sent the literal
  string "claude" to Claude Code as a prompt.
- **Every install permanently reported "update available."** The installers
  fetched a hardcoded list of files that never included `VERSION`, so
  `check-update` compared against a fallback of `1.0.0` forever.
- **The macOS app launcher went to the wrong directory.** `setup-shortcuts.sh`
  built it with a quoted heredoc, baking in the literal text `$INSTALL_DIR`,
  which expanded to nothing at runtime.
- **Shortcut setup could fail on Windows and leave you with no commands.**
  `[Environment]::GetFolderPath('MyDocuments')` returns an empty string when
  Documents is redirected (OneDrive on managed machines); `Join-Path ""` threw and
  aborted all setup. Now guarded, with per-profile error handling.
- **Pressing Enter at the `ccauth` menu silently did nothing** while printing the
  closing "all done" message, because PowerShell's `switch` skips every clause —
  `default` included — on a null value. Input is validated before the switch.
- `.env` written on Windows could carry a UTF-8 BOM (`Add-Content -Encoding utf8`
  adds one on PowerShell 5.1) and CRLF endings. Docker Compose strips neither, so
  the first variable was read as `<BOM>NAME` and ignored. Now written BOM-free
  with LF.

### 🔄 Updates now reach existing installs

- **`update.sh` / `update.ps1` refresh the cc-install files too**, not just the
  Docker image. Previously they only rebuilt, so a bug fixed in a launcher could
  never reach anyone who had already installed — including every fix listed
  above.
- They also re-run `setup-shortcuts`, so newly added commands appear on existing
  installs, and clear the 24-hour version-check cache.
- **`setup-shortcuts` now always rewrites.** It used to skip entirely if
  `ccvscode` already existed, meaning existing users never received new
  shortcuts. The PowerShell version replaces a marked block in place, preserving
  the rest of your profile and removing pre-1.3.0 unmarked blocks.
- **Installers download the whole repo as an archive** rather than a hardcoded
  file list, which is what had drifted and lost `VERSION`. Adding a file no longer
  requires an installer change. `CC_INSTALL_REF` pins a tag or branch.
- **This also properly fixes the Windows line-ending problem from 1.2.1.** The
  `.gitattributes` `eol=crlf` rule added then only applies on *checkout*, so it
  fixed `git clone` but not installed users — the installer was fetching files
  individually from `raw.githubusercontent.com`, which serves the raw blob with
  **LF**. GitHub's archive endpoint does apply the attribute, so the new download
  path delivers CRLF. Verified against the live repo: archive → CRLF, raw → LF.
  As a second layer, every `.ps1` was confirmed to parse with LF *and* CRLF
  endings, so a stray LF is no longer fatal either.

### 📦 Versions

- **code-server 4.117.0 → 4.133.0**
- **Node.js 20 → 22 LTS** (20 is end-of-life)
- Both are now `Dockerfile` build args (`CODE_SERVER_VERSION`, `NODE_MAJOR`)
- Added `ripgrep` (much faster file search for Claude Code), `less`, `unzip`
- Verified in a real build: Claude Code 2.1.241, code-server 4.133.0, Node 22.23.2

### ✨ Also

- **Bundled skills survive updates.** They were baked into `~/.claude/skills`,
  which is a Docker volume — and a volume is seeded from the image only once, so
  the skills were frozen at each user's very first build forever. They now live
  in `/opt/cc-install/skills` and a new container entrypoint copies them in on
  every start, leaving skills you added yourself alone. Verified: 34 skills
  present in the volume after a fresh start.
- New `code-server-data` volume, so VS Code extensions and settings survive
  container recreation.
- New shortcuts: `ccauth`, `ccdiagnose`, `ccupdate`.
- `init: true` for proper process reaping.
- `run_vscode` reads the published port back from Compose instead of assuming
  8080, so a `docker-compose.override.yml` port change still opens the right URL,
  and polls for readiness instead of a blind `sleep`.
- `run_vscode` no longer tails empty container logs on exit — the container runs
  `sleep infinity`, so there was never anything to show.
- `run_claude` accepts an `auth` subcommand.

### 📚 Documentation

Cut from ~4,500 lines across 17 files to a maintained set. Removed nine
point-in-time documents that had gone stale: `INDEX.md`, `PROJECT_STATUS.md`,
`ROADMAP.md`, `SECURITY_AUDIT.md`, `docs/README.md`, `docs/PROJECT_SUMMARY.md`,
`docs/TEST_RESULTS.md`, `docs/WINDOWS_FIX_2026-05-28.md` and
`docs/SKILLS_INSTALLATION.md` — their durable content is folded into
`SECURITY.md`, `docs/DEVELOPMENT.md` and this changelog.

Also removed `scripts/installers/install-shortcut.sh`, dead code that created an
undocumented `cc` command superseded by `setup-shortcuts.sh`.

`README.md`, `docs/INSTALL_GUIDE.md` and `docs/QUICK_REFERENCE.md` rewritten
around `ccauth` and the browser-IDE workflow. `ATTRIBUTION.md` now credits the
three bundled skill repositories, which it had omitted.

### ⬆️ Upgrading from 1.2.x

```bash
cd cc-install
./scripts/maintenance/update.sh     # or update.ps1 on Windows
```

Then, in a new terminal window:

```bash
ccauth
```

Your `workspace/`, settings and any existing sign-in are preserved. Running
`ccauth` is worth doing even if Claude Code already works — it makes your
credentials persist properly instead of living only in the current container.

## [1.2.2] - 2026-07-22

### 🐛 Critical Bug Fix

#### `ccdocker` / `ccvscode` "command not found" after install (macOS/Linux)
- **Issue**: After a successful install, users who typed `ccdocker` got
  `zsh: command not found: ccdocker`. The shortcuts were created in
  `~/.local/bin`, but that directory was not on the user's `PATH`.
- **Root Cause**: `setup-shortcuts.sh` only *printed* the manual step to add
  `~/.local/bin` to `PATH` — non-technical users never ran it. It also detected
  the rc file from `$ZSH_VERSION`/`$BASH_VERSION`, which describe the **bash
  process running the installer**, not the user's real login shell.
- **Fix**: `setup-shortcuts.sh` now **automatically** appends
  `export PATH="$HOME/.local/bin:$PATH"` to the correct startup file for the
  user's login shell (chosen from `$SHELL`: `.zshrc`, or `.bash_profile` on
  macOS / `.bashrc` on Linux). It's idempotent — reruns won't duplicate the
  line — and tells the user to open a new terminal (or `source` the file).
- **Note**: Windows was unaffected — its shortcuts are PowerShell profile
  functions, which don't depend on `PATH`.

**To recover an existing macOS install without reinstalling:**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```
(Or just launch from the folder: `cd ~/cc-install && ./claude`.)

## [1.2.1] - 2026-05-28

### 🐛 Critical Bug Fix

#### Windows PowerShell Parsing Error
- **Issue**: PowerShell scripts failed to parse with error: "The string is missing the terminator" 
  - Error occurred at `run_vscode.ps1:103` when users ran `ccvscode` after installation
  - Affected all `.ps1` files in the project
  
- **Root Cause**: PowerShell scripts were committed with Unix (LF) line endings, but PowerShell on Windows expects Windows (CRLF) line endings
  - This caused quote parsing issues and syntax errors
  - Files downloaded via installer had LF endings from GitHub
  
- **Fix**: Added `.gitattributes` to enforce CRLF line endings for all PowerShell files
  - `*.ps1 text eol=crlf` ensures proper endings on all platforms
  - Future checkouts and downloads will have correct endings
  - Shell scripts (`.sh`) remain LF via `*.sh text eol=lf`

### 📦 Deployment

All changes pushed to: `https://github.com/wmo4buva/cc-install`

Users who previously installed can update by running:
```powershell
cd cc-install
.\scripts\maintenance\update.ps1
```

Or re-run the one-line installer to get the fixed version.

### 🙏 Credits

- Issue reported by UVA faculty user testing on Windows
- Built with Claude Sonnet 4.5

---

## [1.2.0] - 2026-05-27

### 🎉 Major Release: Windows & macOS Reliability + Documentation Overhaul

This release fixes critical installation blockers on Windows and macOS, dramatically improves documentation for non-technical faculty, and ensures cross-platform compatibility.

### 🐛 Critical Bug Fixes

#### Windows Issues Fixed
- **PowerShell 7 vs 5.1 Profile Mismatch** 
  - Root cause: Installer forced `powershell.exe` (5.1) but users ran PowerShell 7+ (default in Windows Terminal)
  - Fix: Now writes shortcuts to BOTH profile locations
  - Result: `ccdocker`/`ccvscode` work regardless of PowerShell version
  
- **Corrupted Emoji Characters**
  - Syntax errors in `setup-shortcuts.ps1` prevented script execution
  - Replaced emoji with `[SUCCESS]` and `[WARNING]` text
  - Script now parses correctly on all systems

- **PowerShell Execution Policy Blocking**
  - Scripts blocked by default Restricted/Undefined policy
  - Now detects and sets RemoteSigned policy before running
  - Uses `-ExecutionPolicy Bypass` flag for reliability

- **Repository URL Mismatch**
  - Installer pointed to old `BattenIT/cc-install` repo (404 errors)
  - Updated to correct `wmo4buva/cc-install` throughout
  - Fixed file paths to match new directory structure

- **Missing Windows Wrapper Scripts**
  - Created `claude.cmd` and `vscode.cmd` for root-level launching
  - Work from installation directory without full paths
  - Cross-platform compatibility with bash wrappers

#### macOS Issues Fixed
- **TTY Hang on Installation**
  - Old: `curl ... | bash` could hang on TTY input
  - New: `curl ... -o install.sh && bash install.sh` (reliable)

- **setup-shortcuts.sh Not Downloaded**
  - macOS users never got shell aliases
  - Now downloads and configures automatically
  - `ccdocker`/`ccvscode` work after `source ~/.zshrc`

- **Incorrect Success Messages**
  - Showed `./run_claude.sh` (wrong path)
  - Now shows `cd cc-install && ./claude` (correct)
  - Clear instructions about working directory

### ✨ Added

#### Windows-Specific Features
- **setup-shortcuts.ps1**: PowerShell profile configuration
  - Adds functions: `ccdocker`, `ccvscode`, `ccstop`, `cclogs`, `ccrestart`
  - Works from anywhere after PowerShell restart
  - Configures both 5.1 and 7+ profiles simultaneously

- **Windows .cmd Wrappers**
  - `claude.cmd` and `vscode.cmd` in repository root
  - Wrap PowerShell launchers for easy execution
  - Work without full paths from install directory

- **Execution Policy Management**
  - Automatic detection of restricted policies
  - Sets RemoteSigned for CurrentUser if needed
  - Clear error messages if admin rights required

#### Documentation Improvements

**Step 1: Docker Installation**
- Added realistic time estimates (10-15 min first time, 2 min if installed)
- Explained what WSL is (Windows Subsystem for Linux)
- Added `wsl --status` check command before updating
- Step-by-step WSL installation with admin PowerShell instructions
- Docker download guidance:
  - How to check Windows system type (x64 vs ARM64)
  - How to check Mac chip (Apple Silicon vs Intel)
  - Which installer to download for each platform
  - What options to select during installation

**Step 2: Run Installation Command**
- macOS: Added note about Terminal permission dialog
- Windows: Detailed PowerShell launch instructions
  - Keyboard shortcuts: Windows + X → Terminal
  - Clarified PowerShell vs Command Prompt requirement
  - Note that `irm | iex` only works in PowerShell

**Step 3: Launch Instructions**
- Prominent warning to restart PowerShell/Terminal
- Explanation that shortcuts only work after restart
- Fallback commands if shortcuts don't work

**Time Estimates Throughout**
- Removed misleading "Quick Start (5 Minutes)" heading
- Added realistic breakdown:
  - Docker running: 10-15 minutes
  - Install Docker first: 20-30 minutes
  - WSL + Docker + restart: 30-45 minutes
- Helps faculty plan time appropriately

### 🔄 Changed

#### Installation Process
- Both installers now 5-step process (added Step 5: Setup shortcuts)
- Consistent step numbering across platforms
- Better error handling with actual error messages (not silent failures)
- Fallback instructions when setup fails

#### Success Messages
- Windows: Prominent "Close and open NEW PowerShell" warning
- macOS: Clear `cd cc-install` instruction before commands
- Both: Correct file paths matching actual directory structure
- Useful commands show full paths

#### File Structure
- Added installer scripts to download lists
- Both platforms download setup-shortcuts scripts
- Cross-platform compatibility maintained

### 📚 Documentation Updates

**README.md**
- Complete rewrite of Quick Start section
- Realistic time expectations
- WSL explanation and setup
- Docker download guidance
- Platform-specific instructions throughout
- Restart reminders for shortcuts

**CLAUDE.md**
- Updated with new Windows features
- Documented PowerShell profile setup
- Cross-platform wrapper scripts

### 🚀 Testing & Validation

- Tested on Windows 11 with PowerShell 7.5.5
- Tested execution policy scenarios
- Validated profile writing to both 5.1 and 7+ locations
- Confirmed shortcuts work after PowerShell restart
- macOS installation validated with download-then-run
- Both platforms: verified directory structure and file paths

### 📦 Deployment

All changes pushed to: `https://github.com/wmo4buva/cc-install`

**Installation commands UPDATED:**

**macOS/Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.sh -o install.sh && bash install.sh
```

**Windows:**
```powershell
irm https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.ps1 | iex
```

### 🙏 Credits

- Windows testing and feedback from UVA faculty members
- Issue reports that uncovered PowerShell version mismatch
- Built with Claude Sonnet 4.5

### 🔗 Related Commits

- `ba24aa4` - Critical fix: Update repo URLs and file paths in installers
- `52de080` - Document pre-installed Claude Code skills in README
- `faa5cb4` - Major Windows support improvements and cross-platform fixes
- `1e5f0aa` - Fix PowerShell execution policy blocking shortcut setup
- `ccfc4ad` - Fix corrupted emoji causing setup-shortcuts.ps1 syntax error
- `65de649` - Fix PowerShell 7 vs 5.1 profile compatibility + improve docs
- `46784f0` - Fix macOS installation issues and improve UX

---

## [1.1.0] - 2026-05-26

### 🎉 Major Release: UX Improvements & Auto-Update

This release focuses on making Claude Code accessible to novice users with improved error messages, automatic update notifications, and easy-to-use launcher commands.

### ✨ Added

#### Easy Launch System
- **Shell Aliases**: Automatic setup of system-wide commands
  - `ccdocker` - Launch Claude Code from anywhere
  - `ccvscode` - Launch VS Code Server from anywhere
  - `ccstop` - Stop the container
  - `cclogs` - View container logs
- **macOS App**: Creates `~/Applications/Claude Code.app` for GUI launch
- **Post-Install Setup**: Automated via `setup-shortcuts.sh`

#### Auto-Update Mechanism
- **Version Checking**: Silent update checks on every launch
- **Smart Caching**: 24-hour cache to avoid excessive network calls
- **User Notifications**: Clear update prompts when new version available
- **check-update.sh**: Standalone script for manual version checks
- **VERSION file**: Semantic versioning tracking

#### Diagnostic Tools
- **diagnose.sh**: Comprehensive system diagnostics
  - Docker installation and daemon status
  - Container health and resource usage
  - Port availability checking
  - Disk space monitoring
  - Workspace and volume verification
  - Common issue detection with solutions

#### Enhanced Error Messages
- **Contexual Help**: OS-specific instructions (macOS vs Linux)
- **Step-by-Step Solutions**: Clear numbered steps for common issues
- **Visual Formatting**: Better use of colors and boxes
- **Diagnostic Links**: Points users to diagnostic tool when needed
- **Friendly Language**: Non-technical explanations for faculty

#### Pre-Installed Skills
- **Anthropic Official Skills**: Example skills and utilities
- **Andrej Karpathy Guidelines**: AI/ML coding best practices
- **Superpowers by Jesse Vincent**: Advanced productivity features
- Automatically installed during Docker image build
- No manual configuration required

### 🔄 Changed

#### README.md Redesign
- **Quick Start Section**: 3-step installation with visual tables
- **Prominent Installation Commands**: Platform-specific tables
- **Emoji Navigation**: Better visual scanning
- **Time Estimates**: Clear expectations (5-10 minutes)
- **Bedrock Priority**: Amazon Bedrock listed first for UVA users

#### First-Time Setup Documentation
- **Bedrock First**: AWS credentials prominently featured
- **Benefits Explained**: Why use Bedrock (billing, compliance)
- **Environment Variables**: Example configuration provided
- **Anthropic API Secondary**: Listed as "Alternative" for personal use

#### Installation Script (`install.sh`)
- Calls `setup-shortcuts.sh` automatically post-install
- Better error messages with visual formatting
- Mentions Bedrock in first-run messaging
- Updated success message with new commands

#### Launcher Scripts
- Auto-update checks on every launch (silent, non-blocking)
- Enhanced Docker error messages with step-by-step help
- OS-specific troubleshooting instructions
- Reference to diagnostic tool

#### Dockerfile
- Pre-installs Claude Code skills from GitHub
- Clones official skill repositories during build
- Skills ready to use on first launch
- Cleaned up temporary files to minimize image size

### 📚 Documentation

- **CHANGELOG.md**: This file - comprehensive change tracking
- **VERSION**: Semantic version number (1.1.0)
- Updated ROADMAP.md to reflect completed items
- Enhanced CLAUDE.md with new features

### 🐛 Fixed

- Installation URLs updated to `wmo4buva/cc-install`
- Proper error handling in all scripts
- Better cross-platform compatibility

### 🚀 Roadmap Items Completed

From ROADMAP.md v1.1.0 goals:
- ✅ Pre-Install Claude Code Skills (Item #1)
- ✅ Auto-Update Mechanism (Item #2)
- ✅ Improved Error Messages (Item #3)
- ✅ Easy Launch Shortcuts (New item)

### 📦 Deployment

All changes pushed to: `https://github.com/wmo4buva/cc-install`

One-line installation commands remain the same:
- **macOS/Linux**: `curl -fsSL https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.sh | bash`
- **Windows**: `irm https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.ps1 | iex`

### 🙏 Credits

- Inspired by [DAAF Project](https://github.com/DAAF-Contribution-Community/daaf)
- Skills from Anthropic, Andrej Karpathy, and Jesse Vincent
- Built with Claude Sonnet 4.5

---

## [1.0.0] - 2026-05-24

### Initial Release

- Docker-based Claude Code installation
- VS Code Server integration
- macOS/Linux installation script
- Windows PowerShell installation script
- Launcher scripts for CLI and VS Code
- Maintenance scripts (update, backup, restore, uninstall)
- Comprehensive documentation
- Workspace persistence
- DAAF attribution

---

**Format**: Based on [Keep a Changelog](https://keepachangelog.com/)
**Versioning**: [Semantic Versioning](https://semver.org/)
