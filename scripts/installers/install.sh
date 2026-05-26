#!/usr/bin/env bash
# Claude Code Faculty Installer - Installation Script for macOS/Linux
# Inspired by DAAF (https://github.com/DAAF-Contribution-Community/daaf)

set -euo pipefail

# Configuration
REPO_URL="https://raw.githubusercontent.com/wmo4buva/cc-install/main"
INSTALL_DIR="${CC_INSTALL_DIR:-cc-install}"
VERBOSE="${CC_INSTALL_VERBOSE:-0}"
DRY_RUN="${CC_INSTALL_DRY_RUN:-0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Enable interactive mode detection
if [ -t 0 ]; then
    INTERACTIVE=1
else
    INTERACTIVE=0
    exec < /dev/tty 2>/dev/null || INTERACTIVE=0
fi

# Exit trap for interactive sessions
if [ "$INTERACTIVE" = "1" ]; then
    trap 'echo -e "\n${YELLOW}Press Enter to exit...${NC}"; read' EXIT
fi

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = "1" ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Dry-run mock commands
if [ "$DRY_RUN" = "1" ]; then
    log_warn "DRY RUN MODE - No actual changes will be made"
    docker() {
        echo "[DRY RUN] docker $*"
        if [ "$1" = "info" ]; then
            return 0
        fi
    }
    curl() {
        echo "[DRY RUN] curl $*"
        touch "${@: -1}" 2>/dev/null || true
        return 0
    }
    mkdir() {
        echo "[DRY RUN] mkdir $*"
        command mkdir "$@"
    }
    cd() {
        echo "[DRY RUN] cd $*"
        command cd "$@"
    }
fi

