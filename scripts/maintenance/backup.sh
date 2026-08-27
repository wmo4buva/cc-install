#!/usr/bin/env bash
# Backup Script for cc-install (macOS/Linux)
# Creates a timestamped backup of the workspace directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/workspace.sh
. "$SCRIPT_DIR/../lib/workspace.sh"

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

# Where the user's files actually live — ./workspace unless ccpath moved it.
WORKSPACE_DIR="$(cc_workspace_dir)"

if [ ! -d "$WORKSPACE_DIR" ]; then
    log_error "workspace directory not found: $WORKSPACE_DIR"
    if cc_workspace_is_relocated; then
        echo "CC_WORKSPACE in .env points there, but the folder is missing."
        echo "Check it still exists, or repoint it with: ccpath"
    else
        echo "Please run this script from the cc-install directory"
    fi
    exit 1
fi

# Create backups directory if it doesn't exist
mkdir -p backups

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="backups/workspace_backup_${TIMESTAMP}.tar.gz"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}║   Workspace Backup Utility                                ║${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "Backing up: $(cc_workspace_label)"

# Check workspace size
WORKSPACE_SIZE=$(du -sh "$WORKSPACE_DIR" | cut -f1)
log_info "Workspace size: $WORKSPACE_SIZE"

# Count files
FILE_COUNT=$(find "$WORKSPACE_DIR" -type f | wc -l | tr -d ' ')
log_info "Files to backup: $FILE_COUNT"

echo ""
log_info "Creating backup: $BACKUP_FILE"

# Archive the folder by name from its parent, so the tarball holds exactly one
# top-level directory and no absolute paths. That keeps the layout identical to
# what earlier versions produced for ./workspace, and restore.sh strips the top
# level either way — so a backup taken before or after ccpath restores the same.
if tar -czf "$BACKUP_FILE" -C "$(dirname "$WORKSPACE_DIR")" "$(basename "$WORKSPACE_DIR")"; then
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo ""
    log_success "Backup created successfully!"
    echo ""
    echo -e "  ${GREEN}File:${NC} $BACKUP_FILE"
    echo -e "  ${GREEN}Size:${NC} $BACKUP_SIZE"
    echo ""
    echo -e "${YELLOW}To restore this backup:${NC}"
    echo -e "  ${BLUE}./scripts/maintenance/restore.sh $BACKUP_FILE${NC}"
    echo ""
else
    log_error "Backup failed"
    exit 1
fi

# List recent backups
echo -e "${BLUE}Recent backups:${NC}"
ls -lh backups/ | tail -5
echo ""
