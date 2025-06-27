#!/system/bin/sh

# Custom Hosts Update Script
# Use this script to update custom hosts without reinstalling the module

MODDIR="/data/adb/modules/custom_hosts"
SYSTEM_HOSTS="/system/etc/hosts"
CUSTOM_HOSTS="$MODDIR/custom_hosts.txt"
TARGET_HOSTS="$MODDIR/system/etc/hosts"

echo "Custom Hosts Update Script"
echo "=========================="

if [ ! -d "$MODDIR" ]; then
    echo "Error: Custom Hosts module not found!"
    exit 1
fi

if [ ! -f "$CUSTOM_HOSTS" ]; then
    echo "Error: custom_hosts.txt not found!"
    exit 1
fi

# Ensure target directory exists
if [ ! -d "$MODDIR/system" ]; then
    mkdir -p "$MODDIR/system"
fi

if [ ! -d "$MODDIR/system/etc" ]; then
    mkdir -p "$MODDIR/system/etc"
fi

echo "Updating hosts file..."

# Backup current hosts if it exists
if [ -f "$TARGET_HOSTS" ]; then
    cp "$TARGET_HOSTS" "$TARGET_HOSTS.bak"
fi

# Regenerate hosts file
cat > "$TARGET_HOSTS" << 'EOF'
# Custom hosts file - managed by KernelSU Custom Hosts module
# This file contains both system hosts and custom entries
# ====================================================================

EOF

# Add custom hosts
grep -v '^#' "$CUSTOM_HOSTS" | grep -v '^[[:space:]]*$' >> "$TARGET_HOSTS"
echo "" >> "$TARGET_HOSTS"

# Add separator
cat >> "$TARGET_HOSTS" << 'EOF'
# ====================================================================
# Original system hosts content below:
# ====================================================================

EOF

# Add original system hosts content
if [ -f "$SYSTEM_HOSTS" ]; then
    cat "$SYSTEM_HOSTS" >> "$TARGET_HOSTS"
else
    cat >> "$TARGET_HOSTS" << 'EOF'
127.0.0.1       localhost
::1             localhost
EOF
fi

echo "Hosts file updated successfully!"
echo "Changes will take effect after reboot or module restart."
echo ""
echo "To apply changes immediately (requires root):"
echo "1. Restart the module in KernelSU Manager, or"
echo "2. Reboot your device"
