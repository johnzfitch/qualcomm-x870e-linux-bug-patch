# Changelog

All notable changes to this project are documented in this file.

---

## [v3.1] - 2025-11-21 14:10

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

### Status
- **Pending reboot test**

---

## [v3] - 2025-11-21 01:06

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

### Issues Found
- Runtime SSDT load showed `AE_ALREADY_EXISTS` error
- This is expected - the BIOS WN00 device doesn't have a _DSM, but runtime load after v2 had already created one
- Early boot load should work correctly

---

## [v2] - 2025-11-20 18:44

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

## [v1] - 2025-11-20 15:25

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

### 2025-11-20 (Initial Session)
1. Identified root cause: board_id 0xff from firmware
2. Analyzed Windows driver (qcwlan64.sys)
3. Analyzed BIOS (F9e) - no ACPI BDF tables
4. Created SSDT v1 (failed)
5. Created SSDT v2 with correct UUID/format (failed)
6. Installed to initramfs, rebooted

### 2025-11-21 (Continuation)
1. Found SSDT in wrong initramfs path (`usr/lib/firmware/acpi/` vs `kernel/firmware/acpi/`)
2. Tried `FILES=(/kernel/firmware/acpi/*.aml)` - didn't work (files in compressed image)
3. SSDT loaded at runtime but not at boot - discovered wrong device path
4. Found actual path via `firmware_node/path`
5. Created SSDT v3 targeting correct device
6. Discovered `acpi_override` hook for proper early CPIO placement
7. Configured hook via `/etc/mkinitcpio.conf.d/zz-acpi-override.conf`
8. Ready for reboot test

---

## Lessons Learned

1. **ACPI Table Override Method**: Use `acpi_override` hook, NOT `FILES=()` directive
   - `FILES=()` puts files in compressed image
   - Kernel ACPI table upgrade requires **uncompressed early CPIO**
   - Hook uses `add_file_early` for correct placement

2. **SSDT Location for acpi_override Hook**:
   - `/usr/lib/initcpio/acpi_override/*.aml` (system-wide)
   - `/etc/initcpio/acpi_override/*.aml` (local override)

3. **Device Path Discovery**: Use `/sys/bus/pci/devices/<bdf>/firmware_node/path` to find actual ACPI path

4. **PCI Topology Matters**: Device at `0d:00.0` isn't necessarily at `\_SB.PCI0.DEV0D` - it may be behind bridges

5. **Driver ACPI Reading**: ath12k uses `ACPI_HANDLE(ab->dev)` which requires SSDT to extend the existing device, not create a new one

6. **UUID Source**: Always check driver source for expected UUID (`hw.c` for wcn7850_uuid)

7. **Drop-in Config Protection**: Use `/etc/mkinitcpio.conf.d/zz-*.conf` to survive framework updates that overwrite base configs

8. **UKI Timestamp Quirk**: mkinitcpio may preserve embedded file timestamps in UKI; verify by content not mtime
