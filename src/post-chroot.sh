#!/bin/sh

#set -x

# variables and functions for sourcing the library file
library="src/lib_post-chroot.sh"
#variables_file="vars.txt"

source_file() {
    [ -f "$1" ] && source "$1"
}

error() {
    echo "$1" >&2 \
        && exit 1
}

source_file "$library" || error "Failed to source the library file." # sources library file, or error
#source_file "$variables_file" || error # sources variables file, or error

# continue configuration and setup

# runs chroot on Arch and Artix images
check_install_os "arch" \
    || check_install_os "artix" \
    && chroot_from_arch

# runs chroot on Debian and Ubuntu images
check_install_os "debian" \
    || check_install_os "ubuntu" \
    && chroot_from_debootstrap
