#!/bin/sh

aurhelper="yay"
export TERM=ansi

#####################################################################
# NEW FUNCTIONS
#####################################################################

# check if path is link
check_path_link() {
    [ -L "$1" ]
}

# check if path is file
check_path_file() {
    [ -f "$1" ]
}

set_timezone() {
    path_to_check="/etc/localtime"

    # remove timezone if link
    check_path_link "$path_to_check" \
        && unlink "$path_to_check"

    # remove timezone if file
    check_path_file "$path_to_check" \
        && rm "$path_to_check"

    # set timezone
    ln -s "/usr/share/zoneinfo/$timezone" /etc/localtime

    unset path_to_check
}

sync_clock() {
    hwclock --systohc
}

set_datetime() {
    # set the timezone
    set_timezone

    # sync system to hardware clock
    # Ubuntu doesn't have `hwclock`
    check_install_os "ubuntu" \
        || sync_clock
}

set_etc_hostname() {
    echo "$hostname" > /etc/hostname
}

set_etc_hosts() {
    echo "127.0.0.1       localhost" > /etc/hosts
    echo "::1             localhost" >> /etc/hosts
    echo "127.0.1.1       $hostname $hostname.$localdomain" >> /etc/hosts
}

set_hosts() {
    set_etc_hostname

    set_etc_hosts
}

enable_networkmanager() {
    systemctl enable NetworkManager
}

template_replace() {
    whiptail \
        --title "Config Update" \
        --infobox "Updating the \`$2\` file..." \
        8 78

    # just long enough for the screen to be read
    sleep 1

    [ -f "$1" ] \
        && [ -f "$2" ] \
        && diff "$2" "$1"

    # update file with template
    cp "$1" "$2"

    # just long enough for the screen to be read
    sleep 1
}

arch_aur_prep() {
    # Allow user to run sudo without entering a password.
    # Since AUR programs must be installed in a fakeroot environment,
    # this is required for all builds with AUR packages.
    trap 'rm -f /etc/sudoers.d/setup-temp' HUP INT QUIT TERM PWR EXIT

    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/setup-temp
    echo "Defaults:%wheel,root runcwd=*" >> /etc/sudoers.d/setup-temp
}

arch_pacman_color() {
    # Adds color, concurrent downloads, and Pacman eye-candy to `pacman`.
    grep -q "ILoveCandy" /etc/pacman.conf \
        || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

    sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf
}

arch_add_arch_mirror() {
    check_install_os "arch" \
        && {
            install_pkg_pacman archlinux-keyring
        } \
        && return 0

    check_install_os "artix" \
        && {
            install_pkg_pacman artix-keyring
            install_pkg_pacman artix-archlinux-support
            grep -q "^\[extra\]" /etc/pacman.conf \
                || echo "
[extra]
Include = /etc/pacman.d/mirrorlist-arch" \
                >>/etc/pacman.conf
            pacman -Syy --noconfirm >/dev/null 2>&1
            pacman-key --populate archlinux >/dev/null 2>&1
        } \
        && return 0
}

arch_makepkg_conf() {
    # Use all cores for compilation.
    sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf
}

install_aur() {
    # Installs $1 manually. Used only for AUR helper here.
    # Should be run after repodir is created and var is set.
    pacman -Qq "$1" \
        && return 0

    whiptail \
        --infobox "Installing \"$1\" manually." \
        7 50

    sudo -u "$username" mkdir -p "$repodir/$1"

    sudo -u "$username" git -C "$repodir" clone \
        --depth 1 \
        --single-branch \
        --no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" \
        > /dev/null 2>&1 \
        || {
            cd "$repodir/$1" \
                || return 1
            sudo -u "$username" git pull --force origin master \
                > /dev/null 2>&1
        }

    cd "$repodir/$1" \
        || exit 1

    sudo -u "$username" makepkg --noconfirm -si \
        > /dev/null 2>&1 \
        || return 1

    cd "/root/.local/src/${post_chroot_path}"
}

arch_aur_install() {
    install_aur $aurhelper \
        || error "Failed to install AUR helper."

    $aurhelper -Y --save --devel
}

#####################################################################
# FUNCTIONS - CHECK_INSTALL_OS
#####################################################################

check_install_os() {
    [ "$install_os_selected" == "$1" ]
}

