#!/bin/sh

############################################
# VARIABLES
############################################

localeconf=(
'export LANG="en_US.UTF-8"
export LC_COLLATE="C"'
)

packfile="https://raw.githubusercontent.com/DavidVogelxyz/debian-setup/master/packages.csv"

TERM=linux

############################################
# FUNCTIONS
############################################

error() {
    # Log to stderr and exit with failure.
    printf "%s\n" "$1" >&2
    exit 1
}

getuserandpass() {
    rootpass1=$(whiptail --title "Root Password" --passwordbox "\\nPlease enter a password for the root user." \
        --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
    )

    rootpass2=$(whiptail --title "Root Password" --passwordbox "\\nPlease retype the password for the root user." \
        --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
    )

    while ! [ "$rootpass1" = "$rootpass2" ]; do
        rootpass1=$(whiptail --title "Root Password" --passwordbox "\\nThe passwords entered do not match each other.\\n\\nPlease enter the root user's password again." \
            --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
        )

        rootpass2=$(whiptail --title "Root Password" --passwordbox "\\nPlease retype the password for the root user." \
            --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
        )
    done

    username=$(whiptail --title "Username" --inputbox "\\nPlease enter a name for the new user that will be created by the script." \
        10 60 3>&1 1>&2 2>&3 3>&1
    ) || exit 1

    while ! echo "$username" | grep -q "^[a-z][a-z0-9_-]*$"; do
        username=$(whiptail --title "Username" --inputbox "\\nInvalid username. Please provide a username using lowercase letters; numbers, -, or _ can be used if not the first character." \
            --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
        )
    done

    userpass1=$(whiptail --title "User Password" --passwordbox "\\nPlease enter a password for $username." \
        --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
    )

    userpass2=$(whiptail --title "User Password" --passwordbox "\\nPlease retype password for $username." \
        --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
    )

    while ! [ "$userpass1" = "$userpass2" ]; do
        userpass1=$(whiptail --title "User Password" --passwordbox "\\nThe passwords entered do not match each other.\\n\\nPlease enter $username's password again." \
            --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
        )

        userpass2=$(whiptail --title "User Password" --passwordbox "\\nPlease retype password for $username." \
            --nocancel 10 60 3>&1 1>&2 2>&3 3>&1
        )
    done
}

getnetworkinginfo() {
    hostname=$(whiptail --title "Hostname" --inputbox "\\nPlease enter a hostname for the Debian computer." \
        10 60 3>&1 1>&2 2>&3 3>&1
    ) || exit 1

    while ! echo "$hostname" | grep -q "^[a-z][a-z0-9_-]*$"; do
        hostname=$(whiptail --title "Hostname" --inputbox "\\nInvalid hostname. Please provide a hostname using lowercase letters; numbers, -, or _ can be used if not the first character." \
            10 60 3>&1 1>&2 2>&3 3>&1
        )
    done

    localdomain=$(whiptail --title "Local Domain" --inputbox "\\nPlease enter the domain of the network. If unsure, just enter 'local'." \
        10 60 3>&1 1>&2 2>&3 3>&1
    ) || exit 1

    while ! echo "$localdomain" | grep -q "^[a-z][a-z0-9_.-]*$"; do
        localdomain=$(whiptail --title "Local Domain" --inputbox "\\nInvalid domain. Please provide a domain using lowercase letters; numbers, -, _, or . can be used if not the first character." \
            10 60 3>&1 1>&2 2>&3 3>&1
        )
    done
}

questions() {
    timezone=$(whiptail --title "Timezone" --menu "\\nWhat timezone are you in?" \
        14 60 4 \
        "US/Eastern" ""\
        "US/Central" ""\
        "US/Mountain" ""\
        "US/Pacific" ""\
        3>&1 1>&2 2>&3 3>&1
    )

    region=$(whiptail --title "Region" --menu "\\nWhat region are you in?" \
        14 60 4 \
        "en_US" ""\
        3>&1 1>&2 2>&3 3>&1
    )

    firmwareanswer=$(whiptail --title "Firmware" --menu "\\nIs this computer running 'legacy BIOS' or 'UEFI'?" \
        14 80 4 \
        "BIOS" ""\
        "UEFI" ""\
        3>&1 1>&2 2>&3 3>&1
    ) || exit 1

    sdx="Ignore since UEFI"

    [[ $firmwareanswer == "BIOS" ]] && {
        sdx=$(whiptail --title "Device Name" --inputbox "\\nWhat is the device name (ex. sda, sdb, nvme0n1)?" \
            10 60 3>&1 1>&2 2>&3 3>&1
        )
    }

    cryptanswer=$(whiptail --title "Encrypted System?" --menu "\\nIs this computer's root storage encrypted?" \
        14 80 4 \
        "yes" ""\
        "no" ""\
        3>&1 1>&2 2>&3 3>&1
    ) || exit 1

    swapanswer=$(whiptail --title "Swap Partition?" --menu "\\nDoes this computer have a swap partition?" \
        14 80 4 \
        "yes" ""\
        "no" ""\
        3>&1 1>&2 2>&3 3>&1
    ) || exit 1
}

