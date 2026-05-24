# Quick Reference Guide

One-page reference for common tasks.

## 🚀 Quick Start

```bash
# Install shortcut command (first time only)
./install-shortcut.sh

# Launch Claude Code
ccdocker

# Or launch VS Code in browser
./run_vscode.sh
```

## 📝 Common Commands

### Using Shortcut (Recommended)
```bash
ccdocker           # Launch Claude Code
ccdocker bash      # Open bash shell
ccdocker logs      # View container logs
ccdocker stop      # Stop container
ccdocker restart   # Restart container
```

### Using Scripts Directly
```bash
./run_claude.sh         # Launch Claude Code
./run_vscode.sh         # Launch VS Code Server (browser)
./update.sh             # Update to latest versions
./backup.sh             # Backup workspace
./restore.sh backup.tar.gz  # Restore from backup
./uninstall.sh          # Remove everything
```

## 🐳 Docker Commands

```bash
# View running containers
docker compose ps

# View logs
docker compose logs -f

# Stop container
docker compose stop

# Start container
docker compose up -d

# Rebuild image
docker compose build --no-cache

# Remove everything (including volumes)
docker compose down -v
```

## 📁 File Locations

| Item | Location |
|------|----------|
| User workspace | `./workspace/` |
| Backups | `./backups/` |
| Claude config | Docker volume `claude-config` |
| Shortcut command | `~/.local/bin/ccdocker` |
| Container name | `cc-install` |
| Docker image | `cc-install:latest` |

## 🔧 Troubleshooting

### Container won't start
```bash
docker compose logs
docker compose down
docker compose up -d
```

### Port 8080 in use
Edit `docker-compose.yml`:
```yaml
ports:
  - "8081:8080"  # Change left number
```

### Docker not running
Start Docker Desktop, wait for it to fully load.

### Reset everything
```bash
./uninstall.sh  # Follow prompts
./install.sh    # Reinstall
```

## 📊 Quick Stats

- **Docker Image Size:** ~1.4 GB
- **Build Time:** 2-3 minutes
- **Startup Time:** ~3 seconds
- **Claude Code Version:** 2.1.148
- **code-server Version:** 4.117.0
- **Base OS:** Debian Bookworm
- **Node.js:** v20 LTS

## 🌐 Web Interfaces

- **VS Code Server:** http://localhost:8080

## 📚 Documentation

- [README.md](../README.md) - User guide
- [CLAUDE.md](../CLAUDE.md) - Developer guide
- [ATTRIBUTION.md](../ATTRIBUTION.md) - Credits
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Implementation details
- [TEST_RESULTS.md](TEST_RESULTS.md) - Test report
- [DEVELOPMENT.md](DEVELOPMENT.md) - Development history

## ⚡ Power User Tips

### Create workspace subdirectories
```bash
mkdir -p workspace/{projects,research,teaching}
```

### Quick backup before major changes
```bash
./backup.sh && echo "Backup created: $(ls -t backups/ | head -1)"
```

### Check Claude Code version
```bash
docker compose exec claude-code claude --version
```

### Access bash shell quickly
```bash
ccdocker bash
# Or
docker compose exec claude-code bash
```

### Monitor resource usage
```bash
docker stats cc-install
```

## 🔑 Keyboard Shortcuts

### In VS Code Server (browser)
- `Ctrl+` ` - Toggle terminal
- `Ctrl+B` - Toggle sidebar
- `Ctrl+P` - Quick file open
- `Ctrl+Shift+P` - Command palette

### In Claude Code CLI
- `Ctrl+C` - Exit/interrupt
- `Ctrl+D` - Exit session

## 📦 Update Workflow

```bash
# 1. Backup current workspace
./backup.sh

# 2. Update to latest versions
./update.sh

# 3. Test that everything works
ccdocker --version

# 4. If issues, restore and report
./restore.sh backups/latest_backup.tar.gz
```

## 🎯 One-Liners

```bash
# Quick status check
docker compose ps && docker images | grep cc-install

# Force rebuild everything
docker compose down -v && docker compose build --no-cache && docker compose up -d

# Clean workspace
rm -rf workspace/* && echo "Workspace cleaned"

# View container size
docker images cc-install:latest --format "{{.Size}}"

# Count workspace files
find workspace -type f | wc -l
```

---

**For detailed information, see the full documentation in the links above.**