check_pkgmgr_apt() {
    check_install_os "debian" \
        || check_install_os "ubuntu"
}

check_pkgmgr_pacman() {
    check_install_os "arch" \
        || check_install_os "artix"
}

#####################################################################
# VARIABLES - DEBIAN-SETUP
#####################################################################

list_packages="https://raw.githubusercontent.com/DavidVogelxyz/debian-setup/master/packages.csv"

#####################################################################
# FUNCTIONS - DEBIAN-SETUP
#####################################################################

# prints argument to STDERR and exits
error() {
    echo "$1" >&2 \
        && exit 1
}

#####################################################################
# FUNCTIONS - DEBIAN-SETUP - ADD_USER_AND_PASS
#####################################################################

add_user_and_pass() {
    whiptail \
        --infobox "Creating new user: \"$username\"" \
        9 70

    # change root password; if successful, unset the password
    echo "root:$rootpass1" | chpasswd \
        && unset rootpass1 rootpass2

    # create user
    check_pkgmgr_apt \
        && useradd -G sudo -s /bin/bash -m "$username"

    check_pkgmgr_pacman \
        && useradd -G wheel -s /bin/bash -m "$username"

    # change user password; if successful, unset the password
    echo "$username:$userpass1" | chpasswd \
        && unset userpass1 userpass2

    # export `repodir`
    export repodir="/home/$username/.local/src"

    # create `repodir`
    mkdir -p "$repodir"

    # change owner of `repodir`
    chown -R "$username": "$(dirname "$repodir")"
}

#####################################################################
# FUNCTIONS - DEBIAN-SETUP - DO_BASIC_ADJUSTMENTS
#####################################################################

do_basic_adjustments() {
    whiptail \
        --infobox "Updating packages and doing basic OS configuration..." \
        9 70

    # set `/etc/hosts` file
    set_hosts

    # set the datetime
    set_datetime

    # Debian and Ubuntu should have `nala` installed at this point
    check_pkgmgr_apt \
        && apt install -y \
            nala \
            > /dev/null 2>&1

    # curl was added so that the script can pull the file while it's reworked
    install_pkg curl

    # git was added so that the script can install `yay` (AUR helper)
    install_pkg git

    # for Arch and Artix, enable AUR installs by temporarily allowing `sudo` without password
    check_pkgmgr_pacman \
        && arch_aur_prep \
        && arch_pacman_color \
        && arch_add_arch_mirror \
        && arch_makepkg_conf \
        && arch_aur_install

    return 0
}

setup_locale() {
    whiptail \
        --infobox "Adjusting \"/etc/locale.conf\" and \"/etc/locale.gen\"..." \
        9 70

    # Debian and Ubuntu need this package installed
    check_pkgmgr_apt \
        && install_pkg_apt "locales"

    # set the `/etc/locale.conf` file
    template_replace src/templates/etc/locale.conf /etc/locale.conf

    # uncomments language files in `/etc/locale.gen`
    [ "$region" == "en_US" ] \
        && sed -i 's/^# en_US/en_US/g' /etc/locale.gen

    # run `locale-gen`
    locale-gen > /dev/null 2>&1
}

setup_ubuntu() {
    template_replace src/templates/etc/kernel-img_ubuntu.conf /etc/kernel-img.conf

    template_replace src/templates/etc/netplan/networkmanager_ubuntu.yaml /etc/netplan/networkmanager.yaml
}

error_install() {
    echo "Failed to install \`$1\`." >> pkg_fail.txt
}

install_pkg_aur() {
    sudo -u "$username" $aurhelper -S --noconfirm "$1" \
        > /dev/null 2>&1
}

install_pkg_apt() {
    apt install -y "$1" \
        > /dev/null 2>&1
}

install_pkg_pacman() {
    pacman --noconfirm --needed -S "$1" \
        > /dev/null 2>&1
}

install_pkg() {
    check_pkgmgr_apt \
        && install_pkg_apt "$1" \
        && return 0

    check_pkgmgr_pacman \
        && install_pkg_pacman "$1" \
        && return 0
}

install_loop_install_aur() {
    whiptail \
        --title "Package Installation" \
        --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" \
        9 70

    install_pkg_aur "$1" \
        || error_install "$1"
}

install_loop_install_default() {
    whiptail \
        --title "Package Installation" \
        --infobox "Installing \`$1\` ($n of $total). $1 $2" \
        9 70

    install_pkg "$1" \
        || error_install "$1"
}

