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
