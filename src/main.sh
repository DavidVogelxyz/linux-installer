#!/bin/sh

#set -x

# source the commands
library="src/lib.sh"

[ -f $library ] && source $library \
    || {
        echo -e "\nfailed to source the library file!" \
            && exit 1
    }

welcome_screen || error # informs the user of how the script works

get_setup_info || error # gets info about system, with little user input

get_partition_info # ask about partition scheme, encryption, etc

check_image_ubuntu && ask_debootstrap # if Ubuntu image, configures and runs `debootstrap`

ask_confirm_inputs || error # asks the users to confirm everything before running

run_format_disk || error # formats the disk

make_file_systems || error # makes file systems

mount_file_systems || error # mounts the file systems

check_image_ubuntu && run_debootstrap # runs debootstrap

################################
# Pre-chroot
################################

#get_os

#get_uefi

#get_disks

#get_ram_size # only needs to run if a swap is being created

################################
# Post-chroot
################################

#get_os
