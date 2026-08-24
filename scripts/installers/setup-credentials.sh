#!/usr/bin/env bash
# Interactive credential setup for cc-install (macOS/Linux).
#
# Writes ./.env, which docker-compose.yml feeds into the container. Because the
# credentials live in the container's environment, they apply to BOTH ways of
# using Claude Code here:
#   ccdocker  - the CLI
#   ccvscode  - the browser IDE (its built-in terminal runs in the container)
#
# Run directly, or via the `ccauth` shortcut from anywhere.

set -euo pipefail

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

# Always operate on the install directory, not wherever the user invoked us.
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$INSTALL_DIR"

ENV_FILE="$INSTALL_DIR/.env"

if [ ! -f docker-compose.yml ]; then
    log_error "docker-compose.yml not found in $INSTALL_DIR"
    echo "This does not look like a cc-install directory."
    exit 1
fi

# ---------------------------------------------------------------------------
# .env helpers
# ---------------------------------------------------------------------------

# Strip any previously-set auth variables so the three options stay mutually
# exclusive. A leftover ANTHROPIC_API_KEY silently overrides a Claude account
# login, which is the single most confusing failure mode here.
strip_auth_vars() {
    local tmp
    tmp="$(mktemp)"
    if [ -f "$ENV_FILE" ]; then
        grep -vE '^[[:space:]]*(CLAUDE_CODE_USE_BEDROCK|ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_MODEL|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|AWS_REGION|AWS_DEFAULT_REGION|AWS_PROFILE)=' \
            "$ENV_FILE" > "$tmp" || true
    fi
    mv "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
}

set_var() {
    printf '%s=%s\n' "$1" "$2" >> "$ENV_FILE"
}

# Read a secret without echoing it, and reject empties.
read_secret() {
    local prompt="$1" var="$2" value=""
    while [ -z "$value" ]; do
        printf '%s' "$prompt"
        read -rs value
        echo ""
        [ -n "$value" ] || log_warn "Cannot be empty — try again."
    done
    eval "$var=\$value"
}

read_plain() {
    local prompt="$1" var="$2" default="${3:-}" value=""
    printf '%s' "$prompt"
    read -r value
    [ -n "$value" ] || value="$default"
    eval "$var=\$value"
}

restart_container() {
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker isn't running, so the container wasn't restarted."
        echo "        Start Docker Desktop, then run: ${BOLD}ccrestart${NC}"
        return 0
    fi
    log_info "Restarting the container so the new settings take effect..."
    docker compose up -d --force-recreate >/dev/null 2>&1 || {
        log_warn "Could not restart automatically. Run: ccrestart"
        return 0
    }
    log_success "Container restarted"
}

# ---------------------------------------------------------------------------
# The three options
# ---------------------------------------------------------------------------

use_claude_account() {
    strip_auth_vars
    log_success "Set up to use your Claude account (interactive sign-in)"
    echo ""
    echo -e "${BOLD}One more step — you have to sign in once:${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} Run: ${YELLOW}ccdocker${NC}"
    echo -e "  ${GREEN}2.${NC} Claude Code will show a sign-in URL. Open it in your browser."
    echo -e "  ${GREEN}3.${NC} Log in, copy the code it gives you, paste it back in the terminal."
    echo ""
    echo -e "That's it — the login is saved and you won't be asked again."
    echo -e "Using the browser IDE instead? See ${BLUE}docs/CREDENTIALS.md${NC}."
}

use_api_key() {
    local key
    echo ""
    echo -e "Get a key at ${BLUE}https://console.anthropic.com/settings/keys${NC}"
    echo -e "${YELLOW}Note:${NC} usage is billed to whoever owns that key."
    echo ""
    read_secret "Anthropic API key (input hidden): " key

    case "$key" in
        sk-ant-*) : ;;
        *) log_warn "That doesn't start with 'sk-ant-'. Saving it anyway, but double-check it." ;;
    esac

    strip_auth_vars
    set_var ANTHROPIC_API_KEY "$key"
    log_success "API key saved to .env (readable only by you)"
}

