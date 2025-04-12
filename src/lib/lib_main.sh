#!/bin/sh

#####################################################################
# VARIABLES
#####################################################################

# HARDCODED, BUT SHOULDN'T BE
export lvm_name="cryptlvm"

# HARDCODED, LEGIT
export TERM=ansi

## PATHS
export path_dev="/dev"
export path_dev_mapper="/dev/mapper"

## LIST OF SUPPORTED OS
linux_supported=(
    "arch"
    "artix"
    "debian"
    "ubuntu"
)

#####################################################################
# FUNCTIONS - PRE-FLIGHT CHECKS
#####################################################################

get_linux_iso() {
    # don't like that the grep is O(n)
    # would it be faster to search once, grab `ID`, and then check against supported OS?
    # probably
    for os in "${linux_supported[@]}"; do
        grep -q "ID=$os" /etc/os-release \
            && export linux_iso="$os" \
            && break
    done
}

check_linux_iso() {
    [ "$linux_iso" == "$1" ]
}

get_ram_size() {
    # `--si` gets the human readable `-h` in units of "GB"
    ram_size=$(free -th --si | grep "Total" | awk '{print $2}')
}

#####################################################################
# FUNCTIONS - FORMAT_DISK
#####################################################################

format_disk_warning_screen() {
    whiptail \
        --title "Format Disk - WARNING!" \
        --yesno "\\nWARNING!
            \\nThis script is about to format \"$path_dev/$disk_selected\".
            \\nThis will irrevocably wipe the data on this disk.
            \\nThe utility SHOULD be able to detect a \"disk in use\" and fail before wiping.
            \\nBut, this is not a guarantee!
            \\nAre you sure you want to do this?" \
        --yes-button "Let's go!" \
        --no-button "No thanks." \
        25 78 \
        3>&1 1>&2 2>&3 3>&1
}

format_disk() {
    whiptail \
        --title "Format Disk" \
        --infobox "Formatting disk..." \
        8 78

    sfdisk ${path_dev}/${disk_selected} < src/templates/format_disk/${uefi}_standard \
        || error "Failed to format disk! Is the disk currently in use?"
}

set_partition_names() {
    # set the first partition as "/boot"
    # may need to change in the future
    export partition_boot=$(sfdisk -d ${path_dev}/${disk_selected} | grep start | head -1 | awk '{print $1}')

    # set the last partition as "rootfs"
    # may need to change in the future
    export partition_rootfs=$(sfdisk -d ${path_dev}/${disk_selected} | grep start | tail -1 | awk '{print $1}')

    # set the encryption partition
    [ "$encryption" = true ] \
        && export partition_crypt="${path_dev_mapper}/${lvm_name}" \
        || return 0
}

encrypt_drive() {
    # assert `encryption` is true, or exit function
    [ "$encryption" = true ] \
        || return 0

    whiptail \
        --title "Encrypt Disk" \
        --infobox "Encrypting disk..." \
        8 78

    echo "${pass_encrypt}" | cryptsetup -q luksFormat "$partition_rootfs" \
        && echo "${pass_encrypt}" | cryptsetup open "$partition_rootfs" "$lvm_name" \
        && unset pass_encrypt \
        || error "Failed to set the encryption password."
}

create_swap() {
    # assert `swapanswer` is true, or exit function
    [ "$swapanswer" = true ] \
        || return 0

    [ "$encryption" = false ] \
        && {
            export volume_physical="${partition_rootfs}"
        }

    [ "$encryption" = true ] \
        && {
            export volume_physical="${partition_crypt}"
        }

    export group_volume="vg${linux_install}"
    export swap_name="swap_1"
    export volume_logical_swap="${path_dev_mapper}/${group_volume}-${swap_name}"
    export volume_logical_root="${path_dev_mapper}/${group_volume}-root"

    pvcreate "${volume_physical}" > /dev/null 2>&1
    vgcreate "${group_volume}" "${volume_physical}" > /dev/null 2>&1
    lvcreate -L "${ram_size}" -n "${swap_name}" "${group_volume}" > /dev/null 2>&1
    lvcreate -l 100%FREE -n root "${group_volume}" > /dev/null 2>&1
}

run_format_disk() {
    format_disk_warning_screen || error "Failed at the format disk warning screen."

    format_disk || error "Failed to format disk! Is the disk currently in use?"

    set_partition_names || error "Failed to set partition names."

    encrypt_drive || error "Failed to encrypt the drive."

    create_swap || error "Failed to create swap partition."
}

#####################################################################
# FUNCTIONS - MAKE AND MOUNT FILE SYSTEMS
#####################################################################

#run_cryptsetup() {}

