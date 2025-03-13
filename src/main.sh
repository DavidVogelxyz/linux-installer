#!/bin/sh

#set -x

# source the commands
source lib.sh

get_os # sets `setup_os`

get_uefi # sets `uefi` (0 is "legacy BIOS")

get_disks || error # sets `disk_count` and `disk_selected`

set_partition_names

get_ram_size # set `ram_size` in the format of `xyGB`

check_so_far # checks progress

format_disk

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
