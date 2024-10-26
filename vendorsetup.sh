#!/bin/bash

TOP=$(pwd)
PATCHES=$TOP/device/sony/sm8250-common/configs/patches
RESET=true

function patch () {
    cd $TOP/$2

    if $RESET; then 
        git reset --hard FETCH_HEAD
        echo -e
    fi

    git config --local user.name "genericuser"
    git config --local user.email "generic@email.com"
    git am $FOLDER/*
    if [ $? -ne 0 ]; then echo "!!! WARNING: Patching failed."; fi
    git config --local --unset user.name
    git config --local --unset user.email
}

function apply () {
    for FOLDER in $PATCHES/*; do
        PATCHDIR=$(basename "$FOLDER") # Remove additional path from DIR name

        SOURCEPATH=${PATCHDIR/platform_/} # Remove platform_ from dir name
        SOURCEPATH=${SOURCEPATH//_//} # replace _ with / to make a path to directory to patch

	if [ $SOURCEPATH == "build" ]; then SOURCEPATH="build/make"; fi # Replace build with build/make

        echo -e
        echo "Applying patches in ${SOURCEPATH}"
        echo -e

        patch $FOLDER $SOURCEPATH
        echo -e
    done

    cd $TOP
    RESET=false
}

echo "This script will apply patches and fixes to your ROMs source code."
echo "Choose an option:"
echo "1. Apply first build patches and start building (For a first time build or if you have repo synced to update the ROM)"
echo "2. Skip patching process and start building (After the first build, if patches have been already been applied)"
read -p "Enter your choice: " choice

case $choice in
    1)
        echo -e
        echo 'Applying patches...'
        echo -e
        apply
        echo -e
        echo 'Done Applying all Patches!'
        echo -e
        echo 'Checking if problematic power folder exists...'
        echo -e
        if [[ -d vendor/qcom/opensource/power ]]; then
            echo 'Problematic power folder found! Removing...'
            rm -rf vendor/qcom/opensource/power
            echo 'Problematic power successfully removed!'
            echo -e
        else
            echo 'Problematic power folder not found, skipping removal.'
            echo -e
        fi
        echo 'All patches and fixes have been applied! Starting build process...'
        echo -e
        ;;
    2)
        echo "Patches and fixes skipped... Starting build process."
        if [[ -d vendor/qcom/opensource/power ]]; then
            echo 'Problematic power folder found! Removing...'
            rm -rf vendor/qcom/opensource/power
            echo 'Problematic power successfully removed!'
            echo -e
        else
            echo 'Problematic power folder not found, skipping removal.'
            echo -e
        fi
        ;;
    *)
        echo "Invalid choice! Using option 2 as a fallback."
        choice=2
        ;;
esac
