#!/bin/bash
echo ----------------------------------------------------------------------------------------------
echo Randall\'s Universal-ish Interactive Arch+Plasma Installer
echo Last Updated March 08, 2022
echo Last Tested Date: March 07, 2022
echo Last Tested x86_64 ISO: March 01, 2022
echo Last Tested PinePhone Image: PENDING
echo ----------------------------------------------------------------------------------------------
echo This script assumes basic knowledge of the Arch Linux installation process.
echo -e Want to learn about the installation process\? The steps are documented in the script files!
echo ----------------------------------------------------------------------------------------------
echo You will be asked some questions before installation.
echo -e "----------------------------------------------------------------------------------------------\n"
read -n 1 -s -r -p 'Press any key to continue'

# Configuration Questions
echo -e '\n\nWhat type of device is this installation intended for?\nPlease input the number only.\n'
echo -e '1. Laptop \(plasma\)\n2. Desktop \(plasma\)\n3. Server \(headless\)\n'
echo Special Devices:
echo -e '\n4. ASUS ROG Zephyrus G14 2020/2021, G15 2021 \(plasma\)\n5. Pine64 PinePhone (non-pro) (phosh) - CURRENTLY NOT FUNCTIONAL, WIP\n'
read -n 1 -r -p "Formfactor: " formfactor

echo -e '\n\nWhat would you like your username to be?\n'
read -r -p "Username: " username

echo -e '\nWhat would you like your user password to be?\n'
read -r -p "User Password: " userpassword

echo -e '\nWhat would you like your root password to be?\n'
read -r -p "Root Password: " rootpassword

echo -e '\nAmerica:'&&ls /usr/share/zoneinfo/America
echo -e '\nWhat timezone are you in?'
echo -e 'e.g. "New_York" or "Aruba"\n'
read -r -p "Timezone: " timezone

if [ "$formfactor" -lt "4" ]; then
    echo -e '\nWhat type of CPU do you have?\nPlease input the number only.\n'
    echo -e '1. AMD\n2. Intel\n'
    read -n 1 -r -p "CPU: " cpu
fi

if [ "$formfactor" -lt "4" ]; then
    echo -e '\n\nWhat type of (primary) graphics do you have?\nOn laptops use iGPU, on desktops use preference\nPlease input the number only.\n'
    echo -e '1. AMD\n2. Intel\n3. Nvidia\n'
    read -n 1 -r -p "Primary Graphics: " gpu
fi

if [ "$gpu" == "2" ]; then
    echo -e '\nPlease select a VA-API driver (for hardware video acceleration).\nPlease input the number only.\n'
    echo -e '1. libva-intel-driver \(Intel iGPUs up to Coffee Lake\)\n2. intel-media-driver (Intel iGPUs/dGPUs newer than Coffe Lake)\n'
    read -n 1 -r -p "Primary Graphics: " intel_vaapi_driver
fi

if [ "$formfactor" == "1" ]; then
    echo -e '\nWhat type of (secondary\) graphics do you have?\nThis will be your dGPU, if one is available.\nPlease input the number only.\n'
    echo -e '1. AMD\n2. Intel\n3. Nvidia4. None\n'
    read -n 1 -r -p "Secondary Graphics: " gpu2
fi

if [ "$formfactor" -lt "4" ]; then
    echo -e '\n'&&fdisk -l&&echo -e '\nWhat disk are you installing to?'
    echo -e 'e.g. "/dev/sda" or "/dev/nvme0n1" or "/dev/mmcblk1"\n'
    read -r -p "Disk: " disk
fi

echo -e '\n'&&fdisk -l&&echo -e '\nHow much space should be allocated for SWAP?'
echo -e 'Enter in terms of GB, e.g. "2" or "6" (a value of "0" will disable SWAP)'
read -r -p "SWAP (default 4): " swap

echo -e '\n'&&fdisk -l&&echo -e '\nDo you want to do a clean install on the OS disk (deletes all pre-existing partitions on OS disk)?'
read -n 1 -r -p "(y/N) " wipe
wipe=$(echo "$wipe" | tr '[:upper:]' '[:lower:]')

# Config for G14
if [ "$formfactor" == "4" ]; then
    disk=/dev/nvme0n1;cpu=1;gpu=1;gpu2=3
fi

# Config for PinePhone
if [ "$formfactor" == "5" ]; then
    disk=/dev/mmcblk2;cpu=4;gpu=4;gpu2=4
fi

# De-bug Mode
if [ "$username" == "debug" ]; then
    disk=/dev/vda
fi

