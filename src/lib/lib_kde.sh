#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_KDE
#####################################################################

install_kde() {
    check_pkgmgr_pacman \
        && arch_aur_prep

    install_loop \
        || error "Failed during the install loop."
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

    return 0
}
