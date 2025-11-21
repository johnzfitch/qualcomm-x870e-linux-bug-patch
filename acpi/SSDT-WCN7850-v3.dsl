/*
 * SSDT for Qualcomm WCN7850 WiFi 7 Board Data Override (v3 - CORRECT PATH)
 *
 * Purpose: Add _DSM method to existing WCN7850 device for board calibration
 * Hardware: Gigabyte X870E AORUS MASTER (AI TOP)
 *
 * CRITICAL FIX: v1 and v2 created new device at wrong path (\_SB.PCI0.WCN7)
 * Actual device path is: \_SB_.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00
 *
 * This version adds _DSM to the EXISTING device at the correct path.
 */

DefinitionBlock ("SSDT-WCN7850.aml", "SSDT", 2, "GBYTE", "WCN7850", 0x00000003)
{
    /* Reference to the EXISTING WN00 device in BIOS DSDT */
    External (\_SB.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00, DeviceObj)

    Scope (\_SB.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00)
    {
        /*
         * Device-Specific Method (_DSM)
         * UUID: F634F534-6147-11EC-90D6-0242AC120003 (wcn7850_uuid from ath12k)
         */
        Method (_DSM, 4, Serialized)
        {
            /* Check for WCN7850 UUID */
            If (LEqual (Arg0, ToUUID ("f634f534-6147-11ec-90d6-0242ac120003")))
            {
                /* Function 0: Query supported functions */
                If (LEqual (Arg2, Zero))
                {
                    Return (Buffer () { 0x04 })  /* BIT(2) = Function 3 supported */
                }

                /* Function 3: BDF_EXT - Board Data File Extension */
                If (LEqual (Arg2, 0x03))
                {
                    Return ("BDFQC_5mm")  /* BDF + variant name */
                }
            }

            Return (Buffer () { 0x00 })
        }
    }
}
