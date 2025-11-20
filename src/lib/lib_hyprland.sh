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
    # clone `hyprland-dotfiles` repo for systems running Hyprland
    run_git-clone "https://github.com/DavidVogelxyz/hyprland-dotfiles" "$repodir/hyprland-dotfiles"

    # do symlinks for `hyprland-dotfiles`
    ln -s "/home/$username/.local/src/hyprland-dotfiles/hypr" "/home/$username/.config/hypr"
    ln -s "/home/$username/.local/src/hyprland-dotfiles/waybar" "/home/$username/.config/waybar"

    # make sure all files in user's home dir are owned by them
    chown -R "$username": "/home/$username"
}
