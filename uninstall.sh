#!/system/bin/sh

# Custom Hosts Module Uninstall Script
# Cleans up any temporary files created by the module

# Log uninstallation
echo "[Custom Hosts] Module uninstalled on $(date)" >> /cache/custom_hosts.log

# Remove any temporary files if they exist
rm -f /cache/custom_hosts.log

echo "Custom Hosts module uninstalled successfully!"
