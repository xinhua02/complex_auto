param(
    [string]$VsimExe = "C:\questasim64_2021.1\win64\vsim.exe",
    [string]$BenderExe = "/c/Users/xinhua02/.cargo/bin/bender.exe",
    [int]$Seed = 1,
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

Write-Warning "[DEPRECATED] scripts/run_axi_xbar_uvm.ps1 is a compatibility wrapper. Use scripts/run_tb.ps1 as the canonical run entry."

$newScript = Join-Path $PSScriptRoot "run_tb.ps1"
if (-not (Test-Path $newScript)) {
    throw "New run entry script not found: $newScript"
}

& $newScript @PSBoundParameters
