#!/usr/bin/env fish

# ==============================================================================
# File: run_formal_equiv_check.fish
# Author: Daniel Kropf
# License: MIT License
# 
# Description: The main test runner and orchestrator. It automatically transitions
#              execution into the Docker container and defines the test suites. 
#              It uses loops to exhaustively test different generic configurations
#              and logs all results to the build_output directory.
#
# Usage: 
#   ./run_formal_equiv_check.fish [suite_name]
#
# Arguments:
#   all                 (Default) Runs all defined test suites.
#   <suite_name>        Runs a specific test suite (e.g., immdec).
# ==============================================================================

# ==============================================================================
# 1. Docker Auto-Execution (Host Machine)
# ==============================================================================
# If the IN_DOCKER variable is not set, we are on the host. 
# Spin up Docker and execute this exact script inside it.
if not set -q IN_DOCKER
    # Build the image automatically if it doesn't exist yet
    if not docker image inspect vhdl-formal-env >/dev/null 2>&1
        echo "Docker image 'vhdl-formal-env' not found. Building it now..."
        docker build -t vhdl-formal-env .
    end

    echo "Starting Docker environment..."
    # 'exec' replaces the current host shell process with the Docker process
    exec docker run --rm -u (id -u):(id -g) -v (pwd):/workspace -e IN_DOCKER=1 -e HOME=/tmp vhdl-formal-env ./run_formal_equiv_check.fish $argv
end

# ==============================================================================
# 2. Test Environment Setup (Inside Docker)
# ==============================================================================
set -gx build_dir "build"
set -gx results_file "$build_dir/test_results.csv"

mkdir -p $build_dir
rm -f $results_file

# ==============================================================================
# 3. Define Test Suites
# ==============================================================================
function test_immdec
    echo "--- Running ImmDec Suite ---"

    for shared in true false
        for w in 1 4
            
            # Create a unique name for this specific combination
            set -l test_name "serv_immdec_shared_"$shared"_w_"$w
            echo "-> Testing configuration: $test_name"
            
            check_equiv \
                --name "$test_name" \
                --top "serv_immdec" \
                --vhdl riscV_edu_platform/hdl/modules/serv/vhdl/serv_immdec.vhdl \
                --verilog riscV_edu_platform/hdl/modules/serv/verilog/serv_immdec.v \
                --generic "SHARED_RFADDR_IMM_REGS=$shared" \
                --generic "W=$w"  \
                --strict
        end
    end
end

function test_compdec
    echo "--- Running CompDec Suite ---"
    check_equiv \
        --name "serv_compdec" \
        --top "serv_compdec" \
        --vhdl riscV_edu_platform/hdl/modules/serv/vhdl/serv_compdec.vhdl \
        --verilog riscV_edu_platform/hdl/modules/serv/verilog/serv_compdec.v  \
        --strict
end

function test_aligner
    echo "--- Running Aligner Suite ---"
    check_equiv \
        --name "serv_aligner" \
        --top "serv_aligner" \
        --vhdl riscV_edu_platform/hdl/modules/serv/vhdl/serv_aligner.vhdl \
        --verilog riscV_edu_platform/hdl/modules/serv/verilog/serv_aligner.v  \
        --strict
end

function test_decode
    echo "--- Running Decode Suite ---"

    for pre_register in true false
        for mdu in true false
            # Create a unique name for this specific combination
            set -l test_name "serv_decode_pre_register_"$pre_register"_mdu_"$mdu
            echo "-> Testing configuration: $test_name"
            
            check_equiv \
                --name "$test_name" \
                --top "serv_decode" \
                --vhdl riscV_edu_platform/hdl/modules/serv/vhdl/serv_decode.vhdl \
                --verilog riscV_edu_platform/hdl/modules/serv/verilog/serv_decode.v \
                --generic "PRE_REGISTER=$pre_register" \
                --generic "MDU=$mdu" \
                --strict
        end
    end
end

function test_alu
    echo "--- Running ALU Suite ---"

    for W in 1 2 4 32
        # Create a unique name for this specific combination
        set -l test_name "serv_alu_W_"$W
        echo "-> Testing configuration: $test_name"
        
        check_equiv \
            --name "$test_name" \
            --top "serv_alu" \
            --vhdl riscV_edu_platform/hdl/modules/serv/vhdl/serv_alu.vhdl \
            --verilog riscV_edu_platform/hdl/modules/serv/verilog/serv_alu.v \
            --generic "W=$W" \
            --strict
    end
end

function test_bufreg
    echo "--- Running BufReg Suite ---"

    for mdu in true false
        for W in 1 4
            # Create a unique name for this specific combination
            set -l test_name "serv_bufreg_mdu_"$mdu"_w_"$W
            echo "-> Testing configuration: $test_name"
            
            check_equiv \
                --name "$test_name" \
                --top "serv_bufreg" \
                --vhdl riscV_edu_platform/hdl/modules/serv/vhdl/serv_bufreg.vhdl \
                --verilog riscV_edu_platform/hdl/modules/serv/verilog/serv_bufreg.v \
                --generic "MDU=$mdu" \
                --generic "W=$W" \
                --strict
        end
    end
end

function test_bufreg2
    echo "--- Running BufReg2 Suite ---"

    for W in 1 4
        # Create a unique name for this specific combination
        set -l test_name "serv_bufreg2_W_"$W
        echo "-> Testing configuration: $test_name"
        
        check_equiv \
            --name "$test_name" \
            --top "serv_bufreg2" \
            --vhdl riscV_edu_platform/hdl/modules/serv/vhdl/serv_bufreg2.vhdl \
            --verilog riscV_edu_platform/hdl/modules/serv/verilog/serv_bufreg2.v \
            --generic "W=$W" \
            --strict
    end
end

# ==============================================================================
# 4. Argument Parsing & Execution
# ==============================================================================
set -l suite $argv[1]

# Default to "all" if no argument is provided
if test -z "$suite"
    set suite "all"
end

echo "=== Starting Formal Verification ($suite) ==="

switch $suite
    case "immdec"
        test_immdec
    case "compdec"
        test_compdec
    case "aligner"
        test_aligner
    case "decode"
        test_decode
    case "alu"
        test_alu
    case "bufreg"
        test_bufreg
    case "bufreg2"
        test_bufreg2
    case "all"
        test_immdec
        test_compdec
        test_aligner
        test_decode
        test_alu
        test_bufreg
        test_bufreg2
    case '*'
        echo "Error: Unknown test suite '$suite'."
        echo "Available suites: all, immdec, compdec, aligner, decode, alu, bufreg, bufreg2"
        exit 1
end

echo "=== Verification Complete ==="
cat $results_file
# Immdec


