#!/bin/sh

################################
# VARIABLES
################################

# HARDCODED, BUT SHOULDN'T BE
lvm_name="cryptlvm"

# HARDCODED, LEGIT

## PATHS
path_dev="/dev"
path_dev_mapper="/dev/mapper"

## LISTS

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

welcome_screen() {
    whiptail \
        --title "Welcome!" \
        --yesno "On the next few screens, you will be asked some questions.
            \\nThe script will configure and install Linux based on the provided answers.
            \\nYou will have a chance to exit out of the script before any changes are made." \
        --yes-button "Let's go!" \
        --no-button "No thanks." \
        25 78 \
        3>&1 1>&2 2>&3 3>&1
}

get_setup_os() {
    # don't like that the grep is O(n)
    # would it be faster to search once, grab `ID`, and then check against supported OS?
    # probably
    for os in "${os_supported[@]}"; do
        grep "ID=$os" /etc/os-release > /dev/null 2>&1 \
            && export setup_os="$os" \
            && break
    done
}

ask_uefi() {
    # `whiptail --default-item` wasn't working; so, alternative way to set default
    [ $uefi = false ] \
        && choices=(
            "bios" "| No, I only want compatibility with legacy BIOS."
            "uefi" "| Yes, I want to use UEFI (including hybrid configuration)."
        )

    # `whiptail --default-item` wasn't working; so, alternative way to set default
    [ $uefi = true ] \
        && choices=(
            "uefi" "| Yes, I want to use UEFI (including hybrid configuration)."
            "bios" "| No, I only want compatibility with legacy BIOS."
        )

    uefi=$(whiptail \
        --title "UEFI configuration" \
        --menu "\\nThis script noticed the following about your system:
            \\n    UEFI is currently set to ${uefi}.
            \\nIf you are unsure about the answer to the following question, keep the response the same as the above line.
            \\nDo you want to set this computer up with UEFI?" \
        25 78 2 \
        "${choices[@]}" \
        3>&1 1>&2 2>&3 3>&1
    )
}

get_uefi() {
    uefi=false

    # UEFI check #1
    mount | grep efi > /dev/null 2>&1 \
        && uefi=true

    # UEFI check #2
    ls /sys/firmware/efi > /dev/null 2>&1 \
        && uefi=true

    ask_uefi
}

