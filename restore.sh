#!/usr/bin/env bash
# Restore Script for cc-install (macOS/Linux)
# Restores workspace from a backup file

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

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if backup file provided
if [ $# -eq 0 ]; then
    log_error "No backup file specified"
    echo "Usage: $0 <backup_file.tar.gz>"
    echo ""
    echo "Available backups:"
    if [ -d "backups" ] && [ "$(ls -A backups/)" ]; then
        ls -lh backups/
    else
        echo "  (none found)"
    fi
    exit 1
fi

BACKUP_FILE="$1"

# Check backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}║   Workspace Restore Utility                               ║${NC}"
echo -e "${BLUE}║                                                           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "Backup file: $BACKUP_FILE"
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo -e "  Size: $BACKUP_SIZE"
echo ""

# Warning about existing workspace
if [ -d "workspace" ]; then
    log_warn "This will REPLACE your current workspace directory!"
    echo ""
    echo -n "Continue? (y/N): "
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi

    # Backup current workspace first
    log_info "Creating safety backup of current workspace..."
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    mkdir -p backups
    tar -czf "backups/workspace_before_restore_${TIMESTAMP}.tar.gz" workspace/ 2>/dev/null || true
fi

# Remove existing workspace
if [ -d "workspace" ]; then
    log_info "Removing current workspace..."
    rm -rf workspace/
fi

# Extract backup
log_info "Restoring from backup..."
if tar -xzf "$BACKUP_FILE"; then
    echo ""
    log_success "Restore completed successfully!"
    echo ""
    FILE_COUNT=$(find workspace -type f | wc -l | tr -d ' ')
    echo -e "  ${GREEN}Files restored:${NC} $FILE_COUNT"
    echo ""
else
    log_error "Restore failed"
    exit 1
fi
