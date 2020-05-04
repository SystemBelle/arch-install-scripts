#!/bin/bash

# Install basic Arch Linux system on a single disk.

HOSTNAME='ada'
DISK_DEV='/dev/sda'
FILESYSTEM='btrfs'
LOCALE='LANG=en_US.UTF-8'
LOCALE_GEN='en_US.UTF-8 UTF-8'
CPU_MFG='intel' # `amd` or `intel`

set -ex


# Partition Disk
parted --script $DISK_DEV mklabel gpt

parted --script $DISK_DEV -a optimal mkpart primary fat32 1MiB 261MiB
parted --script $DISK_DEV set 1 esp on

parted --script $DISK_DEV -a optimal mkpart primary $FILESYSTEM 261MiB 20.5GiB
parted --script $DISK_DEV -a optimal mkpart primary $FILESYSTEM 20.5GiB 100%


# Format Disk
mkfs.fat -F32 -n ESP ${DISK_DEV}1
mkfs.${FILESYSTEM} -f -L arch-root ${DISK_DEV}2
mkfs.${FILESYSTEM} -f -L arch-home ${DISK_DEV}3


# Mount file systems
mount -t $FILESYSTEM ${DISK_DEV}2 /mnt

mkdir /mnt/efi /mnt/home

mount ${DISK_DEV}1 /mnt/efi
mount -t $FILESYSTEM ${DISK_DEV}3 /mnt/home


# Stuff
timedatectl set-ntp true


# Update the mirror list
pacman -Sy
pacman -S --noconfirm reflector
reflector --sort rate -c "United States" -n 10 --save /etc/pacman.d/mirrorlist


# Install system
pacstrap /mnt base linux-lts linux-firmware grub efibootmgr btrfs-progs ${CPU_MFG}-ucode


# Copy updated mirror list to installed system
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist


# Generate /etc/fstab
genfstab -L /mnt >> /mnt/etc/fstab


# Set Local Timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime


# Configure localization
echo "$LOCALE_GEN" > /etc/locale.gen
arch-chroot /mnt locale-gen

echo "$LOCALE" /etc/locale.conf


# Sync hardware clock to system clock
arch-chroot /mnt hwclock --systohc


# Set Hostname
echo "$HOSTNAME" > /mnt/etc/hostname


# Install GRUB Bootloader
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB_ARCH_LINUX
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
