#!/usr/bin/env bash
# Backup Script for cc-install (macOS/Linux)
# Creates a timestamped backup of the workspace directory

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

# Check workspace exists
if [ ! -d "workspace" ]; then
    log_error "workspace directory not found"
    echo "Please run this script from the cc-install directory"
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

# Check workspace size
WORKSPACE_SIZE=$(du -sh workspace | cut -f1)
log_info "Workspace size: $WORKSPACE_SIZE"

# Count files
FILE_COUNT=$(find workspace -type f | wc -l | tr -d ' ')
log_info "Files to backup: $FILE_COUNT"

echo ""
log_info "Creating backup: $BACKUP_FILE"

# Create backup
if tar -czf "$BACKUP_FILE" workspace/; then
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo ""
    log_success "Backup created successfully!"
    echo ""
    echo -e "  ${GREEN}File:${NC} $BACKUP_FILE"
    echo -e "  ${GREEN}Size:${NC} $BACKUP_SIZE"
    echo ""
    echo -e "${YELLOW}To restore this backup:${NC}"
    echo -e "  ${BLUE}./restore.sh $BACKUP_FILE${NC}"
    echo ""
else
    log_error "Backup failed"
    exit 1
fi

# List recent backups
echo -e "${BLUE}Recent backups:${NC}"
ls -lh backups/ | tail -5
echo ""
