#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_GNOME
#####################################################################

install_gnome() {
    whiptail \
        --title "GNOME Installation" \
        --infobox "Installing GNOME." \
        9 70

    check_linux_install "debian" \
        && install_pkg_apt gnome-core

    check_linux_install "ubuntu" \
        && install_pkg_apt ubuntu-desktop-minimal

    #check_pkgmgr_pacman \
    #    && install_pkg_pacman xorg \
    #    && install_pkg_pacman gnome
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
    # may only currently work on Debian
    install_gnome_dash-to-dock

    # add GNOME tweaks to Debian
    check_linux_install "debian" \
        && install_pkg_apt gnome-tweaks

    #check_linux_install "arch" \
    #    && systemctl enable gdm

    #check_linux_install "artix" \
    #    && install_pkg_pacman gdm-runit \
    #    && ln -s /etc/runit/sv/gdm /run/runit/service
}
