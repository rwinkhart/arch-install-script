# universal-arch-install-script
A universal-sh Arch Linux installation script that works on x86_64 desktops and is slowly expanding into aarch64 support.

The script includes the following modifications from a typical Arch Linux install:

- opendoas is subbed in for sudo
- pipewire+pipewire-pulse is subbed in for pulseaudio
- many custom configurations and tweaks are made for power management
- makepkg is configured with better compression algorithms and is forced to use all cores

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

- Most x86_64 Desktops and Laptops

Special Configuration:

- ASUS Zephyrus G14 (2020-2021), G15 (2021)
- Pine64 PinePhone (non-pro) (support WIP, not yet functional)