# Test mode (for sourcing in tests)
if [ "${CC_INSTALL_TEST_MODE:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

# Preflight checks
preflight_checks() {
    log_info "Running preflight checks..."

    # Check Docker installation
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

    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║  Docker is installed but not running                     ║"
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
            echo "   • Icon should indicate 'running' status"
        fi
        echo ""
        echo "⏱️  Docker typically takes 20-30 seconds to start"
        echo ""
        echo "🔄 Then run this installer again"
        echo ""
        exit 1
    fi
    log_verbose "Docker daemon is running"

    # Check for existing installation
    if [ -d "$INSTALL_DIR" ]; then
        log_warn "Directory '$INSTALL_DIR' already exists"
        echo -n "Do you want to overwrite it? This will remove existing data. (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
        log_info "Removing existing directory..."
        rm -rf "$INSTALL_DIR"
    fi

    log_success "Preflight checks passed"
}

# Download required files
download_files() {
    log_info "Step 1/4: Downloading required files..."

    # Root files
    local root_files=(
        "Dockerfile"
        "docker-compose.yml"
        ".dockerignore"
        "README.md"
        "claude"
        "vscode"
        "claude.cmd"
        "vscode.cmd"
    )

    # Launcher scripts
    local launcher_files=(
        "scripts/launchers/run_claude.sh"
        "scripts/launchers/run_vscode.sh"
    )

    # Installer scripts
    local installer_files=(
        "scripts/installers/setup-shortcuts.ps1"
    )

    # Maintenance scripts
    local maintenance_files=(
        "scripts/maintenance/update.sh"
        "scripts/maintenance/backup.sh"
        "scripts/maintenance/uninstall.sh"
        "scripts/maintenance/restore.sh"
    )

    # Download root files
    for file in "${root_files[@]}"; do
        log_verbose "Downloading $file..."
        if ! curl -fsSL "$REPO_URL/$file" -o "$file"; then
            log_error "Failed to download $file"
            exit 1
        fi
    done

    # Download launcher scripts
    mkdir -p scripts/launchers
    for file in "${launcher_files[@]}"; do
        log_verbose "Downloading $file..."
        if ! curl -fsSL "$REPO_URL/$file" -o "$file"; then
            log_error "Failed to download $file"
            exit 1
        fi
    done

    # Download installer scripts
    mkdir -p scripts/installers
    for file in "${installer_files[@]}"; do
        log_verbose "Downloading $file..."
        if ! curl -fsSL "$REPO_URL/$file" -o "$file"; then
            log_error "Failed to download $file"
            exit 1
        fi
    done

    # Download maintenance scripts
    mkdir -p scripts/maintenance
    for file in "${maintenance_files[@]}"; do
        log_verbose "Downloading $file..."
        if ! curl -fsSL "$REPO_URL/$file" -o "$file"; then
            log_error "Failed to download $file"
            exit 1
        fi
    done

    # Make scripts executable
    chmod +x claude vscode
    chmod +x scripts/launchers/*.sh
    chmod +x scripts/maintenance/*.sh

    log_success "All files downloaded successfully"
}

# Build Docker image
build_image() {
    log_info "Step 2/4: Building Docker image (this may take a few minutes)..."

    if ! docker compose build --progress plain; then
        log_error "Failed to build Docker image"
        echo "Please check the error messages above and try again"
        exit 1
    fi

    log_success "Docker image built successfully"
}

# Start container
start_container() {
    log_info "Step 3/4: Starting container..."

    if ! docker compose up -d; then
        log_error "Failed to start container"
        exit 1
    fi

    # Wait for container to be ready
    log_info "Waiting for container to be ready..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker compose exec -T claude-code test -f /home/claudeuser/.local/bin/claude 2>/dev/null; then
            log_success "Container is ready"
            return 0
        fi
        sleep 2
        ((attempt++))
        log_verbose "Attempt $attempt/$max_attempts..."
    done

    log_error "Container failed to start properly"
    echo "Please check: docker compose logs"
    exit 1
}

# Initialize workspace
initialize_workspace() {
    log_info "Step 4/4: Initializing workspace..."

    # Create workspace directory if it doesn't exist
    mkdir -p workspace

    # Create a welcome file
    cat > workspace/WELCOME.md << 'EOF'
# Welcome to Claude Code!

This is your workspace directory. All files you create or edit in Claude Code will be stored here.

## Getting Started

1. Your Claude Code installation is ready to use
2. Run `./run_claude.sh` to start Claude Code CLI
3. Run `./run_vscode.sh` to open VS Code Server in your browser
4. Your files in this directory will persist across container restarts

## Need Help?

- See README.md for detailed usage instructions
- Visit https://claude.ai/code for Claude Code documentation
- Check the ATTRIBUTION.md file to learn about the project inspiration

Happy coding!
EOF

    log_success "Workspace initialized"
}

# Print success message
print_success_message() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║   Claude Code Installation Complete!                      ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} Launch Claude Code CLI:"
    echo -e "     ${YELLOW}./run_claude.sh${NC}"
    echo ""
    echo -e "  ${GREEN}2.${NC} Or open VS Code Server in your browser:"
    echo -e "     ${YELLOW}./run_vscode.sh${NC}"
    echo ""
    echo -e "  ${GREEN}3.${NC} Your files will be stored in:"
    echo -e "     ${YELLOW}$INSTALL_DIR/workspace/${NC}"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo ""
    echo -e "  ${YELLOW}./update.sh${NC}      - Update to latest versions"
    echo -e "  ${YELLOW}./backup.sh${NC}      - Backup your workspace"
    echo -e "  ${YELLOW}./uninstall.sh${NC}   - Remove everything"
    echo ""
    echo -e "${BLUE}First-Time Setup:${NC}"
    echo ""
    echo -e "  When you first launch Claude Code, you'll need to:"
    echo -e "  - ${YELLOW}Enter your Amazon Bedrock credentials${NC} (recommended)"
    echo -e "    OR use your Anthropic API key"
    echo -e "  - Configure your preferences"
    echo ""
    echo -e "${GREEN}For more information, see README.md${NC}"
    echo ""
}

# Main installation flow
main() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                           ║${NC}"
    echo -e "${BLUE}║   Claude Code Faculty Installer                           ║${NC}"
    echo -e "${BLUE}║   Inspired by DAAF                                        ║${NC}"
    echo -e "${BLUE}║                                                           ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    preflight_checks

    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    download_files
    build_image
    start_container
    initialize_workspace

    # Setup easy launch shortcuts
    if [ -f "scripts/installers/setup-shortcuts.sh" ]; then
        bash scripts/installers/setup-shortcuts.sh
    fi

    print_success_message
}

# Run main function
main
