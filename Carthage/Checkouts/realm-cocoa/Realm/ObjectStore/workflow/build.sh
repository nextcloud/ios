#!/bin/sh

# This script is used by CI to build for a specific flavor.  It can be used
# locally: `./workspace/build.sh [linux|android] [sync]`
#
# For Android builds, you must set the ANDROID_NDK_PATH environment variable
# to point to your Android NDK installation.

flavor=${1:-linux}
sync=${2}
extra_flags=${3}

nprocs=4
if [ "$(uname)" = "Linux" ]; then
  nprocs=$(grep -c ^processor /proc/cpuinfo)
fi

: ${OPENSSL_ROOT_DIR:=/usr/local}

set -e

rm -rf ci.build
mkdir -p ci.build
cd ci.build

cmake_flags="-DCMAKE_CXX_FLAGS=-Werror"
if [ "${flavor}" = "android" ]; then
  [ -z $ANDROID_NDK_PATH ] && (echo "ANDROID_NDK_PATH is not set!"; exit 1)
  cmake_flags="-DREALM_PLATFORM=Android -DANDROID_NDK=${ANDROID_NDK_PATH}"
fi

if [ "${sync}" = "sync" ]; then
    cmake_flags="${cmake_flags} -DREALM_ENABLE_SYNC=1 -DREALM_ENABLE_SERVER=1 -DOPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}"
fi

cmake ${cmake_flags} ${extra_flags} ..
make VERBOSE=1 -j${nprocs}
