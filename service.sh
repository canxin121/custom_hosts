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
else
    log_info "Error: Hosts file not found"
fi

log_info "Service script completed"
