#!/bin/sh

####################################################################
# VARIABLES
####################################################################

# HARDCODED, BUT SHOULDN'T BE
export lvm_name="cryptlvm"

# HARDCODED, LEGIT

## PATHS
export path_dev="/dev"
export path_dev_mapper="/dev/mapper"

## LISTS

os_supported=(
    "arch"
    "artix"
    "debian"
    "ubuntu"
)

####################################################################
# FUNCTIONS - WELCOME
####################################################################

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

####################################################################
# FUNCTIONS - CHECK_SETUP_OS
####################################################################

check_image_arch() {
    [ "$setup_os" == "arch" ]
}

check_image_artix() {
    [ "$setup_os" == "artix" ]
}

check_image_ubuntu() {
    [ "$setup_os" == "ubuntu" ]
}

####################################################################
# FUNCTIONS - GET_UEFI
####################################################################

check_uefi() {
    export uefi=false

    # UEFI check #1
    mount | grep efi > /dev/null 2>&1 \
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

    ask_uefi || error
}

####################################################################
# FUNCTIONS - GET_DISKS
####################################################################

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

####################################################################
# FUNCTIONS - GET_SETUP_INFO
####################################################################

get_ram_size() {
    # `--si` gets the human readable `-h` in units of "GB"
    ram_size=$(free -th --si | grep "Total" | awk '{print $2}')
}

get_setup_info() {
    error() {
        echo "failed to get setup info!" && exit 1
    }

    get_setup_os # sets `setup_os`

    get_uefi || error # sets `uefi` (0 is "legacy BIOS")

    get_disks || error # sets `disk_count` and `disk_selected`

    get_ram_size # set `ram_size` in the format of `xyGB`

    [ -z "$install_os_selected" ] && export install_os_selected="$setup_os"
    [ -z "$release_selected" ] && release_selected="rolling"
}

####################################################################
# FUNCTIONS - PARTITIONS AND ENCRYPTION
####################################################################

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

    pass_encrypt="$pass1"
    unset pass1
    unset pass2
}

get_partition_info() {
    #ask_partition_scheme || error

    ask_to_encrypt || error

    # if `encryption` is `true`, run `get_encryption_pass`
    # if `get_encryption_pass` fails, error
    [ "$encryption" = true ] \
        && {
            get_encryption_pass \
                || error
        }
}

####################################################################
# FUNCTIONS - CHECK_INSTALL_OS
####################################################################

check_install_arch() {
    [ "$install_os_selected" == "arch" ]
}

check_install_artix() {
    [ "$install_os_selected" == "artix" ]
}

check_install_debian() {
    [ "$install_os_selected" == "debian" ]
}

check_install_ubuntu() {
    [ "$install_os_selected" == "ubuntu" ]
}

####################################################################
# FUNCTIONS - ASK_DEBOOTSTRAP
####################################################################

