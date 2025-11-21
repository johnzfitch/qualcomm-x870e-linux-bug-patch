# Emergency Rollback Procedures

**Last Updated**: 2025-11-21

---

## If System Won't Boot

### Option 1: Limine Snapshot (Easiest)

1. At Limine boot menu, select **Snapshots**
2. Choose a snapshot from before SSDT changes
3. System boots to previous working state

### Option 2: Boot and Rollback

If system boots but has issues:

```bash
# Remove SSDT from acpi_override directory
sudo rm /etc/initcpio/acpi_override/SSDT-WCN7850.aml

# Remove hook config (optional - keeps hook but no files to load)
sudo rm /etc/mkinitcpio.conf.d/zz-acpi-override.conf

# Rebuild UKI without SSDT
cat /proc/cmdline > /tmp/kernel-cmdline
sudo mkinitcpio --kernel $(uname -r) --uki /tmp/new_uki.efi --cmdline /tmp/kernel-cmdline
sudo cp /tmp/new_uki.efi /boot/EFI/Linux/omarchy_linux.efi

# Reboot
sudo reboot
```

### Option 3: Emergency Shell

If system boots to emergency shell:

```bash
# Mount boot partition if needed
mount /boot

# Remove SSDT
rm /etc/initcpio/acpi_override/SSDT-WCN7850.aml

# Remove hook config
rm /etc/mkinitcpio.conf.d/zz-acpi-override.conf

# Rebuild UKI
cat /proc/cmdline > /tmp/cmdline
mkinitcpio --kernel $(uname -r) --uki /tmp/uki.efi --cmdline /tmp/cmdline
cp /tmp/uki.efi /boot/EFI/Linux/omarchy_linux.efi

# Reboot
reboot
```

### Option 4: Live USB Recovery

If system won't boot at all:

```bash
# Boot from Arch live USB
# Mount your system
cryptsetup open /dev/nvme2n1p2 root
mount -o subvol=@ /dev/mapper/root /mnt
mount /dev/nvme2n1p1 /mnt/boot

# Remove SSDT config
rm /mnt/etc/initcpio/acpi_override/SSDT-WCN7850.aml
rm /mnt/etc/mkinitcpio.conf.d/zz-acpi-override.conf

# Chroot and rebuild
arch-chroot /mnt
cat /proc/cmdline > /tmp/cmdline  # or manually enter cmdline
mkinitcpio --kernel 6.17.8-arch1-1 --uki /tmp/uki.efi --cmdline /tmp/cmdline
cp /tmp/uki.efi /boot/EFI/Linux/omarchy_linux.efi
exit

# Unmount and reboot
umount -R /mnt
reboot
```

---

## What Was Changed

### Files Added
- `/etc/initcpio/acpi_override/SSDT-WCN7850.aml` (179 bytes)
- `/etc/mkinitcpio.conf.d/zz-acpi-override.conf` (hook config)

### Files Modified
- `/boot/EFI/Linux/omarchy_linux.efi` - UKI rebuilt with SSDT in early CPIO

### Files Removed (cleaned up)
- `/kernel/firmware/acpi/` - Old staging location (no longer used)

### Backups Available
- `acpi/SSDT-WCN7850-v1-backup.aml` - v1 SSDT
- Limine snapshots - Previous boot states

---

## Verify System Health After Rollback

```bash
# WiFi should work (at 1 dBm as before)
iw dev

# No boot errors
sudo journalctl -b | grep -i "error\|fail" | head -20

# Network connectivity
ping -c 3 8.8.8.8

# Check no SSDT loaded
sudo dmesg | grep -i "GBYTE.*WCN7850"
# Should return nothing if rollback successful
```

---

## Safe State

Even if SSDT doesn't work correctly:
- WiFi will continue working at current performance (~910 Mbps)
- System will boot normally
- SSDT is just a hint table - it doesn't break anything if ignored

The worst case is the driver continues showing `failed to get ACPI BDF EXT: 0` which is the current state anyway.

---

## Quick Reference

| Action | Command |
|--------|---------|
| Remove SSDT | `sudo rm /etc/initcpio/acpi_override/SSDT-WCN7850.aml` |
| Remove hook config | `sudo rm /etc/mkinitcpio.conf.d/zz-acpi-override.conf` |
| Rebuild UKI | `sudo mkinitcpio --kernel $(uname -r) --uki /tmp/uki.efi --cmdline /tmp/cmdline` |
| Install UKI | `sudo cp /tmp/uki.efi /boot/EFI/Linux/omarchy_linux.efi` |
