#!/bin/bash
echo "=== PRE-REBOOT SAFETY CHECK v2 ==="
echo ""

# 1. UKI size check
echo "[1] UKI File Size:"
ls -lh /boot/EFI/Linux/omarchy_linux.efi | awk '{print $5}'

# 2. SSDT in /boot
echo "[2] SSDT in /boot:"
if [ -f /boot/acpi/tables/SSDT-WCN7850.aml ]; then
    echo "OK ($(stat -c%s /boot/acpi/tables/SSDT-WCN7850.aml) bytes)"
else
    echo "MISSING!"
fi

# 3. SSDT in /usr/lib
echo "[3] SSDT in /usr/lib:"
if [ -f /usr/lib/firmware/acpi/SSDT-WCN7850.aml ]; then
    echo "OK ($(stat -c%s /usr/lib/firmware/acpi/SSDT-WCN7850.aml) bytes)"
else
    echo "MISSING!"
fi

# 4. SSDT in UKI
echo "[4] SSDT in UKI:"
if lsinitcpio /boot/EFI/Linux/omarchy_linux.efi | grep -q "SSDT-WCN7850.aml"; then
    echo "OK"
else
    echo "MISSING!"
fi

# 5. Limine config
echo "[5] limine.conf:"
if [ -f /boot/limine.conf ]; then
    echo "OK"
else
    echo "MISSING!"
fi

# 6. mkinitcpio ACPI files
echo "[6] mkinitcpio ACPI:"
if grep -q "/usr/lib/firmware/acpi/\*.aml" /etc/mkinitcpio.conf; then
    echo "OK"
else
    echo "MISSING!"
fi

# 7. /boot mounted
echo "[7] /boot mounted:"
if mountpoint -q /boot; then
    echo "YES"
else
    echo "NO - CRITICAL!"
fi

# 8. Encryption hook
echo "[8] Encrypt hook:"
if grep -q "^HOOKS=.*encrypt" /etc/mkinitcpio.conf; then
    echo "OK (CRITICAL)"
else
    echo "MISSING - CRITICAL!"
fi

# 9. WiFi device present
echo "[9] WiFi device:"
if lspci -d 17cb:1107 &>/dev/null; then
    echo "DETECTED"
else
    echo "NOT FOUND!"
fi

# 10. mkinitcpio backup exists
echo "[10] mkinitcpio backup:"
if [ -f /etc/mkinitcpio.conf.backup-20251120 ]; then
    echo "EXISTS"
else
    echo "MISSING!"
fi

# 11. SSDT v1 backup
echo "[11] SSDT v1 backup:"
if [ -f ~/dev/qualcomm-x870e-linux-bug-patch/acpi/SSDT-WCN7850-v1-backup.aml ]; then
    echo "EXISTS"
else
    echo "MISSING!"
fi

# 12. SSDT v2 size check
echo "[12] SSDT v2 size:"
size=$(stat -c%s /boot/acpi/tables/SSDT-WCN7850.aml 2>/dev/null)
if [ "$size" = "182" ]; then
    echo "182 bytes (CORRECT for v2)"
else
    echo "$size bytes (expected 182)"
fi

# 13. Limine snapshots
echo "[13] Limine snapshots:"
snapshot_count=$(grep -c "^:Snapshot" /boot/limine.conf 2>/dev/null || echo 0)
echo "$snapshot_count available"

echo ""
echo "=== CRITICAL CHECKS ==="
critical_pass=true

if ! mountpoint -q /boot; then
    echo "❌ /boot not mounted!"
    critical_pass=false
fi

if ! grep -q "^HOOKS=.*encrypt" /etc/mkinitcpio.conf; then
    echo "❌ Encryption hook missing!"
    critical_pass=false
fi

if [ ! -f /boot/EFI/Linux/omarchy_linux.efi ]; then
    echo "❌ UKI missing!"
    critical_pass=false
fi

if [ ! -f /usr/lib/firmware/acpi/SSDT-WCN7850.aml ]; then
    echo "❌ SSDT not in initramfs location!"
    critical_pass=false
fi

if $critical_pass; then
    echo "✅ ALL CRITICAL CHECKS PASSED"
    echo ""
    echo "=== READY TO REBOOT ==="
else
    echo "❌ CRITICAL CHECKS FAILED - DO NOT REBOOT!"
fi
