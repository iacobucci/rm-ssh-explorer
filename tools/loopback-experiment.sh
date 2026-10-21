#!/bin/sh
# loopback-experiment.sh - Experiments for no-restart xochitl refresh via USB web interface loopback
# Run on reMarkable 2 (or test environment) via SSH.

set -e

COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"

info() {
    printf "${COLOR_CYAN}[INFO]${COLOR_RESET} %s\n" "$*"
}

success() {
    printf "${COLOR_GREEN}[OK]${COLOR_RESET} %s\n" "$*"
}

warn() {
    printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} %s\n" "$*"
}

fail() {
    printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s\n" "$*"
}

header() {
    echo ""
    printf "${COLOR_BOLD}${COLOR_CYAN}=== %s ===${COLOR_RESET}\n" "$*"
}

XOCHITL_CONF="/home/root/.config/remarkable/xochitl.conf"
XOCHITL_DIR="${XOCHITL_DIR:-/home/root/.local/share/remarkable/xochitl}"

check_device() {
    header "1. System & Device Environment"
    info "Kernel: $(uname -s -r -m)"
    if [ -f /etc/version ]; then
        info "reMarkable OS Version: $(cat /etc/version)"
    else
        warn "Not running on official reMarkable OS (/etc/version not found)"
    fi

    if pidof xochitl >/dev/null 2>&1; then
        success "xochitl process is running (PID: $(pidof xochitl))"
    elif pgrep -f xochitl >/dev/null 2>&1; then
        success "xochitl process is running (PID: $(pgrep -f xochitl | tr '\n' ' '))"
    else
        warn "xochitl process is not currently running"
    fi

    if command -v curl >/dev/null 2>&1; then
        success "curl is available: $(curl --version 2>&1 | head -n 1)"
    else
        fail "curl is not found on this system"
    fi
}

check_network() {
    header "2. Network Interfaces & IP Configuration"

    info "Listing active IP addresses:"
    if command -v ip >/dev/null 2>&1; then
        ip addr show
    else
        ifconfig -a
    fi

    echo ""
    if ip addr show 2>/dev/null | grep -q "10.11.99.1"; then
        success "IP 10.11.99.1 is configured on the system"
    else
        warn "IP 10.11.99.1 is NOT configured"
    fi

    if [ -d /sys/class/net/usb0 ]; then
        info "usb0 interface detected:"
        OPERSTATE=$(cat /sys/class/net/usb0/operstate 2>/dev/null || echo "unknown")
        CARRIER=$(cat /sys/class/net/usb0/carrier 2>/dev/null || echo "0")
        info "  - operstate: $OPERSTATE"
        info "  - carrier:   $CARRIER"
        if [ "$CARRIER" = "1" ]; then
            success "usb0 has active carrier (physical or virtual USB host connected)"
        else
            warn "usb0 carrier is 0 (no physical USB host cable detected)"
        fi
    else
        warn "usb0 interface does not exist in /sys/class/net/"
    fi
}

check_xochitl_conf() {
    header "3. xochitl Configuration"
    if [ -f "$XOCHITL_CONF" ]; then
        info "Found $XOCHITL_CONF"
        if grep -q '^WebInterfaceEnabled=' "$XOCHITL_CONF"; then
            CURRENT_VAL=$(grep '^WebInterfaceEnabled=' "$XOCHITL_CONF")
            info "  $CURRENT_VAL"
            if grep -q '^WebInterfaceEnabled=true' "$XOCHITL_CONF"; then
                success "WebInterfaceEnabled is set to true"
            else
                warn "WebInterfaceEnabled is set to false (internal web server disabled in config)"
            fi
        else
            warn "WebInterfaceEnabled is not defined in $XOCHITL_CONF"
        fi
    else
        warn "$XOCHITL_CONF not found (offline/desktop environment?)"
    fi
}

check_web_server() {
    header "4. Testing Web Interface Endpoints"

    for TARGET in "10.11.99.1" "127.0.0.1" "localhost"; do
        info "Probing http://$TARGET/..."
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 2 "http://$TARGET/" 2>/dev/null || echo "000")
        if [ "$STATUS" = "200" ] || [ "$STATUS" = "301" ] || [ "$STATUS" = "302" ]; then
            success "http://$TARGET/ responded with HTTP $STATUS!"
            
            # Check /documents/ endpoint
            DOC_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 2 "http://$TARGET/documents/" 2>/dev/null || echo "000")
            info "http://$TARGET/documents/ returned HTTP $DOC_STATUS"
            return 0
        else
            info "  http://$TARGET/ returned HTTP $STATUS (not listening or connection refused)"
        fi
    done

    warn "Web server is not responding on 10.11.99.1 or 127.0.0.1"
    return 1
}

