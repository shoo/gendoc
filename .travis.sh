#!/bin/bash

set -eux -o pipefail

function if_error_exit() {
    exit 1
}

TEST_TARGET_ARCH=${TEST_TARGET_ARCH:-x86_64}
COVERAGE_DIR=${COVERAGE_DIR:-.cov}
COVERAGE_MERGE=${COVERAGE_MERGE:-true}
DC=${DC:-dmd}

dub run -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=default --compiler=${DC} -- -a=${TEST_TARGET_ARCH}
dub run :candydoc -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=default --compiler=${DC} -- -a=${TEST_TARGET_ARCH} --gendocConfig=candydoc --gendocTarget=docs_candydoc
