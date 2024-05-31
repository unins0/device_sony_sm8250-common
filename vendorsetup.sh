#!/bin/bash

echo -e
echo 'Start Applying needed patches'
echo -e
echo 'Applying Dolby patch in frameworks/av'
echo -e
cd frameworks/av
git reset --hard FETCH_HEAD
echo -e
git am ../../device/sony/sm8250-common/patches/frameworks_av/*
cd ../..
echo -e
echo 'Applying X-Reality patches in frameworks/base'
cd frameworks/base
git reset --hard FETCH_HEAD
echo -e
git am ../../device/sony/sm8250-common/patches/frameworks_base/*
cd ../..
echo -e
echo 'Applying X-Reality/touch polling rate patches in packages/apps/Settings'
cd packages/apps/Settings
git reset --hard FETCH_HEAD
echo -e
git am ../../../device/sony/sm8250-common/patches/packages_apps_Settings/*
cd ../../..
echo 'Done applying'
echo -e
echo 'Continue'
