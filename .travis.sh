#!/bin/bash

function if_error_exit() {
    exit 1
}

dub test --arch=$ARCH || if_error_exit
dub run --arch=$ARCH -- --arch=$ARCH -v || if_error_exit
