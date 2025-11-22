# Emergency Rollback Procedures

**Last Updated**: 2025-11-21

---

## Quick Reference

| Issue | Fix |
|-------|-----|
| WiFi not working | Reinstall linux-firmware (see below) |
| Custom firmware causing issues | Remove pacman hook + reinstall firmware |
| SSDT causing boot issues | Remove from acpi_override directory |
| System won't boot | Use Limine snapshot |

---

## Rollback Custom Firmware (Primary Fix)

### Option 1: Reinstall Original Firmware

```bash
# Remove pacman hook first (prevents re-applying custom firmware)
sudo rm /etc/pacman.d/hooks/99-wcn7850-board-fix.hook

# Reinstall original firmware
sudo pacman -S linux-firmware

# Reboot
sudo reboot
```

### Option 2: Manual Firmware Restore

If you backed up the original:
```bash
# Restore backup
sudo cp /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst.bak \
        /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst

# Remove pacman hook
sudo rm /etc/pacman.d/hooks/99-wcn7850-board-fix.hook

# Reboot
sudo reboot
```

---

## Rollback SSDT (Historical - Secondary Fix)

The SSDT changes are safe but can be removed if needed:

### Remove SSDT

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

---

## If System Won't Boot

### Option 1: Limine Snapshot (Easiest)

1. At Limine boot menu, select **Snapshots**
2. Choose a snapshot from before changes
3. System boots to previous working state

### Option 2: Emergency Shell

If system boots to emergency shell:

```bash
# Mount boot partition if needed
mount /boot

# Remove custom firmware
rm /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst

# Reinstall will require network, so boot first with fallback
# The system should still boot without board-2.bin (driver uses defaults)

# Or if you have the original backed up:
cp /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst.bak \
   /usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst

# Reboot
reboot
```

### Option 3: Live USB Recovery

If system won't boot at all:

```bash
# Boot from Arch live USB
# Mount your system
cryptsetup open /dev/nvme2n1p2 root
mount -o subvol=@ /dev/mapper/root /mnt
mount /dev/nvme2n1p1 /mnt/boot

# Remove custom firmware
rm /mnt/usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst

# Remove pacman hook
rm /mnt/etc/pacman.d/hooks/99-wcn7850-board-fix.hook

# Remove SSDT config (if present)
rm /mnt/etc/initcpio/acpi_override/SSDT-WCN7850.aml
rm /mnt/etc/mkinitcpio.conf.d/zz-acpi-override.conf

# Chroot and reinstall firmware
arch-chroot /mnt
pacman -S linux-firmware

# Rebuild UKI
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

### Firmware Override (v4.0 - Current)

| File | Action | Purpose |
|------|--------|---------|
| `/usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst` | Modified | Custom firmware with e0fb entry |
| `/etc/pacman.d/hooks/99-wcn7850-board-fix.hook` | Added | Persistence across updates |
| `/usr/local/bin/wcn7850-board-fix.sh` | Added | Restore script |

### SSDT Files (v3.1 - Historical)

| File | Action | Purpose |
|------|--------|---------|
| `/etc/initcpio/acpi_override/SSDT-WCN7850.aml` | Added | ACPI override (179 bytes) |
| `/etc/mkinitcpio.conf.d/zz-acpi-override.conf` | Added | Hook config |
| `/boot/EFI/Linux/omarchy_linux.efi` | Modified | UKI rebuilt with SSDT |

### Backups Available

| Location | Contents |
|----------|----------|
| `/usr/lib/firmware/ath12k/WCN7850/hw2.0/board-2.bin.zst.bak` | Original firmware (if backed up) |
| `acpi/SSDT-WCN7850-v1-backup.aml` | v1 SSDT |
| Limine snapshots | Previous boot states |

---

## Verify System Health After Rollback

```bash
# WiFi should work (at 1 dBm as before)
iw dev

# Check driver loaded
lsmod | grep ath12k

# No boot errors
sudo journalctl -b | grep -i "error\|fail" | head -20

# Network connectivity
ping -c 3 8.8.8.8

# Check no custom firmware loaded (should see generic board_id 0xff)
sudo dmesg | grep -i "board_id"
```

---

## Safe States

### With Custom Firmware (v4.0)
- WiFi should work with proper calibration
- If it doesn't work, fallback to generic is automatic
- System will boot normally regardless

### With Original Firmware
- WiFi works at current performance (~910 Mbps)
- `board_id 0xff` (generic calibration)
- System is in original state

### Without board-2.bin at all
- WiFi may not work or use minimal defaults
- System will boot normally
- Driver will complain but not crash

The worst case is the driver continues showing `failed to get ACPI BDF EXT: 0` which is the original state anyway.

---

## Complete Cleanup

To remove all traces of this fix:

```bash
# Remove firmware hook
sudo rm /etc/pacman.d/hooks/99-wcn7850-board-fix.hook
sudo rm /usr/local/bin/wcn7850-board-fix.sh

# Reinstall original firmware
sudo pacman -S linux-firmware

# Remove SSDT files
sudo rm /etc/initcpio/acpi_override/SSDT-WCN7850.aml
sudo rm /etc/mkinitcpio.conf.d/zz-acpi-override.conf

# Rebuild UKI
cat /proc/cmdline > /tmp/cmdline
sudo mkinitcpio --kernel $(uname -r) --uki /tmp/new_uki.efi --cmdline /tmp/cmdline
sudo cp /tmp/new_uki.efi /boot/EFI/Linux/omarchy_linux.efi

# Reboot
sudo reboot
```

---

## Quick Command Reference

| Action | Command |
|--------|---------|
| Remove pacman hook | `sudo rm /etc/pacman.d/hooks/99-wcn7850-board-fix.hook` |
| Reinstall firmware | `sudo pacman -S linux-firmware` |
| Remove SSDT | `sudo rm /etc/initcpio/acpi_override/SSDT-WCN7850.aml` |
| Remove SSDT config | `sudo rm /etc/mkinitcpio.conf.d/zz-acpi-override.conf` |
| Rebuild UKI | `sudo mkinitcpio --kernel $(uname -r) --uki /tmp/uki.efi --cmdline /tmp/cmdline` |
| Install UKI | `sudo cp /tmp/uki.efi /boot/EFI/Linux/omarchy_linux.efi` |
