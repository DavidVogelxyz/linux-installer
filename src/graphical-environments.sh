#!/bin/sh

# path to the library file
library="src/lib_graphical-environments.sh"

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

# performs the graphical install
playbook_graphical_environments
