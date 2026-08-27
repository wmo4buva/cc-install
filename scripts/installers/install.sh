#!/usr/bin/env bash
# Claude Code Installer - installation script for macOS/Linux
# Inspired by DAAF (https://github.com/DAAF-Contribution-Community/daaf)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.sh -o install.sh && bash install.sh
#
# Environment overrides:
#   CC_INSTALL_DIR=my-dir     install somewhere other than ./cc-install
#   CC_INSTALL_REF=v1.3.0     install a specific tag/branch instead of main
#   CC_INSTALL_VERBOSE=1      show every step
#   CC_INSTALL_DRY_RUN=1      go through the motions without changing anything

set -euo pipefail

REPO_SLUG="wmo4buva/cc-install"
REF="${CC_INSTALL_REF:-main}"
TARBALL_URL="https://codeload.github.com/${REPO_SLUG}/tar.gz/${REF}"
INSTALL_DIR="${CC_INSTALL_DIR:-cc-install}"
VERBOSE="${CC_INSTALL_VERBOSE:-0}"
DRY_RUN="${CC_INSTALL_DRY_RUN:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_verbose() { [ "$VERBOSE" = "1" ] && echo -e "${BLUE}[VERBOSE]${NC} $1" || true; }

# If stdin isn't a terminal (piped install), try to reattach so prompts work.
if [ -t 0 ]; then
    INTERACTIVE=1
else
    INTERACTIVE=0
    exec < /dev/tty 2>/dev/null || INTERACTIVE=0
fi

if [ "$INTERACTIVE" = "1" ]; then
    trap 'echo -e "\n${YELLOW}Press Enter to exit...${NC}"; read -r' EXIT
fi

if [ "$DRY_RUN" = "1" ]; then
    log_warn "DRY RUN MODE - No actual changes will be made"
    docker() {
        echo "[DRY RUN] docker $*"
        [ "${1:-}" = "info" ] && return 0
        return 0
    }
fi

# Test mode (for sourcing in tests)
if [ "${CC_INSTALL_TEST_MODE:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

# ---------------------------------------------------------------------------

preflight_checks() {
    log_info "Running preflight checks..."

    for tool in curl tar; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "'$tool' is required but not installed"
            exit 1
        fi
    done

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║  Installation cannot continue without Docker              ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
        echo "📥 Step 1: Install Docker Desktop"
        echo "   Visit: https://www.docker.com/products/docker-desktop/"
        echo ""
        echo "🚀 Step 2: Start Docker Desktop"
        echo "   After installing, launch the application and wait for it"
        echo "   to fully start (~30 seconds)"
        echo ""
        echo "🔄 Step 3: Run this installer again"
        echo ""
        exit 1
    fi
    log_verbose "Docker found: $(docker --version)"

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║  Docker is installed but not running                      ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
        echo "🚀 Please start Docker Desktop:"
        echo ""
        if [ "$(uname)" = "Darwin" ]; then
            echo "   • Open your Applications folder"
            echo "   • Find and double-click 'Docker'"
            echo "   • Wait for the whale icon in your menu bar"
            echo "   • Icon should show 'Docker Desktop is running'"
        else
            echo "   • Find Docker Desktop in your applications menu"
            echo "   • Start it and wait ~30 seconds"
            echo "   • Look for the Docker icon in your system tray"
        fi
        echo ""
        echo "⏱️  Docker typically takes 20-30 seconds to start"
        echo ""
        echo "🔄 Then run this installer again"
        echo ""
        exit 1
    fi
    log_verbose "Docker daemon is running"

    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose V2 is not available"
        echo "Please update Docker Desktop to a recent version and try again."
        exit 1
    fi

    if [ -d "$INSTALL_DIR" ]; then
        log_warn "Directory '$INSTALL_DIR' already exists"
        echo ""
        echo "If this is an existing cc-install, you probably want to UPDATE it"
        echo "instead — that keeps your files and sign-in:"
        echo -e "    ${GREEN}cd $INSTALL_DIR && ./scripts/maintenance/update.sh${NC}"
        echo ""
        echo -n "Overwrite it instead? Your workspace/ and .env will be kept. (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi

    log_success "Preflight checks passed"
}

# Download the whole repository as a tarball.
#
# This used to fetch a hardcoded list of individual files, which drifted out of
# sync every time a file was added — that's how VERSION went missing (making
# every install permanently report "update available") and it would now also
# miss the Dockerfile's entrypoint. One archive can't drift.
download_files() {
    log_info "Step 1/5: Downloading cc-install ($REF)..."

    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY RUN] Would download $TARBALL_URL into $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
        return 0
    fi

    local tmp_dir tarball
    tmp_dir="$(mktemp -d)"
    tarball="$tmp_dir/cc-install.tar.gz"

    if ! curl -fsSL "$TARBALL_URL" -o "$tarball"; then
        rm -rf "$tmp_dir"
        log_error "Failed to download from $TARBALL_URL"
        echo "Check your internet connection, then try again."
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"
    # --strip-components=1 drops the "cc-install-main/" wrapper directory.
    # Extracting over an existing directory deliberately leaves workspace/ and
    # .env alone — the archive doesn't contain them.
    if ! tar -xzf "$tarball" -C "$INSTALL_DIR" --strip-components=1; then
        rm -rf "$tmp_dir"
        log_error "Failed to extract the download"
        exit 1
    fi
    rm -rf "$tmp_dir"

    chmod +x "$INSTALL_DIR/bin/claude" "$INSTALL_DIR/bin/vscode" 2>/dev/null || true
    find "$INSTALL_DIR/scripts" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

    log_success "Files downloaded"
}

