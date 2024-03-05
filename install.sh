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

archinstall --config ./config.json --creds ./creds.json

# Install configs and environment
pacman -S jq --noconfirm
user=$(jq -r '.["!users"][0].username' <<< cat ./creds.json)

arch-chroot /mnt sh -c '
        printf "Switching to user: '$user'\n";
        su - "'$user'";
        echo "'$HOME'"'

#arch-chroot /mnt sh -c '
#        printf "Switching to user: $user"
#        su "$user"
#        cd $HOME
#        systemctl enable ufw.service;
#        systemctl enable NetworkManager;
#        chsh -s $(which zsh);
#        curl https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh;
#        git clone https://github.com/charlescaseymartin/archlinux-moded-dotfiles.git;
#        cd ~/archlinux-moded-dotfiles;
#        sh install.sh -i'
# Checks if virtual machine argument is valid
#if [ "$2" == "-v" ]
#then
#        printf "\nConfiguring virtualbox environment..."
#        arch-chroot /mnt sh -c '
#                su "$user"
#                pacman -S virtualbox-guest-utils --noconfirm;
#                systemctl enable vboxservice.service;
#                systemctl start vboxservice.service;
#                VBoxClient --clipboard;
#                VBoxClient --seamless'
#fi

printf "*--- Installation Complete! ---*"
