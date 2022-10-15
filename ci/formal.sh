#!/bin/bash -e

PROCESSES="sky130hd asap7 gf180mcu"
ADDERS="brentkung koggestone hancarlson"

gitroot="`git rev-parse --show-toplevel`"

mkdir -p generated

source venv/bin/activate

# Test adders
for PROCESS in ${PROCESSES}; do
	for ADDER in ${ADDERS}; do
		VERILOG=${gitroot}/generated/adder_${PROCESS}_${ADDER}.v
		python3 ${gitroot}/vlsiffra/vlsi-adder --bits=64 --algorithm=${ADDER} --tech=${PROCESS} --output=${VERILOG}
		BITS=64 VERILOG=${VERILOG} PROCESS_VERILOG=verilog/${PROCESS}.v yosys -c formal/adder.tcl
	done
done

# Test multipliers
for PROCESS in ${PROCESSES}; do
	for ADDER in ${ADDERS}; do
		VERILOG=${gitroot}/generated/multiplier_${PROCESS}_${ADDER}.v
		python3 ${gitroot}/vlsiffra/vlsi-multiplier --bits=8 --algorithm=${ADDER} --tech=${PROCESS} --output=${VERILOG}
		BITS=8 VERILOG=${VERILOG} PROCESS_VERILOG=verilog/${PROCESS}.v yosys -c formal/multiplier.tcl
	done
done

# Test multiply adders
for PROCESS in ${PROCESSES}; do
	for ADDER in ${ADDERS}; do
		VERILOG=generated/multiply_adder_${PROCESS}_${ADDER}.v
		python3 ${gitroot}/vlsiffra/vlsi-multiplier --bits=4 --multiply-add --algorithm=${ADDER} --tech=${PROCESS} --output=${VERILOG}
		BITS=4 VERILOG=${VERILOG} PROCESS_VERILOG=verilog/${PROCESS}.v yosys -c formal/multiply_adder.tcl
	done
done

# Test multiply adder with pipelining
for PROCESS in ${PROCESSES}; do
	for ADDER in ${ADDERS}; do
		VERILOG=generated/multiply_adder_${PROCESS}_${ADDER}_pipelined.v
		python3 ${gitroot}/vlsiffra/vlsi-multiplier --bits=4 --multiply-add --algorithm=${ADDER} --tech=${PROCESS} --register-input --register-post-ppa --register-post-ppg --register-output --output=${VERILOG}
		BITS=4 VERILOG=${VERILOG} PROCESS_VERILOG=verilog/${PROCESS}.v yosys -c formal/multiply_adder_pipelined.tcl
	done
done
