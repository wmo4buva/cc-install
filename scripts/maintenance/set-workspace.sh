#!/usr/bin/env bash
# Change which host folder is mounted as your workspace (macOS/Linux). `ccpath`.
#
# Writes CC_WORKSPACE into .env; docker-compose.yml interpolates it as the source
# of the /home/claudeuser/workspace mount. The container side never changes, so
# nothing inside the image knows or cares where the files come from.
#
# Usage:
#   ccpath                      show the current path, then prompt for a new one
#   ccpath /path/to/folder      set it non-interactively
#   ccpath --show               print the current path and exit
#   ccpath --reset              go back to the bundled ./workspace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$INSTALL_DIR"

# shellcheck source=../lib/workspace.sh
. "$SCRIPT_DIR/../lib/workspace.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }

ENV_FILE="$INSTALL_DIR/.env"
DEFAULT_WORKSPACE="./workspace"

# ---------------------------------------------------------------------------

show_current() {
    local dir
    dir="$(cc_workspace_dir)"

    echo ""
    echo -e "${BOLD}Your workspace folder${NC}"
    echo ""
    echo -e "  Host folder:      ${BLUE}${dir}${NC}"
    echo -e "  Inside container: ${BLUE}/home/claudeuser/workspace${NC}  (never changes)"

    if cc_workspace_is_relocated; then
        echo -e "  Status:           ${GREEN}relocated${NC}"
    else
        echo -e "  Status:           default"
    fi

    if [ -d "$dir" ]; then
        local count size
        count="$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')"
        size="$(du -sh "$dir" 2>/dev/null | cut -f1)"
        echo -e "  Contents:         ${count} files, ${size}"
    else
        echo -e "  Contents:         ${YELLOW}folder does not exist yet${NC}"
    fi
    echo ""
}