prep_packages_file() {
    ([ -f packages.csv ] && cp packages.csv /tmp/packages.csv) \
        && sed -i '/^#/d' /tmp/packages.csv \
        || curl -Ls "$list_packages" | sed '/^#/d' > /tmp/packages.csv
}

install_loop_read() {
    total=$(wc -l < /tmp/packages.csv)
    n="0"

    while IFS="," read -r tag pkg comment pkg_debian pkg_arch pkg_artix pkg_ubuntu; do
        n=$((n + 1))
        pkg_check_name="pkg_${install_os_selected}"

        # `!` allows the script to print the value of `pkg_${install_os_selected}`
        # if value of `pkg_check_name` is `skip`, skips to the next package
        [ "${!pkg_check_name}" == "skip" ] \
            && continue

        echo "$comment" | grep -q "^\".*\"$" \
            && comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"

        [ ! -z "${!pkg_check_name}" ] \
            && [ "$tag" == "A" ] \
            && install_loop_install_aur "${!pkg_check_name}" "$comment" \
            && continue

        install_loop_install_default "$pkg" "$comment"
    done < /tmp/packages.csv
}

install_loop() {
    prep_packages_file

    install_loop_read
}

create_useful_directories() {
    # create directories that should exist before deploying dotfiles with stow
    mkdir -p \
        "/home/$username/.cache/bash" \
        "/home/$username/.cache/zsh" \
        "/home/$username/.config" \
        "/home/$username/.local/bin/cron" \
        "/home/$username/.local/bin/statusbar" \
        "/home/$username/.local/share" \
        /root/.cache/bash \
        /root/.cache/zsh \
        /root/.config/lf \
        /root/.config/shell \
        /root/.local/bin
}

fstab_entry_add_swap() {
    # if a swap partition was created, add a line to `/etc/fstab`
    [ "$swapanswer" = true ] \
        && echo "${volume_logical_swap} none swap defaults 0 0" >> /etc/fstab
}

fstab_entry_add_swap_uuid() {
    # this function is run only by Arch and Artix
    # only Arch and Artix create the `/etc/fstab-helper` file

    blkid_partitions=(
        "${volume_logical_swap}"
    )

    while read -r blkid_dev blkid_uuid blkid_block_size blkid_type blkid_partuuid ; do
        for object in "${blkid_partitions[@]}"; do
            grep -q "$object" <<< "$blkid_dev" \
                && {
                    grep_result=$?
                    [ "${grep_result}" == 0 ] && uuid_item="$(echo "$blkid_uuid" | sed -E "s/\"|\"$//g")"
                    sed -i "s|$object|$uuid_item|g" /etc/fstab
                } \
                || return 0
        done
    done < "/etc/fstab-helper"

    rm "/etc/fstab-helper"
}

run_fstab_arch() {
    fstab_entry_add_swap

    fstab_entry_add_swap_uuid
}

run_fstab_debootstrap() {
    # all Debian/Ubuntu machines have the same boot partition
    blkid_partitions=(
        "${partition_boot}"
    )

    # if no swap partition, add default `rootfs` to array
    # if swap partition, add `swap` and `root` LVs to array
    [ -z "$volume_logical_swap" ] \
        && blkid_partitions+=(
            "${partition_rootfs}"
            ) \
        || blkid_partitions+=(
            "${volume_logical_swap}"
            "${volume_logical_root}"
            )

    # loop through each line of `blkid | grep UUID`
    # within loop, loop through each `object` in the array `blkid_partitions`
    # when match, swap UUID for path in `/etc/fstab`
    while read -r blkid_dev blkid_uuid blkid_block_size blkid_type blkid_partuuid ; do
        for object in "${blkid_partitions[@]}"; do
            grep -q "$object" <<< "$blkid_dev" \
                && {
                    grep_result=$?
                    [ "${grep_result}" == 0 ] && uuid_item="$(echo "$blkid_uuid" | sed -E "s/\"|\"$//g")"
                    sed -i "s|$object|$uuid_item|g" /etc/fstab
                } \
                || return 0
        done
    done< <(blkid | grep UUID | sed '/^\/dev\/sr0/d')
}

