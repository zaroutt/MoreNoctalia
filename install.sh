#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installing noctalia config ==="
cp -rv "$SCRIPT_DIR/noctalia/"* "$HOME/.config/noctalia/"

echo ""
echo "=== Installing noctalia-shell (requires sudo) ==="
sudo cp -rv "$SCRIPT_DIR/noctalia-shell/"* /etc/xdg/quickshell/noctalia-shell/

echo ""
echo "=== Done ==="
echo "Restart noctalia-shell: echo 1 | sudo tee /tmp/do-quickshell-reload"
