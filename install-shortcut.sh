#!/usr/bin/env bash
# Install shortcut command for Claude Code Docker

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHORTCUT_NAME="cc"
BIN_DIR="$HOME/.local/bin"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "Installing shortcut command: $SHORTCUT_NAME"

# Create bin directory if it doesn't exist
mkdir -p "$BIN_DIR"

# Create the shortcut script
cat > "$BIN_DIR/$SHORTCUT_NAME" << EOF
#!/usr/bin/env bash
# Claude Code Docker Shortcut
cd "$INSTALL_DIR" && ./run_claude.sh "\$@"
EOF

chmod +x "$BIN_DIR/$SHORTCUT_NAME"

echo -e "${GREEN}✓${NC} Shortcut installed: ${BLUE}$SHORTCUT_NAME${NC}"
echo ""
echo "Usage:"
echo "  $SHORTCUT_NAME           # Launch Claude Code"
echo "  $SHORTCUT_NAME bash      # Open bash shell"
echo "  $SHORTCUT_NAME logs      # View logs"
echo "  $SHORTCUT_NAME stop      # Stop container"
echo ""

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "\033[1;33mNote:\033[0m Add this to your ~/.zshrc or ~/.bashrc:"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi
