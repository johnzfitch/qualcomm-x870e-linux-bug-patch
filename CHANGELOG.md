# Changelog

All notable changes to this project are documented in this file.

---

## [v5.0] - 2025-11-21 23:45 - WORKING FIX - Entry Priority Fix

### Actual Root Cause Discovered
- **e0fb entry EXISTS in upstream** - was NOT missing!
- Entry was in MULTIPLE groups: generic `e0ee`, generic `e0dc`, and `QC_5mm` variant
- Driver searches WITHOUT variant when ACPI fails
- Finds generic `e0ee` group FIRST → wrong calibration → low TX power
- Bluetooth uses same calibration → crashes on scan

### The Fix
1. Removed `e0fb` from all non-variant groups (e0ee and e0dc)
2. Added standalone `e0fb` entry at position [0] pointing to `QC_5mm.bin`
3. Driver now finds correct entry first → proper calibration

### Results - VERIFIED WORKING
| Metric | Before | After |
|--------|--------|-------|
| WiFi Networks | Only own mesh | **40+ networks** |
| Bluetooth | Crash on scan | **Stable, finds devices** |
| Signal Range | None visible | -59 to -82 dBm |

### Technical Details
- Created `fix-e0fb-entry.py` to modify board-2.json
- `BoardNames[0]` now contains standalone e0fb entry
- Points to `e0dc...variant=QC_5mm.bin` calibration data

### Files Created
- `board-2-fixed.json` - Fixed JSON with standalone entry
- `board-2-fixed.bin` - Rebuilt firmware binary
- `fix-e0fb-entry.py` - Automation script

---

## [v4.0] - 2025-11-21 15:30 - board-2.bin Firmware Override (INCOMPLETE)

### Root Cause Discovered (INCORRECT)
- **Subsystem ID `105b:e0fb` is MISSING from linux-firmware's board-2.bin**
- Driver searches for calibration data by PCI subsystem ID
- Missing entry causes fallback to `board_id 0xff` (generic)
- This is the actual problem - not ACPI

### Added
- Custom `board-2.bin.zst` with `105b:e0fb` entry added
- Pacman hook `/etc/pacman.d/hooks/99-wcn7850-board-fix.hook`
- Restore script `/usr/local/bin/wcn7850-board-fix.sh`
- JSON files for firmware modification (`board-2.json`, `board-2-custom.json`)
- DKMS kernel patch approach (alternative, in `dkms/` directory)

### Changed
- Primary fix method: SSDT -> board-2.bin firmware override
- SSDT files moved to historical/reference status

### Technical Details
- Used `qca-swiss-army-knife/ath12k-bdencoder` to modify firmware
- Added entry sharing calibration data with similar `e0dc` variant:
  ```
  bus=pci,vendor=17cb,device=1107,subsystem-vendor=105b,subsystem-device=e0fb,qmi-chip-id=2,qmi-board-id=255,variant=QC_5mm
  ```
- Pacman hook triggers on `linux-firmware` and `linux-firmware-ath` updates

### Status
- **Pending reboot test**

---

## [v3.1] - 2025-11-21 14:10 - SSDT Configuration Fix

### Fixed
- **mkinitcpio configuration method**: Changed from `FILES=()` directive to `acpi_override` hook
- `FILES=()` puts files in compressed image; ACPI table upgrade requires **uncompressed early CPIO**
- The `acpi_override` hook uses `add_file_early` to correctly place SSDTs in early CPIO

### Changed
- SSDT location: `/kernel/firmware/acpi/` -> `/etc/initcpio/acpi_override/`
- Config method: `FILES=(/kernel/firmware/acpi/*.aml)` -> `HOOKS+=(acpi_override)`
- Added drop-in config `/etc/mkinitcpio.conf.d/zz-acpi-override.conf`
- Removed obsolete `/kernel/firmware/acpi/` directory

### Technical
- `zz-` prefix ensures config loads after omarchy_hooks.conf
- Hook survives omarchy-update (which overwrites omarchy_hooks.conf)

### Result
- **SSDT loads at boot** (confirmed via dmesg)
- **Driver still can't read _DSM** (led to v4.0 approach)

---

## [v3] - 2025-11-21 01:06 - Correct ACPI Device Path

