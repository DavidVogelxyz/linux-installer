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

    check_linux_install "rocky" \
        && dependencies=(
            "cmake"
            "gcc"
            "libX11-devel"
            "libXinerama-devel"
            "libXft-devel"
            "fastfetch"
            "google-noto-fonts-common"
        ) \
        && for pkg in "${dependencies[@]}" ; do
            install_pkg_dnf "$pkg" \
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

    # clone `bin-dwm` repo for systems running dwm
    run_git-clone "https://github.com/DavidVogelxyz/bin-dwm" "$repodir/bin-dwm"

    # do symlink for `bin-dwm`
    ln -s "/home/$username/.local/src/bin-dwm/bin-dwm" "/home/$username/.local/bin/bin-dwm"

    # getting extra dotfiles into `~/.config`
    cd "/home/${username}/.config" \
        || error "Failed to change directory to \`/home/${username}/.config\` for additional dotfile deployment."

    list_of_dirs=(
        "wal"
    )

    for dir in "${list_of_dirs[@]}"; do
        [ -e "$dir" ] \
            || sudo -u "$username" ln -s "../.local/src/voidrice/.config/${dir}" .
    done

    # make sure all files in user's home dir are owned by them
    chown -R "$username": "/home/$username"
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
        && sed -i "s/noclear/noclear --autologin ${username}/g" "/etc/runit/sv/agetty-tty1/conf" \
        && unlink /run/runit/service/logind

    # enables autologin on Arch and Debian and Ubuntu
    # this is getting cumbersome
    # TASK: find a way to check for `systemd`
    (check_linux_install "rocky" || check_linux_install "arch" || check_linux_install "debian" || check_linux_install "ubuntu") \
        && sudo mkdir -p /etc/systemd/system/getty@tty1.service.d \
        && sudo tee -a /etc/systemd/system/getty@tty1.service.d/override.conf &>/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $username --noclear %I 38400 linux
EOF

    return 0
}

larbs_fixes() {
    # Write urls for newsboat if it doesn't already exist
    [ -s "/home/${username}/.config/newsboat/urls" ] \
        || echo "$rssurls" | sudo -u "$username" tee "/home/${username}/.config/newsboat/urls" \
            > /dev/null

    # Most important command! Get rid of the beep!
    rmmod pcspkr
    echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

    # Make zsh the default shell for the user.
    #chsh -s /bin/zsh "$username" >/dev/null 2>&1
    sudo -u "$username" mkdir -p "/home/${username}/.config/abook"
    sudo -u "$username" mkdir -p "/home/${username}/.config/mpd/playlists"

    # Make dash the default #!/bin/sh symlink.
    #ln -sfT /bin/dash /bin/sh >/dev/null 2>&1

    # dbus UUID must be generated for Artix runit.
    dbus-uuidgen > /var/lib/dbus/machine-id

    # Use system notifications for Brave on Artix
    # Only do it when systemd is not present
    #[ "$(readlink -f /sbin/init)" != "/usr/lib/systemd/systemd" ] && echo "export \$(dbus-launch)" >/etc/profile.d/dbus.sh

    # Enable tap to click
    [ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    # Enable left mouse button by tapping
    Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf
}

fix_browser_dwm() {
    # if Arch-based, and browser is set to Brave, change default browser to `brave-bin`
    check_pkgmgr_pacman \
        && [ "$browser_install" = "brave" ] \
        && sed -i \
            's/^export BROWSER="librewolf"/export BROWSER="brave-bin"/g' \
            "/home/$username/.dotfiles/.config/shell/profile"

    # if Debian-based, and browser is set to Brave, change default browser to `brave-browser`
    (check_pkgmgr_apt || check_linux_install "rocky" ) \
        && [ "$browser_install" = "brave" ] \
        && sed -i \
            's/^export BROWSER="librewolf"/export BROWSER="brave-browser"/g' \
            "/home/$username/.dotfiles/.config/shell/profile"

    # if browser is set to Chromium, change default browser to `chromium`
    [ "$browser_install" = "chromium" ] \
        && sed -i \
            's/^export BROWSER="librewolf"/export BROWSER="chromium"/g' \
            "/home/$username/.dotfiles/.config/shell/profile"

    # if browser is set to Firefox, change default browser
    [ "$browser_install" = "firefox" ] \
        && sed -i \
            's/^export BROWSER="librewolf"/export BROWSER="firefox-esr"/g' \
            "/home/$username/.dotfiles/.config/shell/profile"

    return 0
}

fix_dwm() {
    fix_dwm_existing_dotfiles

    fix_dwm_additional_dotfiles

    fix_dwm_wallpaper

    enable_dwm_autologin

    check_pkgmgr_pacman \
        && larbs_fixes

    fix_browser_dwm

    return 0
}
