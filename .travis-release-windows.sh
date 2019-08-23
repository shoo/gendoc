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

DUBOPTIONS=-b=release

# pre-build
dub describe ${DUBOPTIONS} --data=pre-generate-commands --data-list>pre-generate-commands.sh
dub describe ${DUBOPTIONS} --data=pre-build-commands --data-list>pre-build-commands.sh
. pre-build-commands.sh

# build
dub describe ${DUBOPTIONS} "--data=dflags,lflags,libs,linker-files,source-files,versions,debug-versions,import-paths,string-import-paths,import-files,options">cmdline.txt
echo -of$(dub describe ${DUBOPTIONS} --data=target-path --data-list)$(dub describe ${DUBOPTIONS} --data=target-name --data-list).exe>>cmdline.txt
cat cmdline.txt

ldc2 @cmdline.txt $DFLAGS

# post-build
dub describe ${DUBOPTIONS} --data=post-build-commands --data-list>post-build-commands.sh
dub describe ${DUBOPTIONS} --data=post-generate-commands --data-list>post-generate-commands.sh
. post-build-commands.sh

cd build
zip "../$archiveName" "*"
cd ..
