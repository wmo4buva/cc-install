#!/usr/bin/env bash
# Setup shortcuts for easy Claude Code access after installation

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

echo -e "${BLUE}Setting up easy launch shortcuts...${NC}\n"

# 1. Add to PATH via shell profile
setup_shell_aliases() {
    local shell_rc=""

    if [ -n "${BASH_VERSION:-}" ]; then
        shell_rc="$HOME/.bashrc"
        [ -f "$HOME/.bash_profile" ] && shell_rc="$HOME/.bash_profile"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        shell_rc="$HOME/.zshrc"
    fi

    if [ -z "$shell_rc" ]; then
        echo -e "${YELLOW}⚠ Could not detect shell. Skipping profile setup.${NC}"
        return
    fi

    # Check if aliases already exist
    if grep -q "# Claude Code shortcuts" "$shell_rc" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Shell aliases already configured in $shell_rc"
        return
    fi

    # Add aliases to shell profile
    cat >> "$shell_rc" << EOF

# Claude Code shortcuts
alias claude-start='cd "$INSTALL_DIR" && ./claude'
alias claude-vscode='cd "$INSTALL_DIR" && ./vscode'
alias claude-stop='cd "$INSTALL_DIR" && ./scripts/launchers/run_claude.sh stop'
alias claude-logs='cd "$INSTALL_DIR" && ./scripts/launchers/run_claude.sh logs'
EOF

    echo -e "${GREEN}✓${NC} Added shell aliases to $shell_rc"
    echo -e "  ${BLUE}claude-start${NC}  - Launch Claude Code CLI"
    echo -e "  ${BLUE}claude-vscode${NC} - Launch VS Code Server"
    echo -e "  ${BLUE}claude-stop${NC}   - Stop the container"
    echo -e "  ${BLUE}claude-logs${NC}   - View container logs"
}

# 2. Create desktop shortcut (macOS)
create_macos_app() {
    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    local app_dir="$HOME/Applications/Claude Code.app"

    if [ -d "$app_dir" ]; then
        echo -e "${GREEN}✓${NC} macOS app already exists"
        return
    fi

    mkdir -p "$app_dir/Contents/MacOS"
    mkdir -p "$app_dir/Contents/Resources"

    # Create launcher script
    cat > "$app_dir/Contents/MacOS/claude-code" << 'EOF'
#!/bin/bash
osascript -e 'tell application "Terminal" to do script "cd '"$INSTALL_DIR"' && ./claude"'
EOF

    # Create Info.plist
    cat > "$app_dir/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>claude-code</string>
    <key>CFBundleIdentifier</key>
    <string>com.batten.claudecode</string>
    <key>CFBundleName</key>
    <string>Claude Code</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF

    chmod +x "$app_dir/Contents/MacOS/claude-code"

    echo -e "${GREEN}✓${NC} Created macOS app in ~/Applications/Claude Code.app"
}

# 3. Print instructions
print_instructions() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Easy Launch Setup Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Quick Start:${NC}"
    echo ""
    echo -e "  1️⃣  ${YELLOW}Restart your terminal${NC} (or run: source ~/.zshrc)"
    echo ""
    echo -e "  2️⃣  Launch Claude Code from ${YELLOW}anywhere${NC}:"
    echo -e "      ${GREEN}claude-start${NC}"
    echo ""
    echo -e "  3️⃣  Or launch VS Code Server:"
    echo -e "      ${GREEN}claude-vscode${NC}"
    echo ""

    if [ "$(uname)" = "Darwin" ]; then
        echo -e "${BLUE}macOS Users:${NC}"
        echo -e "  • Find ${YELLOW}Claude Code${NC} app in your Applications folder"
        echo -e "  • Double-click to launch in Terminal"
        echo ""
    fi

    echo -e "${BLUE}Other Commands:${NC}"
    echo -e "  ${GREEN}claude-stop${NC}   - Stop the container"
    echo -e "  ${GREEN}claude-logs${NC}   - View container logs"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
}

# Run setup
setup_shell_aliases
create_macos_app
print_instructions