ask_debootstrap_install_os() {
    # Debootstrap OS options
    debootstrap_os_installable=(
        "debian" "| Options include Debian 12 and Debian 11"
        "ubuntu" "| Options include Ubuntu 24 and Ubuntu 22"
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

debootstrap_release_version() {
    check_install_debian \
        && release_selected="bookworm"

    check_install_ubuntu \
        && release_selected="noble" \
        || true
}


ask_debootstrap() {
    error() {
        echo "failed to get debootstrap information!" && exit 1
    }

    ask_debootstrap_install_os || error

    debootstrap_release_version || error
}

####################################################################
# FUNCTIONS - ASK_CONFIRM_INPUTS
####################################################################

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
            \\n     Install OS & release            =   $install_os_selected $release_selected" \
        --yes-button "Let's go!" \
        --no-button "Cancel" \
        25 78 \
        3>&1 1>&2 2>&3 3>&1
}

####################################################################
# FUNCTIONS - FORMAT_DISK
####################################################################

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

format_disk_nonsense() {
    #devsel="/dev/${disk_selected}"

    # a check for root user
    # > /dev/null 2>&1
    sfdisk -d $devsel \
        || echo "Are you sure you're running this as the root user?"

    # lots of good new stuff to try with the sfdisk commands
    #sfdisk $devsel < templates/format_disk_*                   # to take a file as a "state"
    #sfdisk -d $devsel                                          # to view
}

format_disk() {
    TERM=ansi whiptail \
        --title "Format Disk" \
        --infobox "Formatting disk..." \
        8 78

    # gives the feeling of starting up
    sleep 0.5

    # if successful, half second to read screen
    # if not, fails immediately
    sfdisk ${path_dev}/${disk_selected} < src/templates/format_disk/${uefi}_standard && sleep 0.5 || error
}

set_partition_names() {
    # set the first partition as "/boot"
    # may need to change in the future
    partition_boot=$(sfdisk -d ${path_dev}/${disk_selected} | grep start | head -1 | awk '{print $1}')

    # set the last partition as "rootfs"
    # may need to change in the future
    partition_rootfs=$(sfdisk -d ${path_dev}/${disk_selected} | grep start | tail -1 | awk '{print $1}')
}

run_format_disk() {
    error() {
        echo "failed to format disk!" && exit 1
    }

    format_disk_warning_screen || error

    format_disk || error

    set_partition_names || error
}

####################################################################
# FUNCTIONS - MAKE AND MOUNT FILE SYSTEMS
####################################################################

#run_cryptsetup() {}

make_file_systems() {
    error() {
        echo "failed to make file systems!" && exit 1
    }

    TERM=ansi whiptail \
        --title "File Systems" \
        --infobox "Making file systems..." \
        8 78

    mkfs.fat -F32 "$partition_boot" > /dev/null 2>&1
    mkfs.ext4 "$partition_rootfs" > /dev/null 2>&1

    # just long enough for the screen to be read
    sleep 1
}

mount_file_systems() {
    error() {
        echo "failed to mount file systems!" && exit 1
    }

    TERM=ansi whiptail \
        --title "File Systems" \
        --infobox "Mounting file systems..." \
        8 78

    mount "$partition_rootfs" /mnt
    mkdir -p /mnt/boot
    mount "$partition_boot" /mnt/boot

    # just long enough for the screen to be read
    sleep 1
}

bind_mounts() {
    TERM=ansi whiptail \
        --title "Bind Mounts" \
        --infobox "Binding certain devices to the chroot environment..." \
        8 78

    for d in sys dev proc; do
        mount --rbind /$d /mnt/$d \
            && mount --make-rslave /mnt/$d
    done

    # just long enough for the screen to be read
    sleep 1
}

####################################################################
# FUNCTIONS - STRAP - MIRRORS
####################################################################

basestrap_mirrorlist() {
    pacstrap_mirrorlist
}

pacstrap_mirrorlist() {
    pkgmgr="pacman"
    mirrorlist_src="src/templates/${pkgmgr}/${install_os_selected}_mirrorlist"
    mirrorlist_dest="/etc/pacman.d/mirrorlist"

    update_mirrors
}

debootstrap_sourceslist() {
    pkgmgr="apt"
    mirrorlist_src="src/templates/${pkgmgr}/${install_os_selected}_${release_selected}_sources.list"
    mirrorlist_dest="/etc/apt/sources.list"

    update_mirrors
}

update_mirrors() {
    TERM=ansi whiptail \
        --title "Package Repositories" \
        --infobox "Making sure that the \`${mirrorlist_dest}\` file is good..." \
        8 78

    # just long enough for the screen to be read
    sleep 1

    [ -f "$mirrorlist_src" ] \
        && [ -f "$mirrorlist_dest" ] \
        && diff "$mirrorlist_dest" "$mirrorlist_src"

    # update `sources.list`
    cp "$mirrorlist_src" "/mnt$mirrorlist_dest"

    unset mirrorlist_src
    unset mirrorlist_dest

    # just long enough for the screen to be read
    sleep 1
}

lsblk_to_grub() {
    lsblk -f >> /mnt/etc/default/grub
}

lsblk_to_fstab() {
    lsblk -f >> /mnt/etc/fstab
}

chroot_arch_prelude() {
    error() {
        echo "failed to chroot!" && exit 1
    }

    repodir="/root/.local/src"
    post_chroot_path="linux-image-setup"
    post_chroot_script="${repodir}/${post_chroot_path}/src/post-chroot.sh"

    mkdir -p "/mnt$repodir"

    # clone `linux-image-setup`
    git clone "https://github.com/DavidVogelxyz/$post_chroot_path" "/mnt${repodir}/${post_chroot_path}"

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
    chroot_arch_prelude || error

    arch-chroot /mnt "${post_chroot_script}"
}

chroot_artix() {
    chroot_artix_prelude || error

    artix-chroot /mnt "${post_chroot_script}"
}

####################################################################
# FUNCTIONS - BASESTRAP - (Artix image)
####################################################################

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
    basestrap -i /mnt "$pkgs"

    unset pkgs

    lsblk_to_grub

    #lsblk_to_fstab

    generate_fstab

    chroot_artix
}

