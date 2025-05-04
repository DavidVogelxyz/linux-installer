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

install_kde_rocky() {
    dnf group install -y --skip-broken "KDE Plasma Workspaces" \
        > /dev/null 2>&1
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

    check_linux_install "rocky" \
        && install_kde_rocky

    return 0
}

fix_kde() {
    # Enable `sddm` on Arch
    check_linux_install "arch" \
        && systemctl enable sddm

    # for some reason, this doesn't work in chroot
    # must be run manually after rebooting
    check_linux_install "artix" \
        && ln -s /etc/runit/sv/sddm /run/runit/service/

    # Install `breeze` theme for SDDM for Arch and Artix
    check_pkgmgr_pacman \
        && mkdir -p /etc/sddm.conf.d \
        && echo "[Theme]" > /etc/sddm.conf.d/sddm.conf \
        && echo "Current=breeze" >> /etc/sddm.conf.d/sddm.conf

    # Install extra packages to Arch and Artix systems
    # these do not come by default
    check_pkgmgr_pacman \
        && install_pkg_pacman arandr \
        && install_pkg_pacman konsole \
        && install_pkg_pacman gnome-terminal

    # Install extra packages to Debian and Ubuntu systems
    check_pkgmgr_apt \
        && install_pkg_apt gnome-terminal

    return 0
}
