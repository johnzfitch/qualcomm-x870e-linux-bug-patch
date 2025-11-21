# Installation Guide - WCN7850 ACPI Override

**System**: Arch Linux with Limine bootloader (UKI)
**Last Updated**: 2025-11-21

---

## Prerequisites

- ACPI compiler: `sudo pacman -S acpica`
- Root access for system modifications

---

## Quick Install (Current State)

SSDT v3 is already installed. Just reboot:

```bash
sudo reboot
```

---

## Full Installation Steps

### Step 1: Compile SSDT (if needed)

```bash
cd ~/dev/qualcomm-x870e-linux-bug-patch/acpi

# Compile v3 source
iasl -tc SSDT-WCN7850-v3.dsl

# Output: SSDT-WCN7850.aml (179 bytes)
```

### Step 2: Install SSDT to acpi_override directory

The `acpi_override` hook reads from `/etc/initcpio/acpi_override/`:

```bash
# Create directory for ACPI override hook
sudo mkdir -p /etc/initcpio/acpi_override

# Copy compiled SSDT
sudo cp acpi/SSDT-WCN7850.aml /etc/initcpio/acpi_override/

# Verify
ls -la /etc/initcpio/acpi_override/
```

### Step 3: Configure mkinitcpio Hook

Create a drop-in config to add the `acpi_override` hook:

```bash
sudo tee /etc/mkinitcpio.conf.d/zz-acpi-override.conf << 'EOF'
# WCN7850 WiFi ACPI board data fix - DO NOT DELETE
# This adds acpi_override hook for early SSDT loading
# The hook loads SSDTs from /etc/initcpio/acpi_override/
HOOKS+=(acpi_override)
EOF
```

**Why `zz-` prefix?** Ensures this loads after other configs (like omarchy_hooks.conf) so `HOOKS+=()` appends correctly.

**Why not FILES directive?** The `FILES=()` directive puts files in the main compressed image. ACPI table upgrade requires files in an **uncompressed early CPIO**, which only the `acpi_override` hook provides via `add_file_early`.

### Step 4: Rebuild UKI

```bash
# Get current kernel cmdline
cat /proc/cmdline > /tmp/kernel-cmdline

# Build new UKI
sudo mkinitcpio --kernel $(uname -r) --uki /tmp/new_uki.efi --cmdline /tmp/kernel-cmdline

# Verify acpi_override hook ran
# Should see: "Running build hook: [acpi_override]"
# Should see: "Early uncompressed CPIO image generation successful"
```

### Step 5: Verify SSDT in UKI

```bash
# Check SSDT is in the initramfs
sudo lsinitcpio /tmp/new_uki.efi | grep -i acpi
# Should show: kernel/firmware/acpi/SSDT-WCN7850.aml

# Check encrypt hook is present (CRITICAL for encrypted systems)
sudo lsinitcpio /tmp/new_uki.efi | grep -q "hooks/encrypt" && echo "OK" || echo "FAIL"
```

### Step 6: Install UKI

```bash
sudo cp /tmp/new_uki.efi /boot/EFI/Linux/omarchy_linux.efi
sudo chmod 755 /boot/EFI/Linux/omarchy_linux.efi
```

### Step 7: Reboot

```bash
sudo reboot
```

---

## Post-Reboot Verification

```bash
cd ~/dev/qualcomm-x870e-linux-bug-patch

# Check SSDT loaded at early boot (should see ACPI: SSDT ... GBYTE WCN7850)
sudo dmesg | grep -i "ACPI.*SSDT\|GBYTE.*WCN7850"

# Check ACPI BDF status
sudo dmesg | grep -i "ACPI BDF\|board_id"

# Check WiFi interface
iw dev

# Scan for networks
sudo iw dev wlan1 scan | grep -E "^BSS|SSID:" | head -20
```

### Expected Success

```
ACPI: SSDT ... GBYTE WCN7850 ...
ath12k_pci: ACPI BDF variant: QC_5mm
ath12k_pci: board_id 0x?? (non-0xff)
```

### Expected Failure (requires kernel patch)

```
ACPI: SSDT ... GBYTE WCN7850 ...  (SSDT loads)
ath12k_pci: failed to get ACPI BDF EXT: 0  (driver can't read it)
ath12k_pci: board_id 0xff  (still generic)
```

---

## Bootloader Notes

### Limine (This System)

Limine uses UKI (Unified Kernel Image) which bundles:
- Kernel
- Initramfs (with ACPI tables in early CPIO)
- Microcode

No bootloader parameter changes needed - ACPI tables are embedded in initramfs.

Config location: `/boot/limine.conf`

### systemd-boot (Other Systems)

If using systemd-boot with UKI, same process applies - the ACPI override is embedded in the UKI.

### GRUB (Other Systems)

For GRUB with separate initramfs, ensure initramfs contains the early CPIO with ACPI tables.

---

## Rollback

### Remove SSDT

```bash
# Remove from hook directory
sudo rm /etc/initcpio/acpi_override/SSDT-WCN7850.aml

# Optionally remove hook config
sudo rm /etc/mkinitcpio.conf.d/zz-acpi-override.conf

# Rebuild UKI without SSDT
cat /proc/cmdline > /tmp/kernel-cmdline
sudo mkinitcpio --kernel $(uname -r) --uki /tmp/new_uki.efi --cmdline /tmp/kernel-cmdline
sudo cp /tmp/new_uki.efi /boot/EFI/Linux/omarchy_linux.efi

# Reboot
sudo reboot
```

---

## File Locations

| File | Location |
|------|----------|
| SSDT Source (v3) | `acpi/SSDT-WCN7850-v3.dsl` |
| SSDT Compiled | `acpi/SSDT-WCN7850.aml` |
| System SSDT | `/etc/initcpio/acpi_override/SSDT-WCN7850.aml` |
| Hook Config | `/etc/mkinitcpio.conf.d/zz-acpi-override.conf` |
| UKI | `/boot/EFI/Linux/omarchy_linux.efi` |
| Bootloader Config | `/boot/limine.conf` |

---

## Troubleshooting

### SSDT not in initramfs

```bash
# Check hook config exists
cat /etc/mkinitcpio.conf.d/zz-acpi-override.conf

# Check SSDT file exists
ls -la /etc/initcpio/acpi_override/

# Rebuild and watch for "Running build hook: [acpi_override]"
sudo mkinitcpio --kernel $(uname -r) --uki /tmp/test.efi --cmdline /tmp/kernel-cmdline 2>&1 | grep acpi
```

### SSDT loads but driver ignores it

The driver may need a kernel patch to read _DSM from the ACPI device.
See `docs/wifi-7-plan.txt` for kernel patching details.

### WiFi not working after reboot

Boot from Limine snapshot or follow rollback steps above.

### acpi_override hook not found

Install mkinitcpio (it's a built-in hook):
```bash
pacman -S mkinitcpio
```
