#!/system/bin/sh

# Custom Hosts Module - Post Mount Script
# Ensures proper file permissions and structure after overlay mount

MODDIR=${0%/*}

# Log function
log_info() {
    echo "[Custom Hosts] $1" | tee -a /cache/custom_hosts.log
}

log_info "Post-mount script started"

# Ensure target hosts file exists and has correct permissions
TARGET_HOSTS="$MODDIR/system/etc/hosts"

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
CUSTOM_HOSTS="$MODDIR/custom_hosts.txt"
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
