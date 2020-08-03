#!/bin/sh

# This script is used by CI to test coverage for a specific flavor.  It can be
# used locally: `./workspace/test_coverage.sh [sync] [dependency-suffix]`

sync=${1}
deps_suffix="${2}"

: ${OPENSSL_ROOT_DIR:=/usr/local}

set -e

if [ "${TMPDIR}" = "" ]; then
  TMPDIR="/tmp"
fi

echo "TMPDIR: ${TMPDIR}"
find $TMPDIR -name 'realm*' -exec rm -rf "{}" \+ || true
rm -rf coverage.build
mkdir -p coverage.build
cd coverage.build

cmake_flags="-DCMAKE_CXX_FLAGS=-Werror"
if [ "${sync}" = "sync" ]; then
    cmake_flags="${cmake_flags} -DREALM_ENABLE_SYNC=1 -DREALM_ENABLE_SERVER=1 -DOPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}"
fi

cmake ${cmake_flags} -G Ninja -DCMAKE_BUILD_TYPE=Coverage -DDEPENDENCIES_FILE="dependencies${deps_suffix}.list" ..
ninja -v generate-coverage-cobertura

find $TMPDIR -name 'realm*' -exec rm -rf "{}" \+ || true
