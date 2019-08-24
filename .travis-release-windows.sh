#!/usr/bin/env bash
# Build the Windows binaries under Linux
set -eux -o pipefail

BIN_NAME=d_test

# Allow the script to be run from anywhere
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

source .travis-release-windows-setup.sh

# Run LDC with cross-compilation
archiveName="$BIN_NAME-$VERSION-$OS-$ARCH_SUFFIX.zip"
echo "Building $archiveName"

# dub build -b=release

# cd build
# zip "../$archiveName" "*"
# cd ..
