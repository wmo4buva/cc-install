#!/usr/bin/env bash
# Claude Code Launcher Script for macOS/Linux

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

# Check for updates (silent, non-blocking)
if [ -f "scripts/maintenance/check-update.sh" ]; then
    bash scripts/maintenance/check-update.sh --silent || true
fi

# Check Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    echo ""
    echo "📥 Please install Docker Desktop:"
    echo "   https://www.docker.com/products/docker-desktop/"
    echo ""
    echo "After installing, make sure Docker Desktop is running before trying again."
    exit 1
fi

# Check Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    echo ""
    echo "🚀 Please start Docker Desktop:"
    echo ""
    if [ "$(uname)" = "Darwin" ]; then
        echo "   1. Open Applications folder"
        echo "   2. Double-click 'Docker' to start"
        echo "   3. Wait for the Docker icon in menu bar to show 'running'"
    else
        echo "   1. Find Docker Desktop in your applications"
        echo "   2. Start it and wait ~30 seconds"
        echo "   3. Look for the Docker icon in your system tray"
    fi
    echo ""
    echo "💡 Run diagnostics: ./scripts/maintenance/diagnose.sh"
    exit 1
fi

# Check if container is running
if ! docker compose ps | grep -q "Up"; then
    log_info "Starting container..."
    docker compose up -d

    # Wait a moment for startup
    sleep 2
fi

# Determine command to run
COMMAND="${1:-claude}"

case "$COMMAND" in
    bash|shell)
        log_info "Opening bash shell in container..."
        docker compose exec claude-code bash
        ;;
    logs)
        log_info "Showing container logs..."
        docker compose logs -f
        ;;
    stop)
        log_info "Stopping container..."
        docker compose stop
        log_success "Container stopped"
        ;;
    restart)
        log_info "Restarting container..."
        docker compose restart
        log_success "Container restarted"
        ;;
    *)
        log_info "Launching Claude Code..."
        docker compose exec claude-code claude "$@"
        ;;
esac
