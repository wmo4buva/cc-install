#!/usr/bin/env bash
# Diagnostic script for troubleshooting cc-install issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/workspace.sh
. "$SCRIPT_DIR/../lib/workspace.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                           ║${NC}"
echo -e "${CYAN}║   Claude Code Installation Diagnostics                   ║${NC}"
echo -e "${CYAN}║                                                           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Information
echo -e "${BLUE}═══ System Information ═══${NC}"
echo -e "OS: $(uname -s)"
echo -e "Architecture: $(uname -m)"
echo -e "Kernel: $(uname -r)"
echo ""

# Docker Check
echo -e "${BLUE}═══ Docker Status ═══${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker installed"
    echo -e "  Version: $(docker --version)"

    if docker info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker daemon running"

        # Docker resources
        echo -e "\n${BLUE}Docker Resources:${NC}"
        docker info 2>/dev/null | grep -E "CPUs|Total Memory|Docker Root Dir" || true
    else
        echo -e "${RED}✗${NC} Docker daemon NOT running"
        echo -e "${YELLOW}⚠ Solution:${NC} Start Docker Desktop and wait for it to fully load"
    fi
else
    echo -e "${RED}✗${NC} Docker NOT installed"
    echo -e "${YELLOW}⚠ Solution:${NC} Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
fi
echo ""

# Docker Compose Check
echo -e "${BLUE}═══ Docker Compose Status ═══${NC}"
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker Compose available"
    echo -e "  Version: $(docker compose version)"
else
    echo -e "${RED}✗${NC} Docker Compose NOT available"
    echo -e "${YELLOW}⚠ Solution:${NC} Update Docker Desktop to get Docker Compose V2"
fi
echo ""

# Container Status
echo -e "${BLUE}═══ Container Status ═══${NC}"
if [ -f "docker-compose.yml" ]; then
    echo -e "${GREEN}✓${NC} docker-compose.yml found"

    if docker compose ps 2>/dev/null | grep -q "cc-install"; then
        echo -e "${GREEN}✓${NC} Container exists"

        if docker compose ps 2>/dev/null | grep -q "Up"; then
            echo -e "${GREEN}✓${NC} Container is running"

            # Container details
            echo -e "\n${BLUE}Container Details:${NC}"
            docker compose ps
        else
            echo -e "${YELLOW}⚠${NC} Container exists but is not running"
            echo -e "${YELLOW}⚠ Solution:${NC} Run: ./scripts/launchers/run_claude.sh"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Container does not exist"
        echo -e "${YELLOW}⚠ Solution:${NC} Run: docker compose up -d"
    fi
else
    echo -e "${RED}✗${NC} docker-compose.yml NOT found"
    echo -e "${YELLOW}⚠ Solution:${NC} Make sure you're in the cc-install directory"
fi
echo ""

# Port Check
echo -e "${BLUE}═══ Port Availability ═══${NC}"
# Check the port this install actually publishes, not a hardcoded 8080.
CC_HOST_PORT="$(docker compose port claude-code 8080 2>/dev/null | sed 's/.*://')"
[ -n "$CC_HOST_PORT" ] || CC_HOST_PORT="$(grep -oE '127\.0\.0\.1:[0-9]+:8080' docker-compose.yml 2>/dev/null | head -1 | cut -d: -f2)"
[ -n "$CC_HOST_PORT" ] || CC_HOST_PORT=8088
if command -v lsof &> /dev/null; then
    if lsof -i :"$CC_HOST_PORT" &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} Port $CC_HOST_PORT is in use"
        echo -e "${BLUE}Process using port $CC_HOST_PORT:${NC}"
        lsof -i :"$CC_HOST_PORT" | head -n 2
        echo -e "\n${YELLOW}⚠ Solution:${NC} Stop the process or change port in docker-compose.yml"
    else
        echo -e "${GREEN}✓${NC} Port $CC_HOST_PORT is available"
    fi
else
    echo -e "${YELLOW}⚠${NC} Cannot check port status (lsof not available)"
fi
echo ""

# Disk Space Check
echo -e "${BLUE}═══ Disk Space ═══${NC}"
if command -v df &> /dev/null; then
    echo -e "${BLUE}Available disk space:${NC}"
    df -h . | tail -n 1 | awk '{print "  Total: " $2 "\n  Used:  " $3 "\n  Free:  " $4 " (" $5 " used)"}'

    # Check if less than 5GB free. `df -BG` is GNU-only and fails on macOS;
    # `df -k` (1K blocks) is POSIX and works everywhere. Also note: `local` is
    # only valid inside a function, and using it out here used to abort the
    # whole script under `set -e`.
    free_gb=$(df -k . | tail -n 1 | awk '{print int($4/1048576)}')
    if [ "${free_gb:-99}" -lt 5 ]; then
        echo -e "${YELLOW}⚠${NC} Low disk space (less than 5GB free)"
        echo -e "${YELLOW}⚠ Solution:${NC} Free up disk space before installing"
    fi
fi
echo ""

