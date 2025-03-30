#!/bin/sh

# path to the library file
library="src/lib_post-chroot.sh"

# sources file, if the path is a file
source_file() {
    [ -f "$1" ] && source "$1"
}

# prints argument to STDERR and exits
error() {
    echo "$1" >&2 \
        && exit 1
}

# sources library file, or error
source_file "$library" \
    || error "Failed to source the library file."

# runs the "post_chroot" playbook
playbook_post_chroot
