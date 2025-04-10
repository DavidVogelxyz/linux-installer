#!/bin/sh

#####################################################################
# FUNCTIONS - CHECK_INSTALL_OS
#####################################################################

check_install_os() {
    [ "$install_os_selected" == "$1" ]
}

#####################################################################
# FUNCTIONS - CHECK_PKGMGR
#####################################################################

check_pkgmgr_apt() {
    check_install_os "debian" \
        || check_install_os "ubuntu"
}

check_pkgmgr_pacman() {
    check_install_os "arch" \
        || check_install_os "artix"
}

#####################################################################
# FUNCTIONS - CHECK_PATH
#####################################################################

# check if path is link
check_path_link() {
    [ -L "$1" ]
}

# check if path is file
check_path_file() {
    [ -f "$1" ]
}
