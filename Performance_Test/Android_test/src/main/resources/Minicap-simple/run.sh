#!/usr/bin/env bash

# Fail on error, verbose output
set -exo pipefail

# Build project
#ndk-build NDK_DEBUG=1 1>&2

# Figure out which ABI and SDK the device has
abi=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
sdk=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
pre=$(adb shell getprop ro.build.version.preview_sdk | tr -d '\r')
rel=$(adb shell getprop ro.build.version.release | tr -d '\r')

if [[ -n "$pre" && "$pre" > "0" ]]; then
  sdk=$(($sdk + 1))
fi

# PIE is only supported since SDK 16
if (($sdk >= 16)); then
  bin=minicap
else
  bin=minicap-nopie
fi

args=
if [ "$1" = "autosize" ]; then
  set +o pipefail
  size=$(adb shell dumpsys window | grep -Eo 'cur=[0-9]+x[0-9]+' | head -1 | cut -d= -f 2)
  if [ "$size" = "" ]; then
    w=$(adb shell dumpsys window | grep -Eo 'DisplayWidth=[0-9]+' | head -1 | cut -d= -f 2)
    h=$(adb shell dumpsys window | grep -Eo 'DisplayHeight=[0-9]+' | head -1 | cut -d= -f 2)
    size="${w}x${h}"
  fi
  sizes=(${size//x/ })
  w=`expr ${sizes[0]} / 4`
  h=`expr ${sizes[1]} / 4`
  size_out="${w}x${h}"
  args="-P $size@$size_out/0 —Q 90"
  set -o pipefail
  shift
fi

# Create a directory for our resources
dir=/data/local/tmp/minicap-devel
# Keep compatible with older devices that don't have `mkdir -p`.
adb shell "mkdir $dir 2>/dev/null || true"

# Upload the binary
adb push libs/$abi/$bin $dir

# Upload the shared library
if [ -e jni/minicap-shared/libs/android-$rel/$abi/minicap.so ]; then
  adb push jni/minicap-shared/libs/android-$rel/$abi/minicap.so $dir
else
  adb push jni/minicap-shared/libs/android-$sdk/$abi/minicap.so $dir
fi

# Run!
adb forward tcp:1717 localabstract:minicap

adb shell LD_LIBRARY_PATH=$dir $dir/$bin $args "$@"


# Clean up
#adb shell rm -r $dir
