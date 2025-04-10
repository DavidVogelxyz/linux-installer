#!/bin/sh

#####################################################################
# FUNCTIONS - PACKAGE INSTALLATION
#####################################################################

error_install() {
    echo "Failed to install \`$1\`." >> pkg_fail.txt
}

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

#####################################################################
# FUNCTIONS - INSTALLATION LOOPS
#####################################################################

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
    ([ -f "$package_file" ] && cp "$package_file" "/tmp/${package_file##*/}") \
        && sed -i '/^#/d' "/tmp/${package_file##*/}" \
        || curl -Ls "$list_packages" | sed '/^#/d' > "/tmp/${package_file##*/}"
}

install_loop_read() {
    curr_dir="$(pwd)"
    pkg_check_name="pkg_${install_os_selected}"

    total=$(wc -l < "/tmp/${package_file##*/}")
    n="0"

    while IFS="," read -r tag pkg comment pkg_debian pkg_arch pkg_artix pkg_ubuntu; do
        n=$((n + 1))

        # `!` allows the script to print the value of `pkg_${install_os_selected}`
        # if value of `pkg_check_name` is `skip`, skips to the next package
        [ "${!pkg_check_name}" == "skip" ] \
            && continue

        echo "$comment" | grep -q "^\".*\"$" \
            && comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"

        [ ! -z "${!pkg_check_name}" ] \
            && pkg="${!pkg_check_name}"

        [ "$tag" == "A" ] \
            && check_pkgmgr_pacman \
            && install_loop_install_aur "$pkg" "$comment" \
            && continue

        [ "$tag" == "G" ] \
            && install_loop_install_git "$pkg" "$comment" \
            && continue

        install_loop_install_default "$pkg" "$comment"
    done < "/tmp/${package_file##*/}"

    cd "$curr_dir" \
        || return 1
}

install_loop() {
    prep_packages_file \
        || error "Failed to prep the package file."

    install_loop_read
}
