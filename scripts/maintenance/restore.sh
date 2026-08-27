#!/usr/bin/env bash
# Restore Script for cc-install (macOS/Linux)
# Restores workspace from a backup file

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

# Where the user's files actually live — ./workspace unless ccpath moved it.
cc_workspace_validate || exit 1
WORKSPACE_DIR="$(cc_workspace_dir)"

# This script clears the workspace before extracting. Once the path is
# user-chosen that stops being a harmless operation on a folder we created, so
# refuse outright on anything that looks like a home directory or a filesystem
# root. Without this, `ccpath ~` followed by a restore would wipe $HOME.
guard_destructive_path() {
    local dir="$1" resolved

    # Resolve to a real absolute path for comparison; a missing dir can't be
    # dangerous, and extraction will create it.
    [ -d "$dir" ] || return 0
    resolved="$(cd "$dir" && pwd)"

    case "$resolved" in
        /|/Users|/home|/root|/tmp|/var|/etc|/opt|/usr|/Volumes)
            log_error "Refusing to restore into $resolved"
            echo "That's a system directory. Restoring would delete everything in it."
            echo "Point your workspace somewhere dedicated first: ccpath"
            exit 1
            ;;
    esac

    if [ "$resolved" = "$HOME" ]; then
        log_error "Refusing to restore into your home directory ($resolved)"
        echo "Restoring clears the workspace first, which would delete everything"
        echo "in your home folder. Point your workspace at a dedicated subfolder:"
        echo "  ccpath \"\$HOME/cc-workspace\""
        exit 1
    fi
}

guard_destructive_path "$WORKSPACE_DIR"

# Warning about existing workspace
if [ -d "$WORKSPACE_DIR" ]; then
    log_warn "This will REPLACE the contents of your workspace!"
    echo -e "  Folder: ${BLUE}$(cc_workspace_label)${NC}"
    echo ""
    echo -n "Continue? (y/N): "
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi

    # Backup current workspace first. Same one-top-level-directory layout as
    # backup.sh produces, so the safety copy restores through this same script.
    log_info "Creating safety backup of current workspace..."
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    mkdir -p backups
    tar -czf "backups/workspace_before_restore_${TIMESTAMP}.tar.gz" \
        -C "$(dirname "$WORKSPACE_DIR")" "$(basename "$WORKSPACE_DIR")" 2>/dev/null || true
fi

# Clear the workspace, but keep the directory itself. It's a live bind-mount
# source: deleting and recreating it detaches the running container's mount, and
# on a relocated path it may also carry file-sharing permissions we can't restore.
if [ -d "$WORKSPACE_DIR" ]; then
    log_info "Clearing current workspace contents..."
    find "$WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
else
    mkdir -p "$WORKSPACE_DIR"
fi

# Extract backup.
#
# --strip-components=1 drops the archive's single top-level directory, so both
# layouts land correctly: older archives rooted at `workspace/`, and archives of
# a relocated folder rooted at whatever that folder is called.
log_info "Restoring from backup..."
if tar -xzf "$BACKUP_FILE" -C "$WORKSPACE_DIR" --strip-components=1; then
    echo ""
    log_success "Restore completed successfully!"
    echo ""
    FILE_COUNT=$(find "$WORKSPACE_DIR" -type f | wc -l | tr -d ' ')
    echo -e "  ${GREEN}Files restored:${NC} $FILE_COUNT"
    echo -e "  ${GREEN}Location:${NC}       $WORKSPACE_DIR"
    echo ""
else
    log_error "Restore failed"
    echo "Your previous files are in the safety backup under backups/"
    exit 1
fi
