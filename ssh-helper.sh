#!/bin/sh
# ssh-helper.sh - Helper script for SSH Explorer on reMarkable 2
# Provides JSON-based CLI subcommands for QML interface.


# Default locations
XOCHITL_DIR="${XOCHITL_DIR:-/home/root/.local/share/remarkable/xochitl}"
CONFIG_DIR="${CONFIG_DIR:-/home/root/.config/ssh-explorer}"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Detect SSH client: Dropbear (dbclient) or OpenSSH (ssh)
setup_ssh_cmd() {
    HOST="$1"
    PORT="${2:-22}"
    USER="${3:-root}"
    KEY="$4"

    if [ -z "$PORT" ] || [ "$PORT" = "0" ]; then
        PORT=22
    fi
    if [ -z "$USER" ]; then
        USER="root"
    fi

    # Determine command
    if command -v dbclient >/dev/null 2>&1; then
        SSH_BIN="dbclient"
        # -y: automatically accept unknown host keys
        # -I: idle timeout
        # -K: keepalive interval
        SSH_ARGS="-y -p $PORT -I 12 -K 5"
        if [ -n "$KEY" ] && [ -f "$KEY" ]; then
            SSH_ARGS="$SSH_ARGS -i $KEY"
        fi
        SSH_TARGET="$USER@$HOST"
    elif command -v ssh >/dev/null 2>&1; then
        SSH_BIN="ssh"
        SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -p $PORT"
        if [ -n "$KEY" ] && [ -f "$KEY" ]; then
            SSH_ARGS="$SSH_ARGS -i $KEY"
        fi
        SSH_TARGET="$USER@$HOST"
    else
        printf '{"success":false,"error":"Neither dbclient nor ssh binary found on device"}\n'
        exit 1
    fi
}

# Run SSH with optional timeout
run_ssh() {
    # If timeout command is available, use it
    if command -v timeout >/dev/null 2>&1; then
        timeout 15 "$SSH_BIN" $SSH_ARGS "$SSH_TARGET" "$@"
    else
        "$SSH_BIN" $SSH_ARGS "$SSH_TARGET" "$@"
    fi
}