fstab_debootstrap_prep() {
    # append to `/etc/fstab` any line from `/proc/mounts` beginning with `/dev`
    grep "^/dev" /proc/mounts >> /etc/fstab

    fstab_entry_add_swap

    # append to `/etc/fstab` any line from `/proc/mounts` beginning with `tmp`
    grep "^tmp" /proc/mounts | sed 's/dev\/shm/tmp/g' >> /etc/fstab

    run_fstab_debootstrap
}

run_git-clone() {
    # add some error correction:
    # - what if the repo already exists?
    # - possible to check the hashes and only clone if not a repo?
    git clone "$1" "$2" > /dev/null 2>&1
}

doconfigs() {
    whiptail \
        --infobox "Performing some basic configurations..." \
        9 70

    # create directories that should exist before deploying dotfiles with stow
    create_useful_directories

    # clone `dotfiles` into home dir for all
    run_git-clone "https://github.com/DavidVogelxyz/dotfiles" "/home/$username/.dotfiles"

    # clone `vim` configs for all
    run_git-clone "https://github.com/DavidVogelxyz/vim" "$repodir/vim"

    # clone `nvim` configs only on Arch and Artix (for now)
    check_pkgmgr_pacman \
        && run_git-clone "https://github.com/DavidVogelxyz/nvim" "$repodir/nvim"

    # files to be checked; will be removed if they exist
    list_files=(
        "/root/.bashrc"
        "/root/.profile"
        "/root/.vim"
        "/home/$username/.bashrc"
        "/home/$username/.profile"
        "/home/$username/.vim"
    )

    # check files; remove if they exist
    for path in "${list_files[@]}"; do
        [ -e "$path" ] \
            && rm -rf "$path"
    done

    # stow
    cd "/home/$username/.dotfiles" \
        && stow . \
        && cd \
        && unlink "/home/$username/.xprofile" # this is true only for servers; should not be done on DWM machines

    # all systems
    links_to_sym=(
        "$repodir/vim" "/root/.vim"
        "$repodir/vim" "/home/$username/.vim"
        "/home/$username/.dotfiles" "$repodir/dotfiles"
        "/home/$username/.dotfiles/.bashrc" "/root/.bashrc"
        "/home/$username/.dotfiles/.config/shell/profile" "/root/.profile"
        "/home/$username/.dotfiles/.config/shell/profile" "/home/$username/.profile"
    )

    # specific to Debian and Ubuntu
    check_pkgmgr_apt \
        && links_to_sym+=(
        "/home/$username/.dotfiles/.config/lf/scope-debian" "/root/.config/lf/scope"
        "/home/$username/.dotfiles/.config/lf/scope-debian" "/home/$username/.config/lf/scope"
        "/home/$username/.dotfiles/.config/shell/aliasrc-debian" "/root/.config/shell/aliasrc"
        "/home/$username/.dotfiles/.config/shell/aliasrc-debian" "/home/$username/.config/shell/aliasrc"
    )

    # specific to Arch and Artix
    check_pkgmgr_pacman \
        && links_to_sym+=(
        "$repodir/nvim" "/root/.config/"
        "$repodir/nvim" "/home/$username/.config/"
        "/home/$username/.dotfiles/.config/lf/scope-arch" "/root/.config/lf/scope"
        "/home/$username/.dotfiles/.config/lf/scope-arch" "/home/$username/.config/lf/scope"
        "/home/$username/.dotfiles/.config/shell/aliasrc-arch" "/root/.config/shell/aliasrc"
        "/home/$username/.dotfiles/.config/shell/aliasrc-arch" "/home/$username/.config/shell/aliasrc"
    )

    # loop through `links_to_sym` and creates the symlinks
    number_of_links="$(( ${#links_to_sym[@]} / 2 ))"
    n=0
    nn=1

    while [ "$((n / 2))" -lt "$number_of_links" ]; do
        link_src="${links_to_sym["$n"]}"
        link_dest="${links_to_sym["$nn"]}"

        ln -s "$link_src" "$link_dest" \
            || {
                error "Failed to link \"$link_src\" to \"$link_dest\"." >> config_fail.txt \
                && return 0
            }

        ((n+=2))
        ((nn+=2))
    done <<< "${links_to_sym[@]}"

    # small edits to `~/.config/shell/profile` for SERVERS
    # DWM and others will want these on
    sed -i \
        's/^\[ \! -f \"\$XDG_CONFIG_HOME/#[ \! -f \"\$XDG_CONFIG_HOME/g' \
        "/home/$username/.dotfiles/.config/shell/profile"
    sed -i \
        's/^\[ "\$(tty)"/#[ "$(tty)"/g' \
        "/home/$username/.dotfiles/.config/shell/profile"
    sed -i \
        's/^sudo -n loadkeys "$XDG_DATA_HOME/#sudo -n loadkeys "$XDG_DATA_HOME/g' \
        "/home/$username/.dotfiles/.config/shell/profile"

    # on Arch and Artix, allow for members of `wheel` group to `sudo`, after providing a password
    check_pkgmgr_pacman \
        && sed -i \
            's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' \
            '/etc/sudoers'

    # this can probably be deleted; only using zsh now
    echo -e \
        "\nsource ~/.bashrc" \
        >> "/home/$username/.dotfiles/.config/shell/profile"

    dozshsetup \
        || error "Failed during \`zsh\` setup."

    sudo chsh -s /bin/zsh "$username" \
        || error "Failed when changing shell."

    # make sure all files in user's home dir are owned by them
    chown -R "$username": "/home/$username"

    # enable NetworkManager
    # this is true only for Debian and Ubuntu
    check_pkgmgr_apt \
        && {
            enable_networkmanager \
                || error "Failed when enabling networking."
        }

    # enable networking on Arch
    check_install_os "arch" \
        && {
            systemctl enable systemd-networkd > /dev/null 2>&1 \
                && systemctl enable dhcpcd > /dev/null 2>&1 \
                || error "Failed when enabling networking."
        }

    # enable ssh on Arch
    check_install_os "arch" \
        && {
            systemctl enable sshd > /dev/null 2>&1 \
                || error "Failed when enabling SSH."
        }

    # enable networking on Artix
    check_install_os "artix" \
        && ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/current

    # enables autologin on Artix
    check_install_os "artix" \
        && sed -i "s/noclear/noclear --autologin ${username}/g" "/etc/runit/sv/agetty-tty1/conf"

    # add relevant content to the `/etc/fstab` file
    check_pkgmgr_apt \
        && {
            fstab_debootstrap_prep \
                || error "Failed while prepping \`/etc/fstab\` file."
        }

    [ "$swapanswer" = true ] \
        && check_pkgmgr_pacman \
        && run_fstab_arch

    return 0
}

