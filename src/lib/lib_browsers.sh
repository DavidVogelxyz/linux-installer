#!/bin/sh

#####################################################################
# FUNCTIONS - BRAVE
#####################################################################

setup_install_brave_apt() {
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
        && echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list \
        && apt update \
            > /dev/null 2>&1
}

setup_install_brave_rocky() {
    dnf install dnf-plugins-core \
        && dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
}

#####################################################################
# FUNCTIONS - LIBREWOLF
#####################################################################

install_librewolf_aur() {
    install_loop \
        || error "Failed during the install loop."
}

makeuserjs(){
    # Get the Arkenfox user.js and prepare it.
    arkenfox="$pdir/arkenfox.js"
    overrides="$pdir/user-overrides.js"
    userjs="$pdir/user.js"
    ln -fs "/home/$username/.config/firefox/larbs.js" "$overrides"
    [ ! -f "$arkenfox" ] && curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js" > "$arkenfox"
    cat "$arkenfox" "$overrides" > "$userjs"
    chown "$username:wheel" "$arkenfox" "$userjs"
}

fix_librewolf() {
    # All this below to get Librewolf installed with add-ons and non-bad settings.

    whiptail \
        --infobox "Setting \`LibreWolf\` browser privacy settings and add-ons..." \
        9 70

    browserdir="/home/$username/.librewolf"
    profilesini="$browserdir/profiles.ini"

    # Start librewolf headless so it generates a profile. Then get that profile in a variable.
    sudo -u "$username" librewolf --headless >/dev/null 2>&1 &
    sleep 7
    profile="$(sed -n "/Default=.*.default-default/ s/.*=//p" "$profilesini")"
    pdir="$browserdir/$profile"

    [ -d "$pdir" ] \
        && makeuserjs

    # Kill the now unnecessary librewolf instance.
    pkill -u "$username" librewolf \
        || return 0
}

#####################################################################
# FUNCTIONS - INSTALL_BROWSER
#####################################################################

install_browser() {
    # vars for "specific browsers"
    package_file="src/packages/packages_${browser_install}.csv"
    list_packages="https://raw.githubusercontent.com/DavidVogelxyz/linux-installer/master/src/packages/packages_${browser_install}.csv"
    file_pkg_fail="pkg_fail_${browser_install}.txt"

    # ARCH-BASED + LIBREWOLF
    check_pkgmgr_pacman \
        && [ "$browser_install" = "librewolf" ] \
        && install_librewolf_aur \
        && fix_librewolf \
        && return 0

    # APT + BRAVE
    check_pkgmgr_apt \
        && setup_install_brave_apt

    # ROCKY + BRAVE
    check_linux_install "rocky" \
        && setup_install_brave_rocky

    # vars for "browsers that can be handled with consolidated CSV"
    package_file="src/packages/packages_browsers.csv"
    list_packages="https://raw.githubusercontent.com/DavidVogelxyz/linux-installer/master/src/packages/packages_browsers.csv"
    file_pkg_fail="pkg_fail_browsers.txt"

    install_loop_browser \
        || error "Failed during the install loop."

    return 0
}
