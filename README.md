# complex_auto

## Windows Compile Entry

Use the root-level PowerShell script so local workflow changes stay outside git submodules:

```powershell
Set-Location .
.\scripts\compile_axi_vsim.ps1
```

Default tool values used by the script:

- Simulator: `vsim.exe` resolved from `PATH` (override with `-VsimExe` if needed)
- Bender: `bender.exe` resolved from `PATH` (override with `-BenderExe` if needed)

You can override them when needed:

```powershell
.\scripts\compile_axi_vsim.ps1 -BenderExe "$env:USERPROFILE\.cargo\bin\bender.exe"
```

## Windows Run Entry (tb)

Use the root-level run script to compile and run `tb` without changing submodule scripts.
This is the only recommended run entry:

```powershell
Set-Location .
.\scripts\run_tb.ps1 -BenderExe "$env:USERPROFILE\.cargo\bin\bender.exe"
```

Backward compatibility:

- `scripts/run_axi_xbar_uvm.ps1` is deprecated and kept only as a compatibility wrapper.
- It forwards to `scripts/run_tb.ps1` and should not be used for new automation.

Useful options:

- `-SkipCompile` to run simulation only with existing build artifacts.
- `-Seed <N>` to control `-sv_seed` (default `1`).

## Regression Profiles

Use the layered regression script for smoke/nightly execution:

```powershell
Set-Location .
.\scripts\run_regression.ps1 -RunTier smoke
```

Nightly example:

```powershell
.\scripts\run_regression.ps1 -RunTier nightly
```

Custom seed range example:

```powershell
.\scripts\run_regression.ps1 -RunTier custom -StartSeed 31 -EndSeed 60
```

Coverage gate template and reporting policy:

- `doc/CoverageGates.md`

## DV Final Check Summary

The UVM AXI xbar testbench in `uvm_tb/` has been reviewed against `doc/DVCodingStyle.md` and aligned for the agreed scope.

Final status:

- Top-level TB naming template is aligned: `uvm_tb/tb.sv`, `module tb`, DUT instance name `dut`.
- Runtime entry uses `run_test()` without explicit test name.
- Constructor signatures were aligned (`uvm_object` classes use `name = ""`; component classes use `name, parent` without defaults).
- `type_id::create()` names were aligned to match assigned variable names.
- Macro include template was aligned in TB/package context by explicitly including `uvm_macros.svh` and `dv_macros.svh`.
- UVM package classes were refactored to one class per file under `uvm_tb/`, and the package now includes those files.

Artifacts added/updated for style closure:

- `uvm_tb/tb.sv`
- `uvm_tb/tb_axi_xbar_uvm_pkg.sv`
- `uvm_tb/dv_macros.svh`
- `uvm_tb/axi_xbar_uvm_configuration.sv`
- `uvm_tb/axi_xbar_uvm_master_sequence.sv`
- `uvm_tb/axi_xbar_uvm_item_tap.sv`
- `uvm_tb/axi_xbar_uvm_scoreboard.sv`
- `uvm_tb/axi_xbar_uvm_test.sv`

Validation:

- Compile passed via `scripts/run_tb.ps1` (log: `axi/build/compile_vsim.log`).
- Simulation passed via `scripts/run_tb.ps1` (log: `axi/build/vsim_tb.log`).
