#!/usr/bin/env bash
# Claude Code launcher for macOS/Linux.
#
# Usage: run_claude.sh [claude args...]
#        run_claude.sh bash | logs | stop | restart | auth

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found"
    echo "Please run this script from the cc-install directory"
    exit 1
fi

# Check for updates (silent, non-blocking)
if [ -f "scripts/maintenance/check-update.sh" ]; then
    bash scripts/maintenance/check-update.sh --silent || true
fi

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    echo ""
    echo "📥 Please install Docker Desktop:"
    echo "   https://www.docker.com/products/docker-desktop/"
    echo ""
    echo "After installing, make sure Docker Desktop is running before trying again."
    exit 1
fi

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

if ! docker compose ps --status running 2>/dev/null | grep -q claude-code; then
    log_info "Starting container..."
    docker compose up -d
    sleep 2
fi

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
        docker compose up -d --force-recreate
        log_success "Container restarted"
        ;;
    auth)
        exec bash scripts/installers/setup-credentials.sh
        ;;
    *)
        # First run with no credentials anywhere? Point at ccauth before Claude
        # Code drops the user into a sign-in prompt they weren't expecting.
        if [ "$#" -eq 0 ]; then
            has_env_creds=0
            if [ -f .env ] && grep -qE '^[[:space:]]*(ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|CLAUDE_CODE_USE_BEDROCK)=.+' .env; then
                has_env_creds=1
            fi
            if [ "$has_env_creds" = "0" ] && \
               ! docker compose exec -T claude-code test -s /home/claudeuser/.claude/.credentials.json 2>/dev/null; then
                echo ""
                echo -e "${YELLOW}First time here — you'll be asked to sign in.${NC}"
                echo ""
                echo -e "  ${BOLD}Claude subscription (Pro/Max/Team)?${NC} Just follow the prompts below."
                echo -e "  ${BOLD}API key or UVA Bedrock credentials?${NC} Ctrl+C and run ${YELLOW}ccauth${NC} instead."
                echo ""
                echo -e "  Details: ${BLUE}docs/CREDENTIALS.md${NC}"
                echo ""
            fi
        fi
        log_info "Launching Claude Code..."
        docker compose exec claude-code claude "$@"
        ;;
esac