cmd_test_connection() {
    HOST="$1"
    PORT="$2"
    USER="$3"
    KEY="$4"

    if [ -z "$HOST" ]; then
        printf '{"success":false,"error":"Host is required"}\n'
        return
    fi

    setup_ssh_cmd "$HOST" "$PORT" "$USER" "$KEY"

    OUTPUT=$(run_ssh "echo __SSH_EXPLORER_OK__" 2>&1)
    STATUS=$?

    if [ $STATUS -eq 0 ] && echo "$OUTPUT" | grep -q "__SSH_EXPLORER_OK__"; then
        printf '{"success":true,"message":"Connection established successfully"}\n'
    else
        CLEAN_ERR=$(echo "$OUTPUT" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":false,"error":"%s"}\n' "$CLEAN_ERR"
    fi
}

cmd_list_dir() {
    HOST="$1"
    PORT="$2"
    USER="$3"
    KEY="$4"
    REMOTE_PATH="$5"

    if [ -z "$HOST" ]; then
        printf '{"success":false,"error":"Host is required"}\n'
        return
    fi

    setup_ssh_cmd "$HOST" "$PORT" "$USER" "$KEY"

    # Send remote shell probe
    RAW_OUT=$(run_ssh "sh -s -- \"$REMOTE_PATH\"" << 'REMOTE_EOF' 2>&1
TARGET="$1"
if [ "$TARGET" = "~" ] || [ -z "$TARGET" ]; then
    cd "$HOME" 2>/dev/null || cd /
else
    if ! cd "$TARGET" 2>/dev/null; then
        CD_ERR=$(cd "$TARGET" 2>&1)
        CLEAN_CD_ERR=$(echo "$CD_ERR" | tr '\n' ' ' | sed 's/.*: //')
        [ -z "$CLEAN_CD_ERR" ] && CLEAN_CD_ERR="Permission denied or directory unreachable"
        echo "ERR:Cannot access directory '$TARGET': $CLEAN_CD_ERR"
        exit 1
    fi
fi

CWD=$(pwd -L 2>/dev/null || pwd)
echo "CWD:$CWD"

for f in .* *; do
    [ "$f" = "." ] && continue
    [ "$f" = ".." ] && continue
    [ ! -e "$f" ] && [ ! -L "$f" ] && continue
    if [ -d "$f" ]; then
        echo "D:$f"
    elif [ -f "$f" ]; then
        sz=$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f" 2>/dev/null || ls -ldn "$f" 2>/dev/null | awk '{print $5}' || echo 0)
        sz=$(echo "$sz" | tr -d ' ')
        echo "F:$sz:$f"
    fi
done
REMOTE_EOF
)
    STATUS=$?

    if [ $STATUS -ne 0 ] || echo "$RAW_OUT" | grep -q "^ERR:"; then
        CLEAN_ERR=$(echo "$RAW_OUT" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":false,"error":"%s"}\n' "$CLEAN_ERR"
        return
    fi

    # Format into JSON using awk
    echo "$RAW_OUT" | awk -F: '
    BEGIN {
        cwd = "/"
        d_count = 0
        f_count = 0
    }
    /^CWD:/ {
        cwd = substr($0, 5)
        next
    }
    /^D:/ {
        name = substr($0, 3)
        dirs[d_count++] = name
        next
    }
    /^F:/ {
        size = $2
        name = substr($0, length($1) + length($2) + 3)
        files_name[f_count] = name
        files_size[f_count] = size
        f_count++
        next
    }
    END {
        parent = cwd
        sub(/\/[^\/]*$/, "", parent)
        if (parent == "") parent = "/"

        gsub(/\\/, "\\\\", cwd)
        gsub(/"/, "\\\"", cwd)
        gsub(/\\/, "\\\\", parent)
        gsub(/"/, "\\\"", parent)

        printf "{\"success\":true,\"path\":\"%s\",\"parent\":\"%s\",\"entries\":[", cwd, parent
        first = 1

        # Dirs first
        for (i = 0; i < d_count; i++) {
            n = dirs[i]
            if (cwd == "/") full_path = "/" n
            else full_path = cwd "/" n

            gsub(/\\/, "\\\\", n)
            gsub(/"/, "\\\"", n)
            gsub(/\\/, "\\\\", full_path)
            gsub(/"/, "\\\"", full_path)

            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"path\":\"%s\",\"rel_path\":\"%s\",\"sub_dir\":\"\",\"type\":\"dir\",\"is_pdf\":false,\"size\":0,\"size_str\":\"\"}", n, full_path, n
        }

        # Files
        for (i = 0; i < f_count; i++) {
            n = files_name[i]
            sz = files_size[i] + 0
            if (cwd == "/") full_path = "/" n
            else full_path = cwd "/" n

            is_pdf = (tolower(n) ~ /\.pdf$/) ? "true" : "false"

            if (sz >= 1073741824) sz_str = sprintf("%.1f GB", sz / 1073741824)
            else if (sz >= 1048576) sz_str = sprintf("%.1f MB", sz / 1048576)
            else if (sz >= 1024) sz_str = sprintf("%.1f KB", sz / 1024)
            else sz_str = sprintf("%d B", sz)

            gsub(/\\/, "\\\\", n)
            gsub(/"/, "\\\"", n)
            gsub(/\\/, "\\\\", full_path)
            gsub(/"/, "\\\"", full_path)

            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"path\":\"%s\",\"rel_path\":\"%s\",\"sub_dir\":\"\",\"type\":\"file\",\"is_pdf\":%s,\"size\":%d,\"size_str\":\"%s\"}", n, full_path, n, is_pdf, sz, sz_str
        }

        printf "]}\n"
    }
    '
}

cmd_search_dir() {
    HOST="$1"
    PORT="$2"
    USER="$3"
    KEY="$4"
    REMOTE_PATH="$5"
    QUERY="$6"

    if [ -z "$HOST" ]; then
        printf '{"success":false,"error":"Host is required"}\n'
        return
    fi

    setup_ssh_cmd "$HOST" "$PORT" "$USER" "$KEY"

    # Send remote search probe via SSH
    RAW_OUT=$(run_ssh "sh -s -- \"$REMOTE_PATH\" \"$QUERY\"" << 'REMOTE_SEARCH_EOF' 2>&1
TARGET="$1"
QUERY="$2"

if [ "$TARGET" = "~" ] || [ -z "$TARGET" ]; then
    cd "$HOME" 2>/dev/null || cd /
else
    if ! cd "$TARGET" 2>/dev/null; then
        CD_ERR=$(cd "$TARGET" 2>&1)
        CLEAN_CD_ERR=$(echo "$CD_ERR" | tr '\n' ' ' | sed 's/.*: //')
        [ -z "$CLEAN_CD_ERR" ] && CLEAN_CD_ERR="Permission denied or directory unreachable"
        echo "ERR:Cannot access directory '$TARGET': $CLEAN_CD_ERR"
        exit 1
    fi
fi

CWD=$(pwd -L 2>/dev/null || pwd)
echo "CWD:$CWD"

if [ -z "$QUERY" ]; then
    exit 0
fi

# Detect case-insensitive find option
INAME_FLAG="-iname"
if ! find . -maxdepth 0 -iname "." >/dev/null 2>&1; then
    INAME_FLAG="-name"
fi

# Construct find search arguments safely with positional parameters (no eval)
set -- . -mindepth 1
first=1
for word in $QUERY; do
    [ -z "$word" ] && continue
    if [ $first -eq 1 ]; then
        set -- "$@" "(" "$INAME_FLAG" "*$word*"
        first=0
    else
        set -- "$@" "-a" "$INAME_FLAG" "*$word*"
    fi
done

if [ $first -eq 0 ]; then
    set -- "$@" ")"
else
    set -- "$@" "$INAME_FLAG" "*$QUERY*"
fi

find "$@" 2>/dev/null | head -n 250 | while IFS= read -r p; do
    [ -z "$p" ] && continue
    p="${p#./}"
    if [ -d "$p" ]; then
        echo "D:$p"
    elif [ -f "$p" ]; then
        sz=$(stat -c %s "$p" 2>/dev/null || stat -f %z "$p" 2>/dev/null || ls -ldn "$p" 2>/dev/null | awk '{print $5}' || echo 0)
        sz=$(echo "$sz" | tr -d ' ')
        echo "F:$sz:$p"
    fi
done
REMOTE_SEARCH_EOF
)
    STATUS=$?

    if [ $STATUS -ne 0 ] || echo "$RAW_OUT" | grep -q "^ERR:"; then
        CLEAN_ERR=$(echo "$RAW_OUT" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":false,"error":"%s"}\n' "$CLEAN_ERR"
        return
    fi

    # Format into JSON using awk
    echo "$RAW_OUT" | awk -F: '
    BEGIN {
        cwd = "/"
        d_count = 0
        f_count = 0
    }
    /^CWD:/ {
        cwd = substr($0, 5)
        next
    }
    /^D:/ {
        rel = substr($0, 3)
        dirs[d_count++] = rel
        next
    }
    /^F:/ {
        size = $2
        rel = substr($0, length($1) + length($2) + 3)
        files_name[f_count] = rel
        files_size[f_count] = size
        f_count++
        next
    }
    END {
        parent = cwd
        sub(/\/[^\/]*$/, "", parent)
        if (parent == "") parent = "/"

        gsub(/\\/, "\\\\", cwd)
        gsub(/"/, "\\\"", cwd)
        gsub(/\\/, "\\\\", parent)
        gsub(/"/, "\\\"", parent)

        printf "{\"success\":true,\"path\":\"%s\",\"parent\":\"%s\",\"entries\":[", cwd, parent
        first = 1

        # Dirs first
        for (i = 0; i < d_count; i++) {
            rel = dirs[i]
            n = rel
            sub(".*/", "", n)
            sub_dir = ""
            if (index(rel, "/") > 0) {
                sub_dir = rel
                sub(/\/[^\/]*$/, "", sub_dir)
            }
            if (cwd == "/") full_path = "/" rel
            else full_path = cwd "/" rel

            gsub(/\\/, "\\\\", n)
            gsub(/"/, "\\\"", n)
            gsub(/\\/, "\\\\", rel)
            gsub(/"/, "\\\"", rel)
            gsub(/\\/, "\\\\", sub_dir)
            gsub(/"/, "\\\"", sub_dir)
            gsub(/\\/, "\\\\", full_path)
            gsub(/"/, "\\\"", full_path)

            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"path\":\"%s\",\"rel_path\":\"%s\",\"sub_dir\":\"%s\",\"type\":\"dir\",\"is_pdf\":false,\"size\":0,\"size_str\":\"\"}", n, full_path, rel, sub_dir
        }

        # Files
        for (i = 0; i < f_count; i++) {
            rel = files_name[i]
            sz = files_size[i] + 0
            n = rel
            sub(".*/", "", n)
            sub_dir = ""
            if (index(rel, "/") > 0) {
                sub_dir = rel
                sub(/\/[^\/]*$/, "", sub_dir)
            }
            if (cwd == "/") full_path = "/" rel
            else full_path = cwd "/" rel

            is_pdf = (tolower(n) ~ /\.pdf$/) ? "true" : "false"

            if (sz >= 1073741824) sz_str = sprintf("%.1f GB", sz / 1073741824)
            else if (sz >= 1048576) sz_str = sprintf("%.1f MB", sz / 1048576)
            else if (sz >= 1024) sz_str = sprintf("%.1f KB", sz / 1024)
            else sz_str = sprintf("%d B", sz)

            gsub(/\\/, "\\\\", n)
            gsub(/"/, "\\\"", n)
            gsub(/\\/, "\\\\", rel)
            gsub(/"/, "\\\"", rel)
            gsub(/\\/, "\\\\", sub_dir)
            gsub(/"/, "\\\"", sub_dir)
            gsub(/\\/, "\\\\", full_path)
            gsub(/"/, "\\\"", full_path)

            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"path\":\"%s\",\"rel_path\":\"%s\",\"sub_dir\":\"%s\",\"type\":\"file\",\"is_pdf\":%s,\"size\":%d,\"size_str\":\"%s\"}", n, full_path, rel, sub_dir, is_pdf, sz, sz_str
        }

        printf "]}\n"
    }
    '
}

# --- USB Loopback & No-Restart Library Refresh ---

# Probe candidates for reMarkable internal web server
probe_web_server() {
    if ! command -v curl >/dev/null 2>&1; then
        return 1
    fi

    # Check candidates: optional LOOPBACK_HOST override, then 10.11.99.1, then 127.0.0.1, then localhost
    for CANDIDATE in ${LOOPBACK_HOST:+"$LOOPBACK_HOST"} "10.11.99.1" "127.0.0.1" "localhost"; do
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 2 "http://$CANDIDATE/" 2>/dev/null || true)
        if [ "$STATUS_CODE" = "200" ] || [ "$STATUS_CODE" = "301" ] || [ "$STATUS_CODE" = "302" ]; then
            echo "$CANDIDATE"
            return 0
        fi
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 2 "http://$CANDIDATE/documents/" 2>/dev/null || true)
        if [ "$STATUS_CODE" = "200" ]; then
            echo "$CANDIDATE"
            return 0
        fi
    done
    return 1
}

# Attempt non-disruptive loopback setup
setup_loopback_env() {
    # 1. Ensure 10.11.99.1 is bound to loopback or an interface so local connection succeeds
    if command -v ip >/dev/null 2>&1; then
        if ! ip addr show dev lo 2>/dev/null | grep -q "10.11.99.1"; then
            ip addr add 10.11.99.1/32 dev lo 2>/dev/null || true
        fi
        if [ -d /sys/class/net/usb0 ]; then
            ip link set dev usb0 up 2>/dev/null || true
        fi
    elif command -v ifconfig >/dev/null 2>&1; then
        if ! ifconfig 2>/dev/null | grep -q "10.11.99.1"; then
            ifconfig lo:1 10.11.99.1 netmask 255.255.255.255 up 2>/dev/null || true
        fi
    fi
}

# Direct xochitl document storage creation (fallback when web server is not running)
import_direct_xochitl() {
    SRC_PDF="$1"
    DOC_TITLE="$2"

    mkdir -p "$XOCHITL_DIR"

    UUID=""
    if [ -f /proc/sys/kernel/random/uuid ]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    elif command -v uuidgen >/dev/null 2>&1; then
        UUID=$(uuidgen)
    else
        UUID=$(od -x /dev/urandom 2>/dev/null | head -1 | awk '{printf "%s-%s-%s-%s-%s", $2, $3, $4, $5, $6$7}')
    fi

    if [ -z "$UUID" ]; then
        rm -f "$SRC_PDF"
        printf '{"success":false,"error":"Failed to generate UUID for document import"}\n'
        return 1
    fi

    mv "$SRC_PDF" "$XOCHITL_DIR/$UUID.pdf"

    NOW_MS=$(date +%s)000
    cat > "$XOCHITL_DIR/$UUID.metadata" << META_EOF
{
  "deleted": false,
  "lastModified": "$NOW_MS",
  "metadatamodified": true,
  "modified": true,
  "parent": "",
  "pinned": false,
  "synced": false,
  "type": "DocumentType",
  "version": 1,
  "visibleName": "$DOC_TITLE"
}
META_EOF

    cat > "$XOCHITL_DIR/$UUID.content" << CONTENT_EOF
{
  "extraMetadata": {},
  "fileType": "pdf",
  "pageCount": 0,
  "lastOpenedPage": 0,
  "lineHeight": -1,
  "margins": 180,
  "textScale": 1,
  "transform": {}
}
CONTENT_EOF

    SAFE_TITLE=$(echo "$DOC_TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"success":true,"method":"direct_xochitl","norestart":false,"title":"%s","uuid":"%s","message":"Document imported to storage (restart required to display)"}\n' "$SAFE_TITLE" "$UUID"
    return 0
}

# Upload PDF via internal web server loopback
upload_via_web_loopback() {
    PDF_FILE="$1"
    DOC_TITLE="$2"

    if [ ! -f "$PDF_FILE" ]; then
        return 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        return 2
    fi

    SERVER_HOST=$(probe_web_server)
    if [ -z "$SERVER_HOST" ]; then
        setup_loopback_env
        SERVER_HOST=$(probe_web_server)
    fi

    if [ -z "$SERVER_HOST" ]; then
        return 3
    fi

    # Sanitize title for filename used by xochitl as visible title
    CLEAN_TITLE=$(echo "$DOC_TITLE" | sed 's/\.[pP][dD][fF]$//')
    SAFE_NAME=$(echo "$CLEAN_TITLE" | sed 's/[^a-zA-Z0-9._ -]/_/g')
    [ -z "$SAFE_NAME" ] && SAFE_NAME="document"
    SAFE_NAME="$SAFE_NAME.pdf"

    TMP_RESP="/tmp/ssh_loopback_resp_$$.txt"
    rm -f "$TMP_RESP"

    HTTP_STATUS=$(curl -s -S -o "$TMP_RESP" -w "%{http_code}" -m 30 -X POST \
        "http://$SERVER_HOST/upload" \
        -H "Origin: http://$SERVER_HOST" \
        -H "Referer: http://$SERVER_HOST/" \
        -F "file=@$PDF_FILE;filename=$SAFE_NAME;type=application/pdf" 2>/dev/null || echo "000")

    rm -f "$TMP_RESP"

    if echo "$HTTP_STATUS" | grep -qE "^(200|201|204)$"; then
        return 0
    fi

    return 4
}

cmd_import_pdf() {
    HOST="$1"
    PORT="$2"
    USER="$3"
    KEY="$4"
    REMOTE_PATH="$5"
    TITLE="$6"

    if [ -z "$HOST" ] || [ -z "$REMOTE_PATH" ]; then
        printf '{"success":false,"error":"Host and remote file path are required"}\n'
        return
    fi

    setup_ssh_cmd "$HOST" "$PORT" "$USER" "$KEY"

    FILENAME=$(basename "$REMOTE_PATH")
    if [ -z "$TITLE" ]; then
        TITLE="$FILENAME"
        # Strip .pdf suffix from title if present
        TITLE=$(echo "$TITLE" | sed 's/\.[pP][dD][fF]$//')
    fi

    TMP_PDF="/tmp/ssh_import_$$.pdf"
    TMP_ERR="/tmp/ssh_import_$$.err"
    rm -f "$TMP_PDF" "$TMP_ERR"

    # Download via SSH streaming with generous timeout
    # Pass REMOTE_PATH safely via sh -s to handle spaces and quotes
    if command -v timeout >/dev/null 2>&1; then
        timeout 180 "$SSH_BIN" $SSH_ARGS "$SSH_TARGET" "sh -s -- \"$REMOTE_PATH\"" << 'REMOTE_CAT_EOF' > "$TMP_PDF" 2> "$TMP_ERR"
TARGET="$1"
if [ ! -f "$TARGET" ] && [ ! -r "$TARGET" ]; then
    echo "Cannot read remote file: $TARGET" >&2
    exit 1
fi
exec cat "$TARGET"
REMOTE_CAT_EOF
        STATUS=$?
    else
        "$SSH_BIN" $SSH_ARGS "$SSH_TARGET" "sh -s -- \"$REMOTE_PATH\"" << 'REMOTE_CAT_EOF' > "$TMP_PDF" 2> "$TMP_ERR"
TARGET="$1"
if [ ! -f "$TARGET" ] && [ ! -r "$TARGET" ]; then
    echo "Cannot read remote file: $TARGET" >&2
    exit 1
fi
exec cat "$TARGET"
REMOTE_CAT_EOF
        STATUS=$?
    fi

    if [ $STATUS -ne 0 ] || [ ! -s "$TMP_PDF" ]; then
        ERR_MSG="Failed to download file from remote host"
        if [ -s "$TMP_ERR" ]; then
            ERR_MSG=$(head -n 2 "$TMP_ERR" | tr '\n' ' ')
        fi
        rm -f "$TMP_PDF" "$TMP_ERR"
        CLEAN_ERR=$(echo "$ERR_MSG" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":false,"error":"%s"}\n' "$CLEAN_ERR"
        return
    fi
    rm -f "$TMP_ERR"

    # Verify PDF magic bytes using dd (POSIX and BusyBox compliant, avoids missing head -c)
    HEADER=$(dd if="$TMP_PDF" bs=4 count=1 2>/dev/null || true)
    if [ "$HEADER" != "%PDF" ] && ! head -n 3 "$TMP_PDF" 2>/dev/null | grep -q "%PDF"; then
        rm -f "$TMP_PDF"
        printf '{"success":false,"error":"%s"}\n' "Downloaded file is not a valid PDF (missing %PDF header)"
        return
    fi

    # Attempt 1: Upload via internal USB web interface loopback (no restart needed!)
    if upload_via_web_loopback "$TMP_PDF" "$TITLE"; then
        rm -f "$TMP_PDF"
        SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":true,"method":"web_loopback","norestart":true,"title":"%s","message":"Document imported live into library via internal server (no restart required)!"}\n' "$SAFE_TITLE"
        return
    fi

    # Attempt 2: Fallback to direct xochitl storage creation (requires xochitl restart to display)
    import_direct_xochitl "$TMP_PDF" "$TITLE"
}

cmd_load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        # Default configuration
        cat << 'DEF_CONF'
{
  "success": true,
  "activeProfile": "Default",
  "profiles": [
    {
      "name": "Default",
      "host": "",
      "port": 22,
      "user": "root",
      "key": "/home/root/.ssh/id_dropbear",
      "remotePath": "~"
    }
  ]
}
DEF_CONF
    fi
}

cmd_save_config() {
    JSON_DATA="$1"
    if [ -z "$JSON_DATA" ]; then
        printf '{"success":false,"error":"No configuration data provided"}\n'
        return
    fi
    mkdir -p "$CONFIG_DIR"
    echo "$JSON_DATA" > "$CONFIG_FILE"
    printf '{"success":true,"message":"Configuration saved"}\n'
}

cmd_import_local_pdf() {
    LOCAL_PATH="$1"
    TITLE="$2"

    if [ -z "$LOCAL_PATH" ] || [ ! -f "$LOCAL_PATH" ]; then
        printf '{"success":false,"error":"Local file not found"}\n'
        return
    fi

    FILENAME=$(basename "$LOCAL_PATH")
    if [ -z "$TITLE" ]; then
        TITLE="$FILENAME"
        TITLE=$(echo "$TITLE" | sed 's/\.[pP][dD][fF]$//')
    fi

    TMP_PDF="/tmp/ssh_import_$$.pdf"
    cp "$LOCAL_PATH" "$TMP_PDF"

    HEADER=$(dd if="$TMP_PDF" bs=4 count=1 2>/dev/null || true)
    if [ "$HEADER" != "%PDF" ] && ! head -n 3 "$TMP_PDF" 2>/dev/null | grep -q "%PDF"; then
        rm -f "$TMP_PDF"
        printf '{"success":false,"error":"%s"}\n' "File is not a valid PDF (missing %PDF header)"
        return
    fi

    # Attempt 1: Upload via internal USB web interface loopback (no restart needed!)
    if upload_via_web_loopback "$TMP_PDF" "$TITLE"; then
        rm -f "$TMP_PDF"
        SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":true,"method":"web_loopback","norestart":true,"title":"%s","message":"Document imported live into library via internal server (no restart required)!"}\n' "$SAFE_TITLE"
        return
    fi

    # Attempt 2: Fallback to direct xochitl storage creation
    import_direct_xochitl "$TMP_PDF" "$TITLE"
}

cmd_test_loopback() {
    setup_loopback_env

    CURL_AVAIL="false"
    if command -v curl >/dev/null 2>&1; then
        CURL_AVAIL="true"
    fi

    WEB_ACTIVE="false"
    ACTIVE_HOST=""
    PROBED_HOST=$(probe_web_server || true)
    if [ -n "$PROBED_HOST" ]; then
        WEB_ACTIVE="true"
        ACTIVE_HOST="$PROBED_HOST"
    fi

    CONF_ENABLED="unknown"
    XOCHITL_CONF="/home/root/.config/remarkable/xochitl.conf"
    if [ -f "$XOCHITL_CONF" ]; then
        if grep -q '^WebInterfaceEnabled=true' "$XOCHITL_CONF"; then
            CONF_ENABLED="true"
        elif grep -q '^WebInterfaceEnabled=false' "$XOCHITL_CONF"; then
            CONF_ENABLED="false"
        else
            CONF_ENABLED="not_set"
        fi
    fi

    IP10_PRESENT="false"
    if ip addr show 2>/dev/null | grep -q "10.11.99.1"; then
        IP10_PRESENT="true"
    elif ifconfig 2>/dev/null | grep -q "10.11.99.1"; then
        IP10_PRESENT="true"
    fi

    USB0_PRESENT="false"
    USB0_STATE="down"
    USB0_CARRIER="0"
    if [ -d "/sys/class/net/usb0" ]; then
        USB0_PRESENT="true"
        if [ -f "/sys/class/net/usb0/operstate" ]; then
            USB0_STATE=$(cat "/sys/class/net/usb0/operstate" 2>/dev/null || echo "unknown")
        fi
        if [ -f "/sys/class/net/usb0/carrier" ]; then
            USB0_CARRIER=$(cat "/sys/class/net/usb0/carrier" 2>/dev/null || echo "0")
        fi
    fi

    STATUS_MSG=""
    if [ "$WEB_ACTIVE" = "true" ]; then
        STATUS_MSG="Internal Web Server is active on $ACTIVE_HOST. No-Restart mode is ready!"
    else
        STATUS_MSG="Internal Web Server is not responding. Direct storage write fallback will be used."
    fi

    printf '{"success":true,"webServerActive":%s,"listeningHost":"%s","curlAvailable":%s,"xochitlConfWebEnabled":"%s","ip10Present":%s,"usb0Present":%s,"usb0State":"%s","usb0Carrier":"%s","message":"%s"}\n' \
        "$WEB_ACTIVE" "$ACTIVE_HOST" "$CURL_AVAIL" "$CONF_ENABLED" "$IP10_PRESENT" "$USB0_PRESENT" "$USB0_STATE" "$USB0_CARRIER" "$STATUS_MSG"
}

cmd_enable_loopback() {
    setup_loopback_env

    CONF_UPDATED="false"
    XOCHITL_CONF="/home/root/.config/remarkable/xochitl.conf"
    if [ -f "$XOCHITL_CONF" ]; then
        if grep -q '^WebInterfaceEnabled=' "$XOCHITL_CONF"; then
            sed -i 's/^WebInterfaceEnabled=.*/WebInterfaceEnabled=true/' "$XOCHITL_CONF"
            CONF_UPDATED="true"
        else
            if grep -q '^\[General\]' "$XOCHITL_CONF"; then
                sed -i '/^\[General\]/a WebInterfaceEnabled=true' "$XOCHITL_CONF"
            else
                echo "WebInterfaceEnabled=true" >> "$XOCHITL_CONF"
            fi
            CONF_UPDATED="true"
        fi
    fi

    HOST=$(probe_web_server || true)
    if [ -n "$HOST" ]; then
        printf '{"success":true,"host":"%s","confUpdated":%s,"message":"Loopback active on %s (No-Restart mode ready)"}\n' "$HOST" "$CONF_UPDATED" "$HOST"
    else
        printf '{"success":true,"host":"","confUpdated":%s,"message":"Loopback network and config prepared. Note: if web server is not running, connect USB or install webinterface-onboot."}\n' "$CONF_UPDATED"
    fi
}

cmd_upload_loopback() {
    LOCAL_PDF="$1"
    DOC_TITLE="$2"

    if [ -z "$LOCAL_PDF" ] || [ ! -f "$LOCAL_PDF" ]; then
        printf '{"success":false,"error":"Local file not found"}\n'
        return 1
    fi

    if [ -z "$DOC_TITLE" ]; then
        DOC_TITLE=$(basename "$LOCAL_PDF" | sed 's/\.[pP][dD][fF]$//')
    fi

    if upload_via_web_loopback "$LOCAL_PDF" "$DOC_TITLE"; then
        SAFE_TITLE=$(echo "$DOC_TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":true,"method":"web_loopback","norestart":true,"title":"%s","message":"Document uploaded to loopback server successfully (live in library)!"}\n' "$SAFE_TITLE"
    else
        printf '{"success":false,"error":"Loopback web server not reachable or rejected upload"}\n'
    fi
}

cmd_restart_xochitl() {
    if command -v systemctl >/dev/null 2>&1; then
        ( sleep 1 && systemctl restart xochitl ) >/dev/null 2>&1 &
        printf '{"success":true,"message":"xochitl is restarting..."}\n'
    else
        printf '{"success":false,"error":"systemctl not found"}\n'
    fi
}

# Main command router
ACTION="$1"
shift || true

case "$ACTION" in
    test-connection)
        cmd_test_connection "$@"
        ;;
    list-dir)
        cmd_list_dir "$@"
        ;;
    search-dir)
        cmd_search_dir "$@"
        ;;
    import-pdf)
        cmd_import_pdf "$@"
        ;;
    import-local)
        cmd_import_local_pdf "$@"
        ;;
    test-loopback)
        cmd_test_loopback "$@"
        ;;
    enable-loopback)
        cmd_enable_loopback "$@"
        ;;
    upload-loopback)
        cmd_upload_loopback "$@"
        ;;
    restart-xochitl)
        cmd_restart_xochitl "$@"
        ;;
    load-config)
        cmd_load_config "$@"
        ;;
    save-config)
        cmd_save_config "$@"
        ;;
    *)
        printf '{"success":false,"error":"Unknown command: %s"}\n' "$ACTION"
        exit 1
        ;;
esac


