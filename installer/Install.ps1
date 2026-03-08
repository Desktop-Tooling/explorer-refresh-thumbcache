# Install Refresh Thumbcache context menu (per-user).
# Run from repo root after: dotnet publish src/RefreshThumbcache/RefreshThumbcache.csproj -c Release
# Or run from installer\ after copying RefreshThumbcache.exe to installer\ or setting $ExePath.

param(
    [string]$ExePath = $null
)

$ErrorActionPreference = 'Stop'
$appName = 'Refresh Thumbcache'
$exeName = 'RefreshThumbcache.exe'

if (-not $ExePath) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $defaultPublish = Join-Path (Split-Path -Parent $scriptRoot) "src\RefreshThumbcache\bin\Release\net8.0\win-x64\publish\$exeName"
    if (Test-Path $defaultPublish) {
        $ExePath = $defaultPublish
    } else {
        $ExePath = Join-Path $scriptRoot $exeName
    }
}

if (-not (Test-Path $ExePath)) {
    Write-Error "RefreshThumbcache.exe not found. Build first: dotnet publish src/RefreshThumbcache/RefreshThumbcache.csproj -c Release"
}

$installDir = Join-Path $env:APPDATA "AMDphreak\RefreshThumbcache"
$null = New-Item -ItemType Directory -Force -Path $installDir
Copy-Item -Path $ExePath -Destination (Join-Path $installDir $exeName) -Force

$exeFullPath = Join-Path $installDir $exeName
$exeEscaped = "`"$exeFullPath`""

# Directory shell (right-click on a folder)
$base = "HKCU:\Software\Classes"
$dirShell = "$base\Directory\shell\RefreshThumbcache"
$dirCmd = "$dirShell\command"
New-Item -Path $dirShell -Force | Out-Null
New-Item -Path $dirCmd -Force | Out-Null
Set-ItemProperty -Path $dirShell -Name "(Default)" -Value "Refresh thumbnail cache"
Set-ItemProperty -Path $dirShell -Name "Position" -Value "Top"
Set-ItemProperty -Path $dirCmd -Name "(Default)" -Value "$exeEscaped `"%1`""

# Directory background (right-click in folder)
$bgShell = "$base\Directory\Background\shell\RefreshThumbcache"
$bgCmd = "$bgShell\command"
New-Item -Path $bgShell -Force | Out-Null
New-Item -Path $bgCmd -Force | Out-Null
Set-ItemProperty -Path $bgShell -Name "(Default)" -Value "Refresh thumbnail cache"
Set-ItemProperty -Path $bgShell -Name "Position" -Value "Top"
Set-ItemProperty -Path $bgCmd -Name "(Default)" -Value "$exeEscaped `"%V`""

Write-Host "Installed. Context menu 'Refresh thumbnail cache' is available when right-clicking a folder or inside a folder."
