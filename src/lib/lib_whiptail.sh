#!/bin/sh

#####################################################################
# FUNCTIONS - WELCOME_SCREEN
#####################################################################

welcome_screen() {
    whiptail \
        --title "Welcome!" \
        --yesno "Greetings, and welcome to DavidVogelxyz's automatic Linux installer!
            \\nOn the next few screens, you will be asked some configuration questions.
            \\nThe script will configure and install Linux based on the provided answers.
            \\nYou will have a chance to exit out of the script before any changes are made." \
        --yes-button "Let's go!" \
        --no-button "No thanks." \
        25 78 \
        3>&1 1>&2 2>&3 3>&1
}

#####################################################################
# FUNCTIONS - SET_LINUX_INSTALL
#####################################################################

ask_debootstrap_install_os() {
    # Linux distro choices for `debootstrap`
    debootstrap_distros=(
        "debian" "| Debian 12 - Bookworm"
        "ubuntu" "| Ubuntu 24 - Noble"
    )

    linux_install=$(whiptail \
        --title "OS Identification" \
        --menu "\\nThis installer believes that it's currently running on \"${linux_iso}\".
            \\nWhen installing via \`debootstrap\`, the user has a choice of which Linux distribution to install.
            \\nPlease select from the following options:" \
        25 78 10 \
        "${debootstrap_distros[@]} " \
        3>&1 1>&2 2>&3 3>&1
    )

    check_linux_install "debian" \
        && release_install="bookworm" \
        && return 0

    check_linux_install "ubuntu" \
        && release_install="noble" \
        && return 0
}

os_identify_screen() {
    whiptail \
        --title "OS Identification" \
        --yesno "This installer believes that it's currently running on \"${linux_iso}\".
            \\nBecause of this, the installer will attempt to install \"${linux_install} ${release_install}\".
            \\nIf this is incorrect, please exit the script now." \
        --yes-button "That's correct!" \
        --no-button "No, that's incorrect." \
        25 78 \
        3>&1 1>&2 2>&3 3>&1
}

set_linux_install() {
    export linux_install=""

    check_linux_iso "ubuntu" \
        && {
            ask_debootstrap_install_os \
                && return 0 \
                || return 1
        }

    [ -z "$linux_install" ] \
        && linux_install="$linux_iso"

    [ -z "$release_install" ] \
        && release_install="rolling"

    os_identify_screen \
        || return 1
}

#####################################################################
# FUNCTIONS - SET_GRAPHICAL_ENVIRONMENT
#####################################################################

set_graphical_environment() {
    export graphical_environment=""

    choices_environment=(
        "server" "| No graphical environment."
        "dwm" "| DavidVogelxyz's custom build of DWM."
    )

    (check_linux_install "debian" || check_linux_install "ubuntu") \
        && choices_environment+=("gnome" "| The GNOME desktop environment.") \
        && choices_environment+=("kde" "| The KDE desktop environment.")

    graphical_environment=$(whiptail \
        --title "Graphical Environment" \
        --menu "\\nPlease choose from the following options:" \
        25 78 10 \
        "${choices_environment[@]} " \
        3>&1 1>&2 2>&3 3>&1
    )
}

#####################################################################
# FUNCTIONS - SET_BROWSER_INSTALL
#####################################################################

set_browser_install() {
    ([ "$graphical_environment" = "server" ] || [ "$graphical_environment" = "dwm" ]) \
        && return 0

    export browser_install=""
    choices_browser=()

    (check_linux_install "debian" || check_linux_install "ubuntu") \
        && choices_browser+=("brave" "| The Brave web browser, based off of Chromium.")

    check_linux_install "debian" \
        && choices_browser+=("firefox" "| The Firefox web browser.")

    browser_install=$(whiptail \
        --title "Web Browser" \
        --menu "\\nPlease choose from the following options:" \
        25 78 10 \
        "${choices_browser[@]} " \
        3>&1 1>&2 2>&3 3>&1
    )
}

#####################################################################
# FUNCTIONS - GET_UEFI
#####################################################################

check_uefi() {
    export uefi=false

    # UEFI check #1
    mount | grep -q "efi" \
        && uefi=true

    # UEFI check #2
    ls /sys/firmware/efi > /dev/null 2>&1 \
        && uefi=true
}

ask_uefi() {
    # `whiptail --default-item` wasn't working; so, alternative way to set default
    [ $uefi = true ] \
        && choices=(
            "uefi" "| Yes, I want to use UEFI (including hybrid configuration)."
            "bios" "| No, I only want compatibility with legacy BIOS."
        ) \
            || choices=(
                "bios" "| No, I only want compatibility with legacy BIOS."
                "uefi" "| Yes, I want to use UEFI (including hybrid configuration)."
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
    check_uefi

    ask_uefi \
        || error "Failed when asking about UEFI."
}

#####################################################################
# FUNCTIONS - GET_DISKS
#####################################################################

ask_for_disk_selected() {
    choices=()
    n=0

    # generate "correct" array for whiptail
    while [ $n -lt $disk_count ]; do
        choices+=("${list_disk_paths[$n]}" "| ${list_disk_sizes[$n]}")
        ((n+=1))
    done

    export disk_selected=$(whiptail \
        --title "Format Disk - Select Disk" \
        --menu "\\nPlease select the disk to format:" \
        25 78 10 \
        "${choices[@]}" \
        3>&1 1>&2 2>&3 3>&1
    )
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

#####################################################################
# FUNCTIONS - GET_SETUP_INFO
#####################################################################

get_setup_info() {
    # sets `uefi` (0 is "legacy BIOS")
    get_uefi \
        || error "Failed to set UEFI."

    # sets `disk_count` and `disk_selected`
    get_disks \
        || error "Failed to set \`disk_selected\`."

    # set `ram_size` in the format of `xyGB`
    get_ram_size

    return 0
}

#####################################################################
# FUNCTIONS - PARTITIONS AND ENCRYPTION
#####################################################################

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

    export encryption=$(whiptail \
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

    while ! [ "$pass1" = "$pass2" ] || [ -z "$pass1" ]; do
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

    unset pass2
    pass_encrypt="$pass1"
    unset pass1
}

get_partition_info() {
    #ask_partition_scheme || error

    ask_to_encrypt \
        || error "Failed to get answer about encryption."

    # if `encryption` is `true`, run `get_encryption_pass`
    # if `get_encryption_pass` fails, error
    [ "$encryption" = true ] \
        && {
            get_encryption_pass \
                || error "Failed to get an encryption password."
        }
}

#####################################################################
# FUNCTIONS - DEBIAN-SETUP - GET_USER_AND_PASS
#####################################################################

ask_root_pass() {
    export rootpass1=""

    # get root pass
    rootpass1=$(whiptail \
        --title "Root Password" \
        --passwordbox "\\nPlease enter a password for the root user." \
        --nocancel \
        10 60 \
        3>&1 1>&2 2>&3 3>&1
    )

    # get root pass confirmation
    rootpass2=$(whiptail \
        --title "Root Password" \
        --passwordbox "\\nPlease retype the password for the root user." \
        --nocancel \
        10 60 \
        3>&1 1>&2 2>&3 3>&1
    )

    # put user in loop until the two "root pass" entries agree
    while ! [ "$rootpass1" = "$rootpass2" ] || [ -z "$rootpass1" ]; do
        rootpass1=$(whiptail \
            --title "Root Password" \
            --passwordbox "\\nThe passwords entered do not match each other, or were left blank.
                \\nPlease enter the root user's password again." \
            --nocancel \
            10 60 \
            3>&1 1>&2 2>&3 3>&1
        )

        rootpass2=$(whiptail \
            --title "Root Password" \
            --passwordbox "\\nPlease retype the password for the root user." \
            --nocancel \
            10 60 \
            3>&1 1>&2 2>&3 3>&1
        )
    done

    unset rootpass2
}

ask_username() {
    # get username
    export username=$(whiptail \
        --title "Username" \
        --inputbox "\\nPlease enter a name for the new user that will be created by the script." \
        10 60 \
        3>&1 1>&2 2>&3 3>&1
    ) || exit 1

    # put user in loop until "username":
    # - true = starts with lowercase
    # - true = is only lowercase, numbers, `_`, and `-`
    while ! echo "$username" | grep -q "^[a-z][a-z0-9_-]*$"; do
        username=$(whiptail \
            --title "Username" \
            --inputbox "\\nInvalid username.
                \\nPlease provide a username using lowercase letters only.
                \\nNumbers, \`-\`, or \`_\` can be used for any letter but the first." \
            --nocancel \
            10 60 \
            3>&1 1>&2 2>&3 3>&1
        )
    done
}

ask_user_pass() {
    export userpass1=""

    # get user pass
    userpass1=$(whiptail \
        --title "User Password" \
        --passwordbox "\\nPlease enter a password for $username." \
        --nocancel \
        10 60 \
        3>&1 1>&2 2>&3 3>&1
    )

    # get user pass confirmation
    userpass2=$(whiptail \
        --title "User Password" \
        --passwordbox "\\nPlease retype password for $username." \
        --nocancel \
        10 60 \
        3>&1 1>&2 2>&3 3>&1
    )

    # put user in loop until the two "user pass" entries agree
    while ! [ "$userpass1" = "$userpass2" ] || [ -z "$userpass1" ]; do
        userpass1=$(whiptail \
            --title "User Password" \
            --passwordbox "\\nThe passwords entered do not match each other, or were left blank.
                \\nPlease enter $username's password again." \
            --nocancel \
            10 60 \
            3>&1 1>&2 2>&3 3>&1
        )

        userpass2=$(whiptail \
            --title "User Password" \
            --passwordbox "\\nPlease retype password for $username." \
            --nocancel \
            10 60 \
            3>&1 1>&2 2>&3 3>&1
        )
    done

    unset userpass2
}

get_user_and_pass() {
    ask_root_pass

    ask_username

    ask_user_pass
}

#####################################################################
# FUNCTIONS - DEBIAN-SETUP - GET_NETWORKING_INFO
#####################################################################

ask_hostname() {
    export hostname=$(whiptail \
        --title "Hostname" \
        --inputbox "\\nPlease enter a hostname for the machine." \
        10 60 \
        3>&1 1>&2 2>&3 3>&1
    ) \
        || exit 1

    while ! echo "$hostname" | grep -q "^[a-z][a-z0-9_-]*$"; do
        hostname=$(whiptail \
            --title "Hostname" \
            --inputbox "\\nInvalid hostname.
                \\nPlease provide a hostname using lowercase letters; numbers, -, or _ can be used if not the first character." \
            10 60 \
            3>&1 1>&2 2>&3 3>&1
        )
    done
}

ask_local_domain() {
    export localdomain=$(whiptail \
        --title "Local Domain" \
        --inputbox "\\nPlease enter the domain of the network.
            \\nIf unsure, just enter 'local'." \
        10 60 \
        3>&1 1>&2 2>&3 3>&1
    ) \
        || exit 1

    while ! echo "$localdomain" | grep -q "^[a-z][a-z0-9_.-]*$"; do
        localdomain=$(whiptail \
            --title "Local Domain" \
            --inputbox "\\nInvalid domain.
                \\nPlease provide a domain using lowercase letters; numbers, -, _, or . can be used if not the first character." \
            10 60 \
            3>&1 1>&2 2>&3 3>&1
        )
    done
}

get_networking_info() {
    ask_hostname

    ask_local_domain
}

#####################################################################
# FUNCTIONS - DEBIAN-SETUP - QUESTIONS
#####################################################################

ask_timezone() {
    # would still need to ask this question
    export timezone=$(whiptail \
        --title "Timezone" \
        --menu "\\nWhat timezone are you in?" \
        14 60 4 \
        "US/Eastern" "" \
        "US/Central" "" \
        "US/Mountain" "" \
        "US/Pacific" "" \
        3>&1 1>&2 2>&3 3>&1
    )
}

ask_region() {
    # would still need to ask this question
    export region=$(whiptail \
        --title "Region" \
        --menu "\\nWhat region are you in?" \
        14 60 4 \
        "en_US" "" \
        3>&1 1>&2 2>&3 3>&1
    )
}

ask_swap() {
    # this should be asked sooner
    # change variable!
    export swapanswer=$(whiptail \
        --title "Swap Partition?" \
        --menu "\\nShould the script create a swap partition for this machine?" \
        14 80 4 \
        "false" "| No, do not create a swap partition."\
        "true" "| Yes, create a swap partition."\
        3>&1 1>&2 2>&3 3>&1
    ) \
        || exit 1
}

questions() {
    ask_timezone

    ask_region

    ask_swap
}

#####################################################################
# FUNCTIONS - GET_OTHER_SETUP_INFO
#####################################################################

get_other_setup_info() {
    get_user_and_pass \
        || error "Failed to get a username and password."

    get_networking_info \
        || error "Failed to get networking information."

    questions \
        || error "Failed to answer all the questions."
}

#####################################################################
# FUNCTIONS - ASK_CONFIRM_INPUTS
#####################################################################

ask_confirm_inputs() {
    whiptail \
        --title "Confirm Inputs" \
        --yesno "\\nHere's what we have:
            \\n    Image OS                     =   $linux_iso
            \\n    Install OS & release         =   $linux_install $release_install
            \\n    Firmware                     =   $uefi $partition_scheme_selected
            \\n    Disk selected                =   ${path_dev}/${disk_selected}
            \\n    Encryption                   =   $encryption
            \\n    LVM name                     =   ${path_dev_mapper}/${lvm_name}
            \\n    user@hostname.domain         =   ${username}@${hostname}.${localdomain}
            \\n    Timezone                     =   $timezone
            \\n    Region                       =   $region
            \\n    RAM                          =   $ram_size
            \\n    swapanswer                   =   $swapanswer" \
        --yes-button "Let's go!" \
        --no-button "Cancel" \
        32 78 \
        3>&1 1>&2 2>&3 3>&1
}