# Workspace Check
echo -e "${BLUE}═══ Workspace ═══${NC}"
ws_dir="$(cc_workspace_dir)"
echo -e "  Host folder: ${ws_dir}"
if cc_workspace_is_relocated; then
    echo -e "  ${BLUE}Relocated via ccpath${NC} (the bundled ./workspace is not in use)"
fi

# A bad CC_WORKSPACE is worth catching here rather than letting it surface as an
# empty folder in the IDE with no explanation.
if ! cc_workspace_validate 2>/dev/null; then
    echo -e "${RED}✗${NC} CC_WORKSPACE in .env is not usable"
    cc_workspace_validate 2>&1 >/dev/null | sed 's/^/  /'
    echo -e "${YELLOW}⚠ Solution:${NC} Reset it with: ccpath --reset"
elif [ -d "$ws_dir" ]; then
    echo -e "${GREEN}✓${NC} Workspace directory exists"
    ws_size=$(du -sh "$ws_dir" 2>/dev/null | cut -f1)
    echo -e "  Size: ${ws_size:-unknown}"
    ws_files=$(find "$ws_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  Files: ${ws_files:-0}"
else
    echo -e "${YELLOW}⚠${NC} Workspace directory not found"
    if cc_workspace_is_relocated; then
        echo -e "${YELLOW}⚠ Solution:${NC} The folder ccpath points at is missing."
        echo -e "             Recreate it, or repoint with: ccpath"
    else
        echo -e "${YELLOW}⚠ Solution:${NC} Will be created on first run"
    fi
fi

# Cross-check against what the container actually mounted. These can disagree if
# .env changed without a container recreate — a bind mount is fixed at creation.
if docker info >/dev/null 2>&1; then
    mounted="$(docker inspect cc-install \
        --format '{{range .Mounts}}{{if eq .Destination "/home/claudeuser/workspace"}}{{.Source}}{{end}}{{end}}' \
        2>/dev/null || true)"
    if [ -n "$mounted" ]; then
        expected="$ws_dir"
        [ "$expected" = "./workspace" ] && expected="$(pwd)/workspace"
        if cc_mount_matches "$mounted" "$expected"; then
            echo -e "${GREEN}✓${NC} Container is mounting this folder"
        else
            echo -e "${RED}✗${NC} Container is mounting a DIFFERENT folder"
            echo -e "  Configured: $expected"
            echo -e "  Mounted:    $mounted"
            echo -e "${YELLOW}⚠ Solution:${NC} Recreate the container: ccrestart"
        fi
    fi
fi
echo ""

# Docker Volumes Check
echo -e "${BLUE}═══ Docker Volumes ═══${NC}"
if docker volume ls 2>/dev/null | grep -q "claude-config"; then
    echo -e "${GREEN}✓${NC} claude-config volume exists"
    docker volume inspect cc-install_claude-config 2>/dev/null | grep -E "Name|Mountpoint" || true
else
    echo -e "${YELLOW}⚠${NC} claude-config volume not found"
    echo -e "${YELLOW}⚠ Solution:${NC} Will be created on first run"
fi
echo ""

# Image Check
echo -e "${BLUE}═══ Docker Image ═══${NC}"
if docker images | grep -q "cc-install"; then
    echo -e "${GREEN}✓${NC} cc-install image exists"
    docker images cc-install --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
else
    echo -e "${YELLOW}⚠${NC} cc-install image not found"
    echo -e "${YELLOW}⚠ Solution:${NC} Run: docker compose build"
fi
echo ""

# Version Check
echo -e "${BLUE}═══ Installation Version ═══${NC}"
if [ -f "VERSION" ]; then
    echo -e "${GREEN}✓${NC} Installed version: $(cat VERSION)"
else
    echo -e "${YELLOW}⚠${NC} VERSION file not found (older installation)"
    echo -e "${YELLOW}⚠ Solution:${NC} Run ./scripts/maintenance/update.sh to refresh this install"
fi
echo ""

# Sign-in / credentials
echo -e "${BLUE}═══ Claude Code Sign-in ═══${NC}"
if [ -f ".env" ] && grep -qE '^[[:space:]]*CLAUDE_CODE_USE_BEDROCK=' .env; then
    echo -e "${GREEN}✓${NC} Configured for Amazon Bedrock (.env)"
    if grep -qE '^[[:space:]]*AWS_ACCESS_KEY_ID=.+' .env || grep -qE '^[[:space:]]*AWS_PROFILE=.+' .env; then
        echo -e "${GREEN}✓${NC} AWS credentials present"
    else
        echo -e "${RED}✗${NC} CLAUDE_CODE_USE_BEDROCK is set but no AWS credentials found"
        echo -e "${YELLOW}⚠ Solution:${NC} Run: ccauth"
    fi
elif [ -f ".env" ] && grep -qE '^[[:space:]]*(ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN)=.+' .env; then
    echo -e "${GREEN}✓${NC} Configured with an Anthropic API key (.env)"
elif docker compose exec -T claude-code test -s /home/claudeuser/.claude/.credentials.json 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Signed in interactively with a Claude account"
else
    echo -e "${YELLOW}⚠${NC} No sign-in configured yet"
    echo -e "${YELLOW}⚠ Solution:${NC} Run ${GREEN}ccauth${NC}, or run ${GREEN}ccdocker${NC} and sign in when prompted"
    echo -e "            See docs/CREDENTIALS.md"
fi
if [ -f ".env" ]; then
    env_perms=$(stat -f '%Lp' .env 2>/dev/null || stat -c '%a' .env 2>/dev/null || echo "")
    if [ -n "$env_perms" ] && [ "$env_perms" != "600" ]; then
        echo -e "${YELLOW}⚠${NC} .env permissions are $env_perms (it holds secrets)"
        echo -e "${YELLOW}⚠ Solution:${NC} Run: chmod 600 .env"
    fi
fi
echo ""

# Browser IDE / extensions health.
#
# The volume-ownership trap: a named volume mounted where the image has no such
# directory is created root-owned, locking claudeuser out. code-server then dies
# with EACCES on startup and every extension install fails. The entrypoint
# repairs it now, but check so a silent recurrence is visible.
echo -e "${BLUE}═══ Browser IDE (code-server) ═══${NC}"
if docker compose ps --status running 2>/dev/null | grep -q claude-code; then
    if docker compose exec -T claude-code test -w /home/claudeuser/.local/share/code-server 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Extensions directory is writable"
        ext_count=$(docker compose exec -T claude-code code-server --list-extensions 2>/dev/null | grep -c . || echo 0)
        echo -e "  Extensions installed: ${ext_count}"
        if docker compose exec -T claude-code code-server --list-extensions 2>/dev/null | grep -qi 'anthropic.claude-code'; then
            echo -e "${GREEN}✓${NC} Claude Code extension is installed"
        else
            echo -e "  ${BLUE}Claude Code extension not installed${NC} (optional — ${YELLOW}claude${NC} works in the terminal without it)"
            echo -e "  To add it: open the Extensions panel in the IDE and search 'Claude Code'"
        fi
    else
        echo -e "${RED}✗${NC} Extensions directory is NOT writable by claudeuser"
        echo -e "${YELLOW}⚠${NC} code-server will fail to start and extensions cannot be installed."
        echo -e "${YELLOW}⚠ Solution:${NC} Run ${GREEN}ccrestart${NC} — the container entrypoint repairs this."
        echo -e "            If it persists, run ${GREEN}ccupdate${NC}."
    fi
else
    echo -e "${YELLOW}⚠${NC} Container not running — cannot check"
fi
echo ""

# Is the IDE port exposed beyond this machine?
echo -e "${BLUE}═══ Browser IDE Exposure ═══${NC}"
if [ -f "docker-compose.yml" ]; then
    published=$(docker compose port claude-code 8080 2>/dev/null || true)
    if [ -z "$published" ]; then
        echo -e "${YELLOW}⚠${NC} Container not running — cannot check"
    elif echo "$published" | grep -q '^127\.0\.0\.1:'; then
        echo -e "${GREEN}✓${NC} Published on $published (this machine only)"
    else
        echo -e "${RED}✗${NC} Published on $published — reachable from your network"
        if [ -f ".env" ] && grep -qE '^[[:space:]]*CC_VSCODE_PASSWORD=.+' .env; then
            echo -e "${GREEN}✓${NC} A password is set, so it is not wide open"
        else
            echo -e "${RED}✗${NC} No password set. Anyone who can reach this port gets a shell."
            echo -e "${YELLOW}⚠ Solution:${NC} Set CC_VSCODE_PASSWORD in .env, or publish on 127.0.0.1 only"
        fi
    fi
fi
echo ""

# Common Issues Summary
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Common Solutions:${NC}"
echo -e ""
echo -e "${YELLOW}1. Docker not running:${NC}"
echo -e "   Start Docker Desktop and wait ~30 seconds"
echo -e ""
echo -e "${YELLOW}2. Port 8080 in use:${NC}"
echo -e "   Copy docs/docker-compose.override.yml.example to docker-compose.override.yml"
echo -e "   here in the install folder, then uncomment the 'ports: !override' block"
echo -e "   (the !override tag is"
echo -e "   required — without it Compose publishes BOTH ports)"
echo -e ""
echo -e "${YELLOW}3. Container won't start:${NC}"
echo -e "   Run: docker compose down && docker compose up -d"
echo -e ""
echo -e "${YELLOW}4. Out of disk space:${NC}"
echo -e "   Run: docker system prune -a"
echo -e ""
echo -e "${YELLOW}5. Need to rebuild or get the latest fixes:${NC}"
echo -e "   Run: ./scripts/maintenance/update.sh"
echo -e ""
echo -e "${YELLOW}6. Claude Code asks you to sign in every time:${NC}"
echo -e "   Run: ccauth   (see docs/CREDENTIALS.md)"
echo -e ""
echo -e "${YELLOW}7. Can't find Claude Code in the browser IDE:${NC}"
echo -e "   There's no button — open Terminal → New Terminal and type: claude"
echo -e ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
