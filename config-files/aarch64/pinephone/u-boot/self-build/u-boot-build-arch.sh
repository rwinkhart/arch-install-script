#!/bin/bash

# This script can be used to build your own U-boot image for the PinePhone
# Use this if you are uncomfortable relying on my pre-built image for any reason

# NOTE Currently, this script is validated only with Arch Linux (x86_64)

read -n 1 -r -p "Install build dependencies? (Arch Linux only) (y/N)" depends

if [ "$depends" == "y" ] || [ "$distro" == "Y" ]; then
    echo
    sudo rm -rf /opt/or1k-linux-musl-cross
    sudo pacman -Sy dtc swig bc aarch64-linux-gnu-gcc --needed --noconfirm
    wget https://musl.cc/or1k-linux-musl-cross.tgz
    tar zxvf or1k-linux-musl-cross.tgz
    sudo mv or1k-linux-musl-cross /opt/
    echo -e '\nDependencies installed. Please re-run the script and proceed.\n'
    exit 0
fi

# Run this script in your working directory

export PATH="$PATH:/opt/or1k-linux-musl-cross/bin/"

git clone https://github.com/crust-firmware/arm-trusted-firmware/
cd arm-trusted-firmware
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64
make PLAT=sun50i_a64 -j$(nproc) bl31
cd ..

git clone https://gitlab.com/pine64-org/u-boot.git
cd arm-trusted-firmware
cp build/sun50i_a64/release/bl31.bin ../u-boot/
cd ..

git clone https://github.com/crust-firmware/crust
cd crust
export CROSS_COMPILE=or1k-linux-musl-
make pinephone_defconfig
make -j$(nproc) scp
cp build/scp/scp.bin ../u-boot/
cd ..

cd u-boot/
git checkout crust
export CROSS_COMPILE=aarch64-linux-gnu-
export BL31=bl31.bin
export ARCH=arm64
export SCP=scp.bin
make distclean
make pinephone_defconfig
make all -j$(nproc)
mv u-boot-sunxi-with-spl.bin ../
echo -e  '\nDone!\n'
