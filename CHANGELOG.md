# Changelog

All notable changes to the Claude Code Faculty Installer (cc-install) project.

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
