#!/bin/bash

# AURia: AUR install amazing
# Fetch package tar, then build and watch for missing dependencies. AUR-install that shit
# In theory, this is the simplest possible AUR installer. No dep management other than "it's missing, I should get it"

# This program has the following dependencies:
#### base packages ####
# bash
# tar
# perl
# head
# grep
# pacman
#### etc packages ####
# curl
# sudo
if [ -z "$1" ]; then
    echo "Usage: $0 <package>"
    echo "eg: $0 bauerbill"
    exit
fi

# We're inside a location where we can run "makepkg -s" to try and create the AUR package
function makepkg_with_dependency_resolve() {
    build_errors=$(yes | makepkg -s --skippgpcheck --noconfirm 2>&1)
    build_status=$?
    missing_targets=$(echo "$build_errors" | grep 'error: target not found:')
    if [ ! -z "$missing_targets" ]; then
        first_dep=$(echo "$missing_targets" | head -n1 | perl -n -e'/error: target not found: ([a-zA-Z0-9-]+)/ && print $1')

        # Recursion =D (hopefully this doesn't get out of hand...)
        echo "Resolve first dep: $first_dep"
        install_package "$first_dep"

        # Try makepkg again. If there are multiple missing deps from the first run, we'll install & try again after each installed dep
        # This is done "just in case" an installed dep installs another missing dep
        makepkg_with_dependency_resolve

    elif [ ! "$build_status" = "0" ]; then
        echo "Build errors in makepkg:"
        echo "$build_errors"
        exit
    # else # assume makepkg finished successfully =D
    fi
}

function install_package() {
    tar_url=$(curl -s "https://aur.archlinux.org/packages/$1" | perl -n -e'/<a href="([^ "]+)">Download snapshot<\/a>/ && print $1')
    if [ -z "$tar_url" ]; then
        echo "Error, could not find download URL for package $1"
        exit
    fi
    curl -s "https://aur.archlinux.org/$tar_url" > package.tar.gz
    tar -xaf package.tar.gz
    pushd $1
        echo "makepkg on $1"
        makepkg_with_dependency_resolve
        # makepkg -s
        echo "installing $1"
        sudo pacman --noconfirm -U *.pkg.tar.xz
    popd
    rm -r $1
    rm package.tar.gz
}

# install_package bauerbill

install_package $1
