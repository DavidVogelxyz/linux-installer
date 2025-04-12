#!/bin/sh

#export username="test"
#export linux_install="artix"
export repodir="/home/$username/.local/src"

# REQUIRES THE FOLLOWING VARIABLES TO BE ALREADY SET:
# username
# linux_install
# repodir

aurhelper="yay"
export TERM=ansi

list_packages="https://raw.githubusercontent.com/DavidVogelxyz/debian-setup/master/packages.csv"

#####################################################################
# FUNCTIONS
#####################################################################

arch_aur_prep() {
    # Allow user to run sudo without entering a password.
    # Since AUR programs must be installed in a fakeroot environment,
    # this is required for all builds with AUR packages.
    trap 'rm -f /etc/sudoers.d/setup-temp' HUP INT QUIT TERM PWR EXIT

    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/setup-temp
    echo "Defaults:%wheel,root runcwd=*" >> /etc/sudoers.d/setup-temp
}

arch_add_arch_mirror() {
    check_linux_install "arch" \
        && {
            install_pkg_pacman archlinux-keyring
        } \
        && return 0

    check_linux_install "artix" \
        && {
            install_pkg_pacman artix-keyring
            install_pkg_pacman artix-archlinux-support
            grep -q "^\[extra\]" /etc/pacman.conf \
                || echo "
[extra]
Include = /etc/pacman.d/mirrorlist-arch" \
                >>/etc/pacman.conf
            pacman -Syy --noconfirm >/dev/null 2>&1
            pacman-key --populate archlinux >/dev/null 2>&1
        } \
        && return 0
}

arch_aur_install() {
    install_aur $aurhelper \
        || error "Failed to install AUR helper."

    $aurhelper -Y --save --devel
}

#####################################################################
# FUNCTIONS - ERROR_INSTALL
#####################################################################

error_install() {
    echo "Failed to install \`$1\`." >> "$file_pkg_fail"
}

#####################################################################
# FUNCTIONS - OTHER FUNCTIONS
#####################################################################

run_git-clone() {
    # add some error correction:
    # - what if the repo already exists?
    # - possible to check the hashes and only clone if not a repo?
    git clone "$1" "$2" > /dev/null 2>&1
}

fixes_post_install_dwm() {
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

    # getting extra progs into `~/.local/bin`
    cd "/home/${username}/.local/bin" \
        || error "Failed to change directory to \`/home/${username}/.local/bin\` for additional dotfile deployment."

    sudo -u "$username" run_git-clone "https://github.com/LukeSmithxyz/voidrice" "$repodir/voidrice"

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

    # get a wallpaper
    file_wallpaper="https://raw.githubusercontent.com/DavidVogelxyz/wallpapers/master/artists/muhammad-nafay/wallhaven-g8pmol.jpg"

    cd "/home/$username/.local/share" \
        && sudo -u "$username" curl -LJO "$file_wallpaper"

    # set the wallpaper
    file_wallpaper=$(basename "$file_wallpaper") \
        && sudo -u "$username" ln -s "$file_wallpaper" bg
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

fixes_post_install_gnome() {
    # install `dash-to-dock` extension
    # may only currently work on Debian
    install_gnome_dash-to-dock

    # add GNOME tweaks to Debian
    check_linux_install "debian" \
        && install_pkg_apt gnome-tweaks
}

install_brave_apt() {
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
        && echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list \
        && apt update \
            > /dev/null 2>&1 \
        && apt install brave-browser
}

install_browser() {
    [ "$linux_install" = "debian" ] \
        && [ "$browser_install" = "firefox" ] \
        && install_pkg_apt firefox_esr

    check_pkgmgr_apt \
        && [ "$browser_install" = "brave" ] \
        && install_brave_apt
}

#####################################################################
# ACTUAL SCRIPT - PLAYBOOK_GRAPHICAL_ENVIRONMENTS
#####################################################################

playbook_kde() {
    package_file="src/packages/packages_kde.csv"
    file_pkg_fail="pkg_fail_kde.txt"

    echo "Updating packages, one moment..."

    check_pkgmgr_apt \
        && apt update \
            > /dev/null 2>&1 \
        && install_pkg_apt whiptail \
            > /dev/null 2>&1

    check_pkgmgr_pacman \
        && pacman -Sy \
            > /dev/null 2>&1 \
        && install_pkg_pacman libnewt \
            > /dev/null 2>&1

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

    install_browser

    return 0
}

playbook_gnome() {
    package_file="src/packages/packages_gnome.csv"
    file_pkg_fail="pkg_fail_gnome.txt"

    echo "Updating packages, one moment..."

    check_pkgmgr_apt \
        && apt update \
            > /dev/null 2>&1 \
        && install_pkg_apt whiptail \
            > /dev/null 2>&1

    check_pkgmgr_pacman \
        && pacman -Sy \
            > /dev/null 2>&1 \
        && install_pkg_pacman libnewt \
            > /dev/null 2>&1

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

    # post install GNOME fixes for machines that ARE NOT Ubuntu
    check_linux_install "ubuntu" \
        || fixes_post_install_gnome

    #check_linux_install "arch" \
    #    && systemctl enable gdm

    #check_linux_install "artix" \
    #    && install_pkg_pacman gdm-runit \
    #    && ln -s /etc/runit/sv/gdm /run/runit/service

    install_browser

    return 0
}

playbook_dwm() {
    package_file="src/packages/packages_dwm.csv"
    file_pkg_fail="pkg_fail_dwm.txt"

    echo "Updating packages, one moment..."

    check_pkgmgr_apt \
        && apt update \
            > /dev/null 2>&1 \
        && install_pkg_apt whiptail \
            > /dev/null 2>&1

    check_pkgmgr_pacman \
        && pacman -Sy \
            > /dev/null 2>&1 \
        && install_pkg_pacman libnewt \
            > /dev/null 2>&1

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
                || echo "Failed to install ${pkg}." >> pkg_fail_dwm.txt
        done

    install_loop \
        || error "Failed during the install loop."

    # post install DWM fixes
    fixes_post_install_dwm

    return 0
}

playbook_graphical_environment() {
    [ "$graphical_environment" = "dwm" ] \
        && playbook_dwm \
        && return 0

    [ "$graphical_environment" = "gnome" ] \
        && playbook_gnome \
        && return 0

    [ "$graphical_environment" = "kde" ] \
        && playbook_kde \
        && return 0
}
