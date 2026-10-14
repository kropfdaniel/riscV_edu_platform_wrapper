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
                --generic "W=$w"
        end
    end
end

function test_compdec
    echo "--- Running CompDec Suite ---"
    check_equiv \
        --name "serv_compdec" \
        --top "serv_compdec" \
        --vhdl riscV_edu_platform/hdl/modules/serv/vhdl/serv_compdec.vhdl \
        --verilog riscV_edu_platform/hdl/modules/serv/verilog/serv_compdec.v
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
    case "all"
        test_immdec
        test_compdec
    case '*'
        echo "Error: Unknown test suite '$suite'."
        echo "Available suites: all, immdec, compdec"
        exit 1
end

echo "=== Verification Complete ==="
cat $results_file
# Immdec


