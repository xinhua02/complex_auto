# Verification Report

Date: 2026-06-24
Project: complex_auto
Target: AXI xbar UVM testbench flow in uvm_tb

## 1. Scope

This report verifies the current UVM TB integration and execution flow after recent updates, including:

- standardized top-level testbench naming and entry flow
- one-class-per-file refactor in uvm_tb
- Windows PowerShell compile and run entry scripts
- coding-style alignment outcomes reflected in project docs

## 2. Environment and Entry Points

Workspace root: complex_auto

Primary scripts:

- scripts/compile_axi_vsim.ps1
- scripts/run_tb.ps1
- scripts/run_axi_xbar_uvm.ps1 (compatibility wrapper, deprecated)

Primary logs:

- axi/build/compile_vsim.log
- axi/build/vsim_tb.log

## 3. Verification Artifacts

Main UVM files under test:

- uvm_tb/tb.sv
- uvm_tb/tb_axi_xbar_uvm_pkg.sv
- uvm_tb/axi_xbar_uvm_configuration.sv
- uvm_tb/axi_xbar_uvm_master_sequence.sv
- uvm_tb/axi_xbar_uvm_item_tap.sv
- uvm_tb/axi_xbar_uvm_scoreboard.sv
- uvm_tb/axi_xbar_uvm_test.sv

## 4. Executed Checks

### 4.1 Baseline compile + simulation

Command:

- .\scripts\run_tb.ps1 -BenderExe "$env:USERPROFILE\\.cargo\\bin\\bender.exe" -Seed 1

Result:

- Compile completed successfully
- Simulation completed successfully

### 4.2 Multi-seed smoke regression

Command:

- run seeds 1..10 with -SkipCompile

Result summary:

- 10/10 PASS
- failed seeds: none

Per-seed status:

- Seed 1: PASS
- Seed 2: PASS
- Seed 3: PASS
- Seed 4: PASS
- Seed 5: PASS
- Seed 6: PASS
- Seed 7: PASS
- Seed 8: PASS
- Seed 9: PASS
- Seed 10: PASS

### 4.3 Static error scan

Scope:

- uvm_tb directory

Result:

- No errors found

### 4.4 Standalone compile entry check

Command:

- .\scripts\compile_axi_vsim.ps1 -BenderExe "$env:USERPROFILE\\.cargo\\bin\\bender.exe"

Result:

- Compile completed successfully

### 4.5 Compatibility wrapper run check

Command:

- .\scripts\run_axi_xbar_uvm.ps1 -BenderExe "$env:USERPROFILE\\.cargo\\bin\\bender.exe" -Seed 7 -SkipCompile

Result:

- Deprecation warning printed as expected
- Simulation completed successfully

### 4.6 Extended and spot seed regression

Commands:

- run seeds 11..30 with -SkipCompile
- run seed 99 with -SkipCompile

Result summary:

- seeds 11..30: 20/20 PASS
- seed 99: PASS
- aggregate with section 4.2: 31/31 PASS (1..30 and 99)

### 4.7 Log marker scan

Scope:

- axi/build/compile_vsim.log
- axi/build/vsim_tb.log

Pattern:

- `** Error`
- `UVM_ERROR`
- `UVM_FATAL`

Result:

- No matched error markers in the latest logs

### 4.8 Layered regression script validation

Commands:

- .\scripts\run_regression.ps1 -RunTier smoke -BenderExe "$env:USERPROFILE\\.cargo\\bin\\bender.exe"
- .\scripts\run_regression.ps1 -RunTier custom -Seeds 1,2 -BenderExe "$env:USERPROFILE\\.cargo\\bin\\bender.exe"

Result summary:

- smoke profile: 10/10 PASS
- custom quick check: 2/2 PASS
- generated summaries archived under `axi/build/regression_*.md`

## 5. Compliance and Structure Status

Confirmed:

- top-level TB file is uvm_tb/tb.sv with module tb
- DUT instance name is dut
- run_test is called without explicit test name
- class definitions are split into separate files and included from package file
- documentation reflects current script and structure conventions

## 6. Conclusion

Verification status: PASS

The current UVM TB flow is stable on the tested Windows environment for baseline and smoke regression scenarios. No compile/runtime failures were observed in the executed scope.
The current UVM TB flow is stable on the tested Windows environment for baseline, compatibility-entry, and extended seed scenarios.

## 7. Residual Risk and Next Recommendations

- Current sampled seeds cover 1..30 and 99; increase seed count further and periodically refresh sampled ranges for stronger statistical confidence.
- Keep using scripts/run_tb.ps1 as the canonical entry in CI and local automation.
- If functionality expands, add scenario-tagged regressions and coverage trend tracking in future reports.

## 8. Closure Updates

To close previously pending plan items, the following were added:

- Layered regression script: `scripts/run_regression.ps1`
  - supports `smoke`, `nightly`, and `custom` profiles
  - executes compile-once + multi-seed simulation
  - generates per-run markdown summaries under `axi/build/`
- Coverage gate template: `doc/CoverageGates.md`
  - defines smoke/nightly gate thresholds
  - provides seed policy and report format
  - defines exception handling and escalation metadata
