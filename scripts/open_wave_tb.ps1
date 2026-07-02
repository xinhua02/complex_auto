param(
    [string]$VsimExe = "C:\questasim64_2021.1\win64\vsim.exe",
    [string]$BenderExe = "/c/Users/xinhua02/.cargo/bin/bender.exe",
    [switch]$SkipCompile,
    [switch]$ViewPreviousWave,
    [string]$WlfFile = "vsim.wlf",
    [string]$DoFile,
    [string]$RunTime = "-all"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$axiDir = Join-Path $repoRoot "axi"
$buildDir = Join-Path $axiDir "build"
$compileScript = Join-Path $PSScriptRoot "compile_axi_vsim.ps1"

if (-not (Test-Path $VsimExe)) {
    throw "vsim executable not found: $VsimExe"
}

if (-not (Test-Path $compileScript)) {
    throw "Compile script not found: $compileScript"
}

if (-not (Test-Path $buildDir)) {
    throw "Build directory not found: $buildDir"
}

if ($ViewPreviousWave) {
    if ([System.IO.Path]::IsPathRooted($WlfFile)) {
        $wlfPath = $WlfFile
    } else {
        $wlfPath = Join-Path $buildDir $WlfFile
    }

    if (-not (Test-Path $wlfPath)) {
        throw "Wave database not found: $wlfPath"
    }

    Push-Location $buildDir
    try {
        # Use a do file to avoid command-line parsing issues with '-r'.
        $viewDoFile = Join-Path $buildDir "open_wave_viewer.do"
        @(
            "view wave",
            "add wave -r /*",
            "wave zoom full"
        ) | Set-Content -Path $viewDoFile -Encoding ascii

        Start-Process -FilePath $VsimExe `
            -WorkingDirectory (Get-Location).Path `
            -ArgumentList @("-view", $wlfPath, "-do", "do $viewDoFile") | Out-Null

        Write-Host "Questa GUI launched in viewer mode."
        Write-Host "Wave database: $wlfPath"
        Write-Host "Wave dofile: $viewDoFile"
    }
    finally {
        Pop-Location
    }

    return
}

if (-not $SkipCompile) {
    & $compileScript -VsimExe $VsimExe -BenderExe $BenderExe
}

if (-not [string]::IsNullOrWhiteSpace($DoFile)) {
    $resolvedDoFile = Resolve-Path $DoFile -ErrorAction Stop
    $doCmd = "do `"$($resolvedDoFile.Path)`""
} else {
    $doCmd = "view wave; log -r /*; add wave -r sim:/tb/*; run $RunTime"
}

Push-Location $buildDir
try {
    # Launch GUI and return control immediately.
    Start-Process -FilePath $VsimExe `
        -WorkingDirectory (Get-Location).Path `
        -ArgumentList @("tb", "-do", $doCmd) | Out-Null

    Write-Host "Questa GUI launched for tb."
    Write-Host "Wave command: $doCmd"
}
finally {
    Pop-Location
}
