#!/bin/bash
# Install devai globally

INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="devai"

if [ "$EUID" -ne 0 ]; then
  echo "This script needs sudo access to install to $INSTALL_DIR"
  echo "Rerunning with sudo..."
  exec sudo bash "$0" "$@"
fi

# Get the actual script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create symlink
ln -sf "$SCRIPT_DIR/devai.sh" "$INSTALL_DIR/$SCRIPT_NAME"

echo "✓ Installed devai to $INSTALL_DIR"
echo ""
echo "You can now use it from anywhere:"
echo "  devai commit"
echo "  devai review"
echo "  devai bug \"description\""
echo ""
echo "To uninstall: sudo rm $INSTALL_DIR/$SCRIPT_NAME"
