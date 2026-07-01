param(
    [string]$VsimExe = "C:\questasim64_2021.1\win64\vsim.exe",
    [string]$BenderExe = "/c/Users/xinhua02/.cargo/bin/bender.exe"
)

$ErrorActionPreference = "Stop"

function Resolve-BenderExecutable {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return $null
    }

    if (Test-Path $InputPath) {
        return (Resolve-Path $InputPath).Path
    }

    # Support MSYS-style path such as /c/Users/.../bender.exe.
    if ($InputPath -match '^/([a-zA-Z])/(.+)$') {
        $drive = $matches[1].ToUpper()
        $rest = $matches[2] -replace '/', '\\'
        $winPath = "${drive}:\\$rest"
        if (Test-Path $winPath) {
            return (Resolve-Path $winPath).Path
        }
    }

    $cmd = Get-Command $InputPath -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        return $cmd.Source
    }

    return $null
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$axiDir = Join-Path $repoRoot "axi"
$buildDir = Join-Path $axiDir "build"

if (-not (Test-Path $VsimExe)) {
    throw "vsim executable not found: $VsimExe"
}

$resolvedBenderExe = Resolve-BenderExecutable -InputPath $BenderExe
if ($null -eq $resolvedBenderExe) {
    throw "Bender executable not found from '$BenderExe'."
}

if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

Push-Location $buildDir
try {
    $compileTcl = Join-Path $buildDir "compile.tcl"
    $compileLog = Join-Path $buildDir "compile_vsim.log"

    $tclLines = & $resolvedBenderExe script vsim -t test -t rtl `
        --vlog-arg="-svinputport=compat" `
        --vlog-arg="-override_timescale 1ns/1ps" `
        --vlog-arg="-suppress 2583" `
        --vlog-arg="-suppress 13389"

    $tcl = $tclLines -join [Environment]::NewLine
    $axiDirUnix = $axiDir -replace '\\', '/'
    $rootReplacement = 'set ROOT "{0}"' -f $axiDirUnix
    $tcl = [regex]::Replace($tcl, 'set ROOT ".*?"', $rootReplacement)
    $tcl = $tcl -replace '"\$ROOT\\', '"$ROOT/'
    $tcl = [regex]::Replace($tcl, '\\(?!\r?\n)', '/')

    @(
        "if {[file exists work]} { vdel -lib work -all }",
        "vlib work",
        "vmap work work"
    ) | Out-File -FilePath $compileTcl -Encoding ascii
    Add-Content -Path $compileTcl -Value $tcl -Encoding ascii
    Add-Content -Path $compileTcl -Value "return 0" -Encoding ascii

    $compileArgs = @(
        "-c",
        "-do", "source compile.tcl; quit -f"
    )

    & $VsimExe @compileArgs *> $compileLog
    if ($LASTEXITCODE -ne 0) {
        throw "vsim compile failed with exit code $LASTEXITCODE. See $compileLog"
    }

    $compileText = Get-Content -Path $compileLog -Raw
    if (($compileText -match "\*\* Error") -or ($compileText -match "\bError:") -or ($compileText -match "\bFatal:")) {
        throw "vsim compile reported errors. See $compileLog"
    }

    Write-Host "Compile completed successfully. Log: $compileLog"
}
finally {
    Pop-Location
}
