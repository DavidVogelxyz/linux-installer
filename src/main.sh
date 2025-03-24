#!/bin/sh

#set -x

# variables and functions for sourcing the library file
library="src/lib.sh"

source_lib() {
    [ -f $library ] && source $library
}

error() {
    echo "$1" >&2 \
        && exit 1
}

# prelude
source_lib || error "Failed to source the library file." # sources library file, or error
grep -q "artix" /etc/os-release \
    && (pacman -S --noconfirm --needed libnewt || error "Are you sure you're running as root?")
welcome_screen || error "Failed at the welcome screen." # informs the user of how the script works, or error

# gather information
get_setup_info || error "Failed to get setup info." # gets info about system, with little user input, or error
get_partition_info # ask about partition scheme, encryption, etc
check_setup_os "ubuntu" && ask_debootstrap # if Ubuntu image, configures and runs `debootstrap`
get_other_setup_info || error "Failed to get other setup info." # gets other user info for setting up new user
ask_confirm_inputs || error "Failed to confirm inputs." # asks the users to confirm everything before running, or error

# perform chores
run_format_disk || error "Failed to format disk." # formats the disk, or error
make_file_systems || error "Failed to make file systems." # makes file systems, or error
mount_file_systems || error "Failed to mount file systems." # mounts the file systems, or error

# begin install
check_setup_os "artix" && run_basestrap && exit 0 # runs basestrap on Artix images
check_setup_os "arch" && run_pacstrap && exit 0 # runs pacstrap on Arch images
check_setup_os "ubuntu" && run_debootstrap && exit 0 # runs debootstrap on Ubuntu images
