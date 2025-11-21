#!/bin/bash
# Quick Safety Checks Before Reboot

echo "=== PRE-REBOOT SAFETY CHECK ==="
echo
ISSUES=0

# 1. UKI exists and has reasonable size
echo -n "[1] UKI file exists... "
if [ -f "/boot/EFI/Linux/omarchy_linux.efi" ]; then
    SIZE=$(stat -c%s /boot/EFI/Linux/omarchy_linux.efi)
    echo "YES ($(( SIZE / 1024 / 1024 ))MB)"
else
    echo "FAIL"; ((ISSUES++))
fi

# 2. SSDT tables installed
echo -n "[2] SSDT in /boot/acpi/tables/... "
[ -f "/boot/acpi/tables/SSDT-WCN7850.aml" ] && echo "YES" || { echo "FAIL"; ((ISSUES++)); }

echo -n "[3] SSDT in /usr/lib/firmware/acpi/... "
[ -f "/usr/lib/firmware/acpi/SSDT-WCN7850.aml" ] && echo "YES" || { echo "FAIL"; ((ISSUES++)); }

# 4. Limine config exists
echo -n "[4] limine.conf exists... "
[ -f "/boot/limine.conf" ] && echo "YES" || { echo "FAIL"; ((ISSUES++)); }

# 5. mkinitcpio.conf has ACPI files
echo -n "[5] mkinitcpio.conf updated... "
grep -q "/usr/lib/firmware/acpi/\*.aml" /etc/mkinitcpio.conf && echo "YES" || { echo "WARN"; }

# 6. Boot partition mounted and writable
echo -n "[6] /boot mounted and writable... "
if mountpoint -q /boot && touch /boot/.test 2>/dev/null; then
    rm -f /boot/.test
    echo "YES"
else
    echo "FAIL"; ((ISSUES++))
fi

# 7. Encryption hook present (critical for your system)
echo -n "[7] Encryption hook in mkinitcpio... "
grep -q "encrypt" /etc/mkinitcpio.conf && echo "YES" || { echo "FAIL - CRITICAL"; ((ISSUES++)); }

# 8. WiFi hardware present
echo -n "[8] WCN7850 WiFi detected... "
lspci | grep -qi "qualcomm.*wcn785x" && echo "YES" || { echo "WARN"; }

# 9. Backup files exist
echo -n "[9] mkinitcpio.conf backup exists... "
ls /etc/mkinitcpio.conf.backup-* 1>/dev/null 2>&1 && echo "YES" || { echo "WARN"; }

echo -n "[10] limine.conf backup exists... "
[ -f "/boot/limine.conf.old" ] && echo "YES" || { echo "WARN"; }

echo
echo "=== RESULT ==="
if [ $ISSUES -eq 0 ]; then
    echo "✓ SAFE TO REBOOT - All critical checks passed"
    echo
    echo "Next: sudo reboot"
    exit 0
else
    echo "✗ DO NOT REBOOT - $ISSUES critical issue(s) found"
    echo
    echo "Fix issues above before rebooting"
    exit 1
fi