get_disks() {
    # store disk names in an array
    mapfile -t list_disk_paths < <(lsblk | grep disk | awk '{print $1}')

    # store disk sizes in an array
    mapfile -t list_disk_sizes < <(lsblk | grep disk | awk '{print $4}')

    # how many disks?
    disk_count=${#list_disk_paths[@]}

    # ask the user to select a disk
    ask_for_disk_selected
}

ask_for_disk_selected() {
    choices=()
    n=0

    # generate "correct" array for whiptail
    while [ $n -lt $disk_count ]; do
        choices+=("${list_disk_paths[$n]}" "| ${list_disk_sizes[$n]}")
        ((n+=1))
    done

    disk_selected=$(whiptail \
        --title "Format Disk - Select Disk" \
        --menu "\\nPlease select the disk to format:" \
        25 78 10 \
        "${choices[@]}" \
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

#ask_partition_scheme() {
#    choices=(
#        "standard" "| The default partition table."
#    )
#
#    [ $uefi = true ] \
#        && choices+=(
#            "hybrid" "| Adds partitions for both UEFI and BIOS compatibility."
#        )
#
#    partition_scheme_selected=$(whiptail \
#        --title "Format Disk - Partition Scheme" \
#        --menu "\\nFor the next section:
#            \\n - \"standard\" is a 1GB \`/boot\` partition, with the remainder for the rootfs.\\n - \"hybrid\" has both BIOS and UEFI capabilities, but is only an option when UEFI is set to true.
#            \\nPlease select the partition scheme you would like to deploy:" \
#        25 78 4 \
#        "${choices[@]}" \
#        3>&1 1>&2 2>&3 3>&1
#    )
#}

ask_to_encrypt() {
    choices=(
        "true" "| encrypt the root file system"
        "false" "| do not encrypt the root file system"
    )

    encryption=$(whiptail \
        --title "Encryption" \
        --menu "\\nDo you want to encrypt the root file system?" \
        25 78 2 \
        "${choices[@]}" \
        3>&1 1>&2 2>&3 3>&1
    )
}

#ask_encryption_type() {
#    choices=(
#        "example1" ""
#        "example2" ""
#    )
#
#    encryption_type=$(whiptail \
#        --title "Encryption" \
#        --menu "\\nWhich type of encryption?" \
#        25 78 10 \
#        "${choices[@]}" \
#        3>&1 1>&2 2>&3 3>&1
#    )
#}

get_encryption_pass() {
     pass1=$(whiptail \
         --title "Encryption Password" \
         --passwordbox "\\nPlease enter a password to unlock the encrypted drive." \
        --nocancel \
        25 78 \
        3>&1 1>&2 2>&3 3>&1
    )

    pass2=$(whiptail \
        --title "Encryption Password" \
        --passwordbox "\\nPlease retype the password to unlock the encrypted drive." \
        --nocancel \
        25 78 \
        3>&1 1>&2 2>&3 3>&1
    )

    while ! [ "$pass1" = "$pass2" ] || [ -z "$pass1"]; do
        pass1=$(whiptail \
            --title "Encryption Password" \
            --passwordbox "\\nThe passwords entered do not match each other, or were left blank.
                \\nPlease enter a password to unlock the encrypted drive." \
            --nocancel \
            25 78 \
            3>&1 1>&2 2>&3 3>&1
        )

        pass2=$(whiptail \
            --title "Encryption Password" \
            --passwordbox "\\nPlease retype the password to unlock the encrypted drive." \
            --nocancel \
            25 78 \
            3>&1 1>&2 2>&3 3>&1
        )
    done

    pass_encrypt="$pass1"
    unset pass1
    unset pass2
}

run_partition_setup() {
    #ask_partition_scheme || error

    ask_to_encrypt || error

    # if Ubuntu image, run `debootstrap`
    # if `debootstrap` fails, error
    [ "$encryption" = true ] \
        && get_encryption_pass \
            || error
}

get_setup_info() {
    get_setup_os # sets `setup_os`

    get_uefi || error # sets `uefi` (0 is "legacy BIOS")

    get_disks || error # sets `disk_count` and `disk_selected`

    set_partition_names # sets variables for the different partitions

    get_ram_size # set `ram_size` in the format of `xyGB`

    [ -z "$install_os_selected" ] && install_os_selected="$setup_os"
    [ -z "$release_selected" ] && release_selected="rolling"
}

ask_confirm_inputs() {
    whiptail \
        --title "Confirm Inputs" \
        --yesno "\\nHere's what we have:
            \\n     Image OS                        =   $setup_os
            \\n     Partitioning to deploy          =   $uefi $partition_scheme_selected
            \\n     Disk selected                   =   $path_dev/$disk_selected
            \\n     Encryption                      =   $encryption
            \\n     LVM name                        =   $path_dev_mapper/$lvm_name
            \\n     RAM                             =   $ram_size
            \\n     Install OS                      =   $install_os_selected
            \\n     Release version                 =   $release_selected" \
        --yes-button "Let's go!" \
        --no-button "Cancel" \
        25 78 \
        3>&1 1>&2 2>&3 3>&1
}

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

ask_debootstrap_install_os() {
    # Debootstrap OS options
    debootstrap_os_installable=(
        "Debian" "| Options include Debian 12 and Debian 11"
        "Ubuntu" "| Options include Ubuntu 24 and Ubuntu 22"
    )

    install_os_selected=$(whiptail \
        --title "Debootstrap - Install OS" \
        --menu "\\nThe script noticed that you are using an Ubuntu image.
            \\nPlease select the OS to install:" \
        25 78 10 \
        "${debootstrap_os_installable[@]} " \
        3>&1 1>&2 2>&3 3>&1
    )
}

ask_debootstrap_release_version() {
    # Debian options
    [ "$install_os_selected" == "Debian" ] \
        && releases=( \
        "bookworm" "| Debian 12"
        "bullseye" "| Debian 11"
        )

    # Ubuntu options
    [ "$install_os_selected" == "Ubuntu" ] \
        && releases=( \
        "noble" "| Ubuntu 24"
        "jammy" "| Ubuntu 22"
        )

    release_selected=$(whiptail \
        --title "Debootstrap - Release Version" \
        --menu "\\nPlease select the $install_os_selected release version to install:" \
        25 78 10 \
        "${releases[@]}" \
        3>&1 1>&2 2>&3 3>&1
    )
}

ask_debootstrap() {
    ask_debootstrap_install_os

    ask_debootstrap_release_version
}

run_debootstrap() {
    # if Ubuntu image, run `debootstrap`
    # if `debootstrap` fails, error
    [ "$setup_os" == "ubuntu" ] \
        && {
            ask_debootstrap \
                || error
    }
}
