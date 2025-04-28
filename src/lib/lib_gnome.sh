#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_GNOME
#####################################################################

install_gnome_debian() {
    install_pkg_apt gnome-core
}

install_gnome_ubuntu() {
    install_pkg_apt ubuntu-desktop-minimal
}

install_gnome_arch() {
    check_linux_install "arch" \
        && install_pkg_pacman noto-fonts \
        && install_pkg_pacman sddm

    check_pkgmgr_pacman \
        && install_pkg_pacman gnome
}

install_gnome_artix() {
    check_linux_install "artix" \
        && install_pkg_pacman noto-fonts \
        && install_pkg_pacman sddm-runit

    check_linux_install "artix" \
        && install_gnome_arch
}

install_gnome() {
    whiptail \
        --title "GNOME Installation" \
        --infobox "Installing GNOME." \
        9 70

    check_linux_install "debian" \
        && install_gnome_debian

    check_linux_install "ubuntu" \
        && install_gnome_ubuntu

    check_linux_install "arch" \
        && install_gnome_arch

    check_linux_install "artix" \
        && install_gnome_artix

    return 0
}

install_gnome_dash-to-dock() {
    progname="dash-to-dock"
    dir="$repodir/$progname"

    check_linux_install "debian" \
        && {
            install_pkg_apt gettext
            install_pkg_apt sassc
        }

    #install_pkg_git "https://github.com/micheleg/dash-to-dock"

    sudo -u "$username" git -C "$repodir" clone \
        --depth 1 \
        --single-branch \
        --no-tags \
        -q \
        "https://github.com/micheleg/dash-to-dock" "$dir" \
        || {
            cd "$dir" \
                || return 1

            sudo -u "$username" git pull --force origin master
        }

    cd "$dir" \
        || exit 1

    sudo -u "$username" make \
        > /dev/null 2>&1

    sudo -u "$username" make install \
        > /dev/null 2>&1

    cd /tmp \
        || return 1
}

fix_gnome() {
    # install `dash-to-dock` extension
    # currently set to "only install on Debian"
    # because only Debian dependencies are certain
    check_linux_install "debian" \
        && install_gnome_dash-to-dock

    # add GNOME tweaks to Debian
    check_linux_install "debian" \
        && install_pkg_apt gnome-tweaks

    # add GNOME tweaks to Arch and Artix
    check_pkgmgr_pacman \
        && install_pkg_pacman gnome-tweaks

    # Enable `sddm` on Arch
    check_linux_install "arch" \
        && systemctl enable sddm

    # Enable `sddm` on Artix
    # for some reason, this doesn't work in chroot
    # must be run manually after rebooting
    check_linux_install "artix" \
        && ln -s /etc/runit/sv/sddm /run/runit/service

    # Install `gnome-terminal` to Arch and Artix machines
    # Debian, Ubuntu, and Rocky all install `gnome-terminal` by default
    check_pkgmgr_pacman \
        && install_pkg_pacman gnome-terminal

    return 0
}
