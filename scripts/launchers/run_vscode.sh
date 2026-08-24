#!/usr/bin/env bash
# VS Code Server (browser IDE) launcher for macOS/Linux.

set -euo pipefail

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

if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found"
    echo "Please run this script from the cc-install directory"
    exit 1
fi

# Check for updates (silent, non-blocking)
if [ -f "scripts/maintenance/check-update.sh" ]; then
    bash scripts/maintenance/check-update.sh --silent || true
fi

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    echo ""
    echo "📥 Please install Docker Desktop:"
    echo "   https://www.docker.com/products/docker-desktop/"
    echo ""
    echo "After installing, make sure Docker Desktop is running before trying again."
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    echo ""
    echo "🚀 Please start Docker Desktop:"
    echo ""
    if [ "$(uname)" = "Darwin" ]; then
        echo "   1. Open Applications folder"
        echo "   2. Double-click 'Docker' to start"
        echo "   3. Wait for the Docker icon in menu bar to show 'running'"
    else
        echo "   1. Find Docker Desktop in your applications"
        echo "   2. Start it and wait ~30 seconds"
        echo "   3. Look for the Docker icon in your system tray"
    fi
    echo ""
    echo "💡 Run diagnostics: ./scripts/maintenance/diagnose.sh"
    exit 1
fi

if ! docker compose ps --status running 2>/dev/null | grep -q claude-code; then
    log_info "Starting container..."
    docker compose up -d
    sleep 2
fi

# ---------------------------------------------------------------------------
# Which port did the user actually publish? Read it back from Compose rather
# than assuming 8080, so a docker-compose.override.yml still gets the right URL.
# ---------------------------------------------------------------------------
HOST_PORT="$(docker compose port claude-code 8080 2>/dev/null | sed 's/.*://')"
[ -n "$HOST_PORT" ] || HOST_PORT=8088
URL="http://localhost:${HOST_PORT}"

# ---------------------------------------------------------------------------
# Is Claude Code already signed in?
#
# Two ways it can be: credentials in .env (API key / Bedrock), or an interactive
# login stored in the claude-config volume. If neither is true, the user will hit
# a sign-in prompt inside the IDE, so tell them how to handle it up front —
# that's the step people miss when they only ever use the browser IDE.
# ---------------------------------------------------------------------------
credentials_configured() {
    if [ -f .env ] && grep -qE '^[[:space:]]*(ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|CLAUDE_CODE_USE_BEDROCK)=.+' .env; then
        return 0
    fi
    # An interactive login writes .credentials.json into ~/.claude.
    docker compose exec -T claude-code test -s /home/claudeuser/.claude/.credentials.json 2>/dev/null
}

if credentials_configured; then
    SIGNED_IN=1
else
    SIGNED_IN=0
fi

