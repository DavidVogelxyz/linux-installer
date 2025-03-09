#!/bin/sh

################################
# VARIABLES
################################

# HARDCODED, BUT SHOULDN'T BE

lvm_name="cryptlvm"
release=""
release_debian="bookworm"
release_ubuntu="noble"

# HARDCODED, LEGIT

## PATHS
path_dev="/dev"
path_dev_mapper="/dev/mapper"

## LISTS

list_release_debian=(
    "bookworm"  # Debian 12
    "bullseye"  # Debian 11
)

list_release_ubuntu=(
    "noble"     # Ubuntu 24
    "jammy"     # Ubuntu 22
)

os_supported=(
    "arch"
    "artix"
    "debian"
    "ubuntu"
)

################################
# FUNCTIONS
################################

#error() {
#
#}

get_os() {
    for os in "${os_supported[@]}"; do
        grep "ID=$os" /etc/os-release > /dev/null 2>&1 \
            && export setup_os="$os" \
            && break
    done
}

get_uefi() {
    uefi="0"

    # UEFI check #1
    mount | grep efi > /dev/null 2>&1 \
        && uefi="1"

    # UEFI check #2
    ls /sys/firmware/efi > /dev/null 2>&1 \
        && uefi="1"
}

get_disks() {
    # store the `lsblk` output into an array
    mapfile -t list_disks < <(lsblk | grep disk | awk '{print $1}')

    # how many disks?
    disk_count=${#list_disks[@]}

    # instantiate `disk_selected`
    disk_selected="not selected yet"

    # if `disk_count` is 1, set it as the disk selected without asking the user
    [[ $disk_count == "1" ]] \
        && disk_selected="${list_disks[0]}"
}

set_partition_names() {
    # could turn this into a loop...
    partition_boot_sda1="${disk_selected}1"
    partition_boot_sda2="${disk_selected}2"
    partition_boot_sda3="${disk_selected}3"
    partition_boot_sda4="${disk_selected}4"
    partition_boot_sda5="${disk_selected}5"
}

get_ram_size() {
    # `--si` gets the human readable `-h` in units of "GB"
    ram_size=$(free -th --si | grep "Total" | awk '{print $2}')
}

check_so_far() {
    echo -e "\nSTATUS:"
    echo "OS = $setup_os"

    echo -e "\nDISKS:"
    echo "DISK COUNT = $disk_count"
    echo "DISKS = ${list_disks[@]}"
    echo "DISK SELECTED = $disk_selected"

    echo -e "\nOTHER:"
    echo "UEFI? = $uefi"
    echo "Partition 4 = $partition_boot_sda4"
    echo "RAM: $ram_size"
    echo "PATH_DEV: $path_dev"
    echo "PATH_DEV_MAPPER: $path_dev_mapper"
    echo "LVM NAME: $lvm_name"

    echo -e "\nTHE OTHER OTHER:"
    echo "SUPPORTED DEBIAN RELEASES: ${list_release_debian[@]}"
    echo "SUPPORTED UBUNTU RELEASES: ${list_release_ubuntu[@]}"
    echo "SELECTED DEBIAN RELEASE: $release_debian"
    echo "SELECTED UBUNTU RELEASE: $release_ubuntu"
}
