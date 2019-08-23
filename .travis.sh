#!/bin/bash

function if_error_exit() {
    exit 1
}

mkdir .cov

dub test --arch=$TEST_TARGET_ARCH || if_error_exit
dub run --arch=$TEST_TARGET_ARCH -- --arch=$TEST_TARGET_ARCH -v || if_error_exit