dozshsetup(){
    git clone \
        --depth=1 \
        https://github.com/romkatv/powerlevel10k \
        "$repodir/powerlevel10k" \
        > /dev/null 2>&1

    fonts=(
        "MesloLGS_NF_Regular.ttf"
        "MesloLGS_NF_Bold.ttf"
        "MesloLGS_NF_Italic.ttf"
        "MesloLGS_NF_Bold_Italic.ttf"
    )

    sudo mkdir -p /usr/local/share/fonts/m

    for font in "${fonts[@]}"; do
        webfont=$(echo $font | sed 's/_/%20/g')

        [ ! -e /usr/local/share/fonts/m/$font ] \
            && sudo curl -L \
                https://github.com/romkatv/powerlevel10k-media/raw/master/$webfont \
                -o /usr/local/share/fonts/m/$font \
                > /dev/null 2>&1
    done
}

cryptsetup_debootstrap() {
    DEBIAN_FRONTEND=noninteractive \
        apt install -q -y \
            cryptsetup-initramfs \
            > /dev/null 2>&1

    while read -r blkid_dev blkid_uuid other ; do
        uuid_crypt="$(echo "$blkid_uuid" | sed -E "s/\"|\"$//g")"
    done< <(blkid | grep UUID | grep crypto)

    echo "${lvm_name} ${uuid_crypt} none luks" >> /etc/crypttab
}

