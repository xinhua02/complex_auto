param(
    [string]$VsimExe = "C:\questasim64_2021.1\win64\vsim.exe",
    [string]$BenderExe = "/c/Users/xinhua02/.cargo/bin/bender.exe",
    [int]$Seed = 1,
    [string]$TestName = "axi_xbar_uvm_test",
    [string]$RunTime = "20us",
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$axiDir = Join-Path $repoRoot "axi"
$buildDir = Join-Path $axiDir "build"
$compileScript = Join-Path $PSScriptRoot "compile_axi_vsim.ps1"
$logFile = Join-Path $buildDir "vsim_tb.log"
$wlfFile = Join-Path $buildDir "vsim.wlf"

if (-not (Test-Path $VsimExe)) {
    throw "vsim executable not found: $VsimExe"
}

if (-not (Test-Path $compileScript)) {
    throw "Compile script not found: $compileScript"
}

if (-not $SkipCompile) {
    & $compileScript -VsimExe $VsimExe -BenderExe $BenderExe
}

if (-not (Test-Path $buildDir)) {
    throw "Build directory not found: $buildDir"
}

Push-Location $buildDir
try {
    $runCmd = if ([string]::IsNullOrWhiteSpace($RunTime)) { "run -all" } else { "run $RunTime" }

    $vsimArgs = @(
        "-c",
        "-sv_seed", "$Seed",
        "-wlf", $wlfFile,
        "tb",
        "+UVM_TESTNAME=$TestName",
        "-do", "log -r /*; $runCmd; quit -f"
    )

    & $VsimExe @vsimArgs *> $logFile
    if ($LASTEXITCODE -ne 0) {
        throw "Simulation failed with exit code $LASTEXITCODE. See $logFile"
    }

    $logText = if (Test-Path $logFile) { Get-Content -Path $logFile -Raw } else { "" }
    if ($logText -match "\*\* Error" -or $logText -match "UVM_ERROR" -or $logText -match "UVM_FATAL") {
        throw "Simulation reported errors. See $logFile"
    }

    Write-Host "Simulation completed successfully. Log: $logFile"
    Write-Host "Wave database updated: $wlfFile"
    Write-Host "Simulation run command: $runCmd"
}
finally {
    Pop-Location
}
