#!/bin/sh

#set -x

# variables and functions for sourcing the library file
library="src/lib_post-chroot.sh"

source_lib() {
    [ -f $library ] && source $library
}

error() {
    echo -e "\nfailed to source the library file!" \
        && exit 1
}

source_lib || error # sources library file, or error

# continue configuration and setup
check_install_artix && chroot_from_arch # runs chroot on Artix images
check_install_arch && chroot_from_arch # runs chroot on Arch images
check_install_debian && chroot_from_debootstrap # runs chroot on Debian images
check_install_ubuntu && chroot_from_debootstrap # runs chroot on Ubuntu images
