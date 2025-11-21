#!/bin/bash
#
# Install ACPI SSDT Override for WCN7850
# For use with mkinitcpio and UKI (Unified Kernel Images)
#

set -e

echo "=== WCN7850 ACPI SSDT Override Installer ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Paths
SSDT_SOURCE="/home/zack/dev/qualcomm-x870e-linux-bug-patch/acpi/SSDT-WCN7850.aml"
ACPI_OVERRIDE_DIR="/boot/acpi/tables"
INITRAMFS_ACPI_DIR="/usr/lib/firmware/acpi"

# Step 1: Install SSDT to boot directory (already done, but verify)
echo "[1/4] Verifying SSDT in /boot/acpi/tables/..."
if [ ! -f "$ACPI_OVERRIDE_DIR/SSDT-WCN7850.aml" ]; then
    echo "  Installing SSDT to $ACPI_OVERRIDE_DIR/"
    mkdir -p "$ACPI_OVERRIDE_DIR"
    cp "$SSDT_SOURCE" "$ACPI_OVERRIDE_DIR/"
    chmod 755 "$ACPI_OVERRIDE_DIR/SSDT-WCN7850.aml"
fi
echo "  ✓ SSDT present: $(ls -lh $ACPI_OVERRIDE_DIR/SSDT-WCN7850.aml | awk '{print $5}')"

# Step 2: Install SSDT to initramfs firmware directory
echo
echo "[2/4] Installing SSDT to initramfs firmware directory..."
mkdir -p "$INITRAMFS_ACPI_DIR"
cp "$SSDT_SOURCE" "$INITRAMFS_ACPI_DIR/"
chmod 644 "$INITRAMFS_ACPI_DIR/SSDT-WCN7850.aml"
echo "  ✓ Copied to $INITRAMFS_ACPI_DIR/"

# Step 3: Update mkinitcpio.conf to include ACPI files
echo
echo "[3/4] Updating mkinitcpio.conf..."
if ! grep -q "/usr/lib/firmware/acpi/\*.aml" /etc/mkinitcpio.conf; then
    # Backup original
    cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup-$(date +%Y%m%d)

    # Add ACPI files to FILES array
    sed -i 's|^FILES=(|FILES=(/usr/lib/firmware/acpi/*.aml |' /etc/mkinitcpio.conf
    echo "  ✓ Added ACPI files to mkinitcpio.conf"
else
    echo "  ✓ ACPI files already in mkinitcpio.conf"
fi

# Step 4: Rebuild initramfs/UKI
echo
echo "[4/4] Rebuilding initramfs (this may take a minute)..."
mkinitcpio -P
echo "  ✓ Initramfs rebuilt"

echo
echo "=== Installation Complete ==="
echo
echo "ACPI SSDT table will be loaded on next boot."
echo
echo "To verify after reboot:"
echo "  sudo ls /sys/firmware/acpi/tables/SSDT*"
echo "  sudo acpidump | grep -i wcn"
echo
echo "Ready to reboot!"
