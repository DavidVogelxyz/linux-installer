#!/bin/sh

#set -x

# source the commands
{
    library="lib.sh"
    [ -f $library ] && source $library
} \
    || \
    {
        library="src/lib.sh"
        [ -f src/lib.sh ] && source src/lib.sh
    }

welcome_screen || error # informs the user of how the script works

get_setup_info # gets info about system, with little user input

run_partition_setup # ask about partition scheme, encryption, etc

run_debootstrap # if Ubuntu image, configures and runs `debootstrap`

ask_confirm_inputs # asks the users to confirm everything before running

#format_disk

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
