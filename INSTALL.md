# Installation Guide - WCN7850 Firmware Fix

**System**: Arch Linux
**Last Updated**: 2025-11-21

---

## Overview

This fix adds the missing subsystem ID `105b:e0fb` (Gigabyte X870E) to the WCN7850 board calibration firmware. The fix includes a pacman hook for persistence across linux-firmware updates.

---

## Prerequisites

- Arch Linux (or derivative)
- Root access for firmware installation
- Git (to clone this repository)

---

## Quick Install

If the fix is already installed on this system, just reboot:

```bash
sudo reboot
```

---

## Fresh Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/johnzfitch/qualcomm-x870e-linux-bug-patch.git
cd qualcomm-x870e-linux-bug-patch
```

### Step 2: Install Custom Firmware

```bash
# Backup original firmware
sudo cp /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst \
        /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst.bak

# Install custom firmware
sudo cp board-2.bin.zst /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst
```

### Step 3: Install Pacman Hook (Persistence)

The pacman hook ensures the custom firmware is restored after linux-firmware package updates.

```bash
# Create restore script
sudo tee /usr/local/bin/wcn7850-board-fix.sh << 'EOF'
#!/bin/bash
# WCN7850 board-2.bin fix for Gigabyte X870E (subsystem 105b:e0fb)
# This script restores the custom board-2.bin after linux-firmware updates

CUSTOM_BOARD="$HOME/dev/qualcomm-x870e-linux-bug-patch/board-2.bin.zst"
TARGET="/usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst"

if [ -f "$CUSTOM_BOARD" ]; then
    cp "$CUSTOM_BOARD" "$TARGET"
    echo "WCN7850 board-2.bin restored with e0fb fix"
else
    echo "Warning: Custom board-2.bin not found at $CUSTOM_BOARD"
fi
EOF

sudo chmod +x /usr/local/bin/wcn7850-board-fix.sh
```

**Note**: Update `CUSTOM_BOARD` path if you cloned the repository elsewhere.

```bash
# Create pacman hook
sudo tee /etc/pacman.d/hooks/99-wcn7850-board-fix.hook << 'EOF'
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
EOF
```

### Step 4: Reboot

```bash
sudo reboot
```

---

## Post-Installation Verification

After reboot, verify the fix:

```bash
# Check if board_id changed from 0xff
sudo dmesg | grep -i "board_id"

# Check for subsystem ID detection
sudo dmesg | grep -i "e0fb\|105b"

# Check WiFi interface is present
iw dev

# Check TX power (should be higher than 1 dBm)
iw dev wlan1 info | grep txpower

# Test connectivity
ping -c 3 8.8.8.8
```

### Expected Success

```
ath12k_pci 0000:0d:00.0: board_id 0x?? (something other than 0xff)
```

### Expected Failure (Needs Investigation)

```
ath12k_pci 0000:0d:00.0: board_id 0xff (still generic)
```

---

## Rebuilding Custom Firmware (Advanced)

If you need to modify or rebuild the custom firmware:

### Install Tools

```bash
git clone https://github.com/qca/qca-swiss-army-knife.git
cd qca-swiss-army-knife/tools/scripts/ath12k
```

### Extract Original

```bash
# Decompress
zstd -d /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst -o board-2.bin

# Extract to JSON
./ath12k-bdencoder -e board-2.bin > board-2.json
```

### Modify JSON

Add entry for `105b:e0fb` by copying an existing similar entry (e.g., `e0dc`):

```json
{
  "names": [
    "bus=pci,vendor=17cb,device=1107,subsystem-vendor=105b,subsystem-device=e0fb,qmi-chip-id=2,qmi-board-id=255,variant=QC_5mm"
  ],
  "data": "<copy from e0dc entry>"
}
```

### Rebuild

```bash
./ath12k-bdencoder -c board-2-custom.json -o board-2.bin
zstd board-2.bin -o board-2.bin.zst
```

---

## File Locations

| File | Purpose |
|------|---------|
| `board-2.bin.zst` | Custom firmware (source in this repo) |
| `/usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst` | System firmware location |
| `/etc/pacman.d/hooks/99-wcn7850-board-fix.hook` | Pacman hook |
| `/usr/local/bin/wcn7850-board-fix.sh` | Restore script |

---

## Rollback

### Remove Custom Firmware

```bash
# Reinstall original firmware
sudo pacman -S linux-firmware

# Remove hook (prevents re-applying custom firmware)
sudo rm /etc/pacman.d/hooks/99-wcn7850-board-fix.hook

# Remove script (optional)
sudo rm /usr/local/bin/wcn7850-board-fix.sh

# Reboot
sudo reboot
```

---

## Troubleshooting

### Custom firmware not applied after update

Check if pacman hook exists and is executable:

```bash
cat /etc/pacman.d/hooks/99-wcn7850-board-fix.hook
ls -la /usr/local/bin/wcn7850-board-fix.sh
```

### WiFi not working after reboot

1. Check if driver loaded: `lsmod | grep ath12k`
2. Check dmesg for errors: `sudo dmesg | grep -i ath12k`
3. Rollback to original firmware (see above)

### board_id still 0xff

The firmware entry format may need adjustment. Check:
- Is the subsystem ID format correct?
- Is the calibration data valid for this board variant?
- Try using a different variant's calibration data

---

## Historical: SSDT Approach

The ACPI SSDT approach (files in `acpi/` directory) was tried first but doesn't work - the ath12k driver doesn't read _DSM methods from the device. The SSDT files remain for reference but are not part of the active fix.
