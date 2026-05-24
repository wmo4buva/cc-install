# Development Guide

This document tracks the development process, decisions made, and how to work with this project.

## Project History

### Creation Date
**May 22-24, 2026**

### Inspiration
This project is inspired by [DAAF (Data Analysis Agent Framework)](https://github.com/DAAF-Contribution-Community/daaf), which pioneered the Docker-based installation approach for AI tools.

### Goal
Make Claude Code accessible to non-technical faculty members through a simple, Docker-based installation that requires only Docker Desktop as a prerequisite.

## Development Timeline

### Phase 1: Initial Setup (May 22, 2026)
- Created project structure
- Developed Dockerfile with Claude Code + VS Code Server
- Created docker-compose.yml for orchestration
- Built installation scripts (install.sh, install.ps1)

### Phase 2: Launcher Scripts (May 22, 2026)
- Created run_claude.sh/ps1 (launch Claude Code CLI)
- Created run_vscode.sh/ps1 (launch browser-based IDE)
- Added support for multiple commands (bash, logs, stop, restart)

### Phase 3: Helper Scripts (May 22, 2026)
- Created update.sh/ps1 (rebuild with latest versions)
- Created backup.sh/ps1 (backup workspace)
- Created restore.sh/ps1 (restore from backup)
- Created uninstall.sh/ps1 (clean removal)

### Phase 4: Documentation (May 22, 2026)
- Comprehensive README.md for end users
- ATTRIBUTION.md crediting DAAF
- CLAUDE.md for developers
- PROJECT_SUMMARY.md tracking implementation

### Phase 5: Testing & Fixes (May 22, 2026)
- Fixed Claude Code install URL (404 issue)
- Removed obsolete docker-compose version attribute
- Tested all core functionality
- Created TEST_RESULTS.md

### Phase 6: Usability Improvements (May 24, 2026)
- Created install-shortcut.sh for easy command access
- Added `ccdocker` command for system-wide access
- Organized project structure with docs/ folder

## Project Structure

```
cc-install/
├── .git/                       # Git repository
├── .github/                    # GitHub Actions (future)
├── docs/                       # Additional documentation
│   ├── PROJECT_SUMMARY.md      # Implementation summary
│   ├── TEST_RESULTS.md         # Test report
│   └── DEVELOPMENT.md          # This file
├── workspace/                  # User workspace (gitignored)
├── backups/                    # Workspace backups (gitignored)
│
├── Dockerfile                  # Container image definition
├── docker-compose.yml          # Container orchestration
├── .dockerignore              # Build context exclusions
├── .gitignore                 # Git exclusions
│
├── install.sh                 # macOS/Linux installer
├── install.ps1                # Windows installer
├── install-shortcut.sh        # System command installer
│
├── run_claude.sh              # Claude Code launcher (macOS/Linux)
├── run_claude.ps1             # Claude Code launcher (Windows)
├── run_vscode.sh              # VS Code Server launcher (macOS/Linux)
├── run_vscode.ps1             # VS Code Server launcher (Windows)
│
├── update.sh / update.ps1     # Update to latest versions
├── backup.sh / backup.ps1     # Backup workspace
├── restore.sh / restore.ps1   # Restore from backup
├── uninstall.sh / uninstall.ps1  # Complete removal
│
├── README.md                  # User documentation
├── ATTRIBUTION.md             # Credits and licenses
└── CLAUDE.md                  # Developer guidance
```

## Key Design Decisions

### 1. Docker-Based Approach
**Decision:** Use Docker for isolation and reproducibility  
**Rationale:** 
- Eliminates "works on my machine" problems
- Isolates dependencies from host system
- Makes distribution trivial (one Docker image)
- Faculty don't need to understand Docker internals

### 2. Two Access Methods
**Decision:** Provide both CLI and browser-based IDE  
**Rationale:**
- CLI for technical users who prefer terminal
- VS Code Server for GUI-preferring users
- Browser access removes installation friction

### 3. Persistent Workspace
**Decision:** Mount `./workspace` as host directory, not Docker volume  
**Rationale:**
- Faculty can access files directly without Docker knowledge
- Easy to backup (just copy a folder)
- Compatible with existing file backup workflows
- Transparent file location

### 4. Launcher Scripts Over Direct Docker Commands
**Decision:** Wrap all Docker commands in simple scripts  
**Rationale:**
- Faculty never need to learn Docker commands
- Scripts handle container lifecycle automatically
- Can add logic (preflight checks, error handling)
- Easier to support ("just run run_claude.sh")

### 5. Cross-Platform Scripts
**Decision:** Maintain both .sh and .ps1 versions  
**Rationale:**
- Faculty use diverse operating systems
- Bash for macOS/Linux, PowerShell for Windows
- Keep feature parity between platforms

### 6. Minimal Docker Image
**Decision:** Start with Debian Bookworm slim, add only what's needed  
**Rationale:**
- Smaller images = faster downloads
- Fewer dependencies = fewer security concerns
- Only Claude Code + code-server + essentials

## Technical Challenges & Solutions

### Challenge 1: Claude Code Install URL
**Problem:** Original URL `https://console.anthropic.com/install.sh` returned 404  
**Solution:** Changed to `https://claude.ai/install.sh` which redirects to the correct location  
**Status:** Fixed in commit 9744516

### Challenge 2: docker-compose Version Warning
**Problem:** `version: '3.8'` attribute is obsolete in modern Docker Compose  
**Solution:** Removed the version line entirely (modern compose doesn't need it)  
**Status:** Fixed in commit 9744516

### Challenge 3: PATH in docker-compose exec
**Problem:** `claude` command not in PATH when using `docker compose exec`  
**Solution:** Launcher scripts use full path `/home/claudeuser/.local/bin/claude`  
**Impact:** No user-facing impact; launcher scripts work correctly

### Challenge 4: Memorable Command
**Problem:** `./run_claude.sh` is verbose and location-dependent  
**Solution:** Created `install-shortcut.sh` that installs `ccdocker` command system-wide  
**Status:** Implemented in install-shortcut.sh

## Development Workflow

### Making Changes to Docker Image

1. Edit `Dockerfile`
2. Rebuild: `docker compose build`
3. Test: `docker compose up -d`
4. Verify: `docker compose exec claude-code claude --version`
5. Update README.md if needed
6. Commit changes

### Adding New Scripts

1. Create `.sh` version (macOS/Linux)
2. Create `.ps1` version (Windows)
3. Make `.sh` executable: `chmod +x script.sh`
4. Test on macOS/Linux
5. Test on Windows (if possible)
6. Document in README.md
7. Update installation scripts to download new files

### Testing Before Release

See [TEST_RESULTS.md](TEST_RESULTS.md) for the testing checklist.

## Git Workflow

### Commits
- Use descriptive commit messages
- Include "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
- Keep commits atomic (one logical change per commit)

### Branches
- `main` - stable, tested code
- Feature branches for major changes

### Tags
Use semantic versioning:
- `v1.0.0` - Initial release
- `v1.1.0` - Minor features
- `v1.0.1` - Bug fixes

## Distribution Checklist

Before releasing to faculty:

- [ ] All tests pass (see TEST_RESULTS.md)
- [ ] Documentation is complete and accurate
- [ ] README installation URLs point to correct repository
- [ ] Scripts have been tested on both macOS and Windows
- [ ] Docker image builds successfully
- [ ] Claude Code and code-server versions are current
- [ ] ATTRIBUTION.md is up to date
- [ ] Create GitHub release with notes

## Support & Maintenance

### Common Support Issues

1. **Docker not running**
   - Solution: Start Docker Desktop
   - Scripts check for this automatically

2. **Port 8080 in use**
   - Solution: Edit docker-compose.yml to use different port

3. **Container won't start**
   - Solution: Check `docker compose logs`
   - Rebuild if needed: `./update.sh`

4. **Workspace permissions**
   - Container uses UID 1000
   - May conflict if host user has different UID

### Maintenance Schedule

- **Weekly:** Check for Claude Code updates
- **Monthly:** Check for code-server updates
- **Quarterly:** Update dependencies in Dockerfile
- **As Needed:** Update documentation

## Future Enhancements

Ideas for future versions:

### High Priority
- [ ] Auto-update mechanism
- [ ] Pre-installed FBS-specific Claude Code skills
- [ ] Better error messages in scripts
- [ ] GitHub Actions for CI/CD

### Medium Priority
- [ ] Integration with UVA SSO
- [ ] Custom FBS branding
- [ ] Usage analytics for IT
- [ ] Fleet management dashboard

### Low Priority
- [ ] Integration with Canvas/Collab
- [ ] Jupyter notebook support
- [ ] Multi-container setup for specialized tools

## Resources

- **Claude Code Documentation:** https://docs.anthropic.com/
- **code-server Documentation:** https://coder.com/docs/code-server/
- **Docker Documentation:** https://docs.docker.com/
- **DAAF Project:** https://github.com/DAAF-Contribution-Community/daaf

## Contact

For questions or contributions:
- **Repository:** https://github.com/BattenIT/cc-install (pending)
- **Support:** FBS IT Team
- **Issues:** GitHub Issues (after repo creation)

---

**Last Updated:** May 24, 2026  
**Project Status:** Testing & Refinement Phase  
**Next Milestone:** GitHub Release v1.0.0
