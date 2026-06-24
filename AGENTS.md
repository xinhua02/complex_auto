# AGENTS Guidance

This file defines the default operating guidance for AI coding agents in this repository.

## Scope

- Prefer changes in the repository root workspace.
- Treat these directories as dependency submodules unless explicitly requested to edit them:
  - axi/
  - common_cells/
  - common_verification/
  - tech_cells_generic/
  - tvip-axi/
- Put new UVM testbench code under uvm_tb/.
- Put local workflow automation at repository root under scripts/.

## Canonical Commands (Windows)

Run from repository root.

- Compile: ./scripts/compile_axi_vsim.ps1
- Compile + simulate: ./scripts/run_tb.ps1
- Simulate only: ./scripts/run_tb.ps1 -SkipCompile
- Seeded run: ./scripts/run_tb.ps1 -Seed <N>

Notes:

- scripts/run_axi_xbar_uvm.ps1 is deprecated and kept only as a compatibility wrapper.
- Prefer PATH-resolved tools or parameter overrides (-VsimExe, -BenderExe).

## UVM Testbench Conventions

- Top-level testbench must be uvm_tb/tb.sv with module name tb and DUT instance name dut.
- Keep run_test() without explicit test name.
- Keep one class per file in uvm_tb/.
- Keep package aggregation in uvm_tb/tb_axi_xbar_uvm_pkg.sv via include list.
- Keep type_id::create() name strings aligned with assigned variable names.
- Keep macro includes explicit where needed (uvm_macros.svh, dv_macros.svh).

## Verification Expectations

- After behavioral or structural changes in UVM code, run compile + simulation with scripts/run_tb.ps1.
- Prefer reporting both logs in summaries:
  - axi/build/compile_vsim.log
  - axi/build/vsim_tb.log

## Reference Docs (Link, Do Not Duplicate)

- Root workflow and run entry: README.md
- DV coding standard: doc/DVCodingStyle.md
- AXI IP documentation: axi/README.md
- AXI xbar design details: axi/doc/axi_xbar.md

## Common Pitfalls

- Do not move new local scripts into submodule directories.
- Do not hardcode machine-specific absolute paths in docs.
- Do not rename canonical tb top entities without updating scripts and manifests together.
