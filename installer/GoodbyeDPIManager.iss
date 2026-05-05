; GoodbyeDPI Manager Installer
; NOTE: You can edit the following variables to customize the installer. Changing variable names are not recommended.
#define MyAppName "GoodbyeDPI Manager"
#ifndef MyAppVersion
#define MyAppVersion "1.3"
#endif
#ifndef MyAppVersionInfo
#define MyAppVersionInfo "1.3.0.0"
#endif
#define MyAppPublisher "ExQueueSee"
#define MyAppURL "https://github.com/ExQueueSee/GoodbyeDPIManager"
#define MyAppExeName "GoodbyeDPIManager.exe"

[Setup]
AppId={{A274DBD6-5B8E-486E-8032-84CCFA96CD1B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=admin

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

DisableProgramGroupPage=yes
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
RestartIfNeededByRun=no
OutputDir=Output
OutputBaseFilename=GoodbyeDPIManager_v{#MyAppVersion}_Setup
VersionInfoVersion={#MyAppVersionInfo}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern dark

SetupIconFile=..\GoodbyeDPIManager\appicon.ico

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\publish\win-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\schtasks.exe"; Parameters: "/delete /tn ""GoodbyeDPIManager_Startup"" /f"; Flags: runhidden; RunOnceId: "DeleteStartupTask"
