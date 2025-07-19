#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_HYPRLAND
#####################################################################

install_hyprland() {
    check_pkgmgr_pacman \
        && arch_aur_prep

    install_loop \
        || error "Failed during the install loop."
}

fix_hyprland() {
    return 0
}
