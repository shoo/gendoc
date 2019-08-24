#!/bin/bash

set -eux -o pipefail

function if_error_exit() {
    exit 1
}

TEST_TARGET_ARCH=${TEST_TARGET_ARCH:-x86_64}
COVERAGE_DIR=${COVERAGE_DIR:-.cov}
COVERAGE_MERGE=${COVERAGE_MERGE:-true}

dub test --arch=${TEST_TARGET_ARCH} --coverage
dub run --arch=${TEST_TARGET_ARCH} -b=unittest-cov -- --arch=${TEST_TARGET_ARCH}
