# Changelog

All notable changes to the Claude Code Installer (cc-install) project.

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
