v0.2.0
======

Released: 2026 Feb 17, Tue

v0.2.0 is a complete rewrite of `linux-installer`.

The code is easier to read, and simpler to maintain. The program runs faster for many reasons, including that it forks less to external programs than it did before. The code is more "pure Bash" than it was before.

New features:
- Installation distribution should no longer be dependent on installation ISO:
    - While this has some bugs, the supporting code is provided.
    - Once the bugs are addressed; Artix, Arch, and Rocky ISOs should be able to install `debootstrap` distributions (Debian and Ubuntu).
- Artix can now install other service managers:
    - While it has been minimally tested, `linux-installer` should now be able to install Artix with OpenRC as the service manager.
    - Other service managers should be available by simply adding them as options in `src/lib/11-ask_user_questions`.
- Artix and Arch now complete much faster, due to concurrent downloads:
    - While this has long been configured for "installed" Artix and Arch hosts, `linux-installer` now leverages concurrent downloads for bootstrapping, and installation of system packages.
- The program now times itself, and lets the user know the "time to completion" at the end of the install.

v0.1.5
======

Released: 2026 Feb 1, Sun

New features:
- added `setxkbmap` to Rocky dwm
- added `ncal` to Ubuntu dwm
- Artix dwm now installs `xlibre` instead of `xorg`

Bug fixes:
- Artix dwm no longer encounters the `dbus` / `elogind` issue when autologin is enabled

v0.1.4
======

Released: 2025 Nov 20, Thu

New features:
- Hyprland now installs `waybar`
- Artix Cinnamon now installs `artix-cinnamon-presets`
- Hyprland now installs `hyprland-dotfiles` repo
- Artix ISOs now update `glibc` when installing `libnewt`

Bug fixes:
- Artix now installs `noto-fonts`, instead of `fonts-noto`
- repos cloned during graphical installs are now owned by the user

v0.1.3
======

Released: 2025 Oct 5, Sun

Removed features:
- removed GNOME and Budgie from Artix

New features:
- added support for `bin-linux` and `bin-dwm`

v0.1.2
======

Released: 2025 Jul 20, Sun

New features:
- added Xfce desktop to all distros
- added Mate desktop to all distros
- added LXQt desktop to all distros except Rocky
- added LXDE desktop to all distros except Rocky
- added Budgie desktop to all distros except Rocky
- added Cinnamon desktop
- added Hyprland to Arch and Artix

Bug fixes:
- added LightDM to Rocky Cinnamon
- added `util-linux-user` to Rocky installs (for `chsh`)

v0.1.1
======

Released: 2025 Jun 11, Wed

New features:
- added more browser support (Brave, Chromium)
- GNOME installs now come with `dash-to-dock`
- autologin for Arch and Ubuntu dwm systems
- added support for Debian 13 (trixie)
- added COSMIC desktop to Arch installs
- added Cinnamon desktop to all distros except Rocky

Bug fixes:
- `nvim` plugins are now installed on Arch-based systems
- `sddm` now installs with the Breeze theme
- Arch now correctly installs `efibootmgr`
- systems with encrypted swap partitions now hibernate correctly
- added `DEBIAN_FRONTEND=interactive` to `install_pkg_apt`

v0.1.0
======

Released: 2025 Apr 30, Wed

Version 0.1.0 is the first true public release, adding support for various graphical environments, as well as support for Rocky Linux.

Supported graphical environments are `server` ("headless"), `dwm`, `gnome`, and `kde`.

Debian and Ubuntu machines can install all graphical environments, with Ubuntu GNOME being the Ubuntu version of GNOME (Ubuntu Desktop), and Ubuntu KDE being Kubuntu.

Arch and Artix can install all graphical environments, with GNOME and KDE running the `sddm` display manager. `gdm` is not supported at this time.

Rocky Linux can install GNOME and KDE.

Rocky Linux has only been tested in a BIOS environment, with no encryption, and no swap partition. It has not been tested with UEFI, nor with `rootfs` encryption, nor with swap partitions.

The project has undergone extensive testing by this point, and additional bug fixes have been merged in.

v0.0.9
======

Released: 2025 Mar 24, Mon

This project has expanded its Arch and Artix capabilities, and can now work with both "basic `rootfs` encryption" and swap partitions.

Tested on an Artix Linux image, with both encryption and swap partition.

v0.0.8
======

Released: 2025 Mar 23, Sun

This project has expanded its Arch and Artix capabilities, and can now install AUR packages.

Tested on an Arch Linux image, with no encryption or swap partition.

v0.0.7
======

Released: 2025 Mar 23, Sun

This project can now complete a basic Arch Linux install.

Also, tons of "editing" occurred to clean up dead code and optimizing surviving code.

Tested on an Arch Linux image, with no encryption or swap partition. Also tested using an Ubuntu image installing Debian Bookworm, with encryption and swap partition.

v0.0.6
======

Released: 2025 Mar 20, Thu

This project is now able to add swap partitions and work with logical volumes.

Also, tons of "editing" occurred to clean up dead code and optimizing surviving code.

Tested on Ubuntu image installing Debian Bookworm, with encryption and swap partition.

v0.0.5
======

Released: 2025 Mar 20, Thu

This project is now able to do basic `rootfs` encryption and pass the necessary UUID to `/etc/crypttab` without user intervention.

Tested on Ubuntu image installing Debian Bookworm; with encryption, but no swap partition.

v0.0.4
======

Released: 2025 Mar 19, Wed

This project no longer requires user intervention beyond the initial input. Once the scripts takes in all inputs and gets started, it should run interrupted until completion.

As referenced in `v0.0.3` release notes, this update handles `/etc/fstab` without requiring user input. `/etc/crypttab` will be handled in a future update.

Tested on Ubuntu image installing Debian Bookworm, with no encryption or swap partition.

v0.0.3
======

Released: 2025 Mar 18, Tue

In this update, this project no longer asks for input within the `chroot` environment. All of the prompts for user data occur outside the `chroot` environment, at the beginning of the run. The only parts now that will ask for user input are the `/etc/fstab` and `/etc/crypttab` files. But, this will be fixed in a future update.

Tested on Ubuntu image installing Debian Bookworm, with no encryption or swap partition.

v0.0.2
======

Released: 2025 Mar 17, Mon

Instead of `git clone debian-setup`, this project now includes an updated `debian-setup` within itself. However, the script requests user input both outside and inside the `chroot` environment.

Tested on Ubuntu image installing Debian Bookworm, with no encryption or swap partition.

v0.0.1
======

Released: 2025 Mar 15, Sat

First commit where this project was able to successfully complete, and then correctly `chroot` into the `debian-setup` script.

Tested on Ubuntu image installing Debian Bookworm, with no encryption or swap partition.
