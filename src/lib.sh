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

error() {
    echo "fail!" && exit 1
}

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
    # store disk names in an array
    mapfile -t list_disk_paths < <(lsblk | grep disk | awk '{print $1}')
    #list_disk_paths=$(lsblk | grep disk | awk '{print $1}')

    # store disk sizes in an array
    mapfile -t list_disk_sizes < <(lsblk | grep disk | awk '{print $4}')

    # how many disks?
    disk_count=${#list_disk_paths[@]}

    # instantiate `disk_selected`
    ask_for_disk_selected

    # if `disk_count` is 1, set it as the disk selected without asking the user
    #[[ $disk_count == "1" ]] \
    #    && disk_selected="${list_disk_paths[0]}"
}

ask_for_disk_selected() {
    disk_selected=$(whiptail \
        --title "Format Disk" \
        --menu "\\nPlease select the disk to format:" \
        25 78 16 \
        "$list_disk_paths" "| $list_disk_sizes" \
        3>&1 1>&2 2>&3 3>&1
    )
}

set_partition_names() {
    # could turn this into a loop...
    partition_boot_1="${disk_selected}1"
    partition_boot_2="${disk_selected}2"
    partition_boot_3="${disk_selected}3"
    partition_boot_4="${disk_selected}4"
    partition_boot_5="${disk_selected}5"
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
    echo "DISKS = ${list_disk_paths[@]}"
    echo "DISK SELECTED = $disk_selected"

    echo -e "\nOTHER:"
    echo "UEFI? = $uefi"
    echo "Partition 4 = $partition_boot_4"
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

#format_disk() {
#    devsel="/dev/${disk_selected}"
#
#    # a check for root user
#    sgdisk --print $devsel > /dev/null 2>&1 \
#        || echo "Are you sure you're running this as the root user?"
#
#    # wipe and puts on GPT signatures
#    sgdisk --zap-all $devsel
#
#    # PARTITIONS
#    sgdisk --new=1:0:+768M $devsel      # this is the boot partition (`/boot`)
#    sgdisk --new=2:0:+2M $devsel        # this is a GRUB partition
#    sgdisk --new=3:0:+128M $devsel      # this is an EFI partition
#    sgdisk --new=4:0:0 $devsel          # this creates a rootfs until the end of the drive
#
#    # TYPECODES
#    sgdisk \
#        --typecode=1:8301 \
#        --typecode=2:ef02 \
#        --typecode=3:ef00 \
#        --typecode=4:8301 \
#        $devsel
#
#    # LABELS
#    sgdisk \
#        --change-name=1:/boot \
#        --change-name=2:GRUB \
#        --change-name=3:EFI-SP \
#        --change-name=4:rootfs \
#        $devsel
#
#    # SET HYBRID SINCE BOTH BIOS AND UEFI
#    sgdisk --hybrid 1:2:3 $devsel
#}

format_disk() {
    devsel="/dev/${disk_selected}"

    # a check for root user
    # > /dev/null 2>&1
    sfdisk -d $devsel \
        || echo "Are you sure you're running this as the root user?"

    # lots of good new stuff to try with the sfdisk commands
    #sfdisk $devsel < templates/format_disk_*                   # to take a file as a "state"
    #sfdisk -d $devsel                                          # to view
}
