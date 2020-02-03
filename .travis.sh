#!/bin/bash

set -eux -o pipefail

TEST_TARGET_ARCH=${TEST_TARGET_ARCH:-x86_64}
TESTTYPE=${TESTTYPE:-unittest}
SCRIPT_DIR=$(cd $(dirname $0); pwd)
DMD=${DMD:-dmd}

mkdir -p cov
if [ "$TESTTYPE" == "unittest" ] ; then
	dub build -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=unittest --compiler=${DMD}
	${SCRIPT_DIR}/build/gendoc -a=${TEST_TARGET_ARCH} --DRT-covopt="merge:1 dstpath:${SCRIPT_DIR}/cov"
	dub build :candydoc -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=unittest --compiler=${DMD}
	mkdir -p docs/candydoc
	${SCRIPT_DIR}/candydoc/gendoc_candydoc -a=${TEST_TARGET_ARCH} --gendocConfig=candydoc --gendocTarget=docs/candydoc --DRT-covopt="merge:1 dstpath:${SCRIPT_DIR}/cov"
elif [ "$TESTTYPE" == "integration" ]; then

	function test_in_dir () {
		pushd $1
		${SCRIPT_DIR}/build/gendoc -a=${TEST_TARGET_ARCH} --root=$2 --DRT-covopt="merge:1 dstpath:${SCRIPT_DIR}/cov"
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
