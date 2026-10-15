#!/usr/bin/env fish

# ==============================================================================
# File: check_equiv.fish
# Author: Daniel Kropf
# License: MIT License
# 
# Description: This script transpiles VHDL to Verilog via GHDL and formally verifies equivalence 
#              against a golden Verilog model using Yosys.
# Required Arguments:
#   -n, --name          Unique name for the test run (used for the build folder).
#   -t, --top           Top-level entity/module name to verify.
#   --vhdl              Path(s) to the VHDL source files (can specify multiple).
#   --verilog           Path(s) to the golden Verilog source files (can specify multiple).
#
# Optional Arguments:
#   --generic           Set VHDL generics and Verilog parameters (Format: NAME=VALUE).
#                       Can specify multiple times (e.g., --generic "W=1" --generic "SHARED=true").
#   --sat_cycles        Number of cycles for the Yosys SAT solver to prove (Default: 12).
#   --v_include         Include directory for Verilog headers.
#   --blackbox          Verilog file containing stub modules to blackbox.
#   --reset_constraints Additional Yosys script commands for custom clock/reset setups.
#
# Note: This script is based on the orginal work of Pascal Gesell
# ==============================================================================

# Parse named arguments
argparse 'n/name=' 't/top=' 'vhdl=+' 'verilog=+' 'reset_constraints=' \
         'v_include=' 'blackbox=' 'sat_cycles=' 'generic=+' 'strict' -- $argv
or return 1

# Assert global output variables exist
if not set -q build_dir; or not set -q results_file
    echo "Error: Global variables \$build_dir and \$results_file must be set in your test runner."
    return 1
end

# Ensure mandatory parameters are provided
if not set -q _flag_top; or not set -q _flag_name
    echo "Error: Both --top and --name arguments must be provided."
    return 1
end

# Set defaults
set -q _flag_sat_cycles; or set -l _flag_sat_cycles 12
set -q _flag_reset_constraints; or set -l _flag_reset_constraints ""

set -l work_dir "$build_dir/$_flag_name/ghdl-work"
set -l silver_file "$build_dir/$_flag_name/$_flag_top.v"
set -l log_file "$build_dir/$_flag_name/$_flag_top.log"

set -l vhdl_generic_args
set -l verilog_chparam ""

for generic_value in $_flag_generic
    set -a vhdl_generic_args "-g$generic_value"
    set -l parameter (string split '=' -- $generic_value)
    set -l verilog_value $parameter[2]
    
    if test "$verilog_value" = true
        set verilog_value 1
    else if test "$verilog_value" = false
        set verilog_value 0
    end
    set verilog_chparam "$verilog_chparam chparam -set $parameter[1] $verilog_value gold;"
end

set -l verilog_include ""
if set -q _flag_v_include
    set verilog_include "-I$_flag_v_include"
end

set -l vhdl_flags --synth --std=08
if set -q _flag_strict
    set -a vhdl_flags -Wall
end

mkdir -p "$build_dir/$_flag_name" $work_dir
printf '\n=== %s (reset-constrained assertions) ===\n' $_flag_name | tee $log_file

# Step 1: Synthesize VHDL to Verilog using GHDL
if not ghdl $vhdl_flags --out=verilog --workdir=$work_dir $vhdl_generic_args $_flag_vhdl -e $_flag_top >$silver_file 2>>$log_file
    printf '%s,ghdl-synth-failed\n' $_flag_name >> $results_file
    printf 'GHDL synthesis failed: %s\n' $_flag_name | tee -a $log_file

    echo "--- GHDL ERROR LOG ---"
    cat $log_file
    echo "----------------------"
    return 1
end

# Catch warnings from GHDL synthesis
if set -q _flag_strict; and grep -qi 'warning:' $log_file
    printf '%s,strict-warnings-found\n' $_flag_name >> $results_file
    printf 'Strict mode failed (Warnings found): %s\n' $_flag_name | tee -a $log_file
    return 1
end

set -l blackbox_command ""
set -l sat_options ""
if set -q _flag_blackbox
    set blackbox_command "read_verilog -formal $_flag_blackbox;"
    set sat_options '-ignore-unknown-cells'
end

# Step 2: Yosys Equivalence Checking Script
set -l yosys_script "
    $blackbox_command
    read_verilog -formal $verilog_include $_flag_verilog
    rename $_flag_top gold
    $verilog_chparam
    read_verilog -formal $silver_file
    rename $_flag_top silver
    proc; memory; async2sync
    equiv_make -make_assert gold silver equiv
    prep -top equiv
    flatten; async2sync; opt -keepdc
    sat $sat_options -seq $_flag_sat_cycles -verify -prove-asserts -set-init-zero -show-public \
                     -dump_vcd $build_dir/$_flag_name/fail.vcd $_flag_reset_constraints
"

# Step 3: Execute Yosys
if not yosys -p "$yosys_script" >>$log_file 2>&1
    printf '%s,equivalence-failed\n' $_flag_name >> $results_file
    printf 'Reset-constrained equivalence failed: %s\n' $_flag_name | tee -a $log_file

    echo "--- YOSYS ERROR LOG ---"
    cat $log_file
    echo "-----------------------"

    return 1
end

printf '%s,proven\n' $_flag_name >> $results_file
printf 'Reset-constrained proof: %s\n' $_flag_name | tee -a $log_file
return 0