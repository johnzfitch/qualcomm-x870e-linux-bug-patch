# Post-Reboot Verification Guide

## ✅ Pre-Reboot Status: COMPLETE

**What was installed:**
- ✅ ACPI SSDT table (`SSDT-WCN7850.aml`) added to initramfs
- ✅ UKI (Unified Kernel Image) rebuilt with ACPI override
- ✅ mkinitcpio configured to include ACPI files
- ✅ WiFi driver will get clean restart

**Ready to reboot!**

---

## Step 1: Reboot System

```bash
# Save all work
sudo reboot
```

---

## Step 2: Verify ACPI SSDT Loaded

After reboot, check if the SSDT table is present:

```bash
cd ~/dev/qualcomm-x870e-linux-bug-patch

# Check for SSDT tables
sudo ls -lh /sys/firmware/acpi/tables/SSDT*

# Dump ACPI tables and search for WCN7850
sudo acpidump 2>/dev/null | grep -i "wcn\|wlan" || echo "Custom SSDT may not be visible in acpidump"

# Alternative: Check if custom SSDT is loaded
sudo dmesg | grep -i "acpi.*ssdt\|acpi.*override"
```

**Expected:** Should see multiple SSDT files, our custom one is embedded

---

## Step 3: Check WiFi Driver Status

```bash
# Check WiFi interface exists
iw dev

# Check board-id (still 0xff until kernel patch)
sudo dmesg | grep "board_id\|chip_id"

# Check current TX power (will still be 1 dBm without kernel patch)
iw dev wlanX info | grep txpower
```

**Expected:**
- Interface present (wlan0, wlan1, etc.)
- board-id: 0xff (firmware-reported, unchanged)
- TX power: 1.00 dBm (still limited without kernel patch)

---

## Step 4: Baseline WiFi Test

```bash
# Scan for networks
sudo iw dev wlanX scan | grep "^BSS" | wc -l

# Check signal levels
sudo iw dev wlanX scan | grep -E "^BSS|signal"
```

**Expected:** Still limited range (only own network) until kernel patch

---

## Phase 1 Complete: SSDT Installation ✅

### What We've Accomplished
- ✅ ACPI SSDT table embedded in initramfs/UKI
- ✅ Table provides board calibration hints
- ✅ System ready for Phase 2 (kernel patch)

### What's Next (Phase 2)
**Kernel Module Patch** - Requires:
1. Download ath12k kernel module source (kernel 6.17.8)
2. Create patch adding ACPI _DSM reading:
   ```c
   // New function to read ACPI hints
   static int ath12k_acpi_read_bdf_variant(struct ath12k_base *ab, char *variant, size_t size);

   // Modify existing function
   int ath12k_core_fetch_board_data_api_n()
   // Add ACPI check before loading board-2.bin
   ```
3. Set up DKMS for automatic rebuilds
4. Test full solution

---

## Expected Results Timeline

### After Phase 1 (Current - SSDT Only):
- ❌ TX power still 1 dBm (kernel doesn't read ACPI yet)
- ✅ SSDT loaded and ready
- ✅ Proves ACPI loading mechanism works

### After Phase 2 (SSDT + Kernel Patch):
- ✅ ath12k reads BoardVariant="QC_5mm" from ACPI
- ✅ TX power increases to 24 dBm
- ✅ Can detect neighbor networks
- ✅ Full WiFi 7 range restored

---

## If Something Goes Wrong

### SSDT Not Loading
**Check:**
```bash
# Verify SSDT in initramfs
lsinitcpio /boot/EFI/Linux/omarchy_linux.efi | grep -i ssdt

# Check mkinitcpio config
grep "usr/lib/firmware/acpi" /etc/mkinitcpio.conf
```

### WiFi Not Working At All
**Rollback:**
```bash
# Remove ACPI override from mkinitcpio
sudo nano /etc/mkinitcpio.conf
# Remove: /usr/lib/firmware/acpi/*.aml from FILES=()

# Rebuild UKI
sudo mkinitcpio -P

# Reboot
sudo reboot
```

---

## Next Session Tasks

**To implement kernel patch:**
1. Download ath12k source matching kernel 6.17.8
2. Create `ath12k-acpi-bdf-override.patch`
3. Set up DKMS build system
4. Build and install patched module
5. Test with: `modprobe ath12k acpi_bdf_override=1 debug_acpi=1`

**Files needed:**
- `kernel/ath12k-acpi-bdf-override.patch`
- `kernel/dkms.conf`
- `kernel/Makefile`
- `kernel/install-dkms-module.sh`

---

## Questions After Reboot?

**Check:**
- `~/dev/qualcomm-x870e-linux-bug-patch/STATUS.md` - Current status
- `~/dev/qualcomm-x870e-linux-bug-patch/INSTALL.md` - Installation guide
- `~/dev/qualcomm-x870e-linux-bug-patch/README.md` - Full investigation

**Logs:**
```bash
cd ~/dev/qualcomm-x870e-linux-bug-patch
sudo dmesg > logs/dmesg-after-reboot.txt
sudo journalctl -b > logs/journal-after-reboot.txt
```

---

**Status:** Ready to reboot and verify Phase 1!
**Time estimate:** 5 min reboot + 10 min verification = 15 minutes
**Next:** Phase 2 kernel patch (separate session)
