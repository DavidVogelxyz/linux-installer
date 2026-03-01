linux-installer
===============

> [!Note]
> This README has been updated for v0.2.0.

`linux-installer` is a program, written in Bash, for quickly and easily installing Linux distributions, with little user input.

Table of contents
-----------------

- [Introduction](#linux-installer)
- [Usage](#usage)
    - [Program details](#program-details)
- [Features](#features)
    - [Legend for "features" tables](#legend-for-"features"-tables)
    - [Supported Linux distributions](#supported-linux-distributions)
    - [Supported graphical environments](#supported-graphical-environments)
    - [Supported web browsers](#supported-web-browsers)
    - [New features](#new-features)
- [History](#history)

Usage
-----

To run `linux-installer`, boot an ISO of a [supported Linux distribution](#supported-linux-distributions) and clone this repo. Then, run the `linux-installer` script found within the repo's root directory.

Answer a few questions, and let `linux-installer` take care of the rest!

### Program details

In v0.2.0, `linux-installer` was simplified down to two main scripts: `linux-installer`, and `src/chroot-tasks`.

To start the program, a user will run `linux-installer`. The `main` function in `linux-installer` will run through a series of functions, which are either defined within the `linux-installer` script, or within library files found within `src/lib`. The `main` function details which functions can be found in which library files; but, they generally follow a convention of "function name = library filename".

The last function call in the `main` function of `linux-installer` is `do_bootstrap`, and the last function call of `do_bootstrap` is to `chroot` into the new installation. Normally, when chrooting, the user will provide a shell (such as `/bin/bash`) located within the new root, which provides the user with an interactive session within the new root. Instead, `do_bootstrap` runs `src/chroot-tasks`, which performs all of its tasks within the new root.

Similar to the `linux-installer` script, `src/chroot-tasks` executes its `main` function, which is a series of functions that are defined in library files found within `src/lib`. As with `linux-installer`, the `main` function of `src/chroot-tasks` should clearly describe which functions can be found in which library files, and generally follows the convention of "function name = library filename".

This approach was taken to contrast with previous versions of `linux-installer`, for which function definitions were sometimes difficult to find. This new arrangement simplifies the structure and makes it easier to review the order of operations.

Features
--------

### Legend for "features" tables

✅ Working | 🏗️ Work in progress (but, *should* work) | ☢️ Works, but has known bugs | ⛔ No support

### Supported Linux distributions

The following table shows the supported Linux ISOs (vertical) for each available Linux distribution (horizontal).

|            | Artix | Arch | Debian | Ubuntu | Rocky |
| ---        | ---   | ---  | ---    | ---    | ---   |
| Artix ISO  | ✅    | ⛔   | 🏗️     | 🏗️     | ⛔    |
| Arch ISO   | ⛔    | ✅   | 🏗️     | 🏗️     | ⛔    |
| Debian ISO | ⛔    | ⛔   | ✅     | ✅     | ⛔    |
| Ubuntu ISO | ⛔    | ⛔   | ✅     | ✅     | ⛔    |
| Rocky ISO  | ⛔    | ⛔   | 🏗️     | 🏗️     | ✅    |

Recently, it came to my attention that Artix, Arch, and Rocky can all install `debootstrap`, the bootstrap package for Debian and Ubuntu. However, during testing, attempts to install Debian from an Artix ISO were met with various bugs that weren't encountered when installing Debian from an Ubuntu ISO.

For now, running `debootstrap` from an ISO that isn't Debian or Ubuntu is a work in progress; though, most of the supporting code is already included.

### Supported release versions

The following release versions are *supported* by this program.

Artix and Arch:
- "rolling" (aka, "latest")

Debian:
- Debian 12 (bookworm)
- Debian 13 (trixie)

Ubuntu:
- Ubuntu 20 LTS (focal)
- Ubuntu 22 LTS (jammy)
- Ubuntu 24 LTS (noble)

Rocky:
- Rocky 9
- Rocky 10

There are multiple caveats with release versions:
- Debian and Ubuntu (`debootstrap`):
    - Release versions that are newer than the version of `debootstrap` will not be found in `/usr/share/debootstrap/scripts`:
        - As an example, an Ubuntu 22 (jammy) ISO will not be able to install Ubuntu 24 (noble).
        - However, most previous versions *are* accessible.
- Rocky:
    - It appears that the release version cannot be newer than the ISO used:
        - As an example, a Rocky 9 ISO cannot install Rocky 10.
        - It is currently unknown whether a newer ISO can install an older release version.

To install a release version of Debian or Ubuntu that is not listed:
- Update the `get_debootstrap_scripts` function found within `src/lib/11-ask_user_questions` to include that release version:
    - If the version exists in `/usr/share/debootstrap/scripts`, it will be selectable when running `linux-installer`.

### Supported graphical environments

The following table shows the available graphical environment (vertical) for each available Linux distribution (horizontal):

|          | Artix | Arch | Debian | Ubuntu | Rocky |
| ---      | ---   | ---  | ---    | ---    | ---   |
| None     | ✅    | ✅   | ✅     | ✅     | ✅    |
| dwm      | ✅    | 🏗️   | 🏗️     | 🏗️     | ☢️    |
| GNOME    | ⛔    | 🏗️   | 🏗️     | 🏗️     | 🏗️    |
| KDE      | 🏗️    | 🏗️   | 🏗️     | 🏗️     | ⛔    |
| Hyprland | ✅    | 🏗️   | ⛔     | ⛔     | ⛔    |
| COSMIC   | ⛔    | 🏗️   | ⛔     | ⛔     | ⛔    |
| Cinnamon | 🏗️    | 🏗️   | 🏗️     | 🏗️     | 🏗️    |
| Xfce     | ✅    | 🏗️   | 🏗️     | 🏗️     | 🏗️    |
| Mate     | 🏗️    | 🏗️   | 🏗️     | 🏗️     | 🏗️    |
| LXQt     | 🏗️    | 🏗️   | 🏗️     | 🏗️     | ⛔    |
| LXDE     | 🏗️    | 🏗️   | 🏗️     | 🏗️     | ⛔    |
| Budgie   | ⛔    | 🏗️   | 🏗️     | 🏗️     | ⛔    |

Some notes about available graphical enviroments:
- All:
    - Any graphical environment marked by "🏗️" was available in previous versions of `linux-installer`:
        - It is marked as "work in progress" simply because I have not verified that it works as expected.
        - It *should* work -- but, there may be bugs.
        - The table will be updated as more combinations are tested and verified.
- dwm:
    - Artix:
        - Artix dwm installs `xlibre-xserver`, as opposed to `xorg-xserver`:
            - This was implemented in 2026 January, as part of v0.1.5.
    - Rocky:
        - As was true with previous version of `linux-installer`, Rocky dwm is extremely buggy:
            - The Rocky repos are missing many packages.
            - Compiling certain packages from source has been successful; others, not so much.
            - Rocky dwm is very "use at your own risk"; and, will be for the foreseeable future.
- GNOME:
    - Artix:
        - GNOME is no longer available on Artix, due to dependency on `systemd` as the init system:
            - For more information, view [this link](https://forum.artixlinux.org/index.php/topic,8700.0.html) to the Artix forums.
    - Ubuntu:
        - GNOME on Ubuntu installs as Ubuntu's version of GNOME (`ubuntu-desktop-minimal`), the standard Ubuntu desktop.
- KDE:
    - Ubuntu:
        - KDE on Ubuntu installs as Kubuntu (`kubuntu-desktop`).
    - Rocky:
        - I have never been able to install KDE correctly on Rocky Linux. It may be possible, though.
- Hyprland:
    - Debian / Ubuntu / Rocky:
        - As of 2025 July, Hyprland was not available in the package repos of these distros. This may have changed.
- COSMIC:
    - Artix / Debian / Ubuntu / Rocky:
        - As of 2025 May, COSMIC not available in the package repos of these distros. This may have changed.
- LXQt / LXDE:
    - Rocky:
        - As of 2025 June, LXQt and LXDE were not available in Rocky's package repos.
- Budgie:
    - Artix:
        - Budgie is no longer available on Artix, due to a dependency on `systemd` as the init system:
            - For more information, view [this link](https://forum.artixlinux.org/index.php/topic,8700.msg53186.html#msg53186) to the Artix forums.
    - Rocky:
        - As of 2025 June, Budgie was not available in Rocky's package repos.

### Supported web browsers

The following table shows the available web browsers (vertical) for each available Linux distribution (horizontal):

|           | Artix | Arch | Debian | Ubuntu | Rocky |
| ---       | ---   | ---  | ---    | ---    | ---   |
| LibreWolf | ✅    | 🏗️   | ⛔     | ⛔     | ⛔    |
| Brave     | ✅    | 🏗️   | 🏗️     | 🏗️     | 🏗️    |
| Chromium  | 🏗️    | 🏗️   | 🏗️     | ⛔     | 🏗️    |
| Firefox   | 🏗️    | 🏗️   | 🏗️     | ⛔     | 🏗️    |

Some notes about available web browsers:
- LibreWolf:
    - LibreWolf installs via the AUR; as such, it is only available on Artix and Arch.
- Brave:
    - Brave is the only browser installable on all available Linux distributions.
- Chromium / Firefox:
    - Chromium and Firefox are not installable on Ubuntu:
        - This is because Ubuntu forces the installation of these browsers as snap packages:
            - `linux-installer` does not support snap packages.

### New features

Features new to v0.2.0 include:
- Installation distribution should no longer be dependent on installation ISO:
    - While this has some bugs, the supporting code is provided.
    - Once the bugs are addressed; Artix, Arch, and Rocky ISOs should be able to install `debootstrap` distributions (Debian and Ubuntu).
- Artix can now install other service managers:
    - While it has been minimally tested, `linux-installer` should now be able to install Artix with OpenRC as the service manager.
    - Other service managers should be available by simply adding them as options in `src/lib/11-ask_user_questions`.
- Artix and Arch now complete much faster, due to concurrent downloads:
    - While this has long been configured for "installed" Artix and Arch hosts, `linux-installer` now leverages concurrent downloads for bootstrapping, and installation of system packages.

History
-------

`linux-installer` has a longer history that the Git history of this repo indicates.

The project started out as [debian-dwm](https://github.com/DavidVogelxyz/debian-dwm), a set of scripts that were largely inspired by LukeSmithxyz's [LARBS](https://github.com/LukeSmithxyz/LARBS). `debian-dwm` was first written in 2023 August as an attempt to reproducibly install dwm on Debian hosts. The expectation was always that, like LARBS, `debian-dwm` would be run on a host that already had Debian installed.

Then, another project was created in 2024 February: [debian-setup](https://github.com/DavidVogelxyz/debian-setup). `debian-setup` was created as a response to a situation at work, where a coworker has connected via `ssh` to the company Proxmox and deleted a handful of servers that I had configured. In order to save time with the configuration of future Debian servers, `debian-setup` was written to expedite the "post-`chroot`" process.

For any future Debian host, the installation process had been simplified. As soon as the `chroot` command had been run, `debian-setup` could be deployed to configure the server from there. And, the handoff between `debian-setup` to `debian-dwm` was seamless -- as soon as `debian-setup` completed, and the user had booted into the new installation, `debian-dwm` could be run in order to install dwm on the host.

Taking more inspiration from LARBS, `debian-setup` was the first project to run with `whiptail` screens. `debian-setup` was also written to read installation packages from a CSV file, just like LARBS. Ultimately, the script was also extended to support Ubuntu.

However, there were a few key items that `debian-setup` and `debian-dwm` did not accomplish:
- Neither of the scripts could handle the "pre-`chroot`" tasks.
- Neither of the scripts would work on any Linux distribution besides Debian.
- Neither of the scripts could install anything besides dwm.
- And, the scripts were part of two separate projects.

So, in 2025 March, work began on a new project named `linux-installer`.

`linux-installer` was always meant to be the combination of `debian-setup` and `debian-dwm`, but with more features. Because of the previous projects' focus on Debian, the v0.0.x versions of `linux-installer` focused on Debian first. Then, `linux-installer` was configured to handle Artix; and, eventually, Arch and Ubuntu. After about 100 hours spent on `linux-installer` over the course of 2 months, v0.1.0 was released at the end of 2025 April.

`linux-installer` achieved on all of the items that `debian-setup` and `debian-setup` did not:
- It could handle the "pre-`chroot`" ***AND*** the "post-`chroot`".
- It worked on a handful of Linux distributions.
- It could install multiple graphical environments, including dwm.
- It was one single project that could "do everything".

`linux-installer` was maintained throughout 2025, with bug fixes and support for new desktop environments. However, the code started to show its age, and it became difficult to maintain. In addition, I had spent the second half of 2025 learning how to write better Bash, including by completing most of 2025's [Advent of Code](https://github.com/DavidVogelxyz/advent_of_code) in Bash.

So, in 2025 February, work began on a complete rewrite of `linux-installer`, incorporating a bunch of new Bash tricks, and vastly simplifying the codebase in order to make the scripts more readable and easy to maintain.
