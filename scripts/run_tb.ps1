param(
    [string]$VsimExe = "C:\questasim64_2021.1\win64\vsim.exe",
    [string]$BenderExe = "/c/Users/xinhua02/.cargo/bin/bender.exe",
    [int]$Seed = 1,
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$axiDir = Join-Path $repoRoot "axi"
$buildDir = Join-Path $axiDir "build"
$compileScript = Join-Path $PSScriptRoot "compile_axi_vsim.ps1"
$logFile = Join-Path $buildDir "vsim_tb.log"

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
    $proc = Start-Process -FilePath $VsimExe `
        -ArgumentList @("-c", "-sv_seed", "$Seed", "tb", "-do", "run -all; quit -f") `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $logFile

    if ($proc.ExitCode -ne 0) {
        throw "Simulation failed with exit code $($proc.ExitCode). See $logFile"
    }

    $logText = Get-Content -Path $logFile -Raw
    if ($logText -match "\*\* Error" -or $logText -match "UVM_ERROR" -or $logText -match "UVM_FATAL") {
        throw "Simulation reported errors. See $logFile"
    }

    Write-Host "Simulation completed successfully. Log: $logFile"
}
finally {
    Pop-Location
}
