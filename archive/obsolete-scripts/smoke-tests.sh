#!/bin/bash
#
# Pre-Reboot Smoke Tests for ACPI SSDT Installation
# Ensures system is safe to reboot after UKI rebuild
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║           PRE-REBOOT SMOKE TESTS - ACPI SSDT INSTALLATION        ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo

test_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASS++))
}

test_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAIL++))
}

test_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((WARN++))
}

echo "[TEST 1] UKI File Integrity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check UKI exists
if [ -f "/boot/EFI/Linux/omarchy_linux.efi" ]; then
    test_pass "UKI exists: /boot/EFI/Linux/omarchy_linux.efi"

    # Check UKI size (should be reasonable, 50MB-300MB)
    UKI_SIZE=$(stat -f%z /boot/EFI/Linux/omarchy_linux.efi 2>/dev/null || stat -c%s /boot/EFI/Linux/omarchy_linux.efi 2>/dev/null)
    if [ "$UKI_SIZE" -gt 52428800 ] && [ "$UKI_SIZE" -lt 314572800 ]; then
        test_pass "UKI size reasonable: $(numfmt --to=iec-i --suffix=B $UKI_SIZE)"
    else
        test_warn "UKI size unusual: $(numfmt --to=iec-i --suffix=B $UKI_SIZE)"
    fi

    # Check UKI is readable
    if head -c 2 /boot/EFI/Linux/omarchy_linux.efi | grep -q "MZ"; then
        test_pass "UKI has valid PE header (MZ signature)"
    else
        test_fail "UKI missing PE header - may be corrupt"
    fi
else
    test_fail "UKI not found at /boot/EFI/Linux/omarchy_linux.efi"
fi

echo
echo "[TEST 2] ACPI SSDT Files Present"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check /boot/acpi/tables
if [ -f "/boot/acpi/tables/SSDT-WCN7850.aml" ]; then
    test_pass "SSDT in /boot/acpi/tables/"
    if [ "$(stat -c%s /boot/acpi/tables/SSDT-WCN7850.aml 2>/dev/null)" -eq 425 ]; then
        test_pass "SSDT file size correct (425 bytes)"
    else
        test_warn "SSDT file size unexpected"
    fi
else
    test_fail "SSDT not found in /boot/acpi/tables/"
fi

# Check /usr/lib/firmware/acpi
if [ -f "/usr/lib/firmware/acpi/SSDT-WCN7850.aml" ]; then
    test_pass "SSDT in /usr/lib/firmware/acpi/"
else
    test_fail "SSDT not found in /usr/lib/firmware/acpi/"
fi

echo
echo "[TEST 3] Limine Bootloader Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check limine.conf exists and is readable
if [ -f "/boot/limine.conf" ]; then
    test_pass "limine.conf exists"

    # Check if it references the UKI
    if grep -q "omarchy_linux.efi" /boot/limine.conf; then
        test_pass "limine.conf references UKI"
    else
        test_warn "limine.conf may not reference UKI"
    fi

    # Check for boot entry
    if grep -q "protocol.*efi" /boot/limine.conf; then
        test_pass "Boot protocol configured (EFI)"
    else
        test_fail "No EFI boot protocol found"
    fi

    # Check cmdline exists
    if grep -q "cmdline\|kernel_cmdline" /boot/limine.conf; then
        test_pass "Kernel command line present"
    else
        test_warn "No kernel command line found"
    fi
else
    test_fail "limine.conf not found"
fi

echo
echo "[TEST 4] mkinitcpio Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check mkinitcpio.conf
if [ -f "/etc/mkinitcpio.conf" ]; then
    test_pass "mkinitcpio.conf exists"

    # Check if ACPI files added to FILES
    if grep -q "/usr/lib/firmware/acpi/\*.aml" /etc/mkinitcpio.conf; then
        test_pass "ACPI files in FILES array"
    else
        test_warn "ACPI files not in FILES array"
    fi

    # Check backup exists
    if ls /etc/mkinitcpio.conf.backup-* 1>/dev/null 2>&1; then
        test_pass "Backup exists: $(ls -t /etc/mkinitcpio.conf.backup-* | head -1)"
    else
        test_warn "No mkinitcpio.conf backup found"
    fi

    # Check essential hooks present
    if grep -q "HOOKS=.*base.*udev.*block.*filesystems" /etc/mkinitcpio.conf; then
        test_pass "Essential hooks present"
    else
        test_warn "Some essential hooks may be missing"
    fi
else
    test_fail "mkinitcpio.conf not found"
fi