build_image() {
    log_info "Step 2/5: Building Docker image (this takes 10-15 minutes)..."
    echo "        ☕ Good time to grab a coffee."

    if ! docker compose build --progress plain; then
        log_error "Failed to build Docker image"
        echo "Please check the error messages above and try again"
        exit 1
    fi

    log_success "Docker image built successfully"
}

start_container() {
    log_info "Step 3/5: Starting container..."

    if ! docker compose up -d; then
        log_error "Failed to start container"
        exit 1
    fi

    log_info "Waiting for container to be ready..."
    local attempt=0
    while [ $attempt -lt 30 ]; do
        if docker compose exec -T claude-code test -x /home/claudeuser/.local/bin/claude 2>/dev/null; then
            log_success "Container is ready"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
        log_verbose "Attempt $attempt/30..."
    done

    log_error "Container failed to start properly"
    echo "Please check: docker compose logs"
    exit 1
}

initialize_workspace() {
    log_info "Step 4/5: Initializing workspace..."

    mkdir -p workspace

    # Seed .env so credentials have somewhere to live and Compose always finds
    # the file. It contains only comments until the user runs ccauth.
    if [ ! -f .env ] && [ -f .env.example ]; then
        cp .env.example .env
        chmod 600 .env
    fi

    cat > workspace/WELCOME.md << 'EOF'
# Welcome to Claude Code

Everything you put in this folder is saved on your computer (in `workspace/`)
and is visible inside Claude Code. It survives restarts and updates.

## Two ways to use it

| Command | What you get |
|---|---|
| `ccdocker` | Claude Code in your terminal |
| `ccvscode` | VS Code in your browser, with Claude Code in its terminal |

## Signing in

Run `ccauth` once and pick how you want to sign in — your Claude account, an
Anthropic API key, or UVA Amazon Bedrock. It applies to both commands above.

Using `ccvscode`? There's no Claude Code button in the browser IDE. Open
**Terminal → New Terminal** and type `claude`.

Full detail: `docs/CREDENTIALS.md`.

## Other commands

`ccstop` stop the container · `ccrestart` restart it · `cclogs` view logs

Docs: `README.md`, `docs/QUICK_REFERENCE.md`
EOF

    log_success "Workspace initialized"
}

print_success_message() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Claude Code Installation Complete!                      ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}⚠  First: open a NEW Terminal window.${NC}"
    echo -e "   The shortcuts below won't exist in this one."
    echo ""
    echo -e "${BOLD}Then, in the new window:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} Set up how you sign in (once):"
    echo -e "     ${YELLOW}ccauth${NC}"
    echo ""
    echo -e "  ${GREEN}2.${NC} Start Claude Code:"
    echo -e "     ${YELLOW}ccdocker${NC}     in your terminal"
    echo -e "     ${YELLOW}ccvscode${NC}     in your browser (VS Code)"
    echo ""
    echo -e "  ${GREEN}3.${NC} Your files live in:"
    echo -e "     ${YELLOW}$(pwd)/workspace/${NC}"
    echo ""
    echo -e "${BLUE}Using ccvscode?${NC} There's no Claude Code button in the browser IDE."
    echo -e "Open ${BOLD}Terminal → New Terminal${NC} and type ${YELLOW}claude${NC}."
    echo ""
    echo -e "${BLUE}Maintenance:${NC}"
    echo -e "  ${YELLOW}./scripts/maintenance/update.sh${NC}     update to the latest version"
    echo -e "  ${YELLOW}./scripts/maintenance/diagnose.sh${NC}   check for problems"
    echo -e "  ${YELLOW}./scripts/maintenance/backup.sh${NC}     back up your workspace"
    echo ""
    echo -e "Docs: ${BLUE}README.md${NC} · sign-in help: ${BLUE}docs/CREDENTIALS.md${NC}"
    echo ""
}

main() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Claude Code Installer                                   ║${NC}"
    echo -e "${BLUE}║   Inspired by DAAF                                        ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    preflight_checks
    download_files
    cd "$INSTALL_DIR"

    build_image
    start_container
    initialize_workspace

    log_info "Step 5/5: Setting up launch shortcuts..."
    if [ -f "scripts/installers/setup-shortcuts.sh" ]; then
        bash scripts/installers/setup-shortcuts.sh || {
            log_warn "Failed to setup shortcuts, but installation is complete"
            echo -e "${YELLOW}You can still launch using: cd $INSTALL_DIR && ./bin/claude${NC}"
        }
    else
        log_warn "setup-shortcuts.sh not found, skipping shortcut setup"
        echo -e "${YELLOW}You can launch using: cd $INSTALL_DIR && ./bin/claude${NC}"
    fi

    print_success_message
}

main