confirminputs() {
    whiptail --title "Confirm Your Inputs" --yes-button "Let's go!" --no-button "Never mind..." \
        --yesno "\\nYou gave the following inputs:\\n\\n    Username: $username\\n    Hostname: $hostname\\n    Local domain: $localdomain\\n    Full address: $hostname.$localdomain\\n    Timezone: $timezone\\n    Region: $region\\n    Firmware: $firmwareanswer\\n    Device name: $sdx\\n    Encryption: $cryptanswer\\n    Swap partition: $swapanswer\\n\\nContinue?" \
        24 85 3>&1 1>&2 2>&3 3>&1
}

adduserandpass() {
    whiptail --infobox "Creating new user: \"$username\"" \
        9 70

    echo "root:$rootpass1" | chpasswd
    unset rootpass1 rootpass2

    useradd -G sudo -s /bin/bash -m "$username"
    export repodir="/home/$username/.local/src"
    mkdir -p "$repodir"
    chown -R "$username": "$(dirname "$repodir")"

    echo "$username:$userpass1" | chpasswd
    unset userpass1 userpass2
}

dobasicadjustments() {
    whiptail --infobox "Updating packages and installing \`nala\`, a wrapper for \`apt\`..." \
        9 70

    cat /proc/mounts >> /etc/fstab
    [[ $swapanswer = "yes" ]] && echo "UUID=<UUID_swap> none swap defaults 0 0" >> /etc/fstab
    blkid | grep UUID >> /etc/fstab

    echo "$hostname" > /etc/hostname
    echo "127.0.0.1     localhost" > /etc/hosts
    echo "::1           localhost" >> /etc/hosts
    echo "127.0.1.1     $hostname $hostname.$localdomain" >> /etc/hosts

    [[ -e /etc/localtime ]] && rm /etc/localtime
    ln -s "/usr/share/zoneinfo/$timezone" /etc/localtime

    # Ubuntu doesn't have `hwclock`
    [[ $setup_os != "ubuntu" ]] && hwclock --systohc

    apt install nala -y > /dev/null 2>&1
}

setuplocale() {
    whiptail --infobox "Adjusting \"/etc/locale.conf\" and \"/etc/locale.gen\"..." \
        9 70

    echo "$localeconf" > /etc/locale.conf

    apt install -y locales > /dev/null 2>&1
    [[ $region == "en_US" ]] && sed -i 's/^# en_US/en_US/g' /etc/locale.gen
    locale-gen > /dev/null 2>&1
}

setupubuntu() {
    ubuntukernelconf=(
'do_symlinks=no
no_symlinks=yes'
    )

    ubuntunetworkconf=(
'network:
 version: 2
 renderer: NetworkManager'
    )

    echo "$ubuntukernelconf" > /etc/kernel-img.conf
    echo "$ubuntunetworkconf" > /etc/netplan/networkmanager.yaml
}

installloop() {
	([ -f packages.csv ] && cp packages.csv /tmp/packages.csv) && sed -i '/^#/d' /tmp/packages.csv ||
		curl -Ls "$packfile" | sed '/^#/d' > /tmp/packages.csv

	total=$(wc -l </tmp/packages.csv)
    n="0"

	while IFS="," read -r program comment; do
		n=$((n + 1))
		echo "$comment" | grep -q "^\".*\"$" &&
			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
        install "$program" "$comment"
	done </tmp/packages.csv
}

install() {
	whiptail --title "Package Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" \
        9 70
	installpkg "$1"
}

installpkg() {
	apt install -y "$1" > /dev/null 2>&1
}

