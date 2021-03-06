# Overview
An Arch Linux installation script that can be used to install and configure Arch Linux with my preferred setup.

Some major/noteworthy differences from common configurations:

- opendoas is used in place of sudo
- an AUR helper (paru) is included
- pipewire is used in place of pulseaudio
- EXT4 fast_commit mode is enabled by default
- many custom configurations and tweaks are made for power management
- makepkg is configured with better compression algorithms than the defaults and is forced to use all cores

# Usage
Upon loading up the official Arch installer and connecting to the internet, run:

```
curl https://raw.githubusercontent.com/rwinkhart/universal-arch-install-script/main/firstInstall.sh -o install.sh
chmod +x install.sh
./install.sh
```

After running the script, it will ask you some questions about your system configuration. Answer them and then the installation will complete automatically.

# Supported Devices
Generic:

- Most x86_64 desktops, laptops, and servers

Special Configuration:

- ASUS Zephyrus G14 (2020-2021), G15 (2021)
- Pine64 PinePhone (non-pro) (support WIP, not yet functional)
