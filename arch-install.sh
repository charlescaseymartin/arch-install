#!/bin/sh
# This uses archinstall and json configurations to install Arch linux with 13-wm

# Checks if drive argument is valid
[ -z "$1" ] && printf "Usage: Provide only the drive to install to (i.e /dev/sda, see lsblk)\n\n./archstrap.sh [DRIVE]\n\n" && exit
[ ! -b "$1" ] && printf "Drive $1 is not a valid block device.\n" && exit

printf "\nThis script will erase all data on $1.\nAre you certain? (y/n): " && read CERTAIN
[ "$CERTAIN" != "y" ] && printf "Abort." && exit

disk=$1
swap=${disk}1
boot=${disk}2
root=${disk}3

# Cleanup from previous runs.
[ -b "$swap" ] && swapoff $swap
umount -R /mnt

# Partition 1G for boot, 1G for swap, rest for root.
# Optimal alignment will change the exact size though!
parted -s $disk mklabel gpt
parted -sa optimal $disk mkpart primary linux-swap 0% 1G
parted -sa optimal $disk mkpart primary fat32 1G 2G
parted -sa optimal $disk mkpart primary ext4 2G 100%
parted -s $disk set 2 esp on

# Format the partitions.
mkfs.ext4 -F $root
mkfs.fat -F 32 $boot
mkswap $swap

# Mount the partitions.
mount $root /mnt
mount --mkdir $boot /mnt/boot
swapon $swap

# Setup Username and Password
set +xv
echo ""
read -p "Enter host name: " hostname
[ -z "$hostname" ] && echo "" && printf "Entered invalid host name!" && exit

read -s -p "Enter root user password: " rootpass
[ -z "$rootpass" ] && echo "" && printf "Entered invalid root user password!" && exit
echo ""

read -p "Enter username: " username
[ -z "$username" ] && echo "" && printf "Entered invalid username!" && exit

read -s -p "Enter user password: " userpass
[ -z "$userpass" ] && echo "" && printf "Entered invalid user password!" && exit
echo -e "\n"

# Packages, time sync and fstab.
timedatectl set-ntp true

pacstrap /mnt \
	linux-hardened linux-hardened-headers linux-firmware efibootmgr grub \
	networkmanager network-manager-applet networkmanager-openvpn ufw man pulseaudio \
	base base-devel xorg-server xorg-apps xorg-xinit i3-wm i3status lightdm \
	lightdm-slick-greeter zsh git neovim docker openvpn pavucontrol rofi tmux \
	firefox curl perl-anyevent-i3 ttf-bigblueterminal-nerd

genfstab -U /mnt > /mnt/etc/fstab

# Check if install is for Virtualbox machine
is_virtual="false"
[ ! -z "$2" ] && [ "$2" == "-v" ] && is_virtual="true"

# Configuring system.
arch-chroot /mnt sh -c \
	'
	set -xe;
	sed -i "s/^#en_US.UTF-8/en_US.UTF-8/g" /etc/locale.gen;
	
	echo "LANG=en_US.UTF-8" > /etc/locale.conf;
	locale-gen;
	ln -sf /usr/share/zoneinfo/Africa/Johannesburg /etc/localtime;
	hwclock --systohc;

	systemctl enable ufw.service;
	systemctl enable NetworkManager;
	systemctl enable lightdm.service;
	systemctl enable docker.service;

	sed -i "s/^#\s*\(%wheel\s\+ALL=(ALL:ALL)\s\+ALL\)/\1/" /etc/sudoers

	set +xe;
	echo "root:'$rootpass'" | chpasswd;
	useradd -m "'$username'"
	usermod -aG wheel,audio,video,storage,power,docker "'$username'"
	echo "'$username':'$userpass'" | chpasswd;

	set -xe;
	echo "'$hostname'" > /etc/hostname;
	echo "127.0.0.1	localhost.localdomain   localhost" >> /etc/hosts;
	echo "::1		localhost.localdomain   localhost" >> /etc/hosts;
	echo "127.0.0.1    '$hostname'.localdomain    '$hostname'" >> /etc/hosts;

	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB;
	grub-mkconfig -o /boot/grub/grub.cfg;

	sed -i \
		"s/#guest-session=/guest-session=lightdm-slick-greeter/" \
		/etc/lightdm/lightdm.conf

	cd /tmp
	sudo -u "'$username'" git clone https://aur.archlinux.org/yay.git;
	cd yay;
	sudo -u "'$username'" makepkg -si;
	cd;

	set +xe
	[ "'$is_virtual'" == "true" ] && \
		yay -S virtualbox-guest-utils --noconfirm && \
		systemctl enable vboxservice.service && \
		VBoxClient --clipboard && \
		VBoxClient --seamless;
	'

# Finalize. 
umount -R /mnt
swapoff $swap
printf "*--- Installation Complete! ---*"
