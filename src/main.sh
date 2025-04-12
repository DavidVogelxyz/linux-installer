#!/bin/sh

#####################################################################
# SOURCE THE REQUIRED LIBRARY FILES
#####################################################################

# path to the library files
libraries=(
    "src/lib/lib_common.sh"
    "src/lib/lib_whiptail.sh"
    "src/lib/lib_bootstrap.sh"
    "src/lib/lib_main.sh"
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

# playbook script that gathers information from the user
# then, performs all steps prior to entering the `chroot` environment
# function defined in `lib_main.sh`
playbook_main
