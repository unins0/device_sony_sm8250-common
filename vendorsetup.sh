#!/bin/bash
echo -e
echo 'Start Patching'
echo -e
echo 'Applying frameworks_av'
echo -e

cd frameworks/av
git reset --hard FETCH_HEAD

echo -e
git am ../../device/sony/sm8250-common/patches/frameworks_av/0001-goddammit-google.patch
cd ../..

echo -e
echo 'Applying hardware_libhardware'
echo -e

cd hardware/libhardware
git reset --hard FETCH_HEAD

echo -e
git am ../../device/sony/sm8250-common/patches/hardware_libhwardware/0001-audio_amplifier-pass-amplifier_device-pointer-to-cal.patch
cd ../..

echo -e
echo 'done'