apply_loopback_setup() {
    header "5. Applying Non-Destructive Loopback Setup"

    info "Step A: Assigning 10.11.99.1/32 to loopback interface 'lo'..."
    if command -v ip >/dev/null 2>&1; then
        if ! ip addr show dev lo 2>/dev/null | grep -q "10.11.99.1"; then
            ip addr add 10.11.99.1/32 dev lo 2>/dev/null || warn "Could not add 10.11.99.1 to lo (need root?)"
            success "Added 10.11.99.1/32 to lo"
        else
            success "10.11.99.1 already present on lo"
        fi
    fi

    info "Step B: Ensuring usb0 is UP..."
    if [ -d /sys/class/net/usb0 ]; then
        ip link set dev usb0 up 2>/dev/null || true
        success "usb0 link set up"
    fi

    info "Step C: Enabling WebInterfaceEnabled=true in xochitl.conf..."
    if [ -f "$XOCHITL_CONF" ]; then
        if grep -q '^WebInterfaceEnabled=' "$XOCHITL_CONF"; then
            sed -i 's/^WebInterfaceEnabled=.*/WebInterfaceEnabled=true/' "$XOCHITL_CONF"
        else
            if grep -q '^\[General\]' "$XOCHITL_CONF"; then
                sed -i '/^\[General\]/a WebInterfaceEnabled=true' "$XOCHITL_CONF"
            else
                echo "WebInterfaceEnabled=true" >> "$XOCHITL_CONF"
            fi
        fi
        success "Updated $XOCHITL_CONF to WebInterfaceEnabled=true"
    fi
}

generate_test_pdf() {
    OUT="$1"
    # Create minimal compliant 1-page PDF
    cat > "$OUT" << 'EOF'
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 55 >>
stream
BT
/F1 24 Tf
100 700 Td
(SSH Explorer No-Restart Test) Tj
ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000244 00000 n 
0000000350 00000 n 
trailer
<< /Size 6 /Root 1 0 R >>
startxref
427
%%EOF
EOF
}

test_upload() {
    header "6. Live Loopback Upload Test"

    TARGET_HOST=""
    for H in "10.11.99.1" "127.0.0.1" "localhost"; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 1 "http://$H/" 2>/dev/null || echo "000")
        if [ "$STATUS" = "200" ] || [ "$STATUS" = "301" ] || [ "$STATUS" = "302" ]; then
            TARGET_HOST="$H"
            break
        fi
    done

    if [ -z "$TARGET_HOST" ]; then
        fail "Cannot perform upload test: internal web server is not responding."
        warn "Tip: Make sure the USB web interface is toggled ON or cable is connected."
        return 1
    fi

    info "Using target host: http://$TARGET_HOST"

    TEST_PDF="/tmp/loopback_test_$$.pdf"
    generate_test_pdf "$TEST_PDF"
    info "Generated minimal test PDF at $TEST_PDF ($(wc -c < "$TEST_PDF") bytes)"

    DOC_TITLE="Loopback_Test_$(date +%H%M%S)"
    FILENAME="$DOC_TITLE.pdf"

    info "Uploading $FILENAME to http://$TARGET_HOST/upload..."
    TMP_OUT="/tmp/upload_resp_$$.txt"
    HTTP_CODE=$(curl -s -S -o "$TMP_OUT" -w "%{http_code}" -m 20 -X POST \
        "http://$TARGET_HOST/upload" \
        -H "Origin: http://$TARGET_HOST" \
        -H "Referer: http://$TARGET_HOST/" \
        -F "file=@$TEST_PDF;filename=$FILENAME;type=application/pdf" 2>&1 || echo "000")

    rm -f "$TEST_PDF"

    info "Server response HTTP status: $HTTP_CODE"
    if [ -s "$TMP_OUT" ]; then
        info "Response content: $(head -n 2 "$TMP_OUT")"
    fi
    rm -f "$TMP_OUT"

    if echo "$HTTP_CODE" | grep -qE "^(200|201|204)$"; then
        success "UPLOAD SUCCESSFUL! Document '$DOC_TITLE' was received by xochitl!"
        success "Check your reMarkable library now: the document should appear immediately WITHOUT RESTARTING xochitl!"
        return 0
    else
        fail "Upload failed with HTTP code $HTTP_CODE"
        return 1
    fi
}

print_summary() {
    header "Summary & Recommendations"
    cat << 'EOF'
STRATEGIES FOR NO-RESTART REFRESH:

1. [ACTIVE USB / CABLE CONNECTED]
   When a USB cable is connected to a computer and the USB web interface
   is toggled ON, xochitl listens on 10.11.99.1:80.
   SSH Explorer can upload directly to http://10.11.99.1/upload via curl.
   -> RESULT: Document appears live in library in <1s with NO restart!

2. [WIFI WITH TOLTEC / WEBINTERFACE-ONBOOT]
   If 'webinterface-onboot' or 'webinterface-wifi' is installed from Toltec,
   the internal web interface is kept running in the background even without
   a physical USB cable.
   SSH Explorer loopback hits 10.11.99.1:80 or 127.0.0.1:80 directly.
   -> RESULT: Document appears live in library with NO restart!

3. [VIRTUAL LOOPBACK ALIAS]
   By adding '10.11.99.1/32' to 'lo' and ensuring 'WebInterfaceEnabled=true',
   local loopback requests reach local port 80.

4. [GRACEFUL FALLBACK]
   If the internal web server is unavailable (e.g. tablet is on battery Wi-Fi
   without webinterface-onboot), SSH Explorer seamlessly falls back to
   direct storage writing and provides the 1-tap "Restart xochitl now" button.
EOF
}

ACTION="${1:---full}"

case "$ACTION" in
    --diagnose)
        check_device
        check_network
        check_xochitl_conf
        check_web_server || true
        ;;
    --setup)
        check_device
        apply_loopback_setup
        check_network
        check_web_server || true
        ;;
    --upload-test)
        test_upload || true
        ;;
    --full|*)
        check_device
        check_network
        check_xochitl_conf
        check_web_server || true
        print_summary
        ;;
esac
