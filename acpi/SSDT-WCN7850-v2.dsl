/*
 * SSDT for Qualcomm WCN7850 WiFi 7 Board Data Override (v2 - CORRECTED)
 *
 * Purpose: Provide board-specific calibration hints to Linux ath12k driver
 * Hardware: Gigabyte X870E AORUS MASTER (AI TOP)
 * PCI Location: 0000:0d:00.0
 * Subsystem ID: 105b:e0fb (Foxconn/Gigabyte)
 *
 * This version uses the CORRECT UUID and format expected by ath12k driver:
 * - UUID: F634F534-6147-11EC-90D6-0242AC120003 (wcn7850_uuid from hw.c)
 * - Function 0: Query supported functions (returns bitmask)
 * - Function 3: BDF_EXT (returns STRING starting with "BDF")
 *
 * Fixes from v1:
 * - Changed from custom UUID to official wcn7850_uuid
 * - Changed from Package return to STRING return
 * - Function 3 (BDF_EXT) now returns "BDFQC_5mm" instead of Package
 *
 * MAINTENANCE NOTES FOR FUTURE UPDATES:
 * ======================================
 * If you need to update the board variant name:
 * 1. Find the correct board variant from Windows driver or firmware
 * 2. Update the Return() statement in Function 3 below
 * 3. Format: "BDF<variant_name>" where <variant_name> is appended as ",variant=<variant_name>"
 * 4. Example variants: QC_5mm, QC_7mm, Generic, Custom, etc.
 * 5. Recompile: iasl -tc SSDT-WCN7850-v2.dsl
 * 6. Reinstall and rebuild initramfs
 *
 * The variant name affects which calibration data is loaded from board-2.bin
 */

DefinitionBlock ("SSDT-WCN7850.aml", "SSDT", 2, "GBYTE", "WCN7850", 0x00000002)
{
    External (_SB.PCI0, DeviceObj)

    Scope (\_SB.PCI0)
    {
        Device (WCN7)
        {
            /*
             * _ADR: PCI Device 0x0D (13), Function 0x00
             * (0x0D << 16) | 0x00 = 0x000D0000
             */
            Name (_ADR, 0x000D0000)
            Name (_UID, "WCN7850-GBYTE-E0FB")

            /*
             * Device-Specific Method (_DSM)
             * UUID: F634F534-6147-11EC-90D6-0242AC120003 (wcn7850_uuid)
             */
            Method (_DSM, 4, Serialized)
            {
                /*
                 * Arg0: UUID - Must match wcn7850_uuid from ath12k/hw.c
                 * Arg1: Revision - We support revision 0
                 * Arg2: Function Index
                 * Arg3: Package (unused)
                 */

                /* Check for WCN7850 UUID */
                If (LEqual (Arg0, ToUUID ("f634f534-6147-11ec-90d6-0242ac120003")))
                {
                    /*
                     * Function 0: Query supported functions
                     * Return bitmask of supported functions
                     * Bit 2: Function 3 (BDF_EXT) = 0x04
                     * So we return Buffer with 0x04 to indicate BDF_EXT support
                     */
                    If (LEqual (Arg2, Zero))
                    {
                        Return (Buffer () { 0x04 })  /* BIT(2) = Function 3 supported */
                    }

                    /*
                     * Function 3: ATH12K_ACPI_DSM_FUNC_BDF_EXT
                     * Must return a STRING that:
                     * 1. Starts with "BDF" (ATH12K_ACPI_BDF_ANCHOR_STRING)
                     * 2. Length 4-100 characters
                     * 3. Content after "BDF" is the board variant name
                     *
                     * The string after "BDF" will be appended to board file search as:
                     * ",variant=QC_5mm"
                     *
                     * CHANGE THIS LINE to update the board variant:
                     * Format: Return ("BDF<your_variant_name>")
                     */
                    If (LEqual (Arg2, 0x03))  /* Function 3 = BDF_EXT */
                    {
                        Return ("BDFQC_5mm")  /* BDF + variant name */
                    }
                }

                /* UUID doesn't match or function not supported */
                Return (Buffer () { 0x00 })
            }

            /*
             * _STA: Device status
             * 0x0F = Present, Enabled, Shown in UI, Functioning
             */
            Method (_STA, 0, NotSerialized)
            {
                Return (0x0F)
            }
        }
    }
}
