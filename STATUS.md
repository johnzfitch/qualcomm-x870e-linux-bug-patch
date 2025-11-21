# Current Status

**Last Updated**: 2025-11-21 14:10 PST
**SSDT Version**: v3 (pending reboot test)
**WiFi Status**: Operational at ~910 Mbps (board_id 0xff, limited TX power)

---

## Current State Summary

| Component | Status | Notes |
|-----------|--------|-------|
| WiFi Hardware | Working | WCN7850 hw2.0 operational |
| WiFi Performance | ~910 Mbps | Despite board_id 0xff limitation |
| SSDT v3 | Ready | Installed via acpi_override hook |
| board_id | 0xff | Generic fallback (root cause) |
| ACPI BDF EXT | Failing | `failed to get ACPI BDF EXT: 0` |

---

## SSDT Version History

| Version | Path Used | Status | Issue |
|---------|-----------|--------|-------|
| v1 | `\_SB.PCI0.WCN7` | Failed | Wrong UUID, wrong function, wrong format |
| v2 | `\_SB.PCI0.WCN7` | Failed | Correct UUID/format, but wrong device path |
| **v3** | `\_SB.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00` | **Pending** | Correct path from firmware_node |

### Key Discovery (v3)
The actual ACPI path for the WiFi device was found via:
```bash
cat /sys/bus/pci/devices/0000:0d:00.0/firmware_node/path
# Output: \_SB_.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00
```

The WiFi card is behind USB4/PCIe bridges, not directly under PCI0.

---

## System Configuration

### Bootloader
- **Type**: Limine (UKI-based)
- **UKI Location**: `/boot/EFI/Linux/omarchy_linux.efi`
- **Config**: `/boot/limine.conf`

### ACPI Override Method
- **Hook**: `acpi_override` (mkinitcpio hook)
- **Hook Config**: `/etc/mkinitcpio.conf.d/zz-acpi-override.conf`
- **SSDT Location**: `/etc/initcpio/acpi_override/SSDT-WCN7850.aml`
- **Size**: 179 bytes (v3)

The `acpi_override` hook uses `add_file_early` to place SSDTs in the **early uncompressed CPIO**, which is required for kernel ACPI table upgrade at boot.

### Why acpi_override Hook (Not FILES Directive)
The `FILES=()` directive in mkinitcpio.conf places files in the main compressed image, but ACPI table upgrade requires files in an **uncompressed early CPIO**. The `acpi_override` hook handles this correctly.

### Network
- **Ethernet**: Atlantic 10GbE (enp16s0) - 10Gbps link
- **WiFi**: Qualcomm WCN7850 (wlan1) - Currently active
- **ISP**: Sonic Fiber

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
├── acpi/
│   ├── SSDT-WCN7850.aml         # Current compiled SSDT (v3, 179 bytes)
│   ├── SSDT-WCN7850.dsl         # Original v1 source
│   ├── SSDT-WCN7850-v2.dsl      # v2 source (correct UUID)
│   ├── SSDT-WCN7850-v3.dsl      # v3 source (correct path) <- CURRENT
│   └── SSDT-WCN7850-v1-backup.aml
│
├── docs/
│   └── wifi-7-plan.txt          # Original investigation log
│
└── archive/                     # Historical files
    ├── FINAL-PRE-REBOOT-STATUS.txt
    ├── FINAL-PRE-REBOOT-STATUS-V2.txt
    └── SSDT-V2-CHANGES.md

System Files:
├── /etc/initcpio/acpi_override/SSDT-WCN7850.aml  # Installed SSDT
├── /etc/mkinitcpio.conf.d/zz-acpi-override.conf  # Hook config
└── /boot/EFI/Linux/omarchy_linux.efi             # UKI with SSDT
```

---

## Next Steps

### Immediate: Reboot to Test SSDT v3
```bash
sudo reboot
```

### After Reboot: Verify
```bash
# Check if SSDT loaded at early boot
sudo dmesg | grep -i "ACPI.*SSDT\|GBYTE.*WCN7850"

# Check ACPI BDF status
sudo dmesg | grep -i "ACPI BDF\|board_id"

# Check WiFi interface
iw dev

# Scan for networks
sudo iw dev wlan1 scan | grep -E "^BSS|SSID:" | head -20
```

### Expected Outcomes

**If v3 works:**
- No "failed to get ACPI BDF EXT" message
- board_id may change from 0xff
- Can detect neighbor networks
- TX power increases to 24 dBm

**If v3 still fails:**
- Driver may need kernel patch to read _DSM from the ACPI device
- Or the device path association isn't happening at boot

---

## Rollback

If issues occur after reboot:
```bash
# Remove SSDT from hook directory
sudo rm /etc/initcpio/acpi_override/SSDT-WCN7850.aml

# Remove hook config (optional)
sudo rm /etc/mkinitcpio.conf.d/zz-acpi-override.conf

# Rebuild UKI
sudo mkinitcpio --kernel $(uname -r) --uki /tmp/uki.efi --cmdline /proc/cmdline
sudo cp /tmp/uki.efi /boot/EFI/Linux/omarchy_linux.efi

# Reboot
sudo reboot
```

---

## Technical References

- **ACPI Device Path**: `\_SB.PCI0.GPP7.UP00.DP40.UP00.DP10.WN00`
- **PCI Location**: `0000:0d:00.0`
- **WCN7850 UUID**: `f634f534-6147-11ec-90d6-0242ac120003`
- **Kernel**: 6.17.8-arch1-1
- **Driver**: ath12k (in-tree)
