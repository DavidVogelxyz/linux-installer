# linux-installer

The purpose of this project is to enable a user to install Linux from a live image environment, with as little user input as possible.

## Table of contents

- [Summary](#linux-installer)
- [Features](#features)
    - [Supported distributions](#supported-distributions)
    - [Supported graphical environments](#supported-graphical-environments)
    - [Supported web browsers](#supported-web-browsers)
- [Instructions](#instructions)
- [Known issues](#known-issues)
- [Future plans](#future-plans)

## Features

The following sections will detail the supported [Linux distributions](#supported-distributions), [graphical environments](#supported-graphical-environments), and [web browsers](#supported-web-browsers).

### Supported distributions

`linux-installer` is able to install a handful of distributions (distros) through the command line. The following table outlines which distributions can be installed, which release version will be installed, and which live image environment to use.

| Distribution | Release version | Live image                           |
| ---          | ---             | ---                                  |
| Arch         | rolling release | Arch Linux                           |
| Artix        | rolling release | Artix Linux                          |
| Debian       | Bookworm (12)   | Ubuntu Noble LTS (Server or Desktop) |
| Rocky        | 9               | Rocky Linux (Workstation)            |
| Ubuntu       | Noble (24)      | Ubuntu Noble LTS (Server or Desktop) |

Some notes on distributions:

- Debian:
    - While `linux-installer` should work fine on a Debian live image, it has not yet been tested.
        - While also untested, it's possible that a Debian image should also be able to install Ubuntu via `debootstrap`.
- Rocky:
    - While `linux-installer` should work fine on any Rocky Linux live image, it has only been successfully tested on the "Workstation" image.

### Supported graphical environments

`linux-installer` is able to install the following graphical environments (GE):

| GE / Distros               | Arch | Artix | Debian | Rocky | Ubuntu              |
| ---                        | ---  | ---   | ---    | ---   | ---                 |
| None ("headless"/"server") | ✅   | ✅    | ✅     | ✅    | ✅                  |
| dwm                        | ✅   | ✅    | ✅     | ❌    | ✅                  |
| GNOME                      | ✅   | ✅    | ✅     | ✅    | ✅ (Ubuntu Desktop) |
| KDE                        | ✅   | ✅    | ✅     | ❌    | ✅ (Kubuntu)        |
| COSMIC                     | ✅   | ❌    | ❌     | ❌    | ❌                  |
| Cinnamon                   | ✅   | ✅    | ✅     | ✅    | ✅                  |
| Xfce                       | ✅   | ✅    | ✅     | ✅    | ✅                  |
| Mate                       | ✅   | ✅    | ✅     | ✅    | ✅                  |
| LXQt                       | ✅   | ✅    | ✅     | ❌    | ✅                  |
| LXDE                       | ✅   | ✅    | ✅     | ❌    | ✅                  |
| Budgie                     | ✅   | ✅    | ✅     | ❌    | ✅                  |

Some notes on graphical environments:

- dwm:
    - This option installs [my personal dwm build](https://github.com/DavidVogelxyz/dwm), which is based off of [Luke Smith's build of dwm](https://github.com/LukeSmithxyz/dwm).
    - Also installed are:
        - [dmenu](https://github.com/DavidVogelxyz/dmenu)
        - [dwmblocks](https://github.com/DavidVogelxyz/dwmblocks)
        - [st](https://github.com/DavidVogelxyz/st)
- GNOME:
    - On Ubuntu, choosing `gnome` will install Ubuntu's version of GNOME (the standard Ubuntu Desktop).
    - All distributions install `gnome-tweaks`.
        - This package allows the user to restore "window buttons at top right of window".
    - `dash-to-dock` is currently installed only on Debian systems.
        - This GNOME extenstion allows the user to have a similar dock to the one found on Ubuntu Desktop.
        - This feature will soon be expanded to Arch, Artix, and Rocky.
    - Systems with GNOME will run `gnome-terminal` as their terminal, by default.
- KDE:
    - On Ubuntu, choosing `kde` will install Ubuntu's version of KDE (Kubuntu).
    - Systems with KDE will run `konsole` as their terminal, by default.

### Supported web browsers

When installing a graphical environment, the following web browsers are available for install:

| Browsers / Distros | Arch | Artix | Debian | Rocky | Ubuntu |
| ---                | ---  | ---   | ---    | ---   | ---    |
| Brave              | ✅   | ✅    | ✅     | ✅    | ✅     |
| Chromium           | ✅   | ✅    | ✅     | ✅    | ❌     |
| Firefox            | ✅   | ✅    | ✅     | ✅    | ❌     |
| LibreWolf          | ✅   | ✅    | ❌     | ❌    | ❌     |

Some notes on web browsers:

- Brave:
    - Brave is the only browser that is available for all currently available distributions.
- Chromium:
    - Chromium is an option on all distributions except for Ubuntu:
        - This is because Ubuntu forces the installation of Chromium as a snap package.
- Firefox:
    - Firefox is an option on all distributions except for Ubuntu:
        - This is because Ubuntu forces the installation of Firefox as a snap package.
- LibreWolf:
    - LibreWolf is only available on systems with access to the AUR.

`linux-installer` can handle both BIOS and UEFI firmware, can encrypt the rootfs, and can create swap partitions based off the machine's total RAM.

## Instructions

To make the most use out of `linux-installer`, follow these simple steps:

- Boot into a supported Linux live image environment.
- In a shell, change user to `root`:
    - On all supported systems, `sudo -i` should elevate the user to a root shell.
- Update the packages repositories and install `git`:
    - Debian/Ubuntu: `apt update && apt install -y git`
    - Arch/Artix: `pacman -Sy && pacman -S --noconfirm git`
    - Rocky: `dnf install -y git`
- Clone this repo to the root user's home directory:
    - `git clone https://github.com/DavidVogelxyz/linux-installer /root/linux-installer`
- Change directory into the repo and run the main script file:
    - `cd /root/linux-installer && bash src/main.sh`

## Known issues

The following is a non-exhaustive list of issues that have been noted:

- `openssh-server` does not install properly on Arch and Artix.
    - Artix also needs proper handling of `openssh-runit`.
- Issues with `sftp` on Arch and Artix systems.
    - Due to line in `/etc/ssh/sshd_config`.
    - Subsystem for `sftp` should be `internal-sftp`.
- Running a Proxmox VM, a newly installed "UEFI Debian GNOME" fails to boot.
    - However, "UEFI Debian GNOME" successfully booted on a laptop.
- The issue of the "post-Librewolf" glitch still occurs:
    - It seems to be limited to `artix`, as `arch` did not encounter this issue
- `gdm` does not work on Arch or Artix:
    - The problem relates to `gdm`, but the problem *isn't* `gdm`:
        - On Arch and Artix, `gdm` expects 3D acceleration.
            - Proxmox isn't configured to do 3D acceleration.
        - On Debian, Rocky, and Ubuntu, `gdm` runs without 3D acceleration.
        - Therefore, the issue is related to a `gdm` config on Arch and Artix.

## Future plans

Future goals for `linux-installer` include the following:

- Add `ssh-agent` to non-dwm machines.
- Ensure systems with `neovim` also install `ripgrep`.
    - Potentially, also `gettext`.
- Test Rocky Linux with:
    - UEFI
    - encryption
    - swap partitions
- Address that some functions should operate based on init system, and not the distro.
- Use content from [library](https://github.com/DavidVogelxyz/library) to expand the `whiptail` info screens.
- **Refactor**; add more comments throughout the code.
- Add support for other desktop environments, including:
    - Xfce
    - Cinnamon
- Add support for Alpine Linux.
- Address distributions that use `America/*` for the timezone, instead of `US/*`.
    - Distributions include Ubuntu and Rocky.
        - A sufficient workaround was implemented for Rocky.
- Add additional graphical environments for Rocky Linux.
    - KDE and dwm are lower priority.
- Add support for Oracle Linux.
