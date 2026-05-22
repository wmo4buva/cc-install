#!/usr/bin/env bash
# VS Code Server Launcher Script for macOS/Linux

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found"
    echo "Please run this script from the cc-install directory"
    exit 1
fi

# Check Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    echo "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

# Check Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

# Check if container is running
if ! docker compose ps | grep -q "Up"; then
    log_info "Starting container..."
    docker compose up -d
    sleep 2
fi

# Start code-server in the container
log_info "Starting VS Code Server..."

# Check if code-server is already running
if docker compose exec -T claude-code pgrep -f code-server > /dev/null 2>&1; then
    log_info "VS Code Server is already running"
else
    # Start code-server in background
    docker compose exec -d claude-code code-server \
        --bind-addr 0.0.0.0:8080 \
        --auth none \
        /home/claudeuser/workspace

    # Wait for code-server to start
    sleep 3
fi

# Display URL
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║   VS Code Server is Running!                              ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}Open in your browser:${NC}"
echo -e "  ${YELLOW}http://localhost:8080${NC}"
echo ""
echo -e "  ${BLUE}Your workspace:${NC} workspace/"
echo ""
echo -e "${YELLOW}Tip:${NC} Press Ctrl+C to stop following logs, or close this window."
echo -e "     The server will continue running in the background."
echo ""

# Open browser (macOS)
if command -v open &> /dev/null; then
    log_info "Opening browser..."
    open http://localhost:8080
fi

# Keep script running to show logs
log_info "Press Ctrl+C to exit (server will keep running)"
echo ""
docker compose logs -f claude-code
