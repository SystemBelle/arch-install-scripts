#!/bin/bash

# install-arch-vagrant_box-grub.sh

# Creates an Arch Linux Vagrant base box (for Virtualbox)

HOSTNAME=$1
COUNTRY='United States'
NAMESERVERS='10.144.15.1'

parted /dev/sda --script -- mklabel msdos
parted /dev/sda --script -- mkpart primary 1 4097
parted /dev/sda --script -- mkpart primary 4097 -1
parted /dev/sda --script -- set 2 boot on

# Format file systems
mkfs.btrfs -f -L root /dev/sda2

# Mount file systems
mount -t btrfs /dev/sda2 /mnt

# Set up swap partition
mkswap /dev/sda1

# Install system
pacman -Sy
pacman -S --noconfirm reflector
reflector --sort rate -c "$COUNTRY" -n 10 --save /etc/pacman.d/mirrorlist
pacstrap /mnt base grub btrfs-progs virtualbox-guest-utils-nox openssh sudo vim

# Write /etc/fstab
cat << EOF > /mnt/etc/fstab
tmpfs        /tmp    tmpfs    nodev,nosuid                                   0 0
/dev/sda1    none    swap     defaults                                       0 0
/dev/sda2    /       btrfs    rw,relatime,space_cache,subvolid=5,subvol=/    0 0
EOF

# Set host name
${HOSTNAME:=localhost}
echo "$HOSTNAME" > /mnt/etc/hostname

# Configure resolver
rm /mnt/etc/resolv.conf
for i in $NAMESERVERS; do
    echo -e "nameserver $i" >> /mnt/etc/resolv.conf
done

# Link the time zone
ln -s /mnt/usr/share/zoneinfo/America/Los_Angeles /mnt/etc/localtime

# Set locales
echo 'LANG="en_US.UTF8"' > /mnt/etc/locale.conf
echo 'en_US ISO-8859-1' > /mnt/etc/locale.gen
echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen
echo 'KEYMAP=us' > /mnt/etc/vconsole.conf

# Generate locales
chroot /mnt locale-gen

# Generate Linux
sed -i '/^HOOKS/ s/\"$/ btrfs\"/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -p linux

# Set up bootloader
arch-chroot /mnt grub-install --recheck /dev/sda
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Configure network interface
echo -e '[Match]\nName=enp0s3\n\n[Network]\nDHCP=ipv4' > /mnt/etc/systemd/network/enp0s3.network

# Enable services
chroot /mnt systemctl enable systemd-networkd
chroot /mnt systemctl enable systemd-timesyncd
chroot /mnt systemctl enable sshd

# Set root password
echo -e "vagrant\nvagrant" | chroot /mnt passwd

# Create Vagrant user
chroot /mnt /usr/bin/useradd -m vagrant
echo -e "vagrant\nvagrant" | chroot /mnt passwd vagrant
mkdir /mnt/home/vagrant/.ssh
/usr/bin/wget -O /mnt/home/vagrant/.ssh/authorized_keys http://git.io/vagrant-insecure-public-key
chroot /mnt chown -R vagrant. /home/vagrant/.ssh
chmod 0700 /mnt/home/vagrant/.ssh
chmod 0600 /mnt/home/vagrant/.ssh/authorized_keys
chroot /mnt gpasswd -a vagrant wheel
chroot /mnt gpasswd -a vagrant vboxsf

# Allow Vagrant user to use sudo
echo 'vagrant ALL=(ALL) NOPASSWD: ALL' >> /mnt/etc/sudoers

# Load Virtualbox modules
echo -e "vboxguest\nvboxsf\nvboxvideo" > /mnt/etc/modules-load.d/virtualbox.conf

