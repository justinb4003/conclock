; Inno Setup script for the Windows installer. Built by CI:
;   iscc /DAppVersion=0.3.0 /DSourceDir=<release dir> /DOutputDir=dist conclock.iss
; Installs per user (no admin prompt) to %LOCALAPPDATA%\Programs\ConClock.
; Uninstalling leaves the data (conclock.json in %APPDATA%) alone.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
; Never change AppId: upgrades and uninstall find the install by it.
AppId={{AD0D53EF-9FA0-4306-A0DD-C640A1F3DEBC}
AppName=ConClock
AppVersion={#AppVersion}
AppVerName=ConClock {#AppVersion}
AppPublisher=ConClock
AppPublisherURL=https://github.com/justinb4003/conclock
DefaultDirName={autopf}\ConClock
DefaultGroupName=ConClock
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; The running app (often hidden in the tray) holds this mutex; ask to quit it.
AppMutex=com.conclock.conclock.instance
CloseApplications=yes
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\conclock.exe
OutputDir={#OutputDir}
OutputBaseFilename=conclock-{#AppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startup"; Description: "Start ConClock when I sign in"; GroupDescription: "Other:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ConClock"; Filename: "{app}\conclock.exe"
Name: "{autodesktop}\ConClock"; Filename: "{app}\conclock.exe"; Tasks: desktopicon
Name: "{userstartup}\ConClock"; Filename: "{app}\conclock.exe"; Tasks: startup

[Run]
Filename: "{app}\conclock.exe"; Description: "{cm:LaunchProgram,ConClock}"; Flags: nowait postinstall skipifsilent
