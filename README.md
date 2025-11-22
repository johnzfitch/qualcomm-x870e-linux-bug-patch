# Qualcomm WCN7850 WiFi 7 - Linux Firmware Fix

**Hardware**: Gigabyte X870E AORUS XTREME AI TOP (QCNCM865 module)
**WiFi**: Qualcomm WCN7850 hw2.0 (FastConnect 7800)
**Status**: FIXED - WiFi sees 40+ networks, Bluetooth working

---

## Problem

The WCN7850 WiFi 7 card reports `board_id 0xff` (generic fallback) because the subsystem ID `105b:e0fb` (Gigabyte X870E) is **missing from the linux-firmware board-2.bin**. This limits TX power calibration, though WiFi still achieves ~910 Mbps in practice.

```
ath12k_pci 0000:0d:00.0: failed to get ACPI BDF EXT: 0
ath12k_pci 0000:0d:00.0: board_id 0xff
```

## Root Cause

**Incorrect**: Originally thought `105b:e0fb` was missing from linux-firmware.

**Actual Problem**: The `e0fb` entry EXISTS in upstream board-2.bin, but in MULTIPLE groups:
1. Generic `e0ee` group (wrong calibration) ← **Driver finds this FIRST**
2. Generic `e0dc` group (also generic)
3. `e0dc,variant=QC_5mm` group (correct calibration)

When ACPI BDF lookup fails (as it does for us), the driver searches board-2.bin WITHOUT variant, finds the generic `e0ee` entry first, and uses conservative TX power calibration.

**Result**: Low TX power (~1 dBm), can only see own mesh network, Bluetooth crashes on scan.

## Solution

Modify board-2.bin to:
1. **Remove** `e0fb` from all generic (non-variant) groups
2. **Add** standalone `e0fb` entry at position [0] pointing to `QC_5mm.bin` calibration data

This ensures the driver finds the correct entry first during search.

### Current State

| Item | Status |
|------|--------|
| WiFi Networks | 40+ detected (was: only own mesh) |
| Bluetooth | Working, stable (was: crash on scan) |
| board_id | Still 0xff (hardware-reported, expected) |
| Custom board-2.bin | Installed |
| Pacman hook | Active (survives updates) |

---

## Quick Start

The fix is installed. To test:

```bash
sudo reboot
```

After reboot, verify:
```bash
# Check if board_id changed from 0xff
sudo dmesg | grep -i "board_id\|ACPI BDF"

# Check subsystem ID detection
sudo dmesg | grep -i "105b:e0fb\|e0fb"
```

---

## Documentation

| File | Description |
|------|-------------|
| `STATUS.md` | Current state and test results |
| `INSTALL.md` | Installation guide |
| `CHANGELOG.md` | Version history |
| `EMERGENCY-ROLLBACK.md` | Rollback procedures |

---

## Technical Details

### Root Cause Analysis

1. Driver loads `board-2.bin` from `/usr/lib/firmware/ath12k/WCN7850/hw2.0/`
2. Searches for entry matching PCI subsystem ID `105b:e0fb`
3. Entry doesn't exist -> falls back to `board_id 0xff` (generic)
4. Generic board uses conservative TX power (1 dBm reported)

### Fix Approach

1. Extract original board-2.bin using `ath12k-bdencoder`
2. Add entry for subsystem ID `105b:e0fb` (shares calibration with `e0dc`)
3. Rebuild and install custom board-2.bin
4. Create pacman hook to restore after linux-firmware updates

### Key Files

```
Project Files:
├── board-2.bin.zst                    # Custom firmware (source of truth)
├── board-2-fixed.json                 # Fixed JSON with standalone e0fb entry
├── board-2-fixed.bin                  # Rebuilt board-2.bin
├── fix-e0fb-entry.py                  # Script to fix JSON
├── board-2.json                       # Original extracted board data
├── qca-swiss-army-knife/              # Qualcomm tools (ath12k-bdencoder)

System Files:
├── /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst  # Installed firmware
├── /etc/pacman.d/hooks/99-wcn7850-board-fix.hook           # Pacman hook
└── /usr/local/bin/wcn7850-board-fix.sh                     # Restore script
```

### Pacman Hook

Automatically restores custom board-2.bin after `linux-firmware` or `linux-firmware-ath` updates:

```ini
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-firmware
Target = linux-firmware-ath

[Action]
Description = Restoring WCN7850 board-2.bin with e0fb fix...
When = PostTransaction
Exec = /usr/local/bin/wcn7850-board-fix.sh
```

---

## System Info

- **Kernel**: 6.17.8-arch1-1
- **Bootloader**: Limine (UKI)
- **Firmware**: linux-firmware 20251111-1
- **PCI**: 0000:0d:00.0 (17cb:1107, subsystem 105b:e0fb)

---

## Previous Approaches (Historical)

### SSDT Approach (v1-v3)

Attempted to provide board calibration hints via ACPI SSDT table. The SSDT loads at boot but the ath12k driver's ACPI lookup doesn't read _DSM from the device.

**Status**: SSDT loads, but driver ignores it. May require kernel patch.

Files in `acpi/` directory are from this approach and remain for reference.

---

## If It Doesn't Work

If board_id still shows 0xff after reboot, the entry format may need adjustment or upstream driver behavior may need investigation.

Current WiFi performance (~910 Mbps) is acceptable as fallback.

## Upstream Submission

Once verified working, this fix should be submitted to linux-firmware upstream to add the `105b:e0fb` subsystem ID entry for Gigabyte X870E motherboards.
