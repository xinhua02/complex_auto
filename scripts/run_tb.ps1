param(
    [string]$VsimExe = "C:\questasim64_2021.1\win64\vsim.exe",
    [string]$BenderExe = "/c/Users/xinhua02/.cargo/bin/bender.exe",
    [int]$Seed = 1,
    [string]$TestName = "axi_xbar_uvm_test",
    [string]$RunTime = "20us",
    [bool]$RequireUvmCompletion = $true,
    [switch]$FailOnAnyUvmWarning,
    [string[]]$WarningAsErrorPatterns = @(
        "UVM_WARNING.*master_agent\[[01]\]\.driver\.read_driver.*UNEXPECTED_RESPONSE.*id 0000000[01]"
    ),
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
    $tempLogFile = Join-Path $buildDir ("vsim_tb_{0}.log" -f ([Guid]::NewGuid().ToString("N")))
    $ucdbFile = Join-Path $buildDir ("coverage_seed_{0}.ucdb" -f $Seed)
    $ucdbFileTcl = $ucdbFile -replace '\\', '/'
    $doFile = Join-Path $buildDir ("run_{0}.do" -f ([Guid]::NewGuid().ToString("N")))
    $doFileName = Split-Path -Leaf $doFile
    $runCmd = if ([string]::IsNullOrWhiteSpace($RunTime)) { "run -all" } else { "run $RunTime" }

    # Create TCL do file with coverage save
    @(
        "onfinish stop",
        "log -r /*",
        $runCmd,
        "coverage save -du tb {$ucdbFileTcl}",
        "quit -f"
    ) | Out-File -FilePath $doFile -Encoding ascii

    $vsimArgs = @(
        "-c",
        "-coverage",
        "-sv_seed", "$Seed",
        "-wlf", $wlfFile,
        "tb",
        "+UVM_TESTNAME=$TestName",
        "-do", "do $doFileName"
    )

    & $VsimExe @vsimArgs *> $tempLogFile
    if ($LASTEXITCODE -ne 0) {
        throw "Simulation failed with exit code $LASTEXITCODE. See $tempLogFile"
    }

    $logText = if (Test-Path $tempLogFile) { Get-Content -Path $tempLogFile -Raw } else { "" }

    $hasSimError = ($logText -match "\*\* Error")
    $uvmErrorCount = 0
    $uvmFatalCount = 0

    $errorCountMatch = [regex]::Match($logText, "(?m)^#\s*UVM_ERROR\s*:\s*(\d+)")
    if ($errorCountMatch.Success) {
        $uvmErrorCount = [int]$errorCountMatch.Groups[1].Value
    }

    $fatalCountMatch = [regex]::Match($logText, "(?m)^#\s*UVM_FATAL\s*:\s*(\d+)")
    if ($fatalCountMatch.Success) {
        $uvmFatalCount = [int]$fatalCountMatch.Groups[1].Value
    }

    $hasUvmErrorMessage = ($logText -match "(?m)^#\s*UVM_ERROR\s+(?!:).+$")
    $hasUvmFatalMessage = ($logText -match "(?m)^#\s*UVM_FATAL\s+(?!:).+$")

    if ($hasSimError -or ($uvmErrorCount -gt 0) -or ($uvmFatalCount -gt 0) -or $hasUvmErrorMessage -or $hasUvmFatalMessage) {
        throw "Simulation reported errors. See $tempLogFile"
    }

    if ($RequireUvmCompletion) {
        $hasUvmDoneSummary =
            ($logText -match "UVM Report Summary") -or
            ($logText -match "\*\* Report counts by severity") -or
            ($logText -match "\[TEST_DONE\]")
        if (-not $hasUvmDoneSummary) {
            throw "Simulation ended without UVM completion summary markers. See $tempLogFile"
        }
    }

    if ($FailOnAnyUvmWarning -and ($logText -match "UVM_WARNING")) {
        throw "Simulation reported UVM_WARNING while -FailOnAnyUvmWarning is enabled. See $tempLogFile"
    }

    foreach ($pattern in $WarningAsErrorPatterns) {
        if (-not [string]::IsNullOrWhiteSpace($pattern) -and ($logText -match $pattern)) {
            throw "Simulation matched warning-as-error pattern '$pattern'. See $tempLogFile"
        }
    }

    $reportedLog = $tempLogFile
    try {
        Copy-Item -Path $tempLogFile -Destination $logFile -Force
        $reportedLog = $logFile
    }
    catch {
        # Keep using temp log if the default log file is locked by another process.
    }

    Write-Host "Simulation completed successfully. Log: $reportedLog"
    Write-Host "Wave database updated: $wlfFile"
    Write-Host "Simulation run command: $runCmd"
    if ((Test-Path $ucdbFile)) {
        Write-Host "Coverage database: $ucdbFile"
    }
}
finally {
    Pop-Location
}
