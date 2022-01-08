#!/bin/bash

# Importing Variables
formfactor="$(cat /tempfiles/formfactor)"
cpu="$(cat /tempfiles/cpu)"
gpu="$(cat /tempfiles/gpu)"
gpu2="$(cat /tempfiles/gpu2)"
intel_vaapi_driver="$(cat /tempfiles/intel_vaapi_driver)"
boot="$(cat /tempfiles/boot)"
disk="$(cat /tempfiles/disk)"
username="$(cat /tempfiles/username)"
userpassword="$(cat /tempfiles/userpassword)"
rootpassword="$(cat /tempfiles/rootpassword)"
timezone="$(cat /tempfiles/timezone)"

# Configuring Locale and Clock Settings
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
ln -s /usr/share/zoneinfo/America/"$timezone" /etc/localtime
locale-gen
hwclock --systohc --utc

# Enabling NetworkManager to Start on Boot
systemctl enable NetworkManager

# Checking TRIM Support, Discarding, and Enabling Automatic Discarding
trimcheck=$(lsblk --discard | awk '{print $3;}')
case "$trimcheck" in
    *512B* ) trimcheck=1;;
esac
if [ "$trimcheck" == 1 ]; then
    fstrim -vA
    systemctl enable fstrim.timer
fi

# makepkg Configuration
curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/makepkg.conf -o /etc/makepkg.conf

# GRUB Bootloader Installation and Configuration
pacman -S grub efibootmgr os-prober mtools dosfstools --noconfirm
if [ "$boot" == 2 ]; then
    grub-install --target=x86_64-efi --bootloader-id=GRUB --recheck
fi
if [ "$boot" == 1 ]; then
    grub-install --target=i386-pc "$disk"
fi
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
if [ "$gpu" != 3 ]; then
    if [ "$gpu2" != 3 ]; then
        curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/grub -o /etc/default/grub
    fi
fi
if [ "$gpu" == 3 ]; then
    curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/grub-nvidia -o /etc/default/grub
    if [ "$formfactor" != 3 ]; then
        curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/nvidia-hook -o /etc/pacman.d/hooks/nvidia.hook
    else
        curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/nvidia-hook-lts -o /etc/pacman.d/hooks/nvidia.hook
    fi
fi
if [ "$gpu2" == 3 ]; then
    curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/grub-nvidia -o /etc/default/grub
    if [ "$formfactor" != 3 ]; then
        curl curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/nvidia-hook -o /etc/pacman.d/hooks/nvidia.hook
    else
        curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/nvidia-hook-lts -o /etc/pacman.d/hooks/nvidia.hook
    fi
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Account Setup
groupadd classmod
echo "$rootpassword
$rootpassword
" | passwd
useradd -m -g users -G classmod "$username"
echo "$userpassword
$userpassword
" | passwd "$username"

# Initial opendoas Configuration
echo "permit nopass $username" > /etc/doas.conf
ln -s /usr/bin/doas /usr/bin/sudo

# Installing AUR helper and various AUR packages

# Navigate to Package Building Directory
mkdir /home/"$username"/.cuaninstaller
mkdir /home/"$username"/.cuaninstaller/aurpackages
chown -R "$username" /home/"$username"/.cuaninstaller

# AUR Helper Installation
su -c "git clone https://aur.archlinux.org/paru-bin.git ~/.cuaninstaller/aurpackages/paru-bin" "$username"
su -c "cd ~/.cuaninstaller/aurpackages/paru-bin && makepkg -si --noconfirm" "$username"
cd ..
curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/paru.conf -o /etc/paru.conf
if [ "$formfactor" -lt 4 ]; then
    curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/pacman.conf -o /etc/pacman.conf
    pacman -Sy
fi

