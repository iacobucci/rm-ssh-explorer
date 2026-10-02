#!/bin/bash
# deploy.sh - Deploy ssh-explorer to reMarkable 2 tablet

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DEVICE_IP="${1:-10.11.99.1}"
REMOTE_USER="root"
REMOTE_DEST="/home/root/xovi/exthome/appload/ssh-explorer"

echo "=== Deploying SSH Explorer to reMarkable 2 ($DEVICE_IP) ==="

# Build first if dist directory doesn't exist
if [ ! -f "$SCRIPT_DIR/dist/ssh-explorer/resources.rcc" ]; then
    echo "Dist files not found, running build.sh first..."
    ./build.sh
fi

echo "Connecting to $REMOTE_USER@$DEVICE_IP..."

# Check connectivity
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$REMOTE_USER@$DEVICE_IP" "echo 'Connected OK'" >/dev/null 2>&1; then
    echo "Error: Cannot connect to $REMOTE_USER@$DEVICE_IP via SSH." >&2
    echo "Please ensure:" >&2
    echo "  1. The tablet is connected via USB cable (IP 10.11.99.1) or Wi-Fi" >&2
    echo "  2. SSH is enabled and authorized" >&2
    echo "Usage: ./deploy.sh [device_ip]" >&2
    exit 1
fi

echo "Creating remote destination directory: $REMOTE_DEST..."
ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$DEVICE_IP" "mkdir -p $REMOTE_DEST"

echo "Copying application files..."
scp -o StrictHostKeyChecking=no -r dist/ssh-explorer/* "$REMOTE_USER@$DEVICE_IP:$REMOTE_DEST/"

echo "Setting permissions..."
ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$DEVICE_IP" "chmod +x $REMOTE_DEST/ssh-helper.sh"

echo ""
echo "=== Deployment Successful! ==="
echo "SSH Explorer has been installed to $REMOTE_DEST."
echo "Open the AppLoad launcher on your reMarkable 2 to launch SSH Explorer."
echo "(If the icon does not appear immediately, tap 'Reload' in the AppLoad menu)."
