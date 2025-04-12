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
# FUNCTIONS - SET_INSTALL_OS
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
# FUNCTIONS - SET_ENVIRONMENT
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
    # get root pass
    export rootpass1=$(whiptail \
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
    # get user pass
    export userpass1=$(whiptail \
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

make_file_systems() {
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
# FUNCTIONS - STRAP - MIRRORS
#####################################################################

basestrap_mirrorlist() {
    pacstrap_mirrorlist
}

pacstrap_mirrorlist() {
    pkgmgr="pacman"
    mirrorlist_src="src/templates/${pkgmgr}/${linux_install}_mirrorlist"
    mirrorlist_dest="/etc/pacman.d/mirrorlist"

    update_mirrors
}

debootstrap_sourceslist() {
    pkgmgr="apt"
    mirrorlist_src="src/templates/${pkgmgr}/${linux_install}_${release_install}_sources.list"
    mirrorlist_dest="/etc/apt/sources.list"

    update_mirrors
}

update_mirrors() {
    whiptail \
        --title "Package Repositories" \
        --infobox "Making sure that the \`${mirrorlist_dest}\` file is good..." \
        8 78

    [ -f "$mirrorlist_src" ] \
        && [ -f "$mirrorlist_dest" ] \
        && diff "$mirrorlist_dest" "$mirrorlist_src"

    # update `sources.list`
    check_pkgmgr_apt \
        && cp "$mirrorlist_src" "/mnt$mirrorlist_dest"

    check_pkgmgr_pacman \
        && cp "$mirrorlist_src" "$mirrorlist_dest"

    unset mirrorlist_src
    unset mirrorlist_dest
}

lsblk_to_grub() {
    lsblk -f >> /mnt/etc/default/grub
}

lsblk_to_fstab() {
    lsblk -f >> /mnt/etc/fstab-helper
}

chroot_arch_prelude() {
    repodir="/root/.local/src"
    export post_chroot_path="linux-image-setup"
    post_chroot_script="${repodir}/${post_chroot_path}/src/post-chroot.sh"

    mkdir -p "/mnt$repodir"

    # clone `linux-image-setup`
    #git clone "https://github.com/DavidVogelxyz/${post_chroot_path}" "/mnt${repodir}/${post_chroot_path}"
    cp -r /root/linux-image-setup "/mnt$repodir"

    # exclusively for compatibilty with `linux-image-setup`
    sed -i "s/bin\/sh/bin\/bash/g" "/mnt${post_chroot_script}"
    sed -i '2 i \\' "/mnt${post_chroot_script}"
    sed -i "3 i cd ${repodir}/${post_chroot_path}" "/mnt${post_chroot_script}"

    # make executable
    chmod +x "/mnt${post_chroot_script}"
}

chroot_artix_prelude() {
    chroot_arch_prelude
}

chroot_arch() {
    chroot_arch_prelude || error "Failed to configure the \`chroot\` environment."

    arch-chroot /mnt "${post_chroot_script}"
}

chroot_artix() {
    chroot_artix_prelude || error "Failed to configure the \`chroot\` environment."

    artix-chroot /mnt "${post_chroot_script}"
}

#####################################################################
# FUNCTIONS - BASESTRAP - (Artix image)
#####################################################################

run_basestrap() {
    pkgs="base base-devel linux linux-firmware runit elogind-runit cryptsetup lvm2 lvm2-runit grub networkmanager networkmanager-runit neovim vim"

    [ "$uefi" = "uefi" ] \
        && pkgs+=" efibootmgr"

    generate_fstab() {
        fstabgen -U /mnt >> /mnt/etc/fstab
    }

    # set mirrors
    basestrap_mirrorlist

    # do the `basestrap`
    # `-i` was removed, as that is for "interactive" mode
    basestrap /mnt $pkgs --noconfirm --needed \
        || error "Failed to basestrap."

    unset pkgs

    #lsblk_to_grub

    [ "$swapanswer" = true ] \
        && lsblk_to_fstab

    generate_fstab

    chroot_artix
}

#####################################################################
# FUNCTIONS - DEBOOTSTRAP (Ubuntu image)
#####################################################################

run_pre_debootstrap() {
    whiptail \
        --title "Pre-Debootstrap" \
        --infobox "Installing \`debootstrap\` and \`vim\` to the install image environment." \
        8 78

    apt update > /dev/null \
        && apt install -y debootstrap git vim > /dev/null 2>&1
}

chroot_debootstrap_prelude() {
    repodir="/root/.local/src"
    export post_chroot_path="linux-image-setup"
    post_chroot_script="${repodir}/${post_chroot_path}/src/post-chroot.sh"

    mkdir -p "/mnt$repodir"

    # clone `debian-setup`
    #git clone "https://github.com/DavidVogelxyz/${post_chroot_path}" "/mnt${repodir}/${post_chroot_path}"
    cp -r /root/linux-image-setup "/mnt$repodir"

    # exclusively for compatibilty with `debian-setup`
    sed -i "s/bin\/sh/bin\/bash/g" "/mnt${post_chroot_script}"
    sed -i '2 i \\' "/mnt${post_chroot_script}"
    sed -i "3 i cd ${repodir}/${post_chroot_path}" "/mnt${post_chroot_script}"

    # make executable
    chmod +x "/mnt${post_chroot_script}"
}

chroot_debootstrap() {
    chroot_debootstrap_prelude || error "Failed to configure the \`chroot\` environment."

    chroot /mnt "${post_chroot_script}"
}

run_debootstrap() {
    # make sure `debootstrap` and `vim` are installed
    run_pre_debootstrap || error "Failed to set up for \`debootstrap\`."

    # do the `debootstrap`
    debootstrap $release_install /mnt || error "Failed to run \`debootstrap\`."

    bind_mounts || error "Failed to bind mounts."

    debootstrap_sourceslist || error "Failed to set up \`/etc/apt/sources.list\`."

    chroot_debootstrap || error "Failed to \`chroot\`!"
}

#####################################################################
# FUNCTIONS - PACSTRAP - (Arch image)
#####################################################################

run_pacstrap() {
    # `iptables` and `mkinitcpio` were added explicitly to avoid user prompts
    pkgs="base base-devel linux linux-firmware cryptsetup lvm2 grub networkmanager dhcpcd openssh neovim vim iptables mkinitcpio"

    [ "$uefi" = true ] \
        && pkgs+=" efibootmgr"

    generate_fstab() {
        genfstab -U /mnt >> /mnt/etc/fstab
    }

    # set mirrors
    pacstrap_mirrorlist

    # do the `pacstrap`
    # `-i` was removed, as that is for "interactive" mode
    pacstrap -K /mnt $pkgs --noconfirm --needed \
        || error "Failed to pacstrap."

    unset pkgs

    #lsblk_to_grub

    [ "$swapanswer" = true ] \
        && lsblk_to_fstab

    generate_fstab

    chroot_arch
}
