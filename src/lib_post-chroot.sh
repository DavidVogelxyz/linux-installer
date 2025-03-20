#!/bin/sh

####################################################################
# NEW FUNCTIONS
####################################################################

# check if timezone is symlink
check_path_link() {
    [[ -L "$path_to_check" ]]
}

# check if timezone is file
check_path_file() {
    [[ -f "$path_to_check" ]]
}

set_timezone() {
    path_to_check="/etc/localtime"

    # remove timezone if link
    check_path_link \
        && unlink /etc/localtime

    # remove timezone if file
    check_path_file \
        && rm /etc/localtime

    # set timezone
    ln -s "/usr/share/zoneinfo/$timezone" /etc/localtime

    unset path_to_check
}

sync_clock() {
    hwclock --systohc
}

set_datetime() {
    set_timezone

    sync_clock
}

set_locale_conf() {
    template_replace src/templates/etc/locale.conf /etc/locale.conf
}

uncomment_locale_gen() {
    [[ "$region" == "en_US" ]] \
        && sed -i 's/^# en_US/en_US/g' /etc/locale.gen
}

run_locale_gen() {
    locale-gen > /dev/null 2>&1
}

set_locales() {
    set_locale_conf

    uncomment_locale_gen

    run_locale_gen
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
    TERM=ansi whiptail \
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
# VARIABLES - DEBIAN-SETUP
####################################################################

packfile="https://raw.githubusercontent.com/DavidVogelxyz/debian-setup/master/packages.csv"

TERM=linux

####################################################################
# FUNCTIONS - DEBIAN-SETUP
####################################################################

error() {
    # Log to stderr and exit with failure.
    printf "%s\n" "$1" >&2
    exit 1
}

####################################################################
# FUNCTIONS - DEBIAN-SETUP - ADD_USER_AND_PASS
####################################################################

add_user_and_pass() {
    whiptail \
        --infobox "Creating new user: \"$username\"" \
        9 70

    # change root password; if successful, unset the password
    echo "root:$rootpass1" | chpasswd \
        && unset rootpass1 rootpass2

    # create user
    useradd -G sudo -s /bin/bash -m "$username"

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

####################################################################
# FUNCTIONS - DEBIAN-SETUP - DO_BASIC_ADJUSTMENTS
####################################################################

prep_fstab_debootstrap() {
    # see if this can't be piped through `grep`
    # maybe the edit commands later on are no longer necessary
    #cat /proc/mounts >> /etc/fstab
    grep "^/dev" /proc/mounts >> /etc/fstab
    grep "^tmp" /proc/mounts | sed 's/dev\/shm/tmp/g' >> /etc/fstab

    # likewise, this should be handled with a variable whose value is the UUID
    [[ $swapanswer = "yes" ]] \
        && echo "UUID=<UUID_swap> none swap defaults 0 0" >> /etc/fstab

    # pretty confident this is used to get the UUIDs
    # possible to get the values from here?
    #blkid | grep UUID | sed '/^\/dev\/sr0/d' >> /etc/fstab
    blkid_partitions=(
        "${partition_rootfs}"
        "${partition_boot}"
    )

    while read -r blkid_dev blkid_uuid blkid_block_size blkid_type blkid_partuuid ; do
        for object in "${blkid_partitions[@]}"; do
            grep "$object" <<< "$blkid_dev" > /dev/null \
                && {
                    grep_result=$?
                    [ "${grep_result}" == 0 ] && uuid_item="$(echo "$blkid_uuid" | sed -E "s/\"|\"$//g")"
                    sed -i "s|$object|$uuid_item|g" /etc/fstab
                }
        done
    done< <(blkid | grep UUID | sed '/^\/dev\/sr0/d')

}

do_basic_adjustments() {
    whiptail \
        --infobox "Updating packages and installing \`nala\`, a wrapper for \`apt\`..." \
        9 70

    # add relevant content to the `/etc/fstab` file
    prep_fstab_debootstrap

    # set `/etc/hostname` file
    set_etc_hostname

    # set `/etc/hosts` file
    set_etc_hosts

    # set the timezone
    set_timezone

    # sync system to hardware clock
    # Ubuntu doesn't have `hwclock`
    [ $install_os_selected != "ubuntu" ] \
        && sync_clock

    # Debian and Ubuntu should have `nala` installed at this point
    # curl was added so that the script can pull the file while it's reworked
    apt install -y nala curl > /dev/null 2>&1
}

setuplocale() {
    whiptail \
        --infobox "Adjusting \"/etc/locale.conf\" and \"/etc/locale.gen\"..." \
        9 70

    # set the `/etc/locale.conf` file
    set_locale_conf

    # Debian and Ubuntu need this package installed
    apt install -y locales > /dev/null 2>&1

    # uncomments language files in `/etc/locale.gen`
    uncomment_locale_gen

    # run `locale-gen`
    run_locale_gen
}

setupubuntu() {
    template_replace src/templates/etc/kernel-img_ubuntu.conf /etc/kernel-img.conf

    template_replace src/templates/etc/netplan/networkmanager_ubuntu.yaml /etc/netplan/networkmanager.yaml
}

installloop() {
    ([ -f packages.csv ] && cp packages.csv /tmp/packages.csv) \
        && sed -i '/^#/d' /tmp/packages.csv \
        || curl -Ls "$packfile" | sed '/^#/d' > /tmp/packages.csv

    total=$(wc -l < /tmp/packages.csv)
    n="0"

    while IFS="," read -r program comment; do
        n=$((n + 1))
        echo "$comment" | grep -q "^\".*\"$" &&
            comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
        install "$program" "$comment"
    done </tmp/packages.csv
}

install() {
    whiptail \
        --title "Package Installation" \
        --infobox "Installing \`$1\` ($n of $total). $1 $2" \
        9 70

    installpkg "$1"
}

installpkg() {
    apt install -y "$1" \
        > /dev/null 2>&1
}

create_useful_directories() {
    # create directories that should exist before deploying dotfiles with stow
    mkdir -p \
        "/home/$username/.cache/bash" \
        "/home/$username/.cache/zsh" \
        "/home/$username/.local/bin" \
        /root/.cache/bash \
        /root/.cache/zsh \
        /root/.config/lf \
        /root/.config/shell \
        /root/.local/bin
}

git_dotfiles() {
    # clone `dotfiles` into the homedir
    # add some error correction:
    # - what if the repo already exists?
    # - possible to check the hashes and only clone if not a repo?
    git clone \
        https://github.com/DavidVogelxyz/dotfiles \
        "/home/$username/.dotfiles" \
        > /dev/null 2>&1

    # symlink `dotfiles` to the repodir
    ln -s \
        "/home/$username/.dotfiles" \
        "$repodir/dotfiles"
}

#editfstab() {
    #sed -i '/^sysfs/,/^devpts/d' /etc/fstab
    #sed -i '/^hugetlbfs/,/^binfmt_misc/d' /etc/fstab
    #sed -i '/^mqueue/d' /etc/fstab
    #sed -i 's/dev\/shm/tmp/g' /etc/fstab
    #sed -i '/^\/dev\/sr0/d' /etc/fstab
#}

doconfigs() {
    whiptail \
        --infobox "Performing some basic configurations..." \
        9 70

    # create directories that should exist before deploying dotfiles with stow
    create_useful_directories

    # clone dotfiles and symlink them
    git_dotfiles

    git clone \
        https://github.com/DavidVogelxyz/vim \
        "$repodir/vim" \
        > /dev/null 2>&1

    # for root user
    [ -e /root/.bashrc ] \
        && rm -f /root/.bashrc

    [ -e /root/.profile ] \
        && rm -f /root/.profile

    [ -e /root/.vim ] \
        && rm -rf /root/.vim

    # for new user
    [ -e "/home/$username/.bashrc" ] \
        && rm -f "/home/$username/.bashrc"

    [ -e "/home/$username/.profile" ] \
        && rm -f "/home/$username/.profile"

    [ -e "/home/$username/.vim" ] \
        && rm -rf "/home/$username/.vim"

    # stow
    cd "/home/$username/.dotfiles" \
        && stow . \
        && cd \
        && unlink "/home/$username/.xprofile"

    # for root user
    ln -s \
        "/home/$username/.dotfiles/.config/shell/profile" \
        "/home/$username/.profile"
    sed -i \
        's/^\[ "\$(tty)"/#[ "$(tty)"]/g' \
        "/home/$username/.dotfiles/.config/shell/profile"
    sed -i \
        's/^sudo -n loadkeys "$XDG_DATA_HOME/#sudo -n loadkeys "$XDG_DATA_HOME/g' \
        "/home/$username/.dotfiles/.config/shell/profile"
    echo -e \
        "\nsource ~/.bashrc" \
        >> "/home/$username/.dotfiles/.config/shell/profile"
    ln -s \
        "$repodir/vim" \
        "/home/$username/.vim"

    # for root user
    ln -s \
        "/home/$username/.dotfiles/.config/shell/aliasrc-debian" \
        /root/.config/shell/aliasrc
    ln -s \
        "/home/$username/.dotfiles/.config/lf/scope-debian" \
        /root/.config/lf/scope

    # for new user
    ln -s \
        "/home/$username/.dotfiles/.bashrc" \
        /root/.bashrc
    ln -s \
        "/home/$username/.dotfiles/.config/shell/profile" \
        /root/.profile
    ln -s \
        "$repodir/vim" \
        /root/.vim

    # for new user
    ln -s \
        "/home/$username/.dotfiles/.config/shell/aliasrc-debian" \
        "/home/$username/.config/shell/aliasrc"
    ln -s \
        "/home/$username/.dotfiles/.config/lf/scope-debian" \
        "/home/$username/.config/lf/scope"

    dozshsetup

    sudo chsh -s /bin/zsh "$username"

    chown -R "$username": "/home/$username"

    # enable NetworkManager
    enable_networkmanager

    # if I change how the fstab is generated
    # I can probably eliminate this entirely
    #editfstab
    # and then no need to edit in Vim
    #vim /etc/fstab
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

do_cryptsetup() {
    [ $encryption = true ] && {
        whiptail \
            --infobox "Configuring the system to request a password on startup to unlock the encrypted disk." \
            9 70

        DEBIAN_FRONTEND=noninteractive \
            apt install -q -y \
                cryptsetup-initramfs \
                > /dev/null 2>&1

        while read -r blkid_dev blkid_uuid other ; do
            uuid_crypt="$(echo "$blkid_uuid" | sed -E "s/\"|\"$//g")"
        done< <(blkid | grep UUID | grep crypto)

        echo "${lvm_name} ${uuid_crypt} none luks" >> /etc/crypttab
    }
}

doinitramfsupdate() {
    whiptail \
        --infobox "Updating initramfs..." \
        9 70

    update-initramfs -u -k all \
        > /dev/null 2>&1
}

dogrubinstall() {
    whiptail \
        --infobox "Installing and updating GRUB..." \
        9 70

    [[ $uefi = "bios" ]] && {
        apt install -y grub-pc \
            > /dev/null 2>&1
        grub-install \
            --target=i386-pc \
            "/dev/$disk_selected" \
            > /dev/null 2>&1
    }

    [[ $uefi = "uefi" ]] && {
        apt install -y grub-efi \
            > /dev/null 2>&1
        grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot \
            --bootloader-id=GRUB \
            > /dev/null 2>&1
    }

    update-grub \
        > /dev/null 2>&1
}

finalmessage() {
    whiptail \
        --title "Congrats!" \
        --msgbox "Provided there were no hidden errors, \`debian-setup\` completed successfully and all packages and configurations are properly installed." \
        9 70

    clear
}

####################################################################
# ACTUAL SCRIPT - DEBIAN-SETUP
####################################################################

chroot_from_debootstrap() {
    echo "Updating packages, one moment..." \
        && apt update \
            > /dev/null 2>&1 \
        && installpkg whiptail \
            > /dev/null 2>&1

    add_user_and_pass

    do_basic_adjustments

    setuplocale

    [[ $install_os_selected = "ubuntu" ]] && setupubuntu

    installloop

    doconfigs

    do_cryptsetup

    doinitramfsupdate

    dogrubinstall

    finalmessage

    exit 0
}

chroot_from_arch() {
    set_datetime

    set_locales

    set_hosts

    enable_networkmanager

    exit 0
}

chroot_from_debian_ubuntu() {
    set_datetime

    set_locales

    set_hosts

    exit 0
}