create_file_systems() {
    whiptail \
        --title "File Systems" \
        --infobox "Making file systems..." \
        8 78

    mkfs.fat -F32 "$partition_boot" > /dev/null 2>&1

    [ "$swapanswer" = true ] \
        && mkfs.ext4 "$volume_logical_root" > /dev/null 2>&1 \
        && mkswap "$volume_logical_swap" > /dev/null 2>&1 \
        && return 0

    [ "$encryption" = false ] \
        && mkfs.ext4 "$partition_rootfs" > /dev/null 2>&1 \
        && return 0

    [ "$encryption" = true ] \
        && mkfs.ext4 "$partition_crypt" > /dev/null 2>&1 \
        && return 0
}

mount_file_systems() {
    whiptail \
        --title "File Systems" \
        --infobox "Mounting file systems..." \
        8 78

    [ "$swapanswer" = false ] \
        && [ "$encryption" = false ] \
        && mount "$partition_rootfs" /mnt

    [ "$swapanswer" = false ] \
        && [ "$encryption" = true ] \
        && mount "$partition_crypt" /mnt

    [ "$swapanswer" = true ] \
        && mount "$volume_logical_root" /mnt

    mkdir -p /mnt/boot
    mount "$partition_boot" /mnt/boot
}

bind_mounts() {
    whiptail \
        --title "Bind Mounts" \
        --infobox "Binding certain devices to the chroot environment..." \
        8 78

    for d in sys dev proc; do
        mount --rbind /$d /mnt/$d \
            && mount --make-rslave /mnt/$d
    done
}

#####################################################################
# FUNCTIONS - PLAYBOOK_MAIN
#####################################################################

playbook_main() {
    # sets `linux_iso`, or error
    # function defined in `lib_main.sh`
    get_linux_iso \
        || error "It appears that the OS image you're using isn't supported by this script. Sorry!"

    # if `linux_iso` is `artix`, install `whiptail`
    # function defined in `lib_main.sh`
    check_linux_iso "artix" \
        && (pacman -S --noconfirm --needed libnewt || error "Are you sure you're running as root?")

    # WHIPTAIL 1
    # informs the user of how the script works
    # function defined in `lib_whiptail.sh`
    welcome_screen \
        || error "Failed at the welcome screen."

    # WHIPTAIL 2
    # confirms with the user both the Linux distro of the ISO, as well as the Linux distro to install
    # function defined in `lib_whiptail.sh`
    set_linux_install \
        || error "Failed to properly set a Linux distribution to install."

    # WHIPTAIL 3
    # allows the user to choose (or refuse) a graphical environment
    # function defined in `lib_whiptail.sh`
    set_graphical_environment \
        || error "Failed to choose (or refuse) a graphical environment."

    # WHIPTAIL 4
    # allows the user to choose a web browser, but only if a graphical environment was chosen
    # function defined in `lib_whiptail.sh`
    set_browser_install \
        || error "Failed to choose a web browser."

    # WHIPTAIL 5
    # function asks the user about BIOS/UEFI, and about which disk to install to
    # function defined in `lib_whiptail.sh`
    get_setup_info \
        || error "Failed to get setup info."

    # WHIPTAIL 6
    # function ask about partition scheme, encryption, etc
    # function defined in `lib_whiptail.sh`
    get_partition_info \
        || error "Failed to configure partitioning, or encryption."

    # WHIPTAIL 7
    # asks question about root pass, username, user pass, hostname, domain, timezone, region, swap
    # function defined in `lib_whiptail.sh`
    get_other_setup_info \
        || error "Failed to get other setup info."

    # WHIPTAIL 8
    # asks the users to confirm everything before running
    # function defined in `lib_whiptail.sh`
    ask_confirm_inputs \
        || error "Failed to confirm inputs."

    # WHIPTAIL 9
    # formats the disk, according to the user's input
    # function defined in `lib_main.sh`
    run_format_disk \
        || error "Failed to format disk."

    # creates file systems
    # function defined in `lib_main.sh`
    create_file_systems \
        || error "Failed to create file systems."

    # mounts the file systems
    # function defined in `lib_main.sh`
    mount_file_systems \
        || error "Failed to mount file systems."

    # now, perform the bootstrap
    # probably want to use a match (case) function in the future
    # functions defined in `lib_bootstrap.sh`

    # runs debootstrap on Ubuntu images; exit on success
    check_linux_iso "ubuntu" \
        && run_debootstrap \
        && exit 0

    # runs pacstrap on Arch images; exit on success
    check_linux_iso "arch" \
        && run_pacstrap \
        && exit 0

    # runs basestrap on Artix images; exit on success
    check_linux_iso "artix" \
        && run_basestrap \
        && exit 0
}
