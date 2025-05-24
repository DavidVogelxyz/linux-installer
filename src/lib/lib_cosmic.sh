#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_COSMIC
#####################################################################

install_cosmic() {
    check_pkgmgr_pacman \
        && arch_aur_prep

    install_loop \
        || error "Failed during the install loop."
}

fix_cosmic() {
    # Enable `cosmic-greeter` on Arch
    check_linux_install "arch" \
        && systemctl enable cosmic-greeter

    return 0
}