# Special Device Package Installation and Configuration
# Zephyrus G14
mkdir /home/"$username"/.cuaninstaller/scripts
if [ "$formfactor" == 4 ]; then
    curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/config-files/x86_64/pacman.conf-g14 -o /etc/pacman.conf
    pacman -Sy supergfxctl asusctl --noconfirm
    systemctl enable --now supergfxd
    systemctl start asusd
    su -c "asusctl -c 80" "$username"
    su -c "systemctl --user enable --now asus-notify.service" "$username"
    # Graphics Switching Scripts
    echo '#!/bin/bash
    supergfxctl -m integrated
    pkill -KILL -u '"$username"'' > /home/"$username"/.cuaninstaller/scripts/graphics-integrated.sh
    echo '#!/bin/bash
    supergfxctl -m nvidia
    pkill -KILL -u '"$username"'' > /home/"$username"/.cuaninstaller/scripts/graphics-dedicated.sh
    chmod +x /home/"$username"/.cuaninstaller/scripts/graphics-integrated.sh /home/"$username"/.cuaninstaller/scripts/graphics-dedicated.sh
    su -c "supergfxctl -m integrated" "$username"
fi
cd /

# Writing CPU Governor Scripts
echo '#!/bin/bash
cpupower frequency-set -g performance
# announce gov settings
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor' > /home/"$username"/.cuaninstaller/scripts/performance.sh
echo '#!/bin/bash
cpupower frequency-set -g powersave
# announce gov settings
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor' > /home/"$username"/.cuaninstaller/scripts/powersave.sh
echo '#!/bin/bash
cpupower frequency-set -g schedutil
# announce gov settings
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor' > /home/"$username"/.cuaninstaller/scripts/schedutil.sh
chmod +x /home/"$username"/.cuaninstaller/scripts/performance.sh /home/"$username"/.cuaninstaller/scripts/powersave.sh /home/"$username"/.cuaninstaller/scripts/ondemand.sh /home/"$username"/.cuaninstaller/scripts/schedutil.sh

# kwin autostart rules
if [ "$formfactor" -lt 3 ]; then
    su -c "mkdir -p /home/"$username"/.config/autostart" "$username"
    su -c "echo '[Desktop Entry]
    Categories=Qt;KDE;System;TerminalEmulator;
    Comment=A drop-down terminal emulator based on KDE Konsole technology.
    Exec=yakuake
    GenericName=Drop-down Terminal
    Icon=yakuake
    Name=Yakuake
    Terminal=false
    Type=Application
    X-DBUS-ServiceName=org.kde.yakuake
    X-DBUS-StartupType=Unique
    X-KDE-StartupNotify=false ' > /home/"$username"/.config/autostart/org.kde.yakuake.desktop" "$username"
    chmod 644 /home/"$username"/.config/autostart/org.kde.yakuake.desktop
fi
if [ "$formfactor" == 4 ]; then
    su -c "mkdir -p /home/"$username"/.config/autostart" "$username"
    su -c "echo '[Desktop Entry]
    Categories=Qt;KDE;System;TerminalEmulator;
    Comment=A drop-down terminal emulator based on KDE Konsole technology.
    Exec=yakuake
    GenericName=Drop-down Terminal
    Icon=yakuake
    Name=Yakuake
    Terminal=false
    Type=Application
    X-DBUS-ServiceName=org.kde.yakuake
    X-DBUS-StartupType=Unique
    X-KDE-StartupNotify=false ' > /home/"$username"/.config/autostart/org.kde.yakuake.desktop" "$username"
    su -c "echo '[Desktop Entry]
    Exec=xbindkeys
    Icon=
    Name=xbindkeys
    Path=
    Terminal=False
    Type=Application ' > /home/"$username"/.config/autostart/xbindkeys.desktop" "$username"
    chmod 644 /home/"$username"/.config/autostart/org.kde.yakuake.desktop /home/"$username"/.config/autostart/xbindkeys.desktop
fi

# Final opendoas Configuration
echo "permit persist keepenv $username as root" > /etc/doas.conf

# Installing Hardware-Specific Packages
if [ "$cpu" == 1 ]; then
    pacman -S amd-ucode --noconfirm
fi
if [ "$cpu" == 2 ]; then
    pacman -S intel-ucode --noconfirm
