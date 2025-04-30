#!/bin/sh

#####################################################################
# FUNCTIONS - BOOTSTRAP - GENERAL
#####################################################################

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

blkid_to_fstab() {
    blkid | grep UUID | sed '/^\/dev\/sr0/d' >> /mnt/etc/fstab-helper
}

create_chroot_workspace() {
    repodir="/root/.local/src"
    export post_chroot_path="linux-image-setup"
    post_chroot_script="${repodir}/${post_chroot_path}/src/post-chroot.sh"

    mkdir -p "/mnt${repodir}"

    # copy `linux-image-setup`
    #git clone "https://github.com/DavidVogelxyz/${post_chroot_path}" "/mnt${repodir}/${post_chroot_path}"
    cp -r /root/linux-image-setup "/mnt${repodir}"

    # exclusively for compatibilty
    # make this more standardized by adding it directly to the script
    sed -i "s/bin\/sh/bin\/bash/g" "/mnt${post_chroot_script}"
    sed -i '2 i \\' "/mnt${post_chroot_script}"
    sed -i "3 i cd ${repodir}/${post_chroot_path}" "/mnt${post_chroot_script}"

    # make executable
    chmod +x "/mnt${post_chroot_script}"
}

chroot_time() {
    # copy the repo into the chroot environment
    create_chroot_workspace || error "Failed to configure the \`chroot\` environment."

    # `chroot` into Debian, Ubuntu, or Rocky
    (check_linux_install "debian" || check_linux_install "ubuntu" || check_linux_install "rocky") \
        && chroot /mnt "${post_chroot_script}" \
        && return 0

    # `chroot` into Arch
    check_linux_install "arch" \
        && arch-chroot /mnt "${post_chroot_script}" \
        && return 0

    # `chroot` into Artix
    check_linux_install "artix" \
        && artix-chroot /mnt "${post_chroot_script}" \
        && return 0
}

#####################################################################
# FUNCTIONS - BOOTSTRAP - MIRRORS
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

    # update `/mnt/etc/apt/sources.list`
    # on Debian and Ubuntu, this is run AFTER `debootstrap`, on the new install
    check_pkgmgr_apt \
        && cp "$mirrorlist_src" "/mnt${mirrorlist_dest}"

    # update `/etc/pacman.d/mirrorlist`
    # on Arch and Artix, this is run BEFORE `pacstrap`/`basestrap`, on the live image
    check_pkgmgr_pacman \
        && cp "$mirrorlist_src" "$mirrorlist_dest"

    unset mirrorlist_src
    unset mirrorlist_dest
}

#####################################################################
# FUNCTIONS - BASESTRAP - ARTIX
#####################################################################

run_basestrap() {
    pkgs="base base-devel linux linux-firmware runit elogind-runit cryptsetup lvm2 lvm2-runit grub networkmanager networkmanager-runit neovim vim"

    [ "$uefi" = "uefi" ] \
        && pkgs+=" efibootmgr"

    # set mirrors
    basestrap_mirrorlist

    # do the `basestrap`
    # `-i` was removed, as that is for "interactive" mode
    basestrap /mnt $pkgs --noconfirm --needed \
        || error "Failed to basestrap."

    unset pkgs

    # if swap, creates the `/etc/fstab-helper` file
    [ "$swapanswer" = true ] \
        && blkid_to_fstab

    # generate the `/etc/fstab` file on Artix
    fstabgen -U /mnt >> /mnt/etc/fstab

    chroot_time || error "Failed to \`chroot\`!"
}

#####################################################################
# FUNCTIONS - DEBOOTSTRAP - DEBIAN/UBUNTU
#####################################################################

run_pre_debootstrap() {
    whiptail \
        --title "Pre-Debootstrap" \
        --infobox "Installing \`debootstrap\` and \`vim\` to the install image environment." \
        8 78

    apt update > /dev/null \
        && apt install -y debootstrap git vim > /dev/null 2>&1
}

run_debootstrap() {
    # make sure `debootstrap` and `vim` are installed
    run_pre_debootstrap || error "Failed to set up for \`debootstrap\`."

    # do the `debootstrap`
    debootstrap $release_install /mnt || error "Failed to run \`debootstrap\`."

    bind_mounts || error "Failed to bind mounts."

    debootstrap_sourceslist || error "Failed to set up \`/etc/apt/sources.list\`."

    chroot_time || error "Failed to \`chroot\`!"
}

#####################################################################
# FUNCTIONS - PACSTRAP - ARCH
#####################################################################

run_pacstrap() {
    # `iptables` and `mkinitcpio` were added explicitly to avoid user prompts
    pkgs="base base-devel linux linux-firmware cryptsetup lvm2 grub networkmanager dhcpcd openssh neovim vim iptables mkinitcpio"

    [ "$uefi" = true ] \
        && pkgs+=" efibootmgr"

    # set mirrors
    pacstrap_mirrorlist

    # do the `pacstrap`
    # `-i` was removed, as that is for "interactive" mode
    pacstrap -K /mnt $pkgs --noconfirm --needed \
        || error "Failed to pacstrap."

    unset pkgs

    # if swap, creates the `/etc/fstab-helper` file
    [ "$swapanswer" = true ] \
        && blkid_to_fstab

    # generate the `/etc/fstab` file on Arch
    genfstab -U /mnt >> /mnt/etc/fstab

    chroot_time || error "Failed to \`chroot\`!"
}

#####################################################################
# FUNCTIONS - "ROCKYSTRAP" (DNF) - ROCKY
#####################################################################

run_rockystrap() {
    # "Rockystrap"
    dnf --releasever=${release_install} --installroot=/mnt -y groupinstall core

    bind_mounts || error "Failed to bind mounts."

    systemd-firstboot --root=/mnt --timezone="America/Chicago" --hostname="${hostname}" --setup-machine-id

    # Rocky doesn't bring this over by default
    cp /etc/resolv.conf /mnt/etc/resolv.conf

    chroot_time || error "Failed to \`chroot\`!"
}
