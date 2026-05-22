# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**cc-install** (Claude Code Install) is a Docker-based installer that simplifies Claude Code distribution to faculty members. It provides one-line installation commands for macOS and Windows that create an isolated, reproducible environment with Claude Code CLI and VS Code Server.

### Purpose

- Make Claude Code accessible to non-technical faculty
- Eliminate complex dependency management and system configuration
- Provide a consistent environment across different machines and operating systems
- Include browser-based IDE (code-server) for users who prefer GUI over CLI

### Inspiration

This project is heavily inspired by [DAAF (Data Analysis Agent Framework)](https://github.com/DAAF-Contribution-Community/daaf). We adapted their Docker-based installation patterns while simplifying for Claude Code specifically. See [ATTRIBUTION.md](ATTRIBUTION.md) for full details.

## Architecture

### Components

1. **Dockerfile** — Defines container image with:
   - Debian Bookworm base
   - Node.js v20 LTS
   - Claude Code (installed via Anthropic's official script)
   - code-server v4.117.0
   - Non-root user `claudeuser` (UID 1000)

2. **docker-compose.yml** — Orchestrates container with:
   - Persistent volume mounts (`./workspace` and `claude-config`)
   - Port 8080 exposed for code-server
   - Resource limits (2-4GB RAM, 1-2 CPUs)

3. **Installation Scripts** — Platform-specific installers:
   - `install.sh` (macOS/Linux) — Bash script with preflight checks, downloads, builds, and setup
   - `install.ps1` (Windows) — PowerShell equivalent

4. **Launcher Scripts** — Start containers and launch applications:
   - `run_claude.sh/.ps1` — Launch Claude Code CLI or access bash shell
   - `run_vscode.sh/.ps1` — Start code-server and open in browser

5. **Helper Scripts** — Maintenance operations:
   - `update.sh/.ps1` — Rebuild image with latest versions
   - `backup.sh/.ps1` — Backup workspace directory
   - `uninstall.sh/.ps1` — Remove everything cleanly

### File Structure

```
cc-install/
├── Dockerfile                  # Image definition
├── docker-compose.yml          # Container orchestration
├── .dockerignore              # Build context exclusions
├── install.sh                 # macOS/Linux installer
├── install.ps1                # Windows installer
├── run_claude.sh              # Claude launcher (macOS/Linux)
├── run_claude.ps1             # Claude launcher (Windows)
├── run_vscode.sh              # VS Code launcher (macOS/Linux)
├── run_vscode.ps1             # VS Code launcher (Windows)
├── update.sh / update.ps1     # Update scripts
├── backup.sh / backup.ps1     # Backup scripts
├── uninstall.sh / uninstall.ps1  # Uninstall scripts
├── README.md                  # User documentation
├── ATTRIBUTION.md             # Credits to DAAF and third-party software
└── CLAUDE.md                  # This file
```

## Common Development Tasks

### Building the Docker Image

```bash
docker compose build --progress plain
```

The `--progress plain` flag shows detailed build output, useful for debugging.

### Testing Locally

1. Build the image:
   ```bash
   docker compose build
   ```

2. Start the container:
   ```bash
   docker compose up -d
   ```

3. Test Claude Code:
   ```bash
   docker compose exec claude-code claude --version
   ```

4. Test code-server:
   ```bash
   docker compose exec claude-code code-server --version
   ```

5. Open code-server in browser:
   ```
   http://localhost:8080
   ```

6. Check logs:
   ```bash
   docker compose logs -f
   ```

7. Stop when done:
   ```bash
   docker compose down
   ```

### Testing Installation Scripts

**Dry-run mode** (no actual changes):
```bash
CC_INSTALL_DRY_RUN=1 bash install.sh
```

**Verbose mode** (detailed output):
```bash
CC_INSTALL_VERBOSE=1 bash install.sh
```

**Custom directory**:
```bash
CC_INSTALL_DIR=my-test-dir bash install.sh
```

### Modifying the Dockerfile

When adding packages or changing the environment:

1. Edit `Dockerfile`
2. Test build locally: `docker compose build`
3. Test the running container: `docker compose up -d`
4. Verify changes: `docker compose exec claude-code bash`
5. Update README.md if adding new features

### Adding New Scripts

When creating new helper scripts:

1. Create both `.sh` (bash) and `.ps1` (PowerShell) versions
2. Make bash scripts executable: `chmod +x script.sh`
3. Add error handling and user feedback
4. Use consistent logging functions (log_info, log_error, log_success)
5. Test on both macOS and Windows if possible
6. Document in README.md
7. Add to installation script downloads

## Key Patterns from DAAF

### Installation Script Structure

```bash
#!/usr/bin/env bash
set -euo pipefail  # Strict error handling

# Configuration
REPO_URL="..."
INSTALL_DIR="..."

# Logging functions
log_info() { ... }
log_error() { ... }

# Preflight checks
preflight_checks() {
    # Check Docker installed
    # Check Docker running
    # Check existing installation
}

# Main steps
download_files() { ... }
build_image() { ... }
start_container() { ... }

# Run
main() {
    preflight_checks
    download_files
    build_image
    start_container
}

main
```

### Launcher Script Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

# Check prerequisites
# Check container status
# Start container if needed
# Execute command
```

### PowerShell Equivalents

Use PowerShell-appropriate patterns:
- `$ErrorActionPreference = "Stop"`
- Functions instead of bash functions
- `try/catch` blocks for error handling
- PowerShell cmdlets (`Test-Path`, `Start-Process`, etc.)

## Testing Checklist

Before pushing changes:

- [ ] Dockerfile builds successfully
- [ ] Container starts and Claude Code is accessible
- [ ] code-server starts and is accessible in browser
- [ ] Workspace persistence works (create file, restart container, file persists)
- [ ] All launcher scripts work (run_claude, run_vscode)
- [ ] Scripts have proper error handling
- [ ] README.md is up to date
- [ ] Both bash and PowerShell versions tested (if modified)

## Common Issues and Solutions

### Claude Code Installation Fails

The Anthropic install script URL might have changed. Check:
```bash
curl -I https://console.anthropic.com/install.sh
```

Update Dockerfile if needed.

### code-server Won't Start

Check that Node.js is properly installed:
```bash
docker compose exec claude-code node --version
```

### Port 8080 Conflicts

If port 8080 is already in use, edit `docker-compose.yml`:
```yaml
ports:
  - "8081:8080"  # Change host port
```

### Container Size Too Large

The image is currently ~1.5-2GB. To reduce size:
- Use multi-stage builds
- Clean up apt caches: `rm -rf /var/lib/apt/lists/*`
- Minimize layers in Dockerfile

### Workspace Permissions

The container uses UID 1000. If host user has different UID, permissions may conflict. Consider:
- Using UID matching in Dockerfile
- Or documenting the limitation

## Version Management

### Updating Claude Code Version

The Dockerfile uses Anthropic's installer which installs the latest version by default. To pin a specific version, modify the Dockerfile:

```dockerfile
RUN curl -fsSL https://console.anthropic.com/install.sh | bash -s -- <VERSION>
```

### Updating code-server Version

Change in Dockerfile:
```dockerfile
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=<VERSION>
```

### Updating Node.js Version

Change in Dockerfile:
```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_<VERSION>.x | bash -
```

## Distribution

### Hosting the Installation Scripts

For one-line installation to work, scripts must be publicly accessible. Options:

1. **GitHub (Recommended)**:
   - Create public repository
   - Use `https://raw.githubusercontent.com/BattenIT/cc-install/main/install.sh`
   - Benefit: Version control, easy updates

2. **FBS Web Server**:
   - Host files on UVA/FBS server
   - Use direct URLs
   - Benefit: Control and privacy

### Creating a Release

1. Test everything thoroughly
2. Tag the release: `git tag v1.0.0`
3. Push tags: `git push --tags`
4. Update README.md with tested one-line commands
5. Create GitHub release with notes

### Faculty Distribution

Provide faculty with:
- One-line installation command
- Link to README.md
- Support contact (FBS IT)
- Estimated installation time (~10 minutes)

## Future Enhancements

Ideas for future versions:

- Auto-update mechanism
- Pre-installed FBS-specific Claude Code skills
- Integration with UVA SSO
- Fleet management for IT (central dashboard)
- Usage analytics
- Custom FBS branding and templates
- Integration with Canvas/Collab

## Support and Documentation

- **Claude Code Docs**: https://docs.anthropic.com/
- **code-server Docs**: https://coder.com/docs/code-server/
- **Docker Docs**: https://docs.docker.com/
- **DAAF Project**: https://github.com/DAAF-Contribution-Community/daaf

## Contributing

When contributing:

1. Follow existing patterns (especially from DAAF)
2. Test on both macOS and Windows
3. Update documentation (README.md, CLAUDE.md)
4. Credit sources and inspirations
5. Keep it simple — this is for faculty, not DevOps engineers
