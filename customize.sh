#!/system/bin/sh

# Custom Hosts Module Installation Script
# This script merges system hosts with custom hosts

MODDIR=${0%/*}
SYSTEM_HOSTS="/system/etc/hosts"
CUSTOM_HOSTS="$MODDIR/custom_hosts.txt"
TARGET_HOSTS="$MODDIR/system/etc/hosts"

ui_print "- Installing Custom Hosts module..."

# Create the target directory if it doesn't exist
mkdir -p "$MODDIR/system/etc"

# Ensure proper directory structure
if [ ! -d "$MODDIR/system" ]; then
    mkdir -p "$MODDIR/system"
fi

if [ ! -d "$MODDIR/system/etc" ]; then
    mkdir -p "$MODDIR/system/etc"
fi

# Start building the new hosts file
ui_print "- Merging system hosts with custom hosts..."

# Add custom hosts header
cat > "$TARGET_HOSTS" << 'EOF'
# Custom hosts file - managed by KernelSU Custom Hosts module
# This file contains both system hosts and custom entries
# ====================================================================

EOF

# Add custom hosts if the file exists
if [ -f "$CUSTOM_HOSTS" ]; then
    ui_print "- Adding custom host entries..."
    # Filter out comments and empty lines, add custom entries
    grep -v '^#' "$CUSTOM_HOSTS" | grep -v '^[[:space:]]*$' >> "$TARGET_HOSTS"
    echo "" >> "$TARGET_HOSTS"
fi

# Add separator
cat >> "$TARGET_HOSTS" << 'EOF'
# ====================================================================
# Original system hosts content below:
# ====================================================================

EOF

# Add original system hosts content
if [ -f "$SYSTEM_HOSTS" ]; then
    ui_print "- Preserving original system hosts..."
    cat "$SYSTEM_HOSTS" >> "$TARGET_HOSTS"
else
    ui_print "- No system hosts found, adding default entries..."
    cat >> "$TARGET_HOSTS" << 'EOF'
127.0.0.1       localhost
::1             localhost
EOF
fi
ui_print "- Hosts file successfully merged!"


# Set execute permissions for action.sh (required for KernelSU action button)
if [ -f "$MODDIR/action.sh" ]; then
    ui_print "- Setting action.sh permissions..."
    chmod +x "$MODDIR/action.sh"
    ui_print "- Action button enabled"
fi

# Ensure webroot directory has proper permissions for KernelSU WebUI
if [ -d "$MODDIR/webroot" ]; then
    ui_print "- Setting webroot permissions..."
    # KernelSU will automatically set the correct permissions and SELinux context
    # We just need to make sure the directory structure is correct
    ui_print "- Web UI enabled"
fi

ui_print "- Custom Hosts module installed successfully!"