use_bedrock() {
    local access_key secret_key region model session_token

    echo ""
    echo -e "${BOLD}Amazon Bedrock (UVA / Batten AWS account)${NC}"
    echo -e "Ask Batten IT for these if you don't have them."
    echo ""

    read_secret "AWS Access Key ID (input hidden): " access_key
    read_secret "AWS Secret Access Key (input hidden): " secret_key
    read_plain  "AWS Region [us-east-1]: " region "us-east-1"
    read_plain  "AWS Session Token (only for temporary credentials, else press Enter): " session_token ""
    read_plain  "Bedrock model ID (press Enter to use the default): " model ""

    strip_auth_vars
    set_var CLAUDE_CODE_USE_BEDROCK 1
    set_var AWS_ACCESS_KEY_ID "$access_key"
    set_var AWS_SECRET_ACCESS_KEY "$secret_key"
    set_var AWS_REGION "$region"
    set_var AWS_DEFAULT_REGION "$region"
    [ -n "$session_token" ] && set_var AWS_SESSION_TOKEN "$session_token"
    [ -n "$model" ] && set_var ANTHROPIC_MODEL "$model"

    log_success "Bedrock credentials saved to .env (readable only by you)"
}

clear_credentials() {
    strip_auth_vars
    log_success "Credentials removed from .env"
    echo ""
    echo -e "To also forget an interactive Claude account sign-in, run:"
    echo -e "  ${YELLOW}ccdocker${NC} then type ${YELLOW}/logout${NC}"
}

show_current() {
    echo ""
    echo -e "${BOLD}Current setting${NC}"
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "  ${YELLOW}No .env file yet${NC} — nothing configured."
        return
    fi
    if grep -qE '^[[:space:]]*CLAUDE_CODE_USE_BEDROCK=' "$ENV_FILE"; then
        echo -e "  ${GREEN}Amazon Bedrock${NC} (region: $(grep -E '^AWS_REGION=' "$ENV_FILE" | cut -d= -f2- || echo 'not set'))"
    elif grep -qE '^[[:space:]]*ANTHROPIC_API_KEY=' "$ENV_FILE"; then
        echo -e "  ${GREEN}Anthropic API key${NC} (value hidden)"
    else
        echo -e "  ${GREEN}Claude account${NC} (interactive sign-in), or not yet configured."
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Seed .env from the example on first run so the file always exists and users
# have the reference comments to hand.
if [ ! -f "$ENV_FILE" ] && [ -f "$INSTALL_DIR/.env.example" ]; then
    cp "$INSTALL_DIR/.env.example" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
fi

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Claude Code — Sign-in Setup                             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"

show_current

cat <<EOF

How do you want to sign in to Claude Code?

  1) My Claude account          (recommended — Pro/Max/Team subscription)
  2) Anthropic API key          (personal, pay-as-you-go)
  3) Amazon Bedrock             (UVA / Batten AWS account)
  4) Clear saved credentials
  5) Quit without changing anything

Whichever you pick applies to BOTH \`ccdocker\` and \`ccvscode\`.
EOF

# A menu option can be passed as $1 to skip the prompt. Secrets are always
# prompted for interactively — never pass a key as an argument, it would end up
# in your shell history.
if [ -n "${1:-}" ]; then
    choice="$1"
    log_info "Using preselected option $choice"
else
    printf '\nChoice [1-5]: '
    read -r choice
fi
echo ""

case "$choice" in
    1) use_claude_account ;;
    2) use_api_key; restart_container ;;
    3) use_bedrock; restart_container ;;
    4) clear_credentials; restart_container ;;
    5) log_info "No changes made."; exit 0 ;;
    "") log_error "No option chosen."
        echo "Run ccauth again and enter a number from 1 to 5."
        exit 1 ;;
    *) log_error "'$choice' isn't one of 1-5."
       echo "Run ccauth again and enter a number from 1 to 5."
       exit 1 ;;
esac

echo ""
echo -e "${BLUE}Full details, including how to sign in from inside the browser IDE:${NC}"
echo -e "  ${YELLOW}$INSTALL_DIR/docs/CREDENTIALS.md${NC}"
echo ""
