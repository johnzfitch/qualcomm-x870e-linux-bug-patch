# Current Status

**Last Updated**: 2025-11-21 15:30 PST
**Fix Method**: board-2.bin firmware override
**WiFi Status**: Operational - pending reboot test for fix verification

---

## Current State Summary

| Component | Status | Notes |
|-----------|--------|-------|
| WiFi Hardware | Working | WCN7850 hw2.0 operational |
| WiFi Performance | ~910 Mbps | Works despite board_id 0xff |
| Custom board-2.bin | Installed | Added 105b:e0fb entry |
| Pacman hook | Active | Survives linux-firmware updates |
| board_id | 0xff | Pending fix verification after reboot |

---

## Root Cause Discovered (2025-11-21)

**The subsystem ID `105b:e0fb` is missing from linux-firmware's board-2.bin.**

The driver searches for calibration data by PCI subsystem ID. Since Gigabyte X870E's ID (`105b:e0fb`) doesn't exist in the firmware file, it falls back to `board_id 0xff` (generic).

This explains why:
- ACPI SSDT approach couldn't help (driver reads board data from firmware, not ACPI)
- `failed to get ACPI BDF EXT: 0` appears (BIOS lacks tables, but that's not the real problem)
- WiFi works but with limited TX power

---

## Fix Implemented

### 1. Custom board-2.bin
Added entry for `105b:e0fb` using calibration data from the similar `e0dc` variant:

```
bus=pci,vendor=17cb,device=1107,subsystem-vendor=105b,subsystem-device=e0fb,qmi-chip-id=2,qmi-board-id=255,variant=QC_5mm
```

### 2. Pacman Hook
Created `/etc/pacman.d/hooks/99-wcn7850-board-fix.hook` to restore custom firmware after linux-firmware updates.

### 3. Restore Script
Created `/usr/local/bin/wcn7850-board-fix.sh` to copy custom firmware from this repository to system location.

---

## SSDT Approach (Historical)

The ACPI SSDT v3 is still installed but ineffective:

**SSDT loads at early boot:**
```
[    0.003804] ACPI: Table Upgrade: install [SSDT- GBYTE- WCN7850]
[    0.003805] ACPI: SSDT 0x0000000099ED4000 0000B3 (v02 GBYTE WCN7850 00000003 INTL 20250404)
```

**Driver still fails to read it:**
```
[   16.999424] ath12k_pci 0000:0d:00.0: failed to get ACPI BDF EXT: 0
```

**Conclusion:** The ath12k driver's ACPI lookup mechanism doesn't find _DSM methods on the device. The board-2.bin firmware approach is more direct and should work.

---

## System Configuration

### Firmware Override
- **Custom firmware**: `~/dev/qualcomm-x870e-linux-bug-patch/board-2.bin.zst`
- **System location**: `/usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst`
- **Pacman hook**: `/etc/pacman.d/hooks/99-wcn7850-board-fix.hook`
- **Restore script**: `/usr/local/bin/wcn7850-board-fix.sh`

### Bootloader
- **Type**: Limine (UKI-based)
- **UKI Location**: `/boot/EFI/Linux/omarchy_linux.efi`

### Network
- **Ethernet**: Atlantic 10GbE (enp16s0) - 10Gbps link
- **WiFi**: Qualcomm WCN7850 (wlan1) - Currently active

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
├── board-2.bin.zst              # Custom firmware with e0fb entry
├── board-2-custom.json          # Board data definition
├── board-2.json                 # Original extracted data
│
├── acpi/                        # Historical SSDT files
│   ├── SSDT-WCN7850.aml         # Compiled SSDT (v3)
│   ├── SSDT-WCN7850-v3.dsl      # v3 source
│   └── ...
│
├── dkms/                        # Alternative kernel patch approach
│   └── ath12k-wcn7850-fix/
│       └── 0001-ath12k-add-bdf-variant-fallback.patch
│
└── qca-swiss-army-knife/        # Qualcomm firmware tools

System Files:
├── /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst
├── /etc/pacman.d/hooks/99-wcn7850-board-fix.hook
├── /usr/local/bin/wcn7850-board-fix.sh
├── /etc/initcpio/acpi_override/SSDT-WCN7850.aml  # Historical
└── /etc/mkinitcpio.conf.d/zz-acpi-override.conf  # Historical
```

---

## Next Steps

### Immediate: Reboot to Test
```bash
sudo reboot
```

### After Reboot: Verify Fix
```bash
# Check if board_id changed from 0xff
sudo dmesg | grep -i "board_id"

# Check for our subsystem ID
sudo dmesg | grep -i "e0fb\|105b"

# Check WiFi interface
iw dev

# Check TX power
iw dev wlan1 info | grep txpower

# Speed test
# Connect to network and test throughput
```

### Expected Outcomes

**If fix works:**
- board_id changes from 0xff to something else
- TX power increases (>1 dBm)
- Possibly better range/stability

**If fix doesn't work:**
- board_id still 0xff
- May need to investigate driver's exact firmware lookup logic
- Or the calibration data format needs adjustment

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
- **ACPI Path**: `\_SB.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00`
- **Firmware Location**: `/usr/lib/firmware/ath12k/WCN7850/hw2.0/`
- **Kernel**: 6.17.8-arch1-1
- **Driver**: ath12k (in-tree)
