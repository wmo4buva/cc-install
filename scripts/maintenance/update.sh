#!/usr/bin/env bash
# Update cc-install (macOS/Linux).
#
# Two things get updated, which is the whole point:
#   1. The cc-install files themselves (launchers, docs, Dockerfile, VERSION).
#      The old version skipped this, so bug fixes in the scripts could never
#      reach anyone who had already installed.
#   2. The Docker image, rebuilt from scratch so Claude Code and code-server
#      come down at their latest versions.
#
# Your workspace/, .env and docker-compose.override.yml are never touched.

set -euo pipefail

REPO_SLUG="wmo4buva/cc-install"
REF="${CC_INSTALL_REF:-main}"
TARBALL_URL="https://codeload.github.com/${REPO_SLUG}/tar.gz/${REF}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found"
    echo "Please run this script from the cc-install directory"
    exit 1
fi

INSTALL_DIR="$(pwd)"

# This script is about to overwrite itself. Bash reads scripts incrementally, so
# replacing the file mid-run corrupts execution. Re-exec from a private copy in
# /tmp first, then it's safe to overwrite the original.
if [ "${CC_UPDATE_RELAUNCHED:-0}" != "1" ]; then
    self_copy="$(mktemp)"
    cat "$0" > "$self_copy"
    chmod +x "$self_copy"
    CC_UPDATE_RELAUNCHED=1 exec bash "$self_copy" "$@"
fi

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Claude Code Updater                                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

CURRENT_VERSION="$(cat VERSION 2>/dev/null || echo "unknown")"
echo -e "Installed version: ${YELLOW}${CURRENT_VERSION}${NC}"
echo ""
log_info "This will update:"
echo "  - The cc-install scripts and docs"
echo "  - Claude Code (latest)"
echo "  - VS Code Server / code-server (latest)"
echo "  - System packages"
echo ""
log_warn "Your workspace/, sign-in and settings will NOT be affected."
echo ""
echo -n "Continue? (y/N): "
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_info "Update cancelled"
    exit 0
fi

# --- 1. Refresh the cc-install files ---------------------------------------
log_info "Downloading the latest cc-install files..."

tmp_dir="$(mktemp -d)"
if curl -fsSL "$TARBALL_URL" -o "$tmp_dir/cc-install.tar.gz"; then
    # Extract to a staging dir, then copy in. workspace/, .env and
    # docker-compose.override.yml aren't in the archive, so they survive.
    mkdir -p "$tmp_dir/extracted"
    if tar -xzf "$tmp_dir/cc-install.tar.gz" -C "$tmp_dir/extracted" --strip-components=1; then
        cp -R "$tmp_dir/extracted/." "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/claude" "$INSTALL_DIR/vscode" 2>/dev/null || true
        find "$INSTALL_DIR/scripts" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
        log_success "Files updated to $(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "latest")"
    else
        log_warn "Could not extract the download — keeping your current files"
    fi
else
    log_warn "Could not reach GitHub — skipping the file update, rebuilding only"
fi
rm -rf "$tmp_dir"

# --- 2. Rebuild the image --------------------------------------------------
log_info "Stopping container..."
docker compose stop || true

log_info "Rebuilding Docker image (this takes 5-10 minutes)..."
if ! docker compose build --no-cache --progress plain; then
    log_error "Failed to rebuild Docker image"
    exit 1
fi

log_info "Starting updated container..."
if ! docker compose up -d --force-recreate; then
    log_error "Failed to start container"
    exit 1
fi

log_info "Waiting for container to be ready..."
for _ in $(seq 1 30); do
    if docker compose exec -T claude-code test -x /home/claudeuser/.local/bin/claude 2>/dev/null; then
        break
    fi
    sleep 2
done

# --- 3. Refresh the shortcuts ---------------------------------------------
# New versions can add commands (ccauth, ccdiagnose, ccupdate). Without this,
# existing installs would keep only the shortcuts they started with.
if [ -f "$INSTALL_DIR/scripts/installers/setup-shortcuts.sh" ]; then
    log_info "Refreshing launch shortcuts..."
    bash "$INSTALL_DIR/scripts/installers/setup-shortcuts.sh" >/dev/null 2>&1 \
        && log_success "Shortcuts refreshed" \
        || log_warn "Could not refresh shortcuts (not fatal)"
fi

# --- 4. Report -------------------------------------------------------------
if CLAUDE_VERSION=$(docker compose exec -T claude-code claude --version 2>/dev/null | head -1); then
    log_success "Claude Code: $CLAUDE_VERSION"
else
    log_warn "Could not verify the Claude Code version"
fi

if CODE_SERVER_VERSION=$(docker compose exec -T claude-code code-server --version 2>/dev/null | head -1); then
    log_success "code-server: $CODE_SERVER_VERSION"
else
    log_warn "Could not verify the code-server version"
fi

# The version check caches for 24h; drop it so the new version is picked up now.
rm -f "$HOME/.cache/cc-install-version-check"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Update Complete!                                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Now at version: ${GREEN}$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")${NC}"
echo ""
echo -e "${BLUE}Start Claude Code:${NC}"
echo -e "  ${YELLOW}ccdocker${NC}   in your terminal"
echo -e "  ${YELLOW}ccvscode${NC}   in your browser"
echo ""
echo -e "${YELLOW}If a shortcut isn't found, open a new Terminal window first.${NC}"
echo ""
