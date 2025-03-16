#!/bin/sh

#set -x

# variables and functions for sourcing the library file
library="src/lib.sh"

source_lib() {
    [ -f $library ] && source $library
}

error() {
    echo -e "\nfailed to source the library file!" \
        && exit 1
}

# prelude
source_lib || error # sources library file, or error
welcome_screen || error # informs the user of how the script works, or error

# gather information
get_setup_info || error # gets info about system, with little user input, or error
get_partition_info # ask about partition scheme, encryption, etc
check_image_ubuntu && ask_debootstrap # if Ubuntu image, configures and runs `debootstrap`
ask_confirm_inputs || error # asks the users to confirm everything before running, or error

# perform chores
run_format_disk || error # formats the disk, or error
make_file_systems || error # makes file systems, or error
mount_file_systems || error # mounts the file systems, or error

# begin install
check_image_artix && run_basestrap # runs basestrap on Artix images
check_image_arch && run_pacstrap # runs pacstrap on Arch images
check_image_ubuntu && run_debootstrap # runs debootstrap on Ubuntu images
