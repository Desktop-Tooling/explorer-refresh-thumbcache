; Inno Setup script for Refresh Thumbcache context menu
; Installs per-user; no admin required.

#define MyAppName "Refresh Thumbcache"
#define MyAppPublisher "AMDphreak"
#define MyAppExeName "RefreshThumbcache.exe"

[Setup]
AppId={{B7C8E9A1-2D3F-4E5A-8B6C-9D0E1F2A3B4C}
AppName={#MyAppName}
AppPublisher={#MyAppPublisher}
AppVersion=0.1.0
DefaultDirName={userappdata}\AMDphreak\RefreshThumbcache
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=RefreshThumbcache-Setup-{#SetupSetting("AppVersion")}
SetupIconFile=
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Registry]
; Right-click on a folder: "Refresh thumbnail cache"
Root: HKCU; Subkey: "Software\Classes\Directory\shell\RefreshThumbcache"; ValueType: string; ValueName: ""; ValueData: "Refresh thumbnail cache"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\shell\RefreshThumbcache"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\shell\RefreshThumbcache\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

; Right-click in folder background (new primary menu target on Windows 11)
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\RefreshThumbcache"; ValueType: string; ValueName: ""; ValueData: "Refresh thumbnail cache"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\RefreshThumbcache"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\RefreshThumbcache\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%V"""; Flags: uninsdeletekey

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
