# Uninstall Refresh Thumbcache context menu (per-user).

$ErrorActionPreference = 'Stop'
$base = "HKCU:\Software\Classes"

Remove-Item -Path "$base\Directory\shell\RefreshThumbcache" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$base\Directory\Background\shell\RefreshThumbcache" -Recurse -Force -ErrorAction SilentlyContinue

$installDir = Join-Path $env:APPDATA "AMDphreak\RefreshThumbcache"
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "Uninstalled."
