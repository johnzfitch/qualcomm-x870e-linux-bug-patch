# Current Status

**Last Updated**: 2025-11-22
**Fix Method**: board-2.bin firmware override (entry priority fix)
**WiFi Status**: WORKING - Full TX power, WiFi and Bluetooth operational

---

## Current State Summary

| Component | Status | Notes |
|-----------|--------|-------|
| WiFi Hardware | Working | WCN7850 hw2.0 operational |
| WiFi TX Power | 30 dBm (2.4/6 GHz), 24 dBm (5 GHz) | Full power achieved |
| WiFi Networks | Visible | Scanning works correctly |
| Bluetooth | Working | Controller active, devices scannable |
| Custom board-2.bin | Installed | Standalone e0fb entry at position [0] |
| Pacman hook | Active | Survives linux-firmware updates |
| board_id | 0xff | Hardware-reported (expected) |

---

## Root Cause (Corrected)

**Original assumption**: `105b:e0fb` was missing from linux-firmware's board-2.bin.

**Actual problem**: The `e0fb` entry EXISTS in upstream but in MULTIPLE groups:
1. Generic `e0ee` group (wrong calibration) - **Driver finds this FIRST**
2. Generic `e0dc` group (also generic)
3. `e0dc,variant=QC_5mm` group (correct calibration)

When ACPI BDF lookup fails, the driver searches board-2.bin WITHOUT variant, finds the generic `e0ee` entry first, and uses conservative TX power calibration.

**Result before fix**: Low TX power (~1 dBm), limited network visibility, Bluetooth crashes on scan.

---

## Fix Implemented (v5.0)

### Solution
1. **Remove** `e0fb` from all generic (non-variant) groups
2. **Add** standalone `e0fb` entry at position [0] pointing to `QC_5mm.bin` calibration data

This ensures the driver finds the correct entry first during search.

### Files
- `board-2-fixed.json` - Fixed JSON with standalone entry at [0]
- `board-2-fixed.bin` - Rebuilt board-2.bin
- `fix-e0fb-entry.py` - Script to modify board-2.json

### BoardNames[0] Entry
```
bus=pci,vendor=17cb,device=1107,subsystem-vendor=105b,subsystem-device=e0fb,qmi-chip-id=2,qmi-board-id=255
```
Points to `QC_5mm.bin` calibration data (88824 bytes).

---

## Verification Results

### WiFi
```
Interface wlan0
    type managed
    wiphy 0

TX Power (from iw phy):
    2.4 GHz: 30.0 dBm
    5 GHz: 24.0 dBm
    6 GHz: 30.0 dBm
```

### Bluetooth
```
Controller C8:A3:E8:11:B6:EA
    Powered: yes
    TX Power Range: -32 to +15 dBm
```

### Kernel Log
```
ath12k_pci 0000:0d:00.0: chip_id 0x2 chip_family 0x4 board_id 0xff soc_id 0x40170200
ath12k_pci 0000:0d:00.0: failed to get ACPI BDF EXT: 0
```
Note: `board_id 0xff` and ACPI BDF failure are normal - the fix works by providing correct board data lookup, not by changing board_id.

---

## System Configuration

### Firmware Override
- **Custom firmware**: `~/dev/qualcomm-x870e-linux-bug-patch/board-2.bin.zst`
- **System location**: `/usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst`
- **Pacman hook**: `/etc/pacman.d/hooks/99-wcn7850-board-fix.hook`
- **Restore script**: `/usr/local/bin/wcn7850-board-fix.sh`

### Network
- **Ethernet**: Atlantic 10GbE (enp16s0)
- **WiFi**: Qualcomm WCN7850 (wlan0)

---

## Files Structure

```
~/dev/qualcomm-x870e-linux-bug-patch/
├── README.md                    # Project overview
├── STATUS.md                    # This file - current state
├── INSTALL.md                   # Installation guide
├── CHANGELOG.md                 # Version history
├── EMERGENCY-ROLLBACK.md        # Rollback procedures
│
├── board-2.bin.zst              # Custom firmware (installed)
├── board-2-fixed.bin            # Rebuilt binary
├── board-2-fixed.json           # Fixed JSON definition
├── board-2.json                 # Original extracted data
├── fix-e0fb-entry.py            # Fix automation script
│
├── acpi/                        # Historical SSDT files
├── dkms/                        # Alternative kernel patch approach
└── qca-swiss-army-knife/        # Qualcomm firmware tools

System Files:
├── /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst
├── /etc/pacman.d/hooks/99-wcn7850-board-fix.hook
└── /usr/local/bin/wcn7850-board-fix.sh
```

---

## Rollback

### Restore Original Firmware
```bash
# Reinstall linux-firmware to get original board-2.bin
sudo pacman -S linux-firmware

# Remove pacman hook (so it doesn't restore custom firmware)
sudo rm /etc/pacman.d/hooks/99-wcn7850-board-fix.hook

# Reboot
sudo reboot
```

---

## Technical References

- **PCI ID**: 17cb:1107 (Qualcomm WCN7850)
- **Subsystem ID**: 105b:e0fb (Gigabyte X870E)
- **Firmware Location**: `/usr/lib/firmware/ath12k/WCN7850/hw2.0/`
- **Kernel**: 6.17.8-arch1-1
- **Driver**: ath12k (in-tree)