# ---------------------------------------------------------------------------
# Drop a sign-in cheat sheet into the workspace. This is the first thing the
# user sees in the IDE's file explorer, which makes it the right place to
# explain something the browser IDE itself can't prompt for.
# ---------------------------------------------------------------------------
write_start_here() {
    mkdir -p workspace
    cat > workspace/START-HERE.md << EOF
# Start here

You're in **VS Code Server**, running inside the Claude Code container. Your
files live in this folder and are also on your computer at \`workspace/\`.

## How to use Claude Code in here

The browser IDE has no Claude Code button — you run it from the built-in
terminal, which is already inside the container:

1. Open the menu: **Terminal → New Terminal** (or press <kbd>Ctrl</kbd>+<kbd>\`</kbd>)
2. Type \`claude\` and press Enter.

That's it. Claude Code runs in the terminal panel at the bottom.

## Signing in (first time only)

The first time you run \`claude\`, it asks how you want to authenticate.

**If you have a Claude subscription (Pro/Max/Team)** — pick the login option.
It prints a URL. **Copy the URL into a new browser tab** (Ctrl/Cmd-click may not
work from the container terminal), sign in, copy the code it gives you, and
paste it back into the terminal. You only do this once — it's saved.

**If you were given an API key or UVA Bedrock credentials** — don't type them
into the terminal. Close this and run \`ccauth\` in a normal terminal on your
computer instead. That stores them properly so both the CLI and this IDE pick
them up, and it survives updates.

**Already set up \`ccauth\`?** Then \`claude\` starts with no questions asked.

## Handy commands

| Command | What it does |
|---|---|
| \`ccauth\` | Set or change how you sign in (run on your computer, not in here) |
| \`ccvscode\` | Open this IDE |
| \`ccdocker\` | Use Claude Code in a normal terminal instead |
| \`ccstop\` | Shut the container down when you're done |

Full detail: \`docs/CREDENTIALS.md\` in the cc-install folder.
EOF
}
write_start_here

# ---------------------------------------------------------------------------
# Start code-server
# ---------------------------------------------------------------------------
log_info "Starting VS Code Server..."

# Optional password, read from .env. Without one, code-server runs with no auth
# — which is fine only because docker-compose.yml publishes the port on
# 127.0.0.1. If you expose it to the network, set CC_VSCODE_PASSWORD.
VSCODE_PASSWORD=""
if [ -f .env ]; then
    VSCODE_PASSWORD="$(grep -E '^[[:space:]]*CC_VSCODE_PASSWORD=' .env | tail -1 | cut -d= -f2- || true)"
fi

if docker compose exec -T claude-code pgrep -f code-server > /dev/null 2>&1; then
    log_info "VS Code Server is already running"
else
    if [ -n "$VSCODE_PASSWORD" ]; then
        docker compose exec -d -e PASSWORD="$VSCODE_PASSWORD" claude-code code-server \
            --bind-addr 0.0.0.0:8080 \
            --auth password \
            /home/claudeuser/workspace
        log_info "Password protection is on (CC_VSCODE_PASSWORD from .env)"
    else
        docker compose exec -d claude-code code-server \
            --bind-addr 0.0.0.0:8080 \
            --auth none \
            /home/claudeuser/workspace
    fi

    # Poll instead of a blind sleep, so slow machines don't open a dead tab.
    for _ in $(seq 1 15); do
        if docker compose exec -T claude-code pgrep -f code-server > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   VS Code Server is running                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}Open in your browser:${NC} ${YELLOW}${URL}${NC}"
echo -e "  ${BLUE}Your files:${NC}            workspace/"
echo ""

# The bit people get stuck on: there is no Claude Code button in the IDE.
echo -e "${BOLD}To use Claude Code in the browser IDE:${NC}"
echo -e "  ${GREEN}1.${NC} In VS Code, open ${BOLD}Terminal → New Terminal${NC}"
echo -e "  ${GREEN}2.${NC} Type ${YELLOW}claude${NC} and press Enter"
echo ""

if [ "$SIGNED_IN" = "1" ]; then
    echo -e "${GREEN}✓${NC} Sign-in is already configured — ${YELLOW}claude${NC} will start straight away."
else
    echo -e "${YELLOW}⚠  You haven't set up a sign-in yet.${NC}"
    echo ""
    echo -e "  ${BOLD}Have an API key or UVA Bedrock credentials?${NC}"
    echo -e "  Press Ctrl+C and run ${YELLOW}ccauth${NC} first. That's the right place for"
    echo -e "  keys — it saves them so both the CLI and this IDE use them."
    echo ""
    echo -e "  ${BOLD}Have a Claude subscription (Pro/Max/Team)?${NC}"
    echo -e "  Just run ${YELLOW}claude${NC} in the IDE terminal and follow the sign-in"
    echo -e "  prompts. Copy the URL it prints into a new browser tab."
    echo ""
    echo -e "  Details: ${BLUE}docs/CREDENTIALS.md${NC}"
fi
echo ""
echo -e "${BLUE}Open ${BOLD}START-HERE.md${NC}${BLUE} in the IDE for these instructions again.${NC}"
echo ""

if command -v open &> /dev/null; then
    log_info "Opening browser..."
    open "$URL"
elif command -v xdg-open &> /dev/null; then
    log_info "Opening browser..."
    xdg-open "$URL" >/dev/null 2>&1 || true
fi

echo ""
echo -e "The server keeps running in the background — you can close this window."
echo -e "Stop it later with: ${YELLOW}ccstop${NC}"
echo ""
