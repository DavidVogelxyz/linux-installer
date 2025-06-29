#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_LXDE
#####################################################################

install_lxde() {
    check_pkgmgr_pacman \
        && arch_aur_prep

    install_loop \
        || error "Failed during the install loop."
}

fix_lxde() {
    # Enable `sddm` on Arch
    check_linux_install "arch" \
        && systemctl enable sddm

    # for some reason, this doesn't work in chroot
    # must be run manually after rebooting
    check_linux_install "artix" \
        && ln -s /etc/runit/sv/sddm /run/runit/service/

    # Install `breeze` theme for SDDM for Arch and Artix
    check_pkgmgr_pacman \
        && cp -r src/configs/sddm-themes/breeze /usr/share/sddm/themes/ \
        && mkdir -p /etc/sddm.conf.d \
        && echo "[Theme]" > /etc/sddm.conf.d/sddm.conf \
        && echo "Current=breeze" >> /etc/sddm.conf.d/sddm.conf \
        && install_pkg_pacman plasma-workspace

    return 0
}
