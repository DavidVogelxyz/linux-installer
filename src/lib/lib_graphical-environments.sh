#!/bin/sh

# REQUIRES THE FOLLOWING VARIABLES TO BE ALREADY SET:
# username
# linux_install
# repodir

#export username="test"
#export linux_install="artix"
export repodir="/home/$username/.local/src"

aurhelper="yay"
export TERM=ansi

#####################################################################
# FUNCTIONS - OTHER FUNCTIONS
#####################################################################

error_install() {
    echo "Failed to install \`$1\`." >> "$file_pkg_fail"
}

whiptail_check() {
    #echo "Updating packages, one moment..."

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
# FUNCTIONS - PLAYBOOK_KDE
#####################################################################

playbook_kde() {
    # installs KDE
    # function defined in `lib_kde.sh`
    install_kde

    # post install KDE fixes for Arch-based machines
    fix_kde

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_GNOME
#####################################################################

playbook_gnome() {
    # installs GNOME
    # function defined in `lib_gnome.sh`
    install_gnome

    # post install GNOME fixes for machines that ARE NOT Ubuntu
    check_linux_install "ubuntu" \
        || fix_gnome

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_DWM
#####################################################################

playbook_dwm() {
    # installs dwm
    # functions defined in `lib_dwm.sh`
    install_dwm

    # post install dwm fixes
    fix_dwm

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_COSMIC
#####################################################################

playbook_cosmic() {
    # installs cosmic
    # functions defined in `lib_cosmic.sh`
    install_cosmic

    # post install cosmic fixes
    fix_cosmic

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_CINNAMON
#####################################################################

playbook_cinnamon() {
    # installs cinnamon
    # functions defined in `lib_cinnamon.sh`
    install_cinnamon

    # post install cinnamon fixes
    fix_cinnamon

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_XFCE
#####################################################################

playbook_xfce() {
    # installs xfce
    # functions defined in `lib_xfce.sh`
    install_xfce

    # post install xfce fixes
    fix_xfce

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_MATE
#####################################################################

playbook_mate() {
    # installs mate
    # functions defined in `lib_mate.sh`
    install_mate

    # post install mate fixes
    fix_mate

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_LXQT
#####################################################################

playbook_lxqt() {
    # installs lxqt
    # functions defined in `lib_lxqt.sh`
    install_lxqt

    # post install lxqt fixes
    fix_lxqt

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_LXDE
#####################################################################

playbook_lxde() {
    # installs lxde
    # functions defined in `lib_lxde.sh`
    install_lxde

    # post install lxqt fixes
    fix_lxde

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_BUDGIE
#####################################################################

playbook_budgie() {
    # installs budgie
    # functions defined in `lib_budgie.sh`
    install_budgie

    # post install budgie fixes
    fix_budgie

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_GRAPHICAL_ENVIRONMENTS
#####################################################################

playbook_graphical_environment() {
    package_file="src/packages/packages_${graphical_environment}.csv"
    file_pkg_fail="pkg_fail_${graphical_environment}.txt"

    # checks for `whiptail`
    whiptail_check

    case "$graphical_environment" in
        dwm)        playbook_dwm ;;
        gnome)      playbook_gnome ;;
        kde)        playbook_kde ;;
        cosmic)     playbook_cosmic ;;
        cinnamon)   playbook_cinnamon ;;
        xfce)       playbook_xfce ;;
        mate)       playbook_mate ;;
        lxqt)       playbook_lxqt ;;
        lxde)       playbook_lxde ;;
        budgie)     playbook_budgie ;;
    esac

    # installs the selected web browser
    install_browser

    return 0
}
