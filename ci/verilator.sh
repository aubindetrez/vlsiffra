#!/bin/bash -e

VERILATOR_OPTS="-O3 -Wno-fatal -Wno-TIMESCALEMOD"
PROCESSES="sky130hd asap7 gf180mcu"
ADDERS="brentkung koggestone hancarlson"

mkdir -p generated

source venv/bin/activate

TESTS=""

build_one_test () {
	PIPELINE_DEPTH="$1"
	shift
	ARGS="$*"

	# Exhaustive test of 8 bit multiply/adder for every process and adder type
	for PROCESS in ${PROCESSES}; do
		for ADDER in ${ADDERS}; do
            # 's/\(.\)$/\1_/' will append _ at the end of the string (if not empty)
			PIPELINE_CMD=$(echo $ARGS | sed -e 's/ --/-/g' -e 's/--//' -e 's/\(.\)$/\1_/')
            WIDTH_BIT=8 # Size in bit
			VERILOG="generated/multiplier_${PROCESS}_${ADDER}_${PIPELINE_CMD}${WIDTH_BIT}.v"
			BINARY=multiply-adder-${PROCESS}-${ADDER}_${PIPELINE_CMD}_${WIDTH_BIT}
            if ! [ -e $VERILOG ] ; then
                echo "Error: Verilog File not found: $VERILOG"
                exit 1
            fi
            # Generate verilog
            # $ > vlsi-multiplier --bits=8 --multiply-add --algorithm=brentkung --tech=sky130hd  --output=generated/multiplier_sky130hd_b
            #    vlsi-multiplier --bits=8 --tech=sky130hd --algorithm=brentkung --multiply-add  --output=generated/multiplier_sky130hd_bre
            if ! [ -x vlsi-multiplier ] ; then
                echo "Error: Cannot run vlsi-multiplier: Problem with python-venv or running from a different directory"
                exit 1
            fi
			vlsi-multiplier --bits=${WIDTH_BIT} --tech=${PROCESS} --algorithm=${ADDER} --multiply-add ${ARGS} --output=${VERILOG}
            # Compile test
			verilator ${VERILATOR_OPTS} -CFLAGS "-O3 -DPIPELINE_DEPTH=${PIPELINE_DEPTH}" --assert --cc --exe --build ${VERILOG} verilog/${PROCESS}.v verilator/multiplier.cpp -o ${BINARY} -top-module multiply_adder
			TESTS="${TESTS} obj_dir/${BINARY}"
		done
	done
}

build_one_test 0 ""

build_one_test 1 "--register-input"
build_one_test 1 "--register-post-ppg"
build_one_test 1 "--register-post-ppa"
build_one_test 1 "--register-output"

build_one_test 2 "--register-input --register-post-ppg"
build_one_test 2 "--register-input --register-post-ppa"
build_one_test 2 "--register-input --register-output"
build_one_test 2 "--register-post-ppg --register-post-ppa"
build_one_test 2 "--register-post-ppg --register-output"
build_one_test 2 "--register-post-ppa --register-output"

build_one_test 3 "--register-input --register-post-ppg --register-post-ppa"
build_one_test 3 "--register-input --register-post-ppg --register-output"

build_one_test 4 "--register-input --register-post-ppa --register-post-ppg --register-output"

# Run N in parallel
N=4
for TEST in ${TESTS}; do
	echo $TEST
	$TEST &

	if [[ $(jobs -r -p | wc -l) -ge $N ]]; then
		wait -n
	fi
done
