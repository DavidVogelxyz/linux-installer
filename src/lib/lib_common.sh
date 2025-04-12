#!/bin/sh

#####################################################################
# FUNCTIONS - CHECK_LINUX_INSTALL
#####################################################################

check_linux_install() {
    [ "$linux_install" == "$1" ]
}

#####################################################################
# FUNCTIONS - CHECK_PKGMGR
#####################################################################

check_pkgmgr_apt() {
    check_linux_install "debian" \
        || check_linux_install "ubuntu"
}

check_pkgmgr_pacman() {
    check_linux_install "arch" \
        || check_linux_install "artix"
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
