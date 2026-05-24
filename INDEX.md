# Claude Code Faculty Installer (cc-install)

**Quick Start:** `./install-shortcut.sh` then use `ccdocker` command

## 📁 Project Structure

```
cc-install/
│
├── 📖 Documentation (Start Here!)
│   ├── README.md ...................... Main user guide (installation, usage)
│   ├── docs/README.md ................. Documentation index
│   ├── docs/QUICK_REFERENCE.md ........ One-page command reference
│   ├── docs/DEVELOPMENT.md ............ Developer guide & project history
│   ├── docs/PROJECT_SUMMARY.md ........ Implementation summary
│   └── docs/TEST_RESULTS.md ........... Test report
│
├── 🐳 Docker Configuration
│   ├── Dockerfile ..................... Container image definition
│   ├── docker-compose.yml ............. Container orchestration
│   └── .dockerignore .................. Build exclusions
│
├── 🚀 Quick Launchers (Root Level)
│   ├── claude ......................... Launch Claude Code CLI (simple!)
│   └── vscode ......................... Launch VS Code Server (simple!)
│
├── 📁 scripts/
│   ├── installers/
│   │   ├── install.sh ................. One-line installer (macOS/Linux)
│   │   ├── install.ps1 ................ One-line installer (Windows)
│   │   └── install-shortcut.sh ........ Install `ccdocker` command
│   ├── launchers/
│   │   ├── run_claude.sh / .ps1 ....... Full Claude Code launcher
│   │   └── run_vscode.sh / .ps1 ....... Full VS Code launcher
│   └── maintenance/
│       ├── update.sh / .ps1 ........... Update to latest versions
│       ├── backup.sh / .ps1 ........... Backup workspace
│       ├── restore.sh / .ps1 .......... Restore from backup
│       └── uninstall.sh / .ps1 ........ Complete removal
│
├── 📝 Attribution & Legal
│   ├── ATTRIBUTION.md ................. Credits to DAAF and third-party software
│   └── CLAUDE.md ...................... Developer guidance for this repository
│
└── 💾 Data Directories (gitignored)
    ├── workspace/ ..................... User files (persistent)
    └── backups/ ....................... Workspace backups
```

## 🎯 Quick Links by Role

### 👨‍🏫 I'm a Faculty Member
**I want to install and use Claude Code**

1. **Install:** [README.md](README.md) → Prerequisites & Installation
2. **Use:** [README.md](README.md) → Usage section
3. **Reference:** [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)

### 🔧 I'm IT Support
**I need to help faculty with issues**

1. **Understand the tool:** [README.md](README.md) → Architecture
2. **Troubleshooting:** [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) → Troubleshooting
3. **Support guide:** [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) → Support & Maintenance

### 👨‍💻 I'm a Developer
**I want to contribute or modify this project**

1. **Architecture:** [CLAUDE.md](CLAUDE.md)
2. **Development guide:** [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
3. **Testing:** [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md)

### 📊 I'm a Stakeholder
**I want to understand what was delivered**

1. **Overview:** [README.md](README.md) → What This Does
2. **Implementation:** [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)
3. **Quality:** [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md)

## ⚡ Quickest Quick Start

```bash
# Install the shortcut (one time only)
./install-shortcut.sh

# Now use it anywhere:
ccdocker              # Launch Claude Code
ccdocker bash         # Open bash shell
ccdocker logs         # View logs
ccdocker stop         # Stop container
```

Or use scripts directly:
```bash
./claude              # Launch Claude Code (easiest!)
./vscode              # Launch VS Code in browser
```

## 📚 Documentation Summary

| Document | Purpose | Who Should Read |
|----------|---------|-----------------|
| [README.md](README.md) | User guide (installation, usage, troubleshooting) | Everyone (start here) |
| [CLAUDE.md](CLAUDE.md) | Developer technical reference | Developers, IT |
| [ATTRIBUTION.md](ATTRIBUTION.md) | Credits and licenses | Legal, Open Source contributors |
| [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) | One-page command cheat sheet | All users (bookmark this) |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Development history and decisions | Developers, Contributors |
| [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md) | Implementation details | Stakeholders, Project Managers |
| [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md) | Test report and quality assurance | QA, Developers |
| [docs/README.md](docs/README.md) | Documentation index | Anyone looking for specific info |

## 🔑 Key Features

- ✅ **One-line installation** for macOS and Windows
- ✅ **Docker-based** isolation (no system pollution)
- ✅ **Persistent workspace** (files survive restarts)
- ✅ **Two interfaces:** CLI + browser-based VS Code
- ✅ **Simple commands:** `ccdocker` to launch
- ✅ **Easy maintenance:** update, backup, restore scripts
- ✅ **Well documented:** 47 KB of comprehensive docs

## 🎉 Project Status

**Status:** ✅ Testing & Refinement Phase  
**Version:** 1.0.0 (pre-release)  
**Last Updated:** May 24, 2026  
**Ready For:** Faculty testing, GitHub distribution

**Tested Components:**
- ✅ Docker build (1.43 GB image)
- ✅ Claude Code v2.1.148
- ✅ code-server v4.117.0
- ✅ Workspace persistence
- ✅ Launcher scripts
- ✅ Container lifecycle

**Pending:**
- ⏳ Windows PowerShell script testing
- ⏳ GitHub repository creation
- ⏳ Full installation flow test
- ⏳ Faculty user testing

## 🚀 Distribution Checklist

Before releasing to faculty:

- [x] Core functionality tested
- [x] Documentation complete
- [x] Scripts created (bash + PowerShell)
- [x] Test report written
- [ ] GitHub repository created
- [ ] Installation URLs updated
- [ ] Windows testing completed
- [ ] Faculty pilot testing

## 💡 Quick Tips

- **New users:** Read [README.md](README.md) from top to bottom
- **Returning users:** Bookmark [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)
- **Developers:** Start with [CLAUDE.md](CLAUDE.md)
- **Support staff:** Keep [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) handy

## 🆘 Getting Help

1. **Check documentation first:** See links above
2. **Troubleshooting:** [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) → Troubleshooting
3. **Still stuck?** GitHub Issues (after repo creation)

## 🏆 Credits

Inspired by [DAAF (Data Analysis Agent Framework)](https://github.com/DAAF-Contribution-Community/daaf)

See [ATTRIBUTION.md](ATTRIBUTION.md) for full credits and licenses.

---

**Made with ❤️ for faculty members who want to explore AI-assisted coding without the technical setup hassle.**

**Built by:** FBS IT Team  
**Powered by:** Docker + Claude Code + code-server  
**License:** See [ATTRIBUTION.md](ATTRIBUTION.md)
