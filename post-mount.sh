#!/system/bin/sh

# Custom Hosts Module - Post Mount Script
# Ensures proper file permissions and structure after overlay mount

MODDIR=${0%/*}

# Paths
SYSTEM_HOSTS="/system/etc/hosts"
CUSTOM_HOSTS="$MODDIR/custom_hosts.txt"

# Log function
log_info() {
    echo "[Custom Hosts] $1" | tee -a /cache/custom_hosts.log
}

log_info "Post-mount script started"

# Ensure target hosts file exists and has correct permissions
TARGET_HOSTS="$MODDIR/system/etc/hosts"

if [ ! -f "$TARGET_HOSTS" ]; then
    # Create initial hosts so that Web UI can read it before first save
    log_info "Creating initial hosts at $TARGET_HOSTS"
    mkdir -p "$MODDIR/system/etc"

    # Build initial merged hosts: custom (filtered) + separator + system/default
    {
        cat << 'EOF'
# Custom hosts file - managed by KernelSU Custom Hosts module
# This file contains both system hosts and custom entries
# ====================================================================

EOF
        if [ -f "$CUSTOM_HOSTS" ]; then
            # add non-comment, non-empty custom entries
            grep -v '^#' "$CUSTOM_HOSTS" | grep -v '^[[:space:]]*$'
            echo ""
        fi
        cat << 'EOF'
# ====================================================================
# Original system hosts content below:
# ====================================================================

EOF
        if [ -f "$SYSTEM_HOSTS" ]; then
            cat "$SYSTEM_HOSTS"
        else
            cat << 'EOF'
127.0.0.1       localhost
::1             localhost
EOF
        fi
    } > "$TARGET_HOSTS"
fi

if [ -f "$TARGET_HOSTS" ]; then
    # Set correct owner/permissions and SELinux context for hosts file
    chown 0:0 "$TARGET_HOSTS" 2>/dev/null || true
    chmod 0644 "$TARGET_HOSTS" 2>/dev/null || true
    # Prefer set_perm if available (KernelSU/Magisk environment)
    if command -v set_perm >/dev/null 2>&1; then
        set_perm "$TARGET_HOSTS" 0 0 0644 u:object_r:system_file:s0
    else
        chcon u:object_r:system_file:s0 "$TARGET_HOSTS" 2>/dev/null || true
    fi
    log_info "Ensured hosts owner/mode/SELinux context"
else
    log_info "Warning: Target hosts file not found at $TARGET_HOSTS"
fi

# Ensure custom_hosts.txt exists
if [ ! -f "$CUSTOM_HOSTS" ]; then
    log_info "Creating default custom_hosts.txt"
    cat > "$CUSTOM_HOSTS" << 'EOF'
# Custom hosts file - managed by KernelSU Custom Hosts module
# Add your custom host entries below:
# Format: IP_ADDRESS    DOMAIN_NAME

# Your custom entries go here:
EOF
    chmod 644 "$CUSTOM_HOSTS"
fi

log_info "Post-mount script completed"
