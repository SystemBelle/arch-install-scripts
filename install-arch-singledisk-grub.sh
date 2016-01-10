#!/bin/bash

# --> This script works, but I had to umount special filesystems, arch-chroot and run grub-install to fix grub setup

HOSTNAME='inspiron'

parted /dev/sda --script -- mklabel msdos
parted /dev/sda --script -- mkpart primary 1 -1
parted /dev/sda --script -- set 1 boot on

# Format file systems
mkfs.btrfs -f -L root /dev/sda1

# Mount file systems
mount -t btrfs /dev/sda1 /mnt

# Install system
pacman -Sy
pacman -S --noconfirm reflector
reflector --sort rate -c "United States" -n 10 --save /etc/pacman.d/mirrorlist
pacstrap /mnt base grub btrfs-progs

# Write /etc/fstab
cat << EOF > /mnt/etc/fstab
tmpfs        /tmp    tmpfs     nodev,nosuid                                   0 0
/dev/sda1    /       btrfs     rw,relatime,space_cache,subvolid=5,subvol=/    0 0
EOF

# Mount filesystems
mount -t proc proc /mnt/proc -o nosuid,noexec,nodev &&
mount -t sysfs sys /mnt/sys -o nosuid,noexec,nodev &&
mount -t devtmpfs udev /mnt/dev -o mode=0755,nosuid &&
mount -t devpts devpts /mnt/dev/pts -o mode=0620,gid=5,nosuid,noexec &&
mount -t tmpfs shm /mnt/dev/shm -o mode=1777,nosuid,nodev &&
mount -t tmpfs run /mnt/run -o nosuid,nodev,mode=0755 &&
mount -t tmpfs tmp /mnt/tmp -o mode=1777,strictatime,nodev,nosuid,size=100M

# Set host name
echo "$HOSTNAME" > /mnt/etc/hostname

# Link the time zone
ln -s /mnt/usr/share/zoneinfo/America/Los_Angeles /mnt/etc/localtime

# Set locales
echo 'LANG="en_US.UTF8"' > /mnt/etc/locale.conf
echo 'en_US ISO-8859-1' > /mnt/etc/locale.gen
echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen
echo 'KEYMAP=us' > /etc/vconsole.conf

# Generate locales
chroot /mnt locale-gen

# Generate Linux
sed -i '/^HOOKS/ s/\"$/ btrfs\"/' /etc/mkinitcpio.conf
chroot /mnt mkinitcpio -p linux

## Set up bootloader
chroot /mnt grub-install --recheck /dev/sda
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

