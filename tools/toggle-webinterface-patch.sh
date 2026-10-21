#!/bin/sh
# toggle-webinterface-patch.sh - Enables internal web interface in xochitl on Wi-Fi without USB cable
# Safely patches the 1-byte carrier check (0x33688c: bne -> b) so xochitl starts HttpListener on port 80.

set -e

XOCHITL_BIN="${XOCHITL_BIN:-/usr/bin/xochitl}"
BACKUP_BIN="${BACKUP_BIN:-/usr/bin/xochitl.stock_backup}"
OFFSET=3303564 # 0x32688c in decimal

if [ ! -f "$XOCHITL_BIN" ]; then
    echo "Error: $XOCHITL_BIN not found"
    exit 1
fi

ACTION="${1:-status}"

read_bytes() {
    hexdump -s $OFFSET -n 4 -e '4/1 "%02x"' "$XOCHITL_BIN" 2>/dev/null || od -j $OFFSET -N 4 -t x1 "$XOCHITL_BIN" 2>/dev/null | awk '{for(i=2;i<=NF;i++) printf "%s", $i}'
}

check_status() {
    BYTES=$(read_bytes)
    echo "Current bytes at 0x32688c: $BYTES"
    if [ "$BYTES" = "0e00001a" ]; then
        echo "Status: STOCK (carrier check active, port 80 requires USB cable)"
    elif [ "$BYTES" = "0e0000ea" ]; then
        echo "Status: PATCHED (carrier check bypassed, port 80 active on Wi-Fi/standalone)"
    else
        echo "Status: UNKNOWN byte sequence ($BYTES) - patch aborted for safety"
    fi
}

apply_patch() {
    BYTES=$(read_bytes)
    if [ "$BYTES" = "0e0000ea" ]; then
        echo "xochitl is already patched!"
        return 0
    fi
    if [ "$BYTES" != "0e00001a" ]; then
        echo "Safety check failed: expected 0e00001a, found $BYTES. Aborting."
        exit 1
    fi

    # Create backup if not present
    if [ ! -f "$BACKUP_BIN" ]; then
        echo "Creating safety backup at $BACKUP_BIN..."
        cp -p "$XOCHITL_BIN" "$BACKUP_BIN"
    fi

    echo "Applying carrier bypass patch..."
    # Replace byte 0x1a with 0xea at offset 0x32688f (OFFSET + 3)
    PATCH_OFFSET=$((OFFSET + 3))
    printf '\xEA' | dd of="$XOCHITL_BIN" bs=1 seek=$PATCH_OFFSET count=1 conv=notrunc 2>/dev/null

    # Ensure 10.11.99.1 is configured on usb0 or lo
    if command -v ip >/dev/null 2>&1; then
        if ! ip addr show 2>/dev/null | grep -q "10.11.99.1"; then
            ip addr add 10.11.99.1/27 dev usb0 2>/dev/null || ip addr add 10.11.99.1/32 dev lo 2>/dev/null || true
        fi
    fi

    echo "Patch applied successfully!"
    echo "Restarting xochitl once to load the patched web interface..."
    systemctl restart xochitl
    sleep 3

    echo "Checking port 80 status:"
    if curl -s -m 2 http://10.11.99.1/ >/dev/null 2>&1 || curl -s -m 2 http://127.0.0.1/ >/dev/null 2>&1; then
        echo "SUCCESS: xochitl web interface is now listening on port 80!"
        echo "All future PDF imports in SSH Explorer will appear live without restarting!"
    else
        echo "Note: Web server is initializing or needs a moment."
    fi
}

restore_stock() {
    if [ ! -f "$BACKUP_BIN" ]; then
        echo "Backup $BACKUP_BIN not found!"
        exit 1
    fi
    echo "Restoring stock binary from $BACKUP_BIN..."
    cp -p "$BACKUP_BIN" "$XOCHITL_BIN"
    systemctl restart xochitl
    echo "Restored stock xochitl and restarted service."
}

case "$ACTION" in
    apply)
        apply_patch
        ;;
    restore)
        restore_stock
        ;;
    status|*)
        check_status
        ;;
esac
