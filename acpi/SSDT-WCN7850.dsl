/*
 * SSDT for Qualcomm WCN7850 WiFi 7 Board Data Override
 *
 * Purpose: Provide board-specific calibration hints to Linux ath12k driver
 * Hardware: Gigabyte X870E AORUS MASTER (AI TOP)
 * PCI Location: 0000:0d:00.0
 * Subsystem ID: 105b:e0fb (Foxconn/Gigabyte)
 *
 * This table adds board calibration metadata that the BIOS lacks.
 * It tells the WiFi driver to use QC_5mm variant instead of generic 0xff calibration.
 */

DefinitionBlock ("SSDT-WCN7850.aml", "SSDT", 2, "GBYTE", "WCN7850", 0x00000001)
{
    /*
     * External reference to PCI root - adjust if needed
     * Common paths: _SB.PCI0 (Intel), _SB.PC00 (AMD Threadripper), _SB.PCIE (some AMD)
     * For X870E chipset, using _SB.PCI0 (standard AMD convention)
     */
    External (_SB.PCI0, DeviceObj)

    /*
     * Scope: Attach to PCI root
     * We create a new device under PCI0 for the WiFi card
     */
    Scope (\_SB.PCI0)
    {
        /*
         * Device WCN7: Qualcomm WCN7850 WiFi 7 adapter
         * Name chosen to avoid conflicts (WCN7 is unique)
         */
        Device (WCN7)
        {
            /*
             * _ADR: Address on PCI bus
             * Format: High 16 bits = device number, Low 16 bits = function number
             * Device 0x0D (13), Function 0x00 -> (0x0D << 16) | 0x00 = 0x000D0000
             * This creates a virtual ACPI device at PCI address 0d:00.0
             */
            Name (_ADR, 0x000D0000)

            /*
             * _UID: Unique ID for this device instance
             */
            Name (_UID, "WCN7850-GBYTE-E0FB")

            /*
             * _SUN: Slot User Number - PCI slot identification
             * Using Bus 0x0D (13 decimal) for PCI location identification
             */
            Name (_SUN, 0x0D)

            /*
             * Device-Specific Method (_DSM)
             * This is the key method that provides board data hints to the driver
             *
             * UUID: Custom UUID for Qualcomm WiFi board data
             * We use a custom UUID that the ath12k driver will check for
             */
            Method (_DSM, 4, Serialized)
            {
                /*
                 * Arg0: UUID (Buffer) - Identifies the type of data being requested
                 * Arg1: Revision (Integer) - Interface version
                 * Arg2: Function Index (Integer) - Which function to call
                 * Arg3: Package (Package) - Function-specific arguments
                 */

                /*
                 * Our custom UUID for Qualcomm WiFi board configuration
                 * UUID: A0B5B7C1-1318-4DE2-B28A-7A30F0B67CEA
                 * (Generated for this purpose, not an official Qualcomm UUID)
                 */
                If (LEqual (Arg0, ToUUID ("a0b5b7c1-1318-4de2-b28a-7a30f0b67cea")))
                {
                    /*
                     * Check revision - we support revision 1
                     */
                    If (LEqual (Arg1, One))
                    {
                        /*
                         * Function 0: Query supported functions
                         * Return a bitmask of supported function indices
                         * Bit 0: Function 0 (this query) - always supported
                         * Bit 1: Function 1 (board data) - supported
                         */
                        If (LEqual (Arg2, Zero))
                        {
                            Return (Buffer () { 0x03 })  // Functions 0 and 1 supported
                        }

                        /*
                         * Function 1: Get board data configuration
                         * Returns a package with board-specific information
                         */
                        If (LEqual (Arg2, One))
                        {
                            Return (Package ()
                            {
                                /*
                                 * Package format:
                                 * [0]: Property name
                                 * [1]: Property value
                                 * [2]: Property name
                                 * [3]: Property value
                                 * ... etc
                                 */

                                /* PCI Subsystem Vendor ID */
                                "SubsystemVendor", 0x105B,

                                /* PCI Subsystem Device ID */
                                "SubsystemDevice", 0xE0FB,

                                /* Board variant name */
                                "BoardVariant", "QC_5mm",

                                /* Board data file name (relative to firmware dir) */
                                "BoardDataFile", "bdwlan_wcn785x_2p0_ncm865_QC_5mm.elf",

                                /* Maximum TX power in dBm */
                                "MaxTxPower", 24,

                                /* Regulatory domain */
                                "RegulatoryDomain", "US",

                                /* Enable custom regdomain (matches Windows driver) */
                                "EnableCustomRegdomain", 4,

                                /* Board ID override hint (0xff = generic, we want device-specific) */
                                "BoardIdHint", 0x01,  // Non-0xFF to signal custom calibration

                                /* Vendor string for identification */
                                "Vendor", "Gigabyte",

                                /* Model string */
                                "Model", "X870E-AORUS-MASTER"
                            })
                        }
                    }
                }

                /*
                 * If UUID doesn't match or function not supported, return empty buffer
                 */
                Return (Buffer () { 0x00 })
            }

            /*
             * _STA: Status method
             * Returns device status: Present, Enabled, Functioning
             */
            Method (_STA, 0, NotSerialized)
            {
                Return (0x0F)  // Device present, enabled, shown in UI, functioning
            }
        }
    }
}
