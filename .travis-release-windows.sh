#!/usr/bin/env bash
# Build the Windows binaries under Linux
set -eux -o pipefail

PROJECTNAME=gendoc

# Allow the script to be run from anywhere
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

source .travis-release-windows-setup.sh

# Run LDC with cross-compilation
archiveName="$PROJECTNAME-$VERSION-$OS-$ARCH_SUFFIX.zip"
echo "Building $archiveName"

dub build -a=$TARGET_MTRIPLE -b=release -c=default --compiler=ldc2

cd build
zip -r "../$archiveName" "./"
cd ..