# Setting Correct Time for Access to SSL Servers
timedatectl set-ntp true
# Fetching Up-to-Date https Mirrorlist
if [ "$formfactor" -lt "5" ]; then
    reflector --verbose --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
fi

# Variable Manipulation (Applying "p" to describe partitions on nvme/mmc drives; other storage devices do not use this)
disk0=$disk
if [[ "$disk" == /dev/nvme0n* ]]; then
    disk="$disk"'p'
fi
if [[ "$disk" == /dev/mmcblk* ]]; then
    disk="$disk"'p'
fi

# Determine if running as UEFI or BIOS
if [ -d "/sys/firmware/efi" ]; then
    boot=2
else
    boot=1
fi

# GPT/UEFI Partitioning
if [ "$boot" == 2 ]; then
    if [ "$wipe" == y ]; then
        partitions=0
        echo "g
        n
        1

        +256M
        t
        1
        n
        3


        w
        " | fdisk "$disk0"
    else
        partitions=$(lsblk "$disk0" -o NAME | grep -o '.$' | tail -1)
        echo "n
        

        +256M
        t

        1
        n
        


        w
        " | fdisk "$disk0"
    fi

    # Disk Formatting
    mkfs.fat -F32 "$disk""$((1 + "$partitions"))"
    mkfs.ext4 -O fast_commit "$disk""$((2 + "$partitions"))"

    # Mounting Storage and EFI Partitions
    mount "$disk""$((2 + "$partitions"))" /mnt
    mkdir /mnt/{boot,etc}
    mkdir /mnt/boot/EFI
    mount "$disk""$((1 + "$partitions"))" /mnt/boot/EFI
fi

# MBR/BIOS Partitioning
if [ "$boot" == 1 ]; then
    if [ "$wipe" == y ]; then
        partitions=0
        echo "o
        n
        p
        2


        w
        " | fdisk "$disk0"
    else
        partitions=$(lsblk "$disk0" -o NAME | grep -o '.$' | tail -1)
        echo "n
        p
        


        w
        " | fdisk "$disk0"
    fi
    
    # Disk Formatting
    mkfs.ext4 -O fast_commit "$disk""$((1 + "$partitions"))"

    # Mounting Storage (no EFI partition, using DOS label)
    mount "$disk""$((1 + "$partitions"))" /mnt
    mkdir /mnt/etc
fi

# Create and mount SWAP file
if [ "$swap" != 0 ]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1M count="$swap"'G' status=progress
    chmod 600 /mnt/swapfile
    mkswap /swapfile
    swapon /swapfile
fi

# Generating fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Installing Base Packages (opendoas is subbed for sudo due to preference)
base_devel='autoconf automake binutils bison fakeroot file findutils flex gawk gcc gettext grep groff pigz pbzip2 libtool m4 make pacman patch pkgconf sed opendoas texinfo which'
if [ "$formfactor" -lt 3 ]; then
pacstrap /mnt base $base_devel pacman-contrib linux-firmware linux linux-headers git networkmanager dialog nano
fi
if [ "$formfactor" == 4 ]; then
pacstrap /mnt base $base_devel pacman-contrib linux-firmware linux linux-headers git networkmanager dialog nano
fi
if [ "$formfactor" == 5 ]; then
pacstrap /mnt base $base_devel pacman-contrib linux-firmware linux-megi linux-megi-headers git networkmanager dialog nano wget
fi
if [ "$formfactor" == 3 ]; then
pacstrap /mnt base $base_devel pacman-contrib linux-firmware linux-lts linux-lts-headers git networkmanager dialog nano
fi

# Exporting Variables (for Importing into Part 2)
mkdir /mnt/tempfiles
echo "$formfactor" > /mnt/tempfiles/formfactor
echo "$cpu" > /mnt/tempfiles/cpu
echo "$gpu" > /mnt/tempfiles/gpu
echo "$gpu2" > /mnt/tempfiles/gpu2
echo "$intel_vaapi_driver" > /mnt/tempfiles/intel_vaapi_driver
echo "$boot" > /mnt/tempfiles/boot
echo "$disk0" > /mnt/tempfiles/disk
echo "$username" > /mnt/tempfiles/username
echo "$userpassword" > /mnt/tempfiles/userpassword
echo "$rootpassword" > /mnt/tempfiles/rootpassword
echo "$timezone" > /mnt/tempfiles/timezone

# Download and Initiate Part 2
curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/universal/secondInstall.sh -o /mnt/secondInstall.sh
chmod +x /mnt/secondInstall.sh
arch-chroot /mnt ./secondInstall.sh