doconfigs() {
    whiptail --infobox "Performing some basic configurations. At some point, vim will open \"/etc/fstab\". You should know what to do here." \
        9 70

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

    # clone git repos into new user's repodir
    git clone https://github.com/DavidVogelxyz/dotfiles "/home/$username/.dotfiles" > /dev/null 2>&1
    ln -s "/home/$username/.dotfiles" "$repodir/dotfiles"

    git clone https://github.com/DavidVogelxyz/vim "$repodir/vim" > /dev/null 2>&1

    # for root user
    [ -e /root/.bashrc ] && rm -f /root/.bashrc
    [ -e /root/.profile ] && rm -f /root/.profile
    [ -e /root/.vim ] && rm -rf /root/.vim

    # for new user
    [ -e "/home/$username/.bashrc" ] && rm -f "/home/$username/.bashrc"
    [ -e "/home/$username/.profile" ] && rm -f "/home/$username/.profile"
    [ -e "/home/$username/.vim" ] && rm -rf "/home/$username/.vim"

    # stow
    cd "/home/$username/.dotfiles" && stow . && cd && unlink "/home/$username/.xprofile"

    # for root user
    ln -s "/home/$username/.dotfiles/.config/shell/profile" "/home/$username/.profile"
    sed -i 's/^\[ "\$(tty)"/#[ "$(tty)"]/g' "/home/$username/.dotfiles/.config/shell/profile"
    sed -i 's/^sudo -n loadkeys "$XDG_DATA_HOME/#sudo -n loadkeys "$XDG_DATA_HOME/g' "/home/$username/.dotfiles/.config/shell/profile"
    echo -e "\nsource ~/.bashrc" >> "/home/$username/.dotfiles/.config/shell/profile"
    ln -s "$repodir/vim" "/home/$username/.vim"

    # for root user
    ln -s "/home/$username/.dotfiles/.config/shell/aliasrc-debian" /root/.config/shell/aliasrc
    ln -s "/home/$username/.dotfiles/.config/lf/scope-debian" /root/.config/lf/scope

    # for new user
    ln -s "/home/$username/.dotfiles/.bashrc" /root/.bashrc
    ln -s "/home/$username/.dotfiles/.config/shell/profile" /root/.profile
    ln -s "$repodir/vim" /root/.vim

    # for new user
    ln -s "/home/$username/.dotfiles/.config/shell/aliasrc-debian" "/home/$username/.config/shell/aliasrc"
    ln -s "/home/$username/.dotfiles/.config/lf/scope-debian" "/home/$username/.config/lf/scope"

    dozshsetup

    sudo chsh -s /bin/zsh "$username"

    chown -R "$username": "/home/$username"

    systemctl enable NetworkManager

    sed -i '/^sysfs/,/^devpts/d' /etc/fstab
    sed -i '/^hugetlbfs/,/^binfmt_misc/d' /etc/fstab
    sed -i '/^mqueue/d' /etc/fstab
    sed -i 's/dev\/shm/tmp/g' /etc/fstab
    sed -i '/^\/dev\/sr0/d' /etc/fstab

    vim /etc/fstab
}

dozshsetup(){
    git clone --depth=1 https://github.com/romkatv/powerlevel10k "$repodir/powerlevel10k" > /dev/null 2>&1

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
            && sudo curl -L https://github.com/romkatv/powerlevel10k-media/raw/master/$webfont -o /usr/local/share/fonts/m/$font > /dev/null 2>&1
    done
}

docryptsetup() {
    [[ $cryptanswer = "yes" ]] && {
        whiptail --infobox "Installing 'cryptsetup-initramfs'..." \
            9 70
        apt install -y cryptsetup-initramfs
        blkid | grep UUID | grep crypto >> /etc/crypttab
        vim /etc/crypttab
    }
}

doinitramfsupdate() {
    whiptail --infobox "Updating initramfs..." \
        9 70
    update-initramfs -u -k all > /dev/null 2>&1
}

dogrubinstall() {
    whiptail --infobox "Installing and updating GRUB..." \
        9 70

    [[ $firmwareanswer = "BIOS" ]] && {
        apt install -y grub-pc \
            > /dev/null 2>&1
        grub-install \
            --target=i386-pc \
            "/dev/$sdx" \
            > /dev/null 2>&1
    }

    [[ $firmwareanswer = "UEFI" ]] && {
        apt install -y grub-efi \
            > /dev/null 2>&1
        grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot \
            --bootloader-id=GRUB \
            > /dev/null 2>&1
    }

    update-grub > /dev/null 2>&1
}

finalmessage() {
	whiptail \
        --title "Congrats!" \
        --msgbox "Provided there were no hidden errors, \`debian-setup\` completed successfully and all packages and configurations are properly installed." \
        9 70

    clear
}

############################################
# ACTUAL SCRIPT
############################################

chroot_from_debootstrap() {
    echo "Updating packages, one moment..." \
        && apt update \
            > /dev/null 2>&1 \
        && installpkg whiptail \
            > /dev/null 2>&1

    getuserandpass

    getnetworkinginfo

    questions

    confirminputs

    adduserandpass

    dobasicadjustments

    setuplocale

    [[ $setup_os = "ubuntu" ]] && setupubuntu

    installloop

    doconfigs

    docryptsetup

    doinitramfsupdate

    dogrubinstall

    finalmessage
}
