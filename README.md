# Qualcomm WCN7850 WiFi 7 - Linux ACPI Fix

**Hardware**: Gigabyte X870E AORUS MASTER
**WiFi**: Qualcomm WCN7850 hw2.0 (FastConnect 7800)
**Status**: SSDT v3 installed - pending reboot test

---

## Problem

The WCN7850 WiFi 7 card reports `board_id 0xff` (generic fallback) because Gigabyte's BIOS lacks ACPI BDF (Board Data File) tables. This limits TX power calibration, though WiFi still achieves ~910 Mbps in practice.

## Solution

Custom ACPI SSDT table that provides board calibration hints to the ath12k driver, loaded via mkinitcpio's `acpi_override` hook.

### Current State

| Item | Status |
|------|--------|
| WiFi Performance | ~910 Mbps (working) |
| board_id | 0xff (generic) |
| SSDT v3 | Installed via acpi_override hook |
| TX Power | Limited (1 dBm reported) |

---

## Quick Start

SSDT v3 is installed. To test:

```bash
sudo reboot
```

After reboot, verify:
```bash
sudo dmesg | grep -i "ACPI BDF\|board_id\|GBYTE"
```

---

## Documentation

| File | Description |
|------|-------------|
| `STATUS.md` | Current state and next steps |
| `INSTALL.md` | Installation guide |
| `CHANGELOG.md` | Version history (v1 -> v2 -> v3) |
| `EMERGENCY-ROLLBACK.md` | Rollback procedures |

---

## Technical Details

### Root Cause
- Firmware reports `board_id 0xff` via QMI interface
- BIOS (F9e) lacks ACPI BDF extension tables
- Driver uses generic calibration instead of device-specific

### SSDT Approach
- v1: Wrong UUID, wrong function, wrong format
- v2: Correct UUID/format, wrong device path (`\_SB.PCI0.WCN7`)
- **v3**: Correct path (`\_SB.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00`)

The WiFi device is behind USB4/PCIe bridges, not directly under PCI0.

### Key Files
```
acpi/SSDT-WCN7850-v3.dsl              # Current source
acpi/SSDT-WCN7850.aml                 # Compiled (179 bytes)
/etc/initcpio/acpi_override/          # System location (for hook)
```

### mkinitcpio Configuration

Uses `acpi_override` hook (NOT the FILES directive):
```
/etc/mkinitcpio.conf.d/zz-acpi-override.conf:
HOOKS+=(acpi_override)
```

The hook loads SSDTs from `/etc/initcpio/acpi_override/` into the **early uncompressed CPIO**, which is required for kernel ACPI table upgrade.

---

## System Info

- **Kernel**: 6.17.8-arch1-1
- **Bootloader**: Limine (UKI)
- **Firmware**: linux-firmware-atheros 20251111-1
- **PCI**: 0000:0d:00.0 (17cb:1107, subsystem 105b:e0fb)

---

## If It Doesn't Work

If SSDT v3 still shows `failed to get ACPI BDF EXT: 0`, the driver may need a kernel patch to read the _DSM method from the ACPI device. See `docs/wifi-7-plan.txt` for details.

Current WiFi performance (~910 Mbps) is acceptable as a fallback.
