# SSDT v2 Changes - Critical Fix

**Date**: 2025-11-20 18:44
**Status**: Ready for reboot

## Problem Discovered

After first reboot, the driver showed:
```
[   15.894975] ath12k_pci 0000:0d:00.0: failed to get ACPI BDF EXT: 0
```

This meant our v1 SSDT was **not being read** by the driver.

## Root Cause Analysis

Analyzed the ath12k kernel driver source (`kernel/ath12k-source/acpi.c` and `hw.c`) and discovered:

1. **Wrong UUID**: v1 used custom UUID `a0b5b7c1-1318-4de2-b28a-7a30f0b67cea`
   - Driver expects: `f634f534-6147-11ec-90d6-0242ac120003` (wcn7850_uuid from hw.c:19)

2. **Wrong Function**: v1 returned Package from Function 1
   - Driver expects: STRING from Function 3 (ATH12K_ACPI_DSM_FUNC_BDF_EXT)

3. **Wrong Format**: v1 returned Package with key-value pairs
   - Driver expects: String starting with "BDF" followed by variant name
   - Format: "BDF<variant_name>" where content after "BDF" is copied to `ab->qmi.target.bdf_ext`
   - This variant becomes `,variant=<variant_name>` in board file search

## SSDT v2 Changes

### Corrected UUID
```asl
If (LEqual (Arg0, ToUUID ("f634f534-6147-11ec-90d6-0242ac120003")))
```
- Now matches wcn7850_uuid from `drivers/net/wireless/ath/ath12k/hw.c`

### Corrected Function 0 (Query Support)
```asl
If (LEqual (Arg2, Zero))
{
    Return (Buffer () { 0x04 })  /* BIT(2) = Function 3 supported */
}
```
- Returns bitmask indicating Function 3 (BDF_EXT) is supported
- Bit 2 = 0x04 = ATH12K_ACPI_FUNC_BIT_BDF_EXT

### Corrected Function 3 (BDF_EXT)
```asl
If (LEqual (Arg2, 0x03))  /* Function 3 = BDF_EXT */
{
    Return ("BDFQC_5mm")  /* BDF + variant name */
}
```
- Returns STRING (not Package)
- Starts with "BDF" (required anchor string)
- "QC_5mm" portion is copied to `ab->qmi.target.bdf_ext`
- Driver searches for board-2.bin entries with `,variant=QC_5mm`

## Driver Code Flow

```c
// acpi.c:42-56
case ATH12K_ACPI_DSM_FUNC_BDF_EXT:
    if (obj->string.length <= ATH12K_ACPI_BDF_ANCHOR_STRING_LEN ||
        obj->string.length > ATH12K_ACPI_BDF_MAX_LEN ||
        memcmp(obj->string.pointer, ATH12K_ACPI_BDF_ANCHOR_STRING,
               ATH12K_ACPI_BDF_ANCHOR_STRING_LEN)) {
        // Error: must start with "BDF" and be 4-100 chars
    }
    memcpy(ab->acpi.bdf_string, obj->string.pointer, obj->buffer.length);

// acpi.c:ath12k_acpi_check_bdf_variant_name()
strscpy(ab->qmi.target.bdf_ext, ab->acpi.bdf_string + 4, max_len);
// Copies everything after "BDF" (position +4)

// core.c:223-225
if (with_variant && ab->qmi.target.bdf_ext[0] != '\0')
    scnprintf(variant, sizeof(variant), ",variant=%s", ab->qmi.target.bdf_ext);
// Appends ",variant=QC_5mm" to board file search
```

## Expected Outcome After Reboot

### What Should Change:
```
# Before (v1 SSDT):
[   15.894975] ath12k_pci 0000:0d:00.0: failed to get ACPI BDF EXT: 0
[   15.894908] ath12k_pci 0000:0d:00.0: board_id 0xff

# After (v2 SSDT):
[   15.XXXXXX] ath12k_pci 0000:0d:00.0: ACPI BDF EXT loaded: BDFQC_5mm
[   15.XXXXXX] ath12k_pci 0000:0d:00.0: board variant: QC_5mm
[   15.XXXXXX] ath12k_pci 0000:0d:00.0: board_id 0x?? (non-0xff)
```

### WiFi Performance:
- **Current**: TX power ~1 dBm, only sees own mesh (39 APs, all "Panic @ the Cisco")
- **Expected**: TX power 24 dBm, can detect neighbor networks

### Board File Search:
Driver will search board-2.bin for entries matching:
```
bus=pci,vendor=17cb,device=1107,subsystem-vendor=105b,subsystem-device=e0fb,qmi-chip-id=2,qmi-board-id=<id>,variant=QC_5mm
```

## Files Modified

- `acpi/SSDT-WCN7850-v2.dsl` - Corrected source (with maintenance docs)
- `acpi/SSDT-WCN7850.aml` - Compiled table (182 bytes, down from 425 bytes)
- `acpi/SSDT-WCN7850-v1-backup.aml` - Backup of original v1 table
- `/boot/acpi/tables/SSDT-WCN7850.aml` - Installed
- `/usr/lib/firmware/acpi/SSDT-WCN7850.aml` - Installed
- `/boot/EFI/Linux/omarchy_linux.efi` - UKI rebuilt with new SSDT

## Verification Steps (Post-Reboot)

```bash
cd ~/dev/qualcomm-x870e-linux-bug-patch

# 1. Check driver loaded ACPI BDF
sudo dmesg | grep -i "ACPI BDF\|board_id\|variant"

# 2. Check WiFi interface status
iw dev wlan0 info

# 3. Test neighbor network detection
sudo iw dev wlan0 scan | grep -E "^BSS|SSID:" | grep -v "Panic @ the Cisco"

# 4. If working, test TX power
sudo iw dev wlan0 set txpower fixed 2400
iw dev wlan0 info | grep txpower
```

## Rollback If Needed

If v2 doesn't work or causes issues:

```bash
# Restore v1 SSDT
cd ~/dev/qualcomm-x870e-linux-bug-patch/acpi
sudo cp SSDT-WCN7850-v1-backup.aml /boot/acpi/tables/SSDT-WCN7850.aml
sudo cp SSDT-WCN7850-v1-backup.aml /usr/lib/firmware/acpi/SSDT-WCN7850.aml
sudo mkinitcpio -P
sudo reboot
```

## Technical References

- Kernel source: `drivers/net/wireless/ath/ath12k/acpi.c`
- WCN7850 UUID: `drivers/net/wireless/ath/ath12k/hw.c:19`
- ACPI DSM functions: `drivers/net/wireless/ath/ath12k/acpi.h:11-19`
- Board file search: `drivers/net/wireless/ath/ath12k/core.c:223-225`

## Next Steps

1. **Reboot**: `sudo reboot`
2. **Verify**: Run post-reboot verification steps above
3. **If successful**: Document as working solution, may skip Phase 2 (kernel patch)
4. **If unsuccessful**: May still need Phase 2 kernel patch to properly read variant
