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

run_git-clone() {
    # add some error correction:
    # - what if the repo already exists?
    # - possible to check the hashes and only clone if not a repo?
    git clone "$1" "$2" > /dev/null 2>&1
}

install_brave_apt() {
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
        && echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list \
        && apt update \
            > /dev/null 2>&1 \
        && install_pkg_apt brave-browser
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
# FUNCTIONS - PLAYBOOK_KDE
#####################################################################

playbook_kde() {
    # installs KDE
    # function defined in `lib_kde.sh`
    install_kde

    # installs the selected web browser
    install_browser

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

    # installs the selected web browser
    install_browser

    return 0
}

#####################################################################
# FUNCTIONS - PLAYBOOK_DWM
#####################################################################

playbook_dwm() {
    # installs DWM
    # functions defined in `lib_dwm.sh`
    install_dwm

    # post install DWM fixes
    fix_dwm

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
