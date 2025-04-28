#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_KDE
#####################################################################

install_kde_debian() {
    install_pkg_apt kde-plasma-desktop
}

install_kde_ubuntu() {
    install_pkg_apt kubuntu-desktop
}

install_kde_arch() {
    check_linux_install "arch" \
        && install_pkg_pacman noto-fonts \
        && install_pkg_pacman sddm

    check_pkgmgr_pacman \
        && install_pkg_pacman plasma-desktop
}

install_kde_artix() {
    check_linux_install "artix" \
        && install_pkg_pacman noto-fonts \
        && install_pkg_pacman sddm-runit

    check_linux_install "artix" \
        && install_kde_arch
}

install_kde() {
    whiptail \
        --title "KDE Installation" \
        --infobox "Installing KDE." \
        9 70

    check_linux_install "debian" \
        && install_kde_debian

    check_linux_install "ubuntu" \
        && install_kde_ubuntu

    check_linux_install "arch" \
        && install_kde_arch

    check_linux_install "artix" \
        && install_kde_artix

    return 0
}

fix_kde() {
    check_linux_install "arch" \
        && systemctl enable sddm

    # for some reason, this doesn't work in chroot
    # must be run manually after rebooting
    check_linux_install "artix" \
        && ln -s /etc/runit/sv/sddm /run/runit/service/

    check_pkgmgr_pacman \
        && install_pkg_pacman arandr \
        && install_pkg_pacman konsole \
        && install_pkg_pacman gnome-terminal

    return 0
}
