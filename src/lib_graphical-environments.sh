#!/bin/sh

export username="test"
export install_os_selected="artix"
export repodir="/home/$username/.local/src"

# REQUIRES THE FOLLOWING VARIABLES TO BE ALREADY SET:
# username
# install_os_selected
# repodir

aurhelper="yay"
export TERM=ansi

list_packages="https://raw.githubusercontent.com/DavidVogelxyz/debian-setup/master/packages.csv"

#####################################################################
# FUNCTIONS
#####################################################################

# prints argument to STDERR and exits
error() {
    echo "$1" >&2 \
        && exit 1
}

# check if path is link
check_path_link() {
    [ -L "$1" ]
}

# check if path is file
check_path_file() {
    [ -f "$1" ]
}

arch_aur_prep() {
    # Allow user to run sudo without entering a password.
    # Since AUR programs must be installed in a fakeroot environment,
    # this is required for all builds with AUR packages.
    trap 'rm -f /etc/sudoers.d/setup-temp' HUP INT QUIT TERM PWR EXIT

    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/setup-temp
    echo "Defaults:%wheel,root runcwd=*" >> /etc/sudoers.d/setup-temp
}

arch_add_arch_mirror() {
    check_install_os "arch" \
        && {
            install_pkg_pacman archlinux-keyring
        } \
        && return 0

    check_install_os "artix" \
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
# FUNCTIONS - CHECK_INSTALL_OS
#####################################################################

check_install_os() {
    [ "$install_os_selected" == "$1" ]
}

check_pkgmgr_apt() {
    check_install_os "debian" \
        || check_install_os "ubuntu"
}

check_pkgmgr_pacman() {
    check_install_os "arch" \
        || check_install_os "artix"
}

error_install() {
    echo "Failed to install \`$1\`." >> "$file_pkg_fail"
}

#####################################################################
# FUNCTIONS - INSTALLATION
#####################################################################

install_pkg_aur() {
    sudo -u "$username" $aurhelper -S --noconfirm "$1" \
        > /dev/null 2>&1
}

install_pkg_git() {
    sudo -u "$username" git -C "$repodir" clone \
        --depth 1 \
        --single-branch \
        --no-tags \
        -q \
        "$1" "$dir" \
        || {
            cd "$dir" \
                || return 1

            sudo -u "$username" git pull --force origin master
        }

    cd "$dir" \
        || exit 1

    make \
        > /dev/null 2>&1

    make install \
        > /dev/null 2>&1

    cd /tmp \
        || return 1
}

install_pkg_apt() {
    apt install -y "$1" \
        > /dev/null 2>&1
}

install_pkg_pacman() {
    pacman --noconfirm --needed -S "$1" \
        > /dev/null 2>&1
}

install_pkg() {
    check_pkgmgr_apt \
        && install_pkg_apt "$1" \
        && return 0

    check_pkgmgr_pacman \
        && install_pkg_pacman "$1" \
        && return 0
}

install_loop_install_aur() {
    whiptail \
        --title "Package Installation" \
        --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" \
        9 70

    install_pkg_aur "$1" \
        || error_install "$1"
}

install_loop_install_git() {
    progname="${1##*/}"
    dir="$repodir/$progname"

    whiptail \
        --title "Package Installation" \
        --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $progname $2" \
        9 70

    install_pkg_git "$1" \
        || error_install "$1"
}

install_loop_install_default() {
    whiptail \
        --title "Package Installation" \
        --infobox "Installing \`$1\` ($n of $total). $1 $2" \
        9 70

    install_pkg "$1" \
        || error_install "$1"
}

prep_packages_file() {
    packfile_changethis="packages_dwm.csv"

    ([ -f "$packfile_changethis" ] && cp "$packfile_changethis" "/tmp/${packfile_changethis}") \
        && sed -i '/^#/d' "/tmp/${packfile_changethis}" \
        || curl -Ls "$list_packages" | sed '/^#/d' > "/tmp/${packfile_changethis}"
}

install_loop_read() {
    curr_dir="$(pwd)"
    file_pkg_fail="pkg_fail_dwm.txt"

    total=$(wc -l < "/tmp/${packfile_changethis}")
    n="0"

    while IFS="," read -r tag pkg comment pkg_debian pkg_arch pkg_artix pkg_ubuntu; do
        n=$((n + 1))
        pkg_check_name="pkg_${install_os_selected}"

        # `!` allows the script to print the value of `pkg_${install_os_selected}`
        # if value of `pkg_check_name` is `skip`, skips to the next package
        [ "${!pkg_check_name}" == "skip" ] \
            && continue

        echo "$comment" | grep -q "^\".*\"$" \
            && comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"

        [ ! -z "${!pkg_check_name}" ] \
            && [ "$tag" == "A" ] \
            && install_loop_install_aur "${!pkg_check_name}" "$comment" \
            && continue

        [ "$tag" == "G" ] \
            && install_loop_install_git "$pkg" "$comment" \
            && continue

        install_loop_install_default "$pkg" "$comment"
    done < "/tmp/${packfile_changethis}"

    cd "$curr_dir" \
        || return 1
}

install_loop() {
    prep_packages_file

    install_loop_read
}

#####################################################################
# FUNCTIONS - CHECK_INSTALL_OS
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
        || error "Failed to change directory to voidrice for additional dotfile deployment."

    run_git-clone "https://github.com/LukeSmithxyz/voidrice" "$repodir/voidrice"

    mapfile -t list_of_files < <(find "$repodir/voidrice/.local/bin" -maxdepth 1 -type f | sed 's/^\.\///g' | sort)

    for file in "${list_of_files[@]}"; do
        file=$(basename "$file")

        [ -e "$file" ] \
            || ln -s "../src/voidrice/.local/bin/${file}" .
    done

    # getting extra progs into `~/.local/bin/statusbar`
    cd "/home/${username}/.local/bin/statusbar" \
        || error "Failed to change directory to voidrice for additional dotfile deployment."

    mapfile -t list_of_files < <(find "$repodir/voidrice/.local/bin/statusbar" -maxdepth 1 -type f | sed 's/^\.\///g' | sort)

    for file in "${list_of_files[@]}"; do
        file=$(basename "$file")

        [ -e "$file" ] \
            || ln -s "../../src/voidrice/.local/bin/statusbar/${file}" .
    done

    # set a wallpaper
    file_wallpaper="https://raw.githubusercontent.com/DavidVogelxyz/wallpapers/master/artists/muhammad-nafay/wallhaven-g8pmol.jpg"

    cd "/home/$username/.local/share"

    # get the wallpaper
    curl -LJO "$file_wallpaper"

    file_wallpaper=$(basename "$file_wallpaper")

    ln -s "$file_wallpaper" bg
}

#####################################################################
# ACTUAL SCRIPT - PLAYBOOK_GRAPHICAL_ENVIRONMENTS
#####################################################################

playbook_graphical_environments() {
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

    install_loop \
        || error "Failed during the install loop."

    # post install DWM fixes
    fixes_post_install_dwm
}
