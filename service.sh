#!/system/bin/sh

# Custom Hosts Module - Service Script
# Ensures hosts file is properly applied after system boot

MODDIR=${0%/*}

# Log function
log_info() {
    echo "[Custom Hosts] $1" | tee -a /cache/custom_hosts.log
}

log_info "Service script started"

# Verify that our hosts file is properly mounted
if [ -f "/system/etc/hosts" ]; then
    log_info "Hosts file is accessible"
    
    # Optional: You can add additional verification here
    # For example, check if custom entries are present
    if grep -q "Custom hosts file" /system/etc/hosts; then
        log_info "Custom hosts file is active"
    else
        log_info "Warning: Custom hosts file may not be active"
    fi

    # Ensure the bind/overlay source has proper context so the mounted view is correct
    SRC_HOSTS="$MODDIR/system/etc/hosts"
    if [ -f "$SRC_HOSTS" ]; then
        # Fix perms/context on source file
        chown 0:0 "$SRC_HOSTS" 2>/dev/null || true
        chmod 0644 "$SRC_HOSTS" 2>/dev/null || true
        if command -v set_perm >/dev/null 2>&1; then
            set_perm "$SRC_HOSTS" 0 0 0644 u:object_r:system_file:s0
        else
            chcon u:object_r:system_file:s0 "$SRC_HOSTS" 2>/dev/null || true
        fi
        log_info "Verified source hosts perms/SELinux context"
    fi
else
    log_info "Error: Hosts file not found"
fi

log_info "Service script completed"
