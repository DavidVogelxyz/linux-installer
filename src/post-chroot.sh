#!/bin/sh

#####################################################################
# SOURCE THE REQUIRED LIBRARY FILES
#####################################################################

# path to the library files
libraries=(
    "src/lib/lib_common.sh"
    "src/lib/lib_installer.sh"
    "src/lib/lib_post-chroot.sh"
)

# sources file, if the path is a file
source_file() {
    [ -f "$1" ] && source "$1"
}

# prints argument to STDERR and exits
error() {
    echo "$1" >&2 \
        && exit 1
}

# sources library files, or error
for file in "${libraries[@]}"; do
    source_file "$file" \
        || error "Failed to source the \`$file\` library."
done

#####################################################################
# RUN THE PLAYBOOK
#####################################################################

# runs the `post_chroot` playbook
playbook_post_chroot
