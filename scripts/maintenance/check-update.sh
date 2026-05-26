#!/usr/bin/env bash
# Check for updates to cc-install

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/wmo4buva/cc-install/main"
LOCAL_VERSION_FILE="VERSION"
CACHE_FILE="$HOME/.cache/cc-install-version-check"
CACHE_DURATION=86400  # 24 hours in seconds

# Get local version
get_local_version() {
    if [ -f "$LOCAL_VERSION_FILE" ]; then
        cat "$LOCAL_VERSION_FILE"
    else
        echo "1.0.0"
    fi
}

# Get remote version (with caching)
get_remote_version() {
    local now=$(date +%s)

    # Check cache
    if [ -f "$CACHE_FILE" ]; then
        local cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        local age=$((now - cache_time))

        if [ $age -lt $CACHE_DURATION ]; then
            cat "$CACHE_FILE"
            return 0
        fi
    fi

    # Fetch remote version
    local remote_version=$(curl -fsSL "$REPO_URL/VERSION" 2>/dev/null || echo "")

    if [ -n "$remote_version" ]; then
        mkdir -p "$(dirname "$CACHE_FILE")"
        echo "$remote_version" > "$CACHE_FILE"
        echo "$remote_version"
    else
        # Return cached version if fetch fails
        if [ -f "$CACHE_FILE" ]; then
            cat "$CACHE_FILE"
        else
            echo "unknown"
        fi
    fi
}

# Compare versions
version_greater() {
    # Returns 0 if $1 > $2
    [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# Main check
check_for_updates() {
    local local_version=$(get_local_version)
    local remote_version=$(get_remote_version)

    if [ "$remote_version" = "unknown" ]; then
        # Silently skip if can't check
        return 1
    fi

    if version_greater "$remote_version" "$local_version"; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                                                           ║${NC}"
        echo -e "${YELLOW}║   📦 Update Available!                                    ║${NC}"
        echo -e "${YELLOW}║                                                           ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}Current version:${NC} $local_version"
        echo -e "${GREEN}Latest version:${NC}  $remote_version"
        echo ""
        echo -e "To update, run:"
        echo -e "  ${GREEN}./scripts/maintenance/update.sh${NC}"
        echo ""
        return 0
    else
        return 1
    fi
}

# Run check (suppress errors for silent checks)
if [ "${1:-}" = "--silent" ]; then
    check_for_updates 2>/dev/null || true
else
    if ! check_for_updates; then
        echo -e "${GREEN}✓${NC} You're running the latest version ($local_version)"
    fi
fi
