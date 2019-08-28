#!/bin/bash

set -eux -o pipefail

TEST_TARGET_ARCH=${TEST_TARGET_ARCH:-x86_64}
TESTTYPE=${TESTTYPE:-unittest}
SCRIPT_DIR=$(cd $(dirname $0); pwd)
DMD=${DMD:-dmd}

echo "--coverage_dir=${COVERAGE_DIR:-.cov}">.coverageopt
echo "--coverage_merge=${COVERAGE_MERGE:-true}">>.coverageopt

if [ "$TESTTYPE" == "unittest" ] ; then
	dub run -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=default --compiler=${DMD} -- -a=${TEST_TARGET_ARCH}
	dub run :candydoc -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=default --compiler=${DMD} -- -a=${TEST_TARGET_ARCH} --gendocConfig=candydoc --gendocTarget=docs/candydoc
elif [ "$TESTTYPE" == "integration" ]; then

	function test_in_dir () {
		pushd $1
		echo "--coverage_dir=${SCRIPT_DIR}/.cov">.coverageopt
		echo "--coverage_merge=true">>.coverageopt
		${SCRIPT_DIR}/build/gendoc -a=${TEST_TARGET_ARCH} --root=$2
		popd
	}
	dub build -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=default --compiler=${DMD}
	
	test_in_dir . testcases/case001
	test_in_dir . testcases/case002
	test_in_dir . testcases/case003
	
	test_in_dir testcases/case001 .
	test_in_dir testcases/case002 .
	test_in_dir testcases/case003 .
	
fi
