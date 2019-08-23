#!/usr/bin/env bash
set -eux -o pipefail
VERSION=$(git describe --abbrev=0 --tags)
ARCH="${ARCH:-64}"
LDC_FLAGS=()
unameOut="$(uname -s)"
case "$unameOut" in
    Linux*) OS=linux; LDC_FLAGS=("-flto=full" "-linker=gold" "-static") ;;
    Darwin*) OS=osx; LDC_FLAGS+=("-L-macosx_version_min" "-L10.7" "-L-lcrt1.o"); ;;
    *) echo "Unknown OS: $unameOut"; exit 1
esac

case "$ARCH" in
    x86_64) ARCH_SUFFIX="x86_64";;
    64) ARCH_SUFFIX="x86_64";;
    i386) ARCH_SUFFIX="x86";;
    i686) ARCH_SUFFIX="x86";;
    x86) ARCH_SUFFIX="x86";;
    32) ARCH_SUFFIX="x86";;
    *) echo "Unknown ARCH: $ARCH"; exit 1
esac

archiveName="gendoc-$VERSION-$OS-$ARCH_SUFFIX.tar.gz"

echo "Building $archiveName"

dub build -b=release

cd build
mkdir -p bin etc/.gendoc
mv gendoc      bin/
mv ddoc        etc/.gendoc/ddoc
mv source_docs etc/.gendoc/docs
tar cvfz "../$archiveName" -C . *
cd ..