fi
if [ "$gpu" == 1 ]; then
    pacman -S mesa vulkan-icd-loader vulkan-radeon libva-mesa-driver libva-utils --needed --noconfirm
fi
if [ "$gpu" == 2 ]; then
    pacman -S mesa vulkan-icd-loader vulkan-intel --needed --noconfirm
    if [ "$intel_vaapi_driver" == 1 ]; then
        pacman -S libva-intel-driver libva-utils --needed --noconfirm
    fi
    if [ "$intel_vaapi_driver" == 2 ]; then
        pacman -S intel-media-driver libva-utils --needed --noconfirm
    fi
fi
if [ "$gpu" == 3 ]; then
    if [ "$formfactor" -lt 3 ]; then
        pacman -S nvidia nvidia-utils nvidia-settings vulkan-icd-loader --needed --noconfirm
    fi
    if [ "$formfactor" == 3 ]; then
        pacman -S nvidia-lts nvidia-utils nvidia-settings vulkan-icd-loader --needed --noconfirm
    fi
    echo 'options nvidia "NVreg_DynamicPowerManagement=0x02"' > /etc/modprobe.d/nvidia.conf
    echo 'options nvidia-drm modeset=1' > /etc/modprobe.d/zz-nvidia-modeset.conf
fi
if [ "$gpu2" == 3 ]; then
    pacman -S nvidia nvidia-utils nvidia-settings nvidia-prime --needed --noconfirm
    echo 'options nvidia "NVreg_DynamicPowerManagement=0x02"' > /etc/modprobe.d/nvidia.conf
    echo 'options nvidia-drm modeset=1' > /etc/modprobe.d/zz-nvidia-modeset.conf
fi

# Disable kernel watchdog
echo 'kernel.nmi_watchdog = 0' > /etc/sysctl.d/disable_watchdog.conf
echo 'blacklist iTCO_wdt' > /etc/modprobe.d/blacklist.conf

if [ "$formfactor" == 1 ]; then
    pacman -R xorg-xbacklight --noconfirm
    pacman -S powertop acpid acpilight xbindkeys --needed --noconfirm
    systemctl enable acpid
    echo 'vm.dirty_writeback_centisecs = 6000' > /etc/sysctl.d/dirty.conf
    echo 'SUBSYSTEM=="backlight", ACTION=="add", \
        RUN+="/bin/chgrp classmod /sys/class/backlight/%k/brightness", \
        RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
    ' > /etc/udev/rules.d/screenbacklight.rules
fi
if [ "$formfactor" == 4 ]; then
    pacman -R xorg-xbacklight --noconfirm
    pacman -S powertop acpid acpilight xbindkeys --needed --noconfirm
    systemctl enable acpid
    echo 'options snd_hda_intel power_save=1' > /etc/modprobe.d/audio_powersave.conf
    echo 'vm.dirty_writeback_centisecs = 6000' > /etc/sysctl.d/dirty.conf
    echo 'SUBSYSTEM=="backlight", ACTION=="add", \
        RUN+="/bin/chgrp classmod /sys/class/backlight/%k/brightness", \
        RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
    ' > /etc/udev/rules.d/screenbacklight.rules
    echo 'RUN+="/bin/chgrp classmod /sys/class/leds/asus::kbd_backlight/brightness"
    RUN+="/bin/chmod g+w /sys/class/leds/asus::kbd_backlight/brightness"
    ' > /etc/udev/rules.d/asuskbdbacklight.rules
    echo '# Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
    ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

    # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
    ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
    ' > /etc/udev/rules.d/90-asusd-nvidia-pm.rules
    # xbindkeys config
    echo '#ScreenBrightUp
    "xbacklight -inc 10"
        m:0x0 + c:210
        XF86Launch3
    #ScreenBrightDown
    "xbacklight -dec 10"
        m:0x0 + c:157
        XF86Launch2
    #G14KeyBrightUp
    "xbacklight -ctrl asus::kbd_backlight -inc 30"
        m:0x0 + c:238
        XF86KbdBrightnessUp
    #G14KeyBrightDown
    "xbacklight -ctrl asus::kbd_backlight -dec 30"
        m:0x0 + c:237
        XF86KbdBrightnessDown
    #G14FanProfile
    "asusctl profile -n"
        m:0x0 + c:156
        XF86Launch1
    #G14IntegratedGPU
    "/home/'"$username"'/.cuaninstaller/scripts/graphics-integrated.sh"
        m:0x0 + c:232
        XF86MonBrightnessDown
    #G14DedicatedGPU
    "/home/'"$username"'/.cuaninstaller/scripts/graphics-dedicated.sh"
        m:0x0 + c:233
        XF86MonBrightnessUp' > /home/"$username"/.xbindkeysrc