# Docker Desktop can only mount paths it's been given access to. On macOS the
# defaults are /Users, /Volumes, /private and /tmp — anything else silently
# produces an empty mount rather than an error, which is a miserable thing to
# debug. Warn rather than block: the user may have added their own shares.
warn_if_unshared() {
    local dir="$1"

    [ "$(uname)" = "Darwin" ] || return 0

    case "$dir" in
        /Users/*|/Volumes/*|/private/*|/tmp/*) return 0 ;;
    esac

    log_warn "Docker Desktop may not have access to this location."
    echo "         By default it can only share /Users, /Volumes, /private and /tmp."
    echo "         If the folder shows up empty in the IDE, add it under:"
    echo "         Docker Desktop → Settings → Resources → File sharing"
    echo ""
}

# Cloud-sync folders and a container writing to the same files is a recipe for
# corrupted saves and permission churn. Worth a word before someone points their
# workspace at Dropbox.
warn_if_cloud_synced() {
    local dir="$1" lower
    lower="$(printf '%s' "$dir" | tr '[:upper:]' '[:lower:]')"

    case "$lower" in
        *dropbox*|*"google drive"*|*googledrive*|*onedrive*|*"library/mobile documents"*|*icloud*)
            log_warn "That looks like a cloud-synced folder."
            echo "         The sync client and the container will both be writing to these"
            echo "         files. That can corrupt saves mid-write and cause permission"
            echo "         churn. A local folder is much safer; sync a backup instead."
            echo ""
            ;;
    esac
}

# Absolute paths only. A relative CC_WORKSPACE resolves against whatever
# directory the caller was in, and Compose does not expand ~.
normalise_path() {
    local input="$1"

    case "$input" in
        "~")   input="$HOME" ;;
        "~/"*) input="$HOME/${input#\~/}" ;;
    esac

    # Resolve to absolute without requiring the path to exist yet.
    if [ -d "$input" ]; then
        (cd "$input" && pwd)
    else
        case "$input" in
            /*) printf '%s' "${input%/}" ;;
            *)  printf '%s/%s' "$(pwd)" "${input#./}" ;;
        esac
    fi
}

# Surgical rewrite: drop any existing CC_WORKSPACE line, append the new one.
# Mirrors how setup-credentials.sh edits .env so the two never fight, and leaves
# every other key (including credentials) untouched.
write_env_var() {
    local value="$1" tmp
    tmp="$(mktemp)"

    if [ -f "$ENV_FILE" ]; then
        grep -vE '^[[:space:]]*CC_WORKSPACE[[:space:]]*=' "$ENV_FILE" > "$tmp" || true
    fi

    if [ -n "$value" ]; then
        printf 'CC_WORKSPACE=%s\n' "$value" >> "$tmp"
    fi

    mv "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
}

# Offer to bring existing files along. Copy, not move, and never delete the
# source — if something goes wrong the user still has their files.
offer_migration() {
    local from="$1" to="$2" count reply

    [ -d "$from" ] || return 0

    count="$(find "$from" -type f 2>/dev/null | wc -l | tr -d ' ')"
    [ "$count" -gt 0 ] || return 0

    echo ""
    log_info "Your current workspace has ${count} file(s)."
    echo -e "  From: ${BLUE}${from}${NC}"
    echo -e "  To:   ${BLUE}${to}${NC}"
    echo ""
    echo "Copy them to the new location? The originals are left exactly where they"
    echo "are either way — nothing is deleted."
    printf "Copy files? [y/N] "
    read -r reply

    case "$reply" in
        [Yy]*)
            log_info "Copying..."
            # -a preserves timestamps and permissions; the trailing /. copies
            # contents rather than nesting the folder inside itself.
            if cp -a "$from/." "$to/" 2>/dev/null; then
                log_success "Files copied. Originals still in ${from}"
            else
                log_error "Copy failed. Nothing was moved or deleted."
                echo "        Your files are still in ${from}"
                return 1
            fi
            ;;
        *)
            log_info "Left files where they are."
            echo "        The new workspace will start out empty."
            ;;
    esac
}

restart_container() {
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker isn't running, so the container wasn't restarted."
        echo "        Start Docker Desktop, then run: ${BOLD}ccrestart${NC}"
        return 0
    fi

    log_info "Recreating the container so the new mount takes effect..."

    # A plain restart is not enough — a bind mount is fixed at container
    # creation, so the container has to be recreated to pick up a new source.
    if docker compose up -d --force-recreate >/dev/null 2>&1; then
        log_success "Container recreated"
    else
        log_warn "Could not recreate the container automatically."
        echo "        Run this yourself: ${BOLD}ccrestart${NC}"
        return 0
    fi
}

# Prove the mount actually landed, rather than trusting that it did. A path
# Docker Desktop can't share produces an empty mount and no error at all.
verify_mount() {
    local expected="$1" actual

    docker info >/dev/null 2>&1 || return 0

    actual="$(docker inspect cc-install \
        --format '{{range .Mounts}}{{if eq .Destination "/home/claudeuser/workspace"}}{{.Source}}{{end}}{{end}}' \
        2>/dev/null || true)"

    if [ -z "$actual" ]; then
        log_warn "Could not read the container's mounts to verify."
        return 0
    fi

    if cc_mount_matches "$actual" "$expected"; then
        log_success "Verified: the container is mounting ${expected}"
    else
        log_warn "The container is mounting a different path than expected."
        echo "        Expected: $expected"
        echo "        Actual:   $actual"
        echo "        Try: ${BOLD}ccrestart${NC}"
    fi
}

apply() {
    local new_raw="$1" new_path old_path

    old_path="$(cc_workspace_dir)"

    if [ "$new_raw" = "$DEFAULT_WORKSPACE" ]; then
        new_path="$DEFAULT_WORKSPACE"
    else
        new_path="$(normalise_path "$new_raw")"
    fi

    if [ "$new_path" = "$old_path" ]; then
        log_info "Workspace is already set to that path. Nothing to do."
        return 0
    fi

    # Create it if needed, before anything else depends on it existing.
    if [ ! -d "$new_path" ]; then
        log_info "Creating ${new_path}"
        if ! mkdir -p "$new_path" 2>/dev/null; then
            log_error "Could not create ${new_path}"
            echo "        Check the path and that you have permission to write there."
            exit 1
        fi
    fi

    if [ ! -w "$new_path" ]; then
        log_error "${new_path} is not writable by you."
        echo "        Claude Code won't be able to save anything there."
        exit 1
    fi

    warn_if_unshared "$new_path"
    warn_if_cloud_synced "$new_path"

    offer_migration "$old_path" "$new_path" || true

    if [ "$new_path" = "$DEFAULT_WORKSPACE" ]; then
        write_env_var ""
        log_success "Workspace reset to the default ./workspace"
    else
        write_env_var "$new_path"
        log_success "Workspace set to ${new_path}"
    fi

    restart_container

    if [ "$new_path" != "$DEFAULT_WORKSPACE" ]; then
        verify_mount "$new_path"
    fi

    echo ""
    echo -e "${BOLD}Done.${NC} Your files now live at:"
    echo -e "  ${BLUE}$( [ "$new_path" = "$DEFAULT_WORKSPACE" ] && echo "$INSTALL_DIR/workspace" || echo "$new_path" )${NC}"
    echo ""
    echo "In the browser IDE they still appear at /home/claudeuser/workspace, and"
    echo "ccbackup now backs up the new location."
    echo ""
    echo -e "Remember: there is ${BOLD}no Claude Code button${NC} in the browser IDE."
    echo "Open a terminal in it and type: claude"
    echo ""
}

# ---------------------------------------------------------------------------

if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found"
    echo "Run this from your cc-install folder, or use the ccpath shortcut."
    exit 1
fi

case "${1:-}" in
    --show|-s)
        show_current
        cc_workspace_validate || exit 1
        exit 0
        ;;
    --reset)
        apply "$DEFAULT_WORKSPACE"
        exit 0
        ;;
    --help|-h)
        echo "Usage: ccpath [PATH|--show|--reset]"
        echo ""
        echo "  ccpath                  show the current folder, then prompt for a new one"
        echo "  ccpath /path/to/folder  point your workspace at that folder"
        echo "  ccpath --show           print the current folder and exit"
        echo "  ccpath --reset          go back to the bundled ./workspace"
        echo ""
        echo "The folder inside the container is always /home/claudeuser/workspace."
        echo "Only the host side changes, so nothing in the IDE moves around."
        exit 0
        ;;
    "")
        show_current
        cc_workspace_validate || true
        echo "Enter the full path to the folder you want to use."
        echo -e "Leave blank to cancel, or type ${BOLD}default${NC} to go back to ./workspace."
        echo ""
        printf "New workspace path: "
        read -r answer

        case "$answer" in
            "")        log_info "Cancelled. Nothing changed." ; exit 0 ;;
            default)   apply "$DEFAULT_WORKSPACE" ;;
            *)         apply "$answer" ;;
        esac
        ;;
    *)
        apply "$1"
        ;;
esac
