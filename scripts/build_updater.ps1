# Compila el actualizador independiente con el compilador de .NET Framework.
# Uso: .\scripts\build_updater.ps1 [-Output <ruta exe>]
param(
    [string]$Output = "build\windows\x64\runner\Release\maple_updater.exe"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) {
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path $csc)) {
    throw "No se encontró csc.exe de .NET Framework"
}

$outDir = Split-Path -Parent $Output
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

& $csc /nologo /target:winexe /optimize+ /out:$Output `
    /r:System.Windows.Forms.dll /r:System.Drawing.dll `
    "updater\MapleUpdater.cs"

if ($LASTEXITCODE -ne 0) {
    throw "csc falló con código $LASTEXITCODE"
}

$file = Get-Item $Output
Write-Output ("maple_updater.exe: " + $file.Length + " bytes")
