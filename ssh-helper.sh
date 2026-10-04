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
            gsub(/\\/, "\\\\", n)
            gsub(/"/, "\\\"", n)
            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"type\":\"dir\",\"is_pdf\":false,\"size\":0,\"size_str\":\"\"}", n
        }

        # Files
        for (i = 0; i < f_count; i++) {
            n = files_name[i]
            sz = files_size[i] + 0
            is_pdf = (tolower(n) ~ /\.pdf$/) ? "true" : "false"

            if (sz >= 1073741824) sz_str = sprintf("%.1f GB", sz / 1073741824)
            else if (sz >= 1048576) sz_str = sprintf("%.1f MB", sz / 1048576)
            else if (sz >= 1024) sz_str = sprintf("%.1f KB", sz / 1024)
            else sz_str = sprintf("%d B", sz)

            gsub(/\\/, "\\\\", n)
            gsub(/"/, "\\\"", n)
            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"type\":\"file\",\"is_pdf\":%s,\"size\":%d,\"size_str\":\"%s\"}", n, is_pdf, sz, sz_str
        }

        printf "]}\n"
    }
    '
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


    # Strategy 1: Upload via local USB web interface (127.0.0.1/upload)
    # This automatically registers the file in xochitl immediately with zero restart needed.
    CURL_OUT=$(curl -s -S -f --connect-timeout 2 --max-time 15 -X POST http://127.0.0.1/upload -F "file=@${TMP_PDF};filename=${FILENAME};type=application/pdf" 2>&1)
    CURL_STATUS=$?

    if [ $CURL_STATUS -eq 0 ]; then
        rm -f "$TMP_PDF"
        SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":true,"method":"web_interface","title":"%s","message":"Document imported via reMarkable web interface"}\n' "$SAFE_TITLE"
        return
    fi

    # Try also 10.11.99.1 in case webserver bound only to usb interface
    CURL_OUT2=$(curl -s -S -f --connect-timeout 2 --max-time 15 -X POST http://10.11.99.1/upload -F "file=@${TMP_PDF};filename=${FILENAME};type=application/pdf" 2>&1)
    CURL_STATUS2=$?

    if [ $CURL_STATUS2 -eq 0 ]; then
        rm -f "$TMP_PDF"
        SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":true,"method":"web_interface","title":"%s","message":"Document imported via reMarkable web interface"}\n' "$SAFE_TITLE"
        return
    fi

    # Strategy 2: Direct xochitl document creation using UUID
    mkdir -p "$XOCHITL_DIR"
    
    # Generate UUID
    UUID=""
    if [ -f /proc/sys/kernel/random/uuid ]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    elif command -v uuidgen >/dev/null 2>&1; then
        UUID=$(uuidgen)
    else
        UUID=$(od -x /dev/urandom | head -1 | awk '{printf "%s-%s-%s-%s-%s", $2, $3, $4, $5, $6$7}')
    fi

    if [ -z "$UUID" ]; then
        rm -f "$TMP_PDF"
        printf '{"success":false,"error":"Failed to generate UUID for document import"}\n'
        return
    fi

    # Move PDF into place
    mv "$TMP_PDF" "$XOCHITL_DIR/$UUID.pdf"

    # Write .metadata
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
  "visibleName": "$TITLE"
}
META_EOF

    # Write .content
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

    SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"success":true,"method":"direct_xochitl","title":"%s","uuid":"%s","message":"PDF written to xochitl storage. Note: Enable USB web interface in settings or restart xochitl to index"}\n' "$SAFE_TITLE" "$UUID"
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

    # Strategy 1: Web interface
    CURL_OUT=$(curl -s -S -f --connect-timeout 2 --max-time 15 -X POST http://127.0.0.1/upload -F "file=@${TMP_PDF};filename=${FILENAME};type=application/pdf" 2>&1)
    CURL_STATUS=$?

    if [ $CURL_STATUS -eq 0 ]; then
        rm -f "$TMP_PDF"
        SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":true,"method":"web_interface","title":"%s","message":"Document imported via reMarkable web interface"}\n' "$SAFE_TITLE"
        return
    fi

    CURL_OUT2=$(curl -s -S -f --connect-timeout 2 --max-time 15 -X POST http://10.11.99.1/upload -F "file=@${TMP_PDF};filename=${FILENAME};type=application/pdf" 2>&1)
    CURL_STATUS2=$?

    if [ $CURL_STATUS2 -eq 0 ]; then
        rm -f "$TMP_PDF"
        SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"success":true,"method":"web_interface","title":"%s","message":"Document imported via reMarkable web interface"}\n' "$SAFE_TITLE"
        return
    fi

    # Strategy 2: Direct xochitl document creation
    mkdir -p "$XOCHITL_DIR"

    UUID=""
    if [ -f /proc/sys/kernel/random/uuid ]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    elif command -v uuidgen >/dev/null 2>&1; then
        UUID=$(uuidgen)
    else
        UUID=$(od -x /dev/urandom | head -1 | awk '{printf "%s-%s-%s-%s-%s", $2, $3, $4, $5, $6$7}')
    fi

    if [ -z "$UUID" ]; then
        rm -f "$TMP_PDF"
        printf '{"success":false,"error":"Failed to generate UUID"}\n'
        return
    fi

    mv "$TMP_PDF" "$XOCHITL_DIR/$UUID.pdf"

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
  "visibleName": "$TITLE"
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

    SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"success":true,"method":"direct_xochitl","title":"%s","uuid":"%s","message":"PDF written to xochitl storage"}\n' "$SAFE_TITLE" "$UUID"
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
    import-pdf)
        cmd_import_pdf "$@"
        ;;
    import-local)
        cmd_import_local_pdf "$@"
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


