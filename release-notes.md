## v0.0.5

This project is now able to do basic `rootfs` encryption and pass the necessary UUID to `/etc/crypttab` without user intervention.

Tested on Ubuntu image installing Debian Bookworm.

## v0.0.4

This project no longer requires user intervention beyond the initial input. Once the scripts takes in all inputs and gets started, it should run interrupted until completion.

As referenced in `v0.0.3` release notes, this update handles `/etc/fstab` without requiring user input. `/etc/crypttab` will be handled in a future update.

Tested on Ubuntu image installing Debian Bookworm.

## v0.0.3

In this update, this project no longer asks for input within the `chroot` environment. All of the prompts for user data occur outside the `chroot` environment, at the beginning of the run. The only parts now that will ask for user input are the `/etc/fstab` and `/etc/crypttab` files. But, this will be fixed in a future update.

Tested on Ubuntu image installing Debian Bookworm.

## v0.0.2

Instead of `git clone debian-setup`, this project now includes an updated `debian-setup` within itself. However, the script requests user input both outside and inside the `chroot` environment.

Tested on Ubuntu image installing Debian Bookworm.

## v0.0.1

First commit where this project was able to successfully complete, and then correctly `chroot` into the `debian-setup` script.

Tested on Ubuntu image installing Debian Bookworm.
