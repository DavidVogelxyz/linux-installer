# linux-image-setup

The purpose of this project is to allow a user to install Linux from a live image environment, with as little user intervention as possible.

## Functionality

Currently, this project is confirmed to run successfully in the following live environments:

- Ubuntu (Desktop or Server)
- Arch Linux
- Artix Linux

Within those environments, the following Linux distributions can be installed:

- Debian (through Ubuntu, running `debootstrap`)
- Ubuntu
- Arch Linux
- Artix Linux

The project is able to install the following desktop environments to those distributions:

- none (`server`)
- DWM (the "dynamic window manager" by Suckless)
- GNOME
    - currently, only works on Debian and Ubuntu
        - on Ubuntu, installs Ubuntu's version of GNOME, instead of "Ubuntu + GNOME"
- KDE
    - currently, only works on Debian and Ubuntu
        - on Ubuntu, installs Kubuntu, instead of "Ubuntu + KDE"

The project also allows the user a choice of web browser:

- Debian machines can choose between `brave-browser` and `firefox-esr`.
- Ubuntu machines only have `brave-browser`, due to Firefox being installed as a snap package.
- Arch and Artix DWM machines will install LibreWolf by default.

The project can handle both BIOS and UEFI firmware, can encrypt the rootfs, and can create swap partitions based off the machine's total RAM.

## Future plans

Future goals include the following:

- Enable Arch and Artix machines to install GNOME and KDE.
- Enable Arch and Artix machines to install `brave-bin` from the AUR.
- Enable Arch and Artix machines to install `firefox`.
- Enable support for Alpine Linux.
- Enable support for Rocky Linux; potentially, Oracle Linux too (though, unlikely).
    - Rocky:
        - First priority is `server`, then GNOME.
        - KDE and DWM are lower priority.
- Enable support for other desktop environments, including:
    - Xfce
    - Cinnamon
- Enable support for distributions that use `America/*` for the timezone, instead of `US/*`.
    - Distributions include Ubuntu and Rocky.
