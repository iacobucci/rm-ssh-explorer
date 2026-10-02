#!/bin/bash
# build.sh - Build and package ssh-explorer for reMarkable 2 (AppLoad)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building SSH Explorer for reMarkable 2 ==="

# Check requirements
if ! command -v rcc >/dev/null 2>&1; then
    echo "Error: 'rcc' (Qt resource compiler) is required but not installed." >&2
    exit 1
fi

DIST_DIR="$SCRIPT_DIR/dist/ssh-explorer"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "[1/4] Compiling QML resources into resources.rcc..."
rcc --binary -o "$DIST_DIR/resources.rcc" application.qrc

echo "[2/4] Copying manifest and icon..."
cp manifest.json "$DIST_DIR/"
cp icon.png "$DIST_DIR/"

echo "[3/4] Copying and preparing ssh-helper.sh..."
cp ssh-helper.sh "$DIST_DIR/"
chmod +x "$DIST_DIR/ssh-helper.sh"

echo "[4/4] Creating tarball for easy transfer..."
cd "$SCRIPT_DIR/dist"
tar -czf ssh-explorer.tar.gz ssh-explorer/

echo ""
echo "=== Build completed successfully! ==="
echo "Output files located in: $DIST_DIR"
echo "Tarball archive: $SCRIPT_DIR/dist/ssh-explorer.tar.gz"
echo ""
echo "To install on reMarkable 2, copy files to:"
echo "  /home/root/xovi/exthome/appload/ssh-explorer/"
echo "Or run:"
echo "  ./deploy.sh [device_ip (default: 10.11.99.1)]"