####################################################################
# FUNCTIONS - DEBOOTSTRAP (Ubuntu image)
####################################################################

run_pre_debootstrap() {
    TERM=ansi whiptail \
        --title "Pre-Debootstrap" \
        --infobox "Installing \`debootstrap\` and \`vim\` to the install image environment." \
        8 78

    apt update > /dev/null \
        && apt install -y debootstrap git vim > /dev/null 2>&1
}

chroot_vars() {
    chroot_vars_dest=/mnt/root/.local/src/linux-image-setup/vars.txt

    echo "path_dev=${path_dev}" >> "${chroot_vars_dest}"
    echo "path_dev_mapper=${path_dev_mapper}" >> "${chroot_vars_dest}"
    echo "lvm_name=${lvm_name}" >> "${chroot_vars_dest}"
    echo "uefi=${uefi}" >> "${chroot_vars_dest}"
    echo "disk_selected=${disk_selected}" >> "${chroot_vars_dest}"
    echo "install_os_selected=${install_os_selected}" >> "${chroot_vars_dest}"
}

chroot_debootstrap_prelude() {
    error() {
        echo "failed to chroot!" && exit 1
    }

    repodir="/root/.local/src"
    post_chroot_path="debian-setup"
    post_chroot_script="${repodir}/${post_chroot_path}/${post_chroot_path}.sh"

    mkdir -p "/mnt$repodir"

    # clone `debian-setup`
    git clone "https://github.com/DavidVogelxyz/$post_chroot_path" "/mnt${repodir}/${post_chroot_path}"

    # exclusively for compatibilty with `debian-setup`
    sed -i "s/bin\/sh/bin\/bash/g" "/mnt${post_chroot_script}"
    sed -i '2 i \\' "/mnt${post_chroot_script}"
    sed -i "3 i cd ${repodir}/${post_chroot_path}" "/mnt${post_chroot_script}"

    # make executable
    chmod +x "/mnt${post_chroot_script}"
}

chroot_debootstrap() {
    chroot_debootstrap_prelude || error

    #chroot_vars

    chroot /mnt "${post_chroot_script}"
}

run_debootstrap() {
    error() {
        echo "failed to debootstrap!" && exit 1
    }

    # make sure `debootstrap` and `vim` are installed
    run_pre_debootstrap || error

    # do the `debootstrap`
    debootstrap $release_selected /mnt || error

    bind_mounts || error

    debootstrap_sourceslist || error

    chroot_debootstrap || error
}

####################################################################
# FUNCTIONS - PACSTRAP - (Arch image)
####################################################################

run_pacstrap() {
    pkgs="base base-devel linux linux-firmware cryptsetup lvm2 grub networkmanager dhcpcd openssh neovim vim"

    [ "$uefi" = "uefi" ] \
        && pkgs+=" efibootmgr"

    generate_fstab() {
        genfstab -U /mnt >> /mnt/etc/fstab
    }

    # set mirrors
    pacstrap_mirrorlist

    # do the `pacstrap`
    pacstrap -K -i /mnt "$pkgs"

    unset pkgs

    lsblk_to_grub

    #lsblk_to_fstab

    generate_fstab

    chroot_arch
}
