## v0.0.3

In this update, this project no longer asks for input within the `chroot` environment. All of the prompts for user data occur outside the `chroot` environment, at the beginning of the run. The only parts now that will ask for user input are the `/etc/fstab` and `/etc/crypttab` files. But, this will be fixed in a future update.

## v0.0.2

Instead of `git clone debian-setup`, this project now includes an updated `debian-setup` within itself. However, the script requests user input both outside and inside the `chroot` environment.

## v0.0.1

First commit where this project was able to successfully complete, and then correctly `chroot` into the `debian-setup` script.