### Fixed
- **ACPI device path**: Changed from `\_SB.PCI0.WCN7` to actual device path `\_SB.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00`
- Path discovered via `/sys/bus/pci/devices/0000:0d:00.0/firmware_node/path`
- WiFi card is behind USB4/PCIe bridge chain, not directly under PCI0

### Changed
- SSDT now adds `_DSM` method to existing `WN00` device instead of creating new device
- Reduced SSDT size: 179 bytes (was 182 in v2)

### Technical
- `SSDT-WCN7850-v3.dsl` uses `Scope` to extend existing device
- Uses `External` declaration to reference BIOS-defined device

### Result
- SSDT compiles and loads
- Driver's ACPI lookup still doesn't find it

---

## [v2] - 2025-11-20 18:44 - Correct UUID and Format

### Fixed
- **UUID**: Changed from custom `a0b5b7c1-...` to official `f634f534-6147-11ec-90d6-0242ac120003`
- **Function**: Changed from Function 1 (Package) to Function 3 (String)
- **Format**: Returns `"BDFQC_5mm"` string instead of Package with key-value pairs

### Changed
- Function 0 returns `0x04` (BIT(2) for Function 3 support)
- SSDT size reduced from 425 to 182 bytes

### Failed
- Still showed `failed to get ACPI BDF EXT: 0`
- Root cause: Wrong device path (discovered in v3)

---

## [v1] - 2025-11-20 15:25 - Initial SSDT Attempt

### Added
- Initial ACPI SSDT table creation
- Custom UUID for board configuration
- Package-based configuration with BoardVariant, MaxTxPower, etc.

### Configuration
- Path: `\_SB.PCI0.WCN7` (incorrect)
- UUID: Custom (incorrect)
- Function 1 returns Package (incorrect)

### Failed
- Driver couldn't read SSDT
- Wrong UUID, wrong function, wrong format

---

## Investigation Timeline

### 2025-11-20 (Session 1)
1. Identified root cause: board_id 0xff from firmware
2. Analyzed Windows driver (qcwlan64.sys)
3. Analyzed BIOS (F9e) - no ACPI BDF tables
4. Created SSDT v1 (failed)
5. Created SSDT v2 with correct UUID/format (failed)
6. Installed to initramfs, rebooted

### 2025-11-21 (Session 2 - Morning)
1. Found SSDT in wrong initramfs path
2. Tried `FILES=()` directive - didn't work
3. SSDT loaded at runtime but not at boot
4. Found actual ACPI path via `firmware_node/path`
5. Created SSDT v3 targeting correct device
6. Discovered `acpi_override` hook for proper early CPIO placement
7. Configured hook via drop-in config
8. Rebooted - SSDT loads but driver still can't read it

### 2025-11-21 (Session 2 - Afternoon)
9. Analyzed driver ACPI lookup mechanism
10. Discovered real problem: subsystem ID missing from board-2.bin
11. Created plan for multiple fix approaches
12. Implemented board-2.bin firmware override
13. Created pacman hook for persistence
14. Ready for reboot test

---

## Lessons Learned

1. **board-2.bin is the source of truth**: The driver loads board calibration from firmware, not ACPI
   - Subsystem ID must exist in board-2.bin
   - ACPI BDF tables are a secondary source that the driver struggles to read

2. **ACPI Table Override Method**: Use `acpi_override` hook, NOT `FILES=()` directive
   - `FILES=()` puts files in compressed image
   - Kernel ACPI table upgrade requires **uncompressed early CPIO**
   - Hook uses `add_file_early` for correct placement

3. **Device Path Discovery**: Use `/sys/bus/pci/devices/<bdf>/firmware_node/path` to find actual ACPI path

4. **PCI Topology Matters**: Device at `0d:00.0` isn't necessarily at `\_SB.PCI0.DEV0D` - it may be behind bridges

5. **Persistence across updates**: Use pacman hooks to restore custom firmware after package updates

6. **UUID Source**: Always check driver source for expected UUID (`hw.c` for wcn7850_uuid)

7. **Drop-in Config Protection**: Use `/etc/mkinitcpio.conf.d/zz-*.conf` to survive framework updates

8. **qca-swiss-army-knife**: Essential tool for modifying Qualcomm WiFi firmware files
