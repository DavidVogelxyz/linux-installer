#!/bin/sh

#####################################################################
# FUNCTIONS - PLAYBOOK_DWM
#####################################################################

install_dwm() {
    check_pkgmgr_pacman \
        && arch_aur_prep

    check_pkgmgr_apt \
        && dependencies=(
            "libx11-dev"
            "libxft-dev"
            "libxinerama-dev"
            "libx11-xcb-dev"
            "libxcb-res0-dev"
            "libharfbuzz-dev"
        ) \
        && for pkg in "${dependencies[@]}" ; do
            install_pkg_apt "$pkg" \
                || error_install "$pkg"
        done

    install_loop \
        || error "Failed during the install loop."
}

fix_dwm_existing_dotfiles() {
    # the xprofile file
    file_xprofile=".dotfiles/.xprofile"

    # xprofile should have a link in the homedir
    # FUTURE: add check to see if link should be unlinked in the first place
    cd "/home/${username}" \
        && sudo -u "$username" \
            ln -s "$file_xprofile" .

    # the xinitrc file
    file_xinitrc="$(readlink .dotfiles/.config/x11/xinitrc)"

    # the xprofile file
    file_xprofile="$(readlink .dotfiles/.xprofile)"

    # the zprofile file
    file_zprofile="$(readlink .dotfiles/.zprofile)"

    # undo a commented out line in zprofile
    # FUTURE: add check to see if line should be commented in the first place
    check_path_file "$file_zprofile" \
        && sed -i \
            's/^#\[ \"\$(tty)\"/[ "$(tty)"/g' \
            "$file_zprofile"

    # undo a commented out line in zprofile
    # FUTURE: add check to see if line should be commented in the first place
    check_path_file "$file_zprofile" \
        && sed -i \
            's/^#sudo -n loadkeys "$XDG_DATA_HOME/sudo -n loadkeys "$XDG_DATA_HOME/g' \
            "$file_zprofile"

    # xinitrc should have a change
    # this is due to stow - the file is a link, not a file
    # FUTURE: change should be upstream in `dotfiles` repo
    check_path_file "$file_xinitrc" \
        && sed -i \
            's/^if \[ -f/if \[ -e/g' \
            "$file_xinitrc"

    # since testing on VM, fix the resolution
    check_path_file "$file_xprofile" \
        && sed -i \
            's/^#xrandr -s/xrandr -s/g' \
            "$file_xprofile"
}

fix_dwm_additional_dotfiles() {
    # getting extra progs into `~/.local/bin`
    cd "/home/${username}/.local/bin" \
        || error "Failed to change directory to \`/home/${username}/.local/bin\` for additional dotfile deployment."

    sudo -u "$username" git clone \
        "https://github.com/LukeSmithxyz/voidrice" \
        "$repodir/voidrice" \
        > /dev/null 2>&1

    mapfile -t list_of_files < <(find "$repodir/voidrice/.local/bin" -maxdepth 1 -type f | sed 's/^\.\///g' | sort)

    for file in "${list_of_files[@]}"; do
        file=$(basename "$file")

        [ -e "$file" ] \
            || sudo -u "$username" ln -s "../src/voidrice/.local/bin/${file}" .
    done

    # getting extra progs into `~/.local/bin/statusbar`
    cd "/home/${username}/.local/bin/statusbar" \
        || error "Failed to change directory to \`/home/${username}/.local/bin/statusbar\` for additional dotfile deployment."

    mapfile -t list_of_files < <(find "$repodir/voidrice/.local/bin/statusbar" -maxdepth 1 -type f | sed 's/^\.\///g' | sort)

    for file in "${list_of_files[@]}"; do
        file=$(basename "$file")

        [ -e "$file" ] \
            || sudo -u "$username" ln -s "../../src/voidrice/.local/bin/statusbar/${file}" .
    done

    # getting extra dotfiles into `~/.config`
    cd "/home/${username}/.config" \
        || error "Failed to change directory to \`/home/${username}/.config\` for additional dotfile deployment."

    list_of_dirs=(
        "dunst"
        "fontconfig"
        "gtk-2.0"
        "gtk-3.0"
        "mimeapps.list"
        "mpd"
        "mpv"
        "newsboat"
        "pipewire"
        "pulse"
        "sxiv"
        "user-dirs.dirs"
        "wal"
        "wget"
        "zathura"
        )

    for dir in "${list_of_dirs[@]}"; do
        [ -e "$dir" ] \
            || sudo -u "$username" ln -s "../.local/src/voidrice/.config/${dir}" .
    done

    # set the `.gtkrc-2.0` symlink
    cd "/home/${username}" \
        && sudo -u "$username" ln -s .local/src/voidrice/.gtkrc-2.0 .
}

fix_dwm_wallpaper() {
    # get a wallpaper
    file_wallpaper="https://raw.githubusercontent.com/DavidVogelxyz/wallpapers/master/artists/muhammad-nafay/wallhaven-g8pmol.jpg"

    cd "/home/$username/.local/share" \
        && sudo -u "$username" curl -LJO "$file_wallpaper"

    # set the wallpaper
    file_wallpaper=$(basename "$file_wallpaper") \
        && sudo -u "$username" ln -s "$file_wallpaper" bg
}

enable_dwm_autologin() {
    # probably best to only enable autologin when the user has performed encryption
    # then, there's still a password prompt prior to entering the environment
    [ "$encryption" = true ] \
        || return 0

    # enables autologin on Artix
    check_linux_install "artix" \
        && sed -i "s/noclear/noclear --autologin ${username}/g" "/etc/runit/sv/agetty-tty1/conf"

    # enables autologin on Debian
    check_linux_install "debian" \
        && sudo mkdir -p /etc/systemd/system/getty@tty1.service.d \
        && sudo tee -a /etc/systemd/system/getty@tty1.service.d/override.conf &>/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $username --noclear %I 38400 linux
EOF

    return 0
}

fix_dwm() {
    fix_dwm_existing_dotfiles

    fix_dwm_additional_dotfiles

    fix_dwm_wallpaper

    enable_dwm_autologin
}
