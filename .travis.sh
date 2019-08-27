#!/bin/bash

set -eux -o pipefail

TEST_TARGET_ARCH=${TEST_TARGET_ARCH:-x86_64}
TESTTYPE=${TESTTYPE:-unittest}
DMD=${DMD:-dmd}

echo "--coverage_dir=${COVERAGE_DIR:-.cov}">.coverageopt
echo "--coverage_merge=${COVERAGE_MERGE:-true}">>.coverageopt

if [ "$TESTTYPE" == "unittest" ] ; then
	dub run -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=default --compiler=${DMD} -- -a=${TEST_TARGET_ARCH}
	dub run :candydoc -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=default --compiler=${DMD} -- -a=${TEST_TARGET_ARCH} --gendocConfig=candydoc --gendocTarget=docs/candydoc
elif [ "$TESTTYPE" == "integration" ]; then
	dub build -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=default --compiler=${DMD}
	build/gendoc -a=${TEST_TARGET_ARCH} --root=testcases/case001
	build/gendoc -a=${TEST_TARGET_ARCH} --root=testcases/case002
fi
