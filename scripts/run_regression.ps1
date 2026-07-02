param(
    [ValidateSet("smoke", "nightly", "custom")]
    [string]$RunTier = "smoke",
    [int[]]$Seeds,
    [int]$StartSeed = 1,
    [int]$EndSeed = 10,
    [string]$VsimExe = "C:\questasim64_2021.1\win64\vsim.exe",
    [string]$BenderExe = "/c/Users/xinhua02/.cargo/bin/bender.exe",
    [string]$RunTime = "20us",
    [bool]$RequireUvmCompletion = $true,
    [switch]$FailOnAnyUvmWarning,
    [string[]]$WarningAsErrorPatterns = @(
        "UVM_WARNING.*master_agent\[[01]\]\.driver\.read_driver.*UNEXPECTED_RESPONSE.*id 0000000[01]"
    ),
    [switch]$StopOnFailure
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$runScript = Join-Path $PSScriptRoot "run_tb.ps1"
$buildDir = Join-Path $repoRoot "axi\build"

if (-not (Test-Path $runScript)) {
    throw "Run script not found: $runScript"
}

switch ($RunTier) {
    "smoke" {
        if (-not $Seeds) {
            $Seeds = 1..10
        }
    }
    "nightly" {
        if (-not $Seeds) {
            $Seeds = 1..100
        }
    }
    "custom" {
        if (-not $Seeds) {
            if ($EndSeed -lt $StartSeed) {
                throw "EndSeed must be >= StartSeed"
            }
            $Seeds = $StartSeed..$EndSeed
        }
    }
}

if (-not $Seeds -or $Seeds.Count -eq 0) {
    throw "No seeds specified"
}

$results = @()
$startTime = Get-Date
$compiled = $false

foreach ($seed in $Seeds) {
    $status = "PASS"
    $message = ""
    try {
        if (-not $compiled) {
            & $runScript `
                -VsimExe $VsimExe `
                -BenderExe $BenderExe `
                -Seed $seed `
                -RunTime $RunTime `
                -RequireUvmCompletion:$RequireUvmCompletion `
                -WarningAsErrorPatterns $WarningAsErrorPatterns `
                -FailOnAnyUvmWarning:$FailOnAnyUvmWarning
            $compiled = $true
        }
        else {
            & $runScript `
                -VsimExe $VsimExe `
                -BenderExe $BenderExe `
                -Seed $seed `
                -RunTime $RunTime `
                -RequireUvmCompletion:$RequireUvmCompletion `
                -WarningAsErrorPatterns $WarningAsErrorPatterns `
                -FailOnAnyUvmWarning:$FailOnAnyUvmWarning `
                -SkipCompile
        }
    }
    catch {
        $status = "FAIL"
        $message = $_.Exception.Message
        if ($StopOnFailure) {
            $results += [pscustomobject]@{ Seed = $seed; Status = $status; Message = $message }
            break
        }
    }

    $results += [pscustomobject]@{
        Seed = $seed
        Status = $status
        Message = $message
    }
}

$endTime = Get-Date
$passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
$totalCount = @($results).Count

Write-Host "Regression profile: $RunTier"
Write-Host "Summary: $passCount/$totalCount PASS"
if ($failCount -ne 0) {
    Write-Host "Failures: $failCount"
}
$results | Format-Table -AutoSize

if (-not (Test-Path $buildDir)) {
    New-Item -Path $buildDir -ItemType Directory | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $buildDir ("regression_{0}_{1}.md" -f $RunTier, $timestamp)

$lines = @()
$lines += "# Regression Run Summary"
$lines += ""
$lines += ("Profile: {0}" -f $RunTier)
$lines += ("Start: {0}" -f $startTime.ToString("s"))
$lines += ("End: {0}" -f $endTime.ToString("s"))
$lines += ("Summary: {0}/{1} PASS" -f $passCount, $totalCount)
$lines += ""
$lines += "| Seed | Status | Message |"
$lines += "|---|---|---|"
foreach ($r in $results) {
    $msg = $r.Message
    if (-not $msg) {
        $msg = "-"
    }
    $msg = $msg -replace "\|", "/"
    $lines += ("| {0} | {1} | {2} |" -f $r.Seed, $r.Status, $msg)
}

Set-Content -Path $reportPath -Value $lines -Encoding utf8
Write-Host "Saved regression report: $reportPath"

if ($failCount -ne 0) {
    throw "Regression failed: $failCount seed(s) failed"
}
