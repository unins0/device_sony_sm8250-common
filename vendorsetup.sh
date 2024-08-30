#!/bin/bash

TOP=$(pwd)
PATCHES=$TOP/device/sony/sm8250-common/patches
RESET=true

function patch () {
    cd $TOP/$2

    if $RESET; then 
        git reset --hard FETCH_HEAD
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

        patch $FOLDER $SOURCEPATH
    done

    cd $TOP
    RESET=false
}

apply

echo 'Deleted vendor/qcom/opensource/commonsys/fm to avoid stupid error'
rm -rf vendor/qcom/opensource/commonsys/fm
