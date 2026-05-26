#!/usr/bin/env bash
# Diagnostic script for troubleshooting cc-install issues

set -euo pipefail

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
if command -v lsof &> /dev/null; then
    if lsof -i :8080 &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} Port 8080 is in use"
        echo -e "${BLUE}Process using port 8080:${NC}"
        lsof -i :8080 | head -n 2
        echo -e "\n${YELLOW}⚠ Solution:${NC} Stop the process or change port in docker-compose.yml"
    else
        echo -e "${GREEN}✓${NC} Port 8080 is available"
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

    # Check if less than 5GB free
    local free_gb=$(df -BG . | tail -n 1 | awk '{print $4}' | sed 's/G//')
    if [ "$free_gb" -lt 5 ]; then
        echo -e "${YELLOW}⚠${NC} Low disk space (less than 5GB free)"
        echo -e "${YELLOW}⚠ Solution:${NC} Free up disk space before installing"
    fi
fi
echo ""

# Workspace Check
echo -e "${BLUE}═══ Workspace ═══${NC}"
if [ -d "workspace" ]; then
    echo -e "${GREEN}✓${NC} Workspace directory exists"
    local ws_size=$(du -sh workspace 2>/dev/null | cut -f1)
    echo -e "  Size: $ws_size"
    local ws_files=$(find workspace -type f 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  Files: $ws_files"
else
    echo -e "${YELLOW}⚠${NC} Workspace directory not found"
    echo -e "${YELLOW}⚠ Solution:${NC} Will be created on first run"
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
    local version=$(cat VERSION)
    echo -e "${GREEN}✓${NC} Installed version: $version"
else
    echo -e "${YELLOW}⚠${NC} VERSION file not found (older installation)"
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
echo -e "   Edit docker-compose.yml and change '8080:8080' to '8081:8080'"
echo -e ""
echo -e "${YELLOW}3. Container won't start:${NC}"
echo -e "   Run: docker compose down && docker compose up -d"
echo -e ""
echo -e "${YELLOW}4. Out of disk space:${NC}"
echo -e "   Run: docker system prune -a"
echo -e ""
echo -e "${YELLOW}5. Need to rebuild:${NC}"
echo -e "   Run: ./scripts/maintenance/update.sh"
echo -e ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
