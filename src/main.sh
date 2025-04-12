#!/bin/sh

#####################################################################
# SOURCE THE REQUIRED LIBRARY FILES
#####################################################################

# path to the library files
libraries=(
    "src/lib/lib_common.sh"
    "src/lib/lib_main.sh"
)

# sources file, if the path is a file
source_file() {
    [ -f "$1" ] && source "$1"
}

# prints argument to STDERR and exits
error() {
    echo "$1" >&2 \
        && exit 1
}

# sources library files, or error
for file in "${libraries[@]}"; do
    source_file "$file" \
        || error "Failed to source the \`$file\` library."
done

#####################################################################
# RUN THE PLAYBOOK
#####################################################################

# sets `linux_iso`, or error
get_linux_iso \
    || error "It appears that the OS image you're using isn't supported by this script. Sorry!"

# if `linux_iso` is `artix`, install `whiptail`
check_linux_iso "artix" \
    && (pacman -S --noconfirm --needed libnewt || error "Are you sure you're running as root?")

# WHIPTAIL 1
# informs the user of how the script works
welcome_screen \
    || error "Failed at the welcome screen."

# WHIPTAIL 2
# confirms with the user both the Linux distro of the ISO, as well as the Linux distro to install
set_linux_install \
    || error "Failed to properly set a Linux distribution to install."

# WHIPTAIL 3
# allows the user to choose (or refuse) a graphical environment
set_graphical_environment \
    || error "Failed to choose (or refuse) a graphical environment."

# WHIPTAIL 4
# allows the user to choose a web browser, if a graphical environment was chosen
set_browser_install \
    || error "Failed to choose a web browser."

# gather information
# gets info about system, with little user input, or error
get_setup_info \
    || error "Failed to get setup info."

# ask about partition scheme, encryption, etc
get_partition_info

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
check_linux_iso "artix" \
    && run_basestrap \
    && exit 0

# runs pacstrap on Arch images; exit on success
check_linux_iso "arch" \
    && run_pacstrap \
    && exit 0

# runs debootstrap on Ubuntu images; exit on success
check_linux_iso "ubuntu" \
    && run_debootstrap \
    && exit 0