echo
echo "[TEST 5] Critical System Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check kernel exists
if [ -f "/boot/vmlinuz-linux" ] || [ -f "/usr/lib/modules/$(uname -r)/vmlinuz" ]; then
    test_pass "Kernel image exists"
else
    test_warn "Standalone kernel image not found (OK for UKI-only)"
fi

# Check microcode
if [ -f "/boot/amd-ucode.img" ]; then
    test_pass "AMD microcode present"
else
    test_warn "AMD microcode not found"
fi

# Check encryption setup (you have encrypted root)
if grep -q "encrypt" /etc/mkinitcpio.conf; then
    test_pass "Encryption hook present"
else
    test_fail "Encryption hook missing - CRITICAL"
fi

# Check btrfs
if grep -q "btrfs" /etc/mkinitcpio.conf; then
    test_pass "BTRFS support present"
else
    test_warn "BTRFS not explicitly in mkinitcpio"
fi

echo
echo "[TEST 6] WiFi Driver Status (Current)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if ath12k module is loaded
if lsmod | grep -q ath12k; then
    test_pass "ath12k module currently loaded"
else
    test_warn "ath12k module not loaded"
fi

# Check if WiFi device exists
if lspci | grep -qi "qualcomm.*wcn785x"; then
    test_pass "WCN7850 device detected"
else
    test_fail "WCN7850 device not found"
fi

# Check if firmware files exist
if [ -f "/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst" ]; then
    test_pass "WiFi firmware files present"
else
    test_warn "WiFi firmware may be missing"
fi

echo
echo "[TEST 7] Boot Partition Health"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check boot partition mounted
if mountpoint -q /boot 2>/dev/null; then
    test_pass "/boot is mounted"
else
    test_fail "/boot is not mounted - CRITICAL"
fi

# Check boot partition has space
BOOT_FREE=$(df -BM /boot | awk 'NR==2 {print $4}' | sed 's/M//')
if [ "$BOOT_FREE" -gt 50 ]; then
    test_pass "Boot partition has ${BOOT_FREE}MB free"
else
    test_warn "Boot partition low on space: ${BOOT_FREE}MB"
fi

# Check filesystem is readable/writable
if touch /boot/.test 2>/dev/null && rm /boot/.test 2>/dev/null; then
    test_pass "Boot partition is writable"
else
    test_fail "Boot partition is not writable"
fi

echo
echo "[TEST 8] System Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check critical packages
for pkg in mkinitcpio linux linux-firmware; do
    if pacman -Q $pkg >/dev/null 2>&1; then
        test_pass "Package installed: $pkg"
    else
        test_fail "Package missing: $pkg"
    fi
done

# Check limine
if command -v limine-update >/dev/null 2>&1; then
    test_pass "Limine tools available"
else
    test_warn "Limine tools not in PATH"
fi

echo
echo "[TEST 9] Rollback Capability"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if we can rollback mkinitcpio.conf
if ls /etc/mkinitcpio.conf.backup-* 1>/dev/null 2>&1; then
    test_pass "Can rollback: mkinitcpio.conf backup exists"
else
    test_warn "No rollback for mkinitcpio.conf"
fi

# Check limine.conf backup
if [ -f "/boot/limine.conf.old" ]; then
    test_pass "Can rollback: limine.conf.old exists"
else
    test_warn "No limine.conf backup"
fi

# Check if we have Limine snapshots in config
if grep -q "Snapshots" /boot/limine.conf; then
    SNAPSHOT_COUNT=$(grep -c "limine_history" /boot/limine.conf)
    test_pass "Limine snapshots available: $SNAPSHOT_COUNT entries"
else
    test_warn "No Limine snapshot entries found"
fi

echo
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                        TEST SUMMARY                               ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo
echo -e "  ${GREEN}PASSED:${NC}  $PASS"
echo -e "  ${YELLOW}WARNINGS:${NC} $WARN"
echo -e "  ${RED}FAILED:${NC}  $FAIL"
echo

if [ $FAIL -eq 0 ] && [ $WARN -lt 5 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ✓ SAFE TO REBOOT                              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "All critical tests passed. System appears safe to reboot."
    echo "Minor warnings are acceptable and won't prevent boot."
    exit 0
elif [ $FAIL -eq 0 ]; then
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                ⚠ PROBABLY SAFE TO REBOOT                         ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "No critical failures, but several warnings detected."
    echo "Review warnings above before rebooting."
    exit 0
else
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                  ✗ DO NOT REBOOT YET                              ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "CRITICAL FAILURES DETECTED. Fix issues before rebooting:"
    echo "1. Review failed tests above"
    echo "2. Check /boot/limine.conf"
    echo "3. Verify UKI integrity"
    echo "4. Run smoke tests again"
    exit 1
fi
