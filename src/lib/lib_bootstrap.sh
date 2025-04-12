#!/bin/sh

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
# FUNCTIONS - BASESTRAP - ARTIX
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
# FUNCTIONS - PACSTRAP - ARCH
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
