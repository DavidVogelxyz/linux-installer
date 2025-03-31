#!/bin/sh

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
# sources library file, or error
source_lib \
    || error "Failed to source the library file."

grep -q "artix" /etc/os-release \
    && (pacman -S --noconfirm --needed libnewt || error "Are you sure you're running as root?")

# informs the user of how the script works, or error
welcome_screen \
    || error "Failed at the welcome screen."

# gather information
# gets info about system, with little user input, or error
get_setup_info \
    || error "Failed to get setup info."

# ask about partition scheme, encryption, etc
get_partition_info

# if Ubuntu image, configures `debootstrap`
check_setup_os "ubuntu" \
    && ask_debootstrap

# gets other user info for setting up new user
get_other_setup_info \
    || error "Failed to get other setup info."

# asks the users to confirm everything before running, or error
ask_confirm_inputs \
    || error "Failed to confirm inputs."

# perform chores
# formats the disk, or error
run_format_disk \
    || error "Failed to format disk."

# makes file systems, or error
make_file_systems \
    || error "Failed to make file systems."

# mounts the file systems, or error
mount_file_systems \
    || error "Failed to mount file systems."

# begin install
# probably want to use a match (case) function in the future
# runs basestrap on Artix images; exit on success
check_setup_os "artix" \
    && run_basestrap \
    && exit 0

# runs pacstrap on Arch images; exit on success
check_setup_os "arch" \
    && run_pacstrap \
    && exit 0

# runs debootstrap on Ubuntu images; exit on success
check_setup_os "ubuntu" \
    && run_debootstrap \
    && exit 0
