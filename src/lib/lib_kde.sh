#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_KDE
#####################################################################

install_kde() {
    whiptail \
        --title "KDE Installation" \
        --infobox "Installing KDE." \
        9 70

    check_linux_install "debian" \
        && install_pkg_apt kde-plasma-desktop

    check_linux_install "ubuntu" \
        && install_pkg_apt kubuntu-desktop

    check_pkgmgr_pacman \
        && install_pkg_pacman plasma-desktop
        #&& install_pkg_pacman xorg-xserver \
        #&& install_pkg_pacman xorg-xinit \
        #&& install_pkg_pacman plasma-desktop
}