cryptsetup_arch() {
    # adds `encrypt lvm2` to `/etc/mkinitcpio.conf`, between `block` and `filesystems`
    sed -i \
        "s/^\(HOOKS.*block\) filesystems/\1 encrypt lvm2 filesystems/g" \
        "/etc/mkinitcpio.conf"

    # sets `volume_logical_root` to `partition_crypt`, if not already set
    [ -z "$volume_logical_root" ] \
        && volume_logical_root="$partition_crypt"

    # lays down the foundation for the UUID substitution
    sed -i \
        "s|^\(GRUB_CMDLINE_LINUX_DEFAULT.*\)\"|\1 cryptdevice=${partition_rootfs}:${lvm_name} root=${volume_logical_root}\"|g" \
        "/etc/default/grub"

    # all Arch and Artix have the same partitions
    blkid_partitions=(
        "${partition_rootfs}"
        "${volume_logical_root}"
    )

    # loop through each line of `blkid | grep UUID`
    # within loop, loop through each `object` in the array `blkid_partitions`
    # when match, swap UUID for path in `/etc/default/grub`
    while read -r blkid_dev blkid_uuid blkid_block_size blkid_type blkid_partuuid ; do
        for object in "${blkid_partitions[@]}"; do
            grep -q "$object" <<< "$blkid_dev" \
                && {
                    grep_result=$?
                    [ "${grep_result}" == 0 ] && uuid_item="$(echo "$blkid_uuid" | sed -E "s/\"|\"$//g")"
                    sed -i "s|$object|$uuid_item|g" /etc/default/grub
                }
        done
    done< <(blkid | grep UUID | sed '/^\/dev\/sr0/d')
}

run_cryptsetup() {
    whiptail \
        --infobox "Configuring the system to request a password on startup to unlock the encrypted disk." \
        9 70

    check_pkgmgr_apt \
        && cryptsetup_debootstrap \
        && return 0

    check_pkgmgr_pacman \
        && cryptsetup_arch \
        && return 0
}

do_initramfs_update() {
    whiptail \
        --infobox "Updating \`initramfs\` on Debian/Ubuntu, and \`mkinitcpio\` on Arch/Artix..." \
        9 70

    check_pkgmgr_apt \
        && update-initramfs -u -k all \
        > /dev/null 2>&1 \
        && return 0

    check_pkgmgr_pacman \
        && mkinitcpio -p linux \
        && return 0
}

run_grub-install() {
    whiptail \
        --infobox "Installing and updating GRUB..." \
        9 70

    [[ $uefi = "bios" ]] \
        && check_pkgmgr_apt \
        && install_pkg_apt grub-pc

    [[ $uefi = "uefi" ]] \
        && check_pkgmgr_apt \
        && install_pkg_apt grub-efi

    [[ $uefi = "bios" ]] \
        && grub-install \
            --target=i386-pc \
            "/dev/$disk_selected" \
            > /dev/null 2>&1

    [[ $uefi = "uefi" ]] \
        && grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot \
            --bootloader-id=GRUB \
            > /dev/null 2>&1

    check_pkgmgr_apt \
        && update-grub > /dev/null 2>&1 \
        && return 0

    check_pkgmgr_pacman \
        && grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
}

final_message() {
    whiptail \
        --title "Congrats!" \
        --msgbox "Provided there were no hidden errors, \`linux-image-setup\` completed successfully and all packages and configurations are properly installed." \
        9 70

    clear
}

#####################################################################
# ACTUAL SCRIPT - PLAYBOOK_POST_CHROOT
#####################################################################

playbook_post_chroot() {
    echo "Updating packages, one moment..."

    check_pkgmgr_apt \
        && apt update \
            > /dev/null 2>&1 \
        && install_pkg_apt whiptail \
            > /dev/null 2>&1

    check_pkgmgr_pacman \
        && pacman -Sy \
            > /dev/null 2>&1 \
        && install_pkg_pacman libnewt \
            > /dev/null 2>&1

    add_user_and_pass \
        || error "Failed to set root pass, username, or user pass."

    do_basic_adjustments \
        || error "Failed to do basic adjustments."

    setup_locale \
        || error "Failed to set up locale."

    check_install_os "ubuntu" \
        && setup_ubuntu

    install_loop \
        || error "Failed during the install loop."

    doconfigs \
        || error "Failed during \`doconfigs\`."

    [ "$encryption" = true ] \
        && run_cryptsetup

    do_initramfs_update \
        || error "Failed while updating the initial ramdisk (initramfs)."

    run_grub-install \
        || error "Failed during GRUB install."

    export flag_graphical_enviroment=true
    export flag_dwm=true

    cd "/root/.local/src/${post_chroot_path}"

    [ "$flag_graphical_enviroment" = true ] \
        && {
            bash src/graphical-environments.sh \
                || error "Failed when installing the graphical environment."
        }

    final_message

    exit 0
}
