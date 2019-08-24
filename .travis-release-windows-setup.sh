#!/usr/bin/env bash

# sets up LDC for cross-compilation. Source this script, s.t. the new LDC is in PATH

ARCH=${ARCH:-32}
VERSION=$(git describe --abbrev=0 --tags)
OS=windows

case "$ARCH" in
    x86_64) ARCH_SUFFIX="x86_64";;
    64) ARCH_SUFFIX="x86_64";;
    i386) ARCH_SUFFIX="x86";;
    i686) ARCH_SUFFIX="x86";;
    x86) ARCH_SUFFIX="x86";;
    32) ARCH_SUFFIX="x86";;
    *) echo "Unknown ARCH: $ARCH"; exit 1
esac

# Step 0: install ldc
if [ ! -f install.sh ] ; then
	wget https://dlang.org/install.sh
fi
LDC_VERSION=${LDC_VERSION:-$(bash ./install.sh -a ldc | sed -E 's/.+\/ldc-([0-9.]+)\/activate/\1/')}
. $(bash ./install.sh -a "ldc-${LDC_VERSION}")

# for the install.sh script only
LDC_PATH="$(dirname $(dirname $(which ldc2)))"

# Step 1a: download the LDC x64 windows binaries
if [ "${ARCH_SUFFIX}" == "x86_64" ] && [ ! -d "ldc2-${LDC_VERSION}-windows-x64" ] ; then
	wget "https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/ldc2-${LDC_VERSION}-windows-x64.7z"
	7z x "ldc2-${LDC_VERSION}-windows-x64.7z" > /dev/null
	# Step 2a: Add LDC windows binaries to LDC Linux
	if [ ! -d "${LDC_PATH}/lib-win64" ] ; then
		cp -r ldc2-${LDC_VERSION}-windows-x64/lib "${LDC_PATH}/lib-win64"
		cat >> "$LDC_PATH"/etc/ldc2.conf <<EOF
"x86_64-.*-windows-msvc":
{
	switches = [
		"-defaultlib=phobos2-ldc,druntime-ldc",
		"-link-defaultlib-shared=false",
	];
	lib-dirs = [
		"%%ldcbinarypath%%/../lib-win64",
	];
};
EOF
	fi
fi
# Step 1b: download the LDC x86 windows binaries
if [ "${ARCH_SUFFIX}" == "x86" ] && [ ! -d "ldc2-${LDC_VERSION}-windows-x86" ] ; then
	wget "https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/ldc2-${LDC_VERSION}-windows-x86.7z"
	7z x "ldc2-${LDC_VERSION}-windows-x86.7z" > /dev/null
	# Step 2b: Add LDC windows binaries to LDC Linux
	if [ ! -d "${LDC_PATH}/lib-win32" ] ; then
		cp -r ldc2-${LDC_VERSION}-windows-x86/lib "${LDC_PATH}/lib-win32"
		cat >> "$LDC_PATH"/etc/ldc2.conf <<EOF
"i686-.*-windows-msvc":
{
	switches = [
		"-defaultlib=phobos2-ldc,druntime-ldc",
		"-link-defaultlib-shared=false",
	];
	lib-dirs = [
		"%%ldcbinarypath%%/../lib-win32",
	];
};
EOF
	fi
fi

# set suffices and compilation flags
if [ "$ARCH_SUFFIX" == "x86_64" ] ; then
	export DFLAGS="-mtriple=x86_64-windows-msvc"
else
	export DFLAGS="-mtriple=i686-windows-msvc"
fi

