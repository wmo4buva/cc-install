# Changelog

All notable changes to the Claude Code Faculty Installer (cc-install) project.

## [1.1.0] - 2026-05-26

### 🎉 Major Release: UX Improvements & Auto-Update

This release focuses on making Claude Code accessible to novice users with improved error messages, automatic update notifications, and easy-to-use launcher commands.

### ✨ Added

#### Easy Launch System
- **Shell Aliases**: Automatic setup of system-wide commands
  - `claude-start` - Launch Claude Code from anywhere
  - `claude-vscode` - Launch VS Code Server from anywhere
  - `claude-stop` - Stop the container
  - `claude-logs` - View container logs
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
