# Empaqueta el build de Windows: ZIP portable + instalador Inno Setup.
# Uso: .\scripts\package_windows.ps1 [-Version 1.1.0] [-Build 2]
param(
    [string]$Version = "",
    [string]$Build = "1"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not $Version) {
    $line = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    $Version = ($line.Matches[0].Groups[1].Value -split '\+')[0]
}

Write-Host "Compilando $Version (build $Build)"
flutter build windows --release --build-name $Version --build-number $Build

$rel = "build/windows/x64/runner/Release"
New-Item -ItemType Directory -Force -Path "$rel/bin" | Out-Null

if (-not (Test-Path "$rel/bin/yt-dlp.exe")) {
    Write-Host "Descargando yt-dlp.exe"
    Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile "$rel/bin/yt-dlp.exe"
}

if (-not (Test-Path "$rel/bin/ffmpeg.exe")) {
    Write-Host "Descargando ffmpeg"
    Invoke-WebRequest -Uri "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" -OutFile "ffmpeg.zip"
    Expand-Archive -Path "ffmpeg.zip" -DestinationPath "ffmpeg-tmp" -Force
    $ffmpeg = Get-ChildItem -Path "ffmpeg-tmp" -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
    $ffprobe = Get-ChildItem -Path "ffmpeg-tmp" -Recurse -Filter "ffprobe.exe" | Select-Object -First 1
    Copy-Item $ffmpeg.FullName "$rel/bin/ffmpeg.exe"
    Copy-Item $ffprobe.FullName "$rel/bin/ffprobe.exe"
    Remove-Item -Recurse -Force "ffmpeg-tmp", "ffmpeg.zip"
}

New-Item -ItemType Directory -Force -Path "dist" | Out-Null
$zip = "dist/maple-video-downloader-$Version-windows-x64.zip"
Compress-Archive -Path "$rel/*" -DestinationPath $zip -CompressionLevel Optimal -Force

$iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $iscc) {
    & $iscc "/DMyAppVersion=$Version" "installer/windows/maple-video-downloader.iss"
} else {
    Write-Warning "Inno Setup no está instalado; se omite el instalador."
}

Get-ChildItem "dist" | Select-Object Name, Length