fi

# Setting Home Directory Permissions
if [ "$formfactor" -lt 3 ]; then
    chmod -R 755 /home
fi
if [ "$formfactor" == 4 ]; then
    chmod -R 755 /home
fi
if [ "$formfactor" == 3 ]; then
    chmod -R 700 /home
fi

# Installing KDE Plasma 5 and Addons + Utilities
if [ "$formfactor" -lt 3 ]; then
    pacman -S pipewire pipewire-pulse plasma-desktop sddm sddm-kcm kscreen kdeplasma-addons spectacle gwenview plasma-nm plasma-pa breeze-gtk kde-gtk-config kio-extras khotkeys kwalletmanager pcmanfm-qt yakuake ark kate bluedevil bluez --needed --noconfirm
    systemctl enable sddm
fi
if [ "$formfactor" == 4 ]; then
    pacman -S pipewire pipewire-pulse plasma-desktop sddm sddm-kcm kscreen kdeplasma-addons spectacle gwenview plasma-nm plasma-pa breeze-gtk kde-gtk-config kio-extras khotkeys kwalletmanager pcmanfm-qt yakuake ark kate bluedevil bluez --needed --noconfirm
    systemctl enable bluetooth
    systemctl enable sddm
fi

# Installing and Configuring Basic Software Packages
if [ "$formfactor" == 3 ]; then
    pacman -S openssh --needed --noconfirm
    mkdir /home/"$username"/.ssh
    touch /home/"$username"/.ssh/authorized_keys
    chmod 700 /home/"$username"/.ssh
    chmod 600 /home/"$username"/.ssh/authorized_keys
    chown -R "$username" /home/"$username"/.ssh
fi
mkdir -p /home/"$username"/.gnupg
echo 'pinentry-program /usr/bin/pinentry-tty' > /home/"$username"/.gnupg/gpg-agent.conf  # forces gpg prompts to use terminal input
pacman -S neofetch htop cpupower openvpn openresolv --needed --noconfirm
curl https://raw.githubusercontent.com/alfredopalhares/openvpn-update-resolv-conf/master/update-resolv-conf.sh -o /etc/openvpn/update-resolv-conf
chmod +x /etc/openvpn/update-resolv-conf

# Saving Copy of Current Install Script for Future Reference
mkdir /home/"$username"/.cuaninstaller/installerbackup
cp /etc/openvpn/update-resolv-conf /home/"$username"/.cuaninstaller/installerbackup/update-resolv-conf
cp /etc/pacman.conf /home/"$username"/.cuaninstaller/installerbackup/pacman.conf
cp /etc/paru.conf /home/"$username"/.cuaninstaller/installerbackup/paru.conf
cp /etc/default/grub /home/"$username"/.cuaninstaller/installerbackup/grub
cp /etc/makepkg.conf /home/"$username"/.cuaninstaller/installerbackup/makepkg.conf
cp /secondInstall.sh /home/"$username"/.cuaninstaller/installerbackup/secondInstall.sh
curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/firstInstall.sh -o /home/"$username"/.cuaninstaller/installerbackup/firstInstall.sh

# Finishing Up + Cleaning
hostnamectl hostname archlinux
rm -rf /secondInstall.sh /tempfiles
echo -e "\n---------------------------------------------------------"
echo Installation completed!
echo All installer files are backed up in ~/.cuaninstaller
echo Please poweroff and remove the installation media before powering back on.
echo -e "---------------------------------------------------------\n"
exit
