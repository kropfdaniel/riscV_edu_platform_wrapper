# SERV VHDL Formal Verification Environment

This repository provides a self-contained, containerized formal verification environment for porting the [SERV RISC-V core](https://github.com/olofk/serv) to VHDL. 

It uses a "wrapper pattern" to keep the verification infrastructure (Docker, test runners, Yosys scripts) separate from the core hardware files. The actual hardware source code is pulled in via a Git submodule pointing to the `riscV_edu_platform` repository.

## Prerequisites

* **Docker:** The toolchain (Yosys, GHDL, OSS CAD Suite) is fully containerized. You only need Docker installed on your host machine.
* **Fish Shell:** The wrapper script uses Fish, but you only need it installed on your host if you want to run the scripts natively. Otherwise, Docker handles it.

## Setup

Because the hardware files are in a Git submodule, you must clone this repository recursively:

```bash
git clone --recurse-submodules https://github.com/kropfdaniel/riscV_edu_platform_wrapper
cd riscV_edu_platform_wrapper
```

*(If you already cloned it normally, initialize the submodule by running: `git submodule update --init --recursive`)*

## Running the Tests

The test runner script automatically detects if it needs to spin up the Docker container, and executes the formal equivalence checks using Yosys and GHDL.

Run all test suites:
```bash
./run_formal_equiv_check.fish
```

Run a specific test suite:
```bash
./run_formal_equiv_check.fish immdec
./run_formal_equiv_check.fish all
```

### Outputs
All generated files, Verilog netlists, Yosys/GHDL error logs, and the final `test_results.csv` summary are placed in the `build_output/` directory. This directory is ignored by Git to keep the repository clean.

## Repository Structure

* `Dockerfile`: A lightweight Debian image packaging the OSS CAD Suite (Yosys, GHDL).
* `check_equiv.fish`: The core verification script. It transpiles VHDL to Verilog using GHDL, then uses the Yosys SAT solver to mathematically prove equivalence between the original Verilog and the new VHDL.
* `run_formal_equiv_check.fish`: The test suite definition. It handles the Docker execution and defines which modules and generic configurations to test.
* `riscV_edu_platform/`: The Git submodule containing the actual VHDL and Verilog source code.

## Adding New Tests

To add a new module to the verification suite, open `run_formal_equiv_check.fish` and create a new function in section 3. 

Use the `check_equiv` command to define the test. For modules with parameters/generics, use standard Fish `for` loops to exhaustively test all configurations:

```fish
function test_my_module
    for <generic> in 1 2
        # Create a unique name for this specific combination
        set -l test_name "my_module_<generic>_"$<generic>
        echo "-> Testing configuration: $test_name"
        
        check_equiv \
            --name "$test_name" \
            --top "my_module" \
            --vhdl riscV_edu_platform/modules/serv/vhdl/my_module.vhdl \
            --verilog riscV_edu_platform/modules/serv/verilog/my_module.v \
            --generic "<generic>=$<generic>"
            
        if test $status -ne 0
            echo "Test failed! Aborting."
            return 1
        end
    end
end
```
Then, add your new function to the `switch` statement at the bottom of the file.