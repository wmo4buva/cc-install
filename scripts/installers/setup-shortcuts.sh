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

# 1. Create standalone scripts in ~/.local/bin
setup_bin_scripts() {
    local bin_dir="$HOME/.local/bin"

    # Create bin directory if it doesn't exist
    mkdir -p "$bin_dir"

    # Check if scripts already exist
    if [ -f "$bin_dir/ccvscode" ]; then
        echo -e "${GREEN}✓${NC} Shortcuts already installed in $bin_dir"
        return
    fi

    # Create ccdocker
    cat > "$bin_dir/ccdocker" << 'SCRIPT'
#!/usr/bin/env bash
# Claude Code Docker Shortcut
cd "INSTALL_DIR_PLACEHOLDER" && ./scripts/launchers/run_claude.sh "$@"
SCRIPT
    sed -i.bak "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$bin_dir/ccdocker" && rm -f "$bin_dir/ccdocker.bak"
    chmod +x "$bin_dir/ccdocker"

    # Create ccvscode
    cat > "$bin_dir/ccvscode" << 'SCRIPT'
#!/usr/bin/env bash
# VS Code Server Launcher Shortcut
cd "INSTALL_DIR_PLACEHOLDER" && ./scripts/launchers/run_vscode.sh "$@"
SCRIPT
    sed -i.bak "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$bin_dir/ccvscode" && rm -f "$bin_dir/ccvscode.bak"
    chmod +x "$bin_dir/ccvscode"

    # Create ccstop
    cat > "$bin_dir/ccstop" << 'SCRIPT'
#!/usr/bin/env bash
# Stop Claude Code Container
cd "INSTALL_DIR_PLACEHOLDER" && ./scripts/launchers/run_claude.sh stop
SCRIPT
    sed -i.bak "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$bin_dir/ccstop" && rm -f "$bin_dir/ccstop.bak"
    chmod +x "$bin_dir/ccstop"

    # Create cclogs
    cat > "$bin_dir/cclogs" << 'SCRIPT'
#!/usr/bin/env bash
# View Claude Code Container Logs
cd "INSTALL_DIR_PLACEHOLDER" && ./scripts/launchers/run_claude.sh logs
SCRIPT
    sed -i.bak "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$bin_dir/cclogs" && rm -f "$bin_dir/cclogs.bak"
    chmod +x "$bin_dir/cclogs"

    # Create ccrestart
    cat > "$bin_dir/ccrestart" << 'SCRIPT'
#!/usr/bin/env bash
# Restart Claude Code Container
cd "INSTALL_DIR_PLACEHOLDER" && ./scripts/launchers/run_claude.sh restart
SCRIPT
    sed -i.bak "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$bin_dir/ccrestart" && rm -f "$bin_dir/ccrestart.bak"
    chmod +x "$bin_dir/ccrestart"

    echo -e "${GREEN}✓${NC} Created shortcuts in $bin_dir"
    echo -e "  ${BLUE}ccdocker${NC}  - Launch Claude Code CLI"
    echo -e "  ${BLUE}ccvscode${NC} - Launch VS Code Server"
    echo -e "  ${BLUE}ccstop${NC}   - Stop the container"
    echo -e "  ${BLUE}cclogs${NC}   - View container logs"
    echo -e "  ${BLUE}ccrestart${NC} - Restart container"

    # Ensure ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo ""
        echo -e "${YELLOW}⚠ Note:${NC} Add ${BLUE}~/.local/bin${NC} to your PATH:"
        echo ""

        local shell_rc=""
        if [ -n "${ZSH_VERSION:-}" ]; then
            shell_rc="$HOME/.zshrc"
        elif [ -n "${BASH_VERSION:-}" ]; then
            shell_rc="$HOME/.bashrc"
            [ -f "$HOME/.bash_profile" ] && shell_rc="$HOME/.bash_profile"
        fi

        if [ -n "$shell_rc" ]; then
            echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> $shell_rc"
            echo "  source $shell_rc"
        else
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
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
    echo -e "  ${GREEN}ccdocker${NC}  - Launch Claude Code CLI"
    echo -e "  ${GREEN}ccvscode${NC} - Launch VS Code Server"
    echo ""

    if [ "$(uname)" = "Darwin" ]; then
        echo -e "${BLUE}macOS Users:${NC}"
        echo -e "  • Find ${YELLOW}Claude Code${NC} app in ~/Applications"
        echo -e "  • Double-click to launch in Terminal"
        echo ""
    fi

    echo -e "${BLUE}Other Commands:${NC}"
    echo -e "  ${GREEN}ccstop${NC}    - Stop the container"
    echo -e "  ${GREEN}cclogs${NC}    - View container logs"
    echo -e "  ${GREEN}ccrestart${NC} - Restart container"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
}

# Run setup
setup_bin_scripts
create_macos_app
print_instructions
