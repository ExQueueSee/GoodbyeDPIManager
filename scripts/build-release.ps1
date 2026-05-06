param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$Version,
    [string]$OutputDir = "Releases",
    [string]$Channel = "win",
    [switch]$PreserveReleaseOutput,
    [switch]$SkipSetupElevationPatch,
    [switch]$SkipPackage
)

$ErrorActionPreference = "Stop"

function Invoke-CommandChecked {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    Write-Host "> $FilePath $($Arguments -join ' ')"
    & $FilePath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath"
    }
}

function ConvertTo-SemVer {
    param([string]$InputVersion)

    if ($InputVersion -match '^\d+\.\d+$') {
        return "$InputVersion.0"
    }

    if ($InputVersion -match '^(\d+\.\d+)([\-+][0-9A-Za-z\-.+]+)$') {
        return "$($Matches[1]).0$($Matches[2])"
    }

    if ($InputVersion -match '^\d+\.\d+\.\d+([\-+][0-9A-Za-z\-.+]+)?$') {
        return $InputVersion
    }

    throw "Version '$InputVersion' is not compatible with Velopack. Use tags/project versions like 1.5, 1.5-beta.1, or package versions like 1.5.0."
}

function Assert-PathInsideRepo {
    param(
        [string]$RepoRoot,
        [string]$Path
    )

    $fullRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $fullPath = [System.IO.Path]::GetFullPath($Path)

    if (-not $fullPath.StartsWith($fullRepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside the repository: $fullPath"
    }
}

function Add-Win32ResourceEditor {
    if ("Win32ResourceEditor" -as [type]) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class Win32ResourceEditor
{
    private const uint LOAD_LIBRARY_AS_DATAFILE = 0x00000002;
    private static readonly IntPtr RT_MANIFEST = new IntPtr(24);
    private static readonly IntPtr MANIFEST_ID = new IntPtr(1);

    private delegate bool EnumResLangProc(IntPtr hModule, IntPtr lpszType, IntPtr lpszName, ushort wIDLanguage, IntPtr lParam);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hFile, uint dwFlags);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool FreeLibrary(IntPtr hModule);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool EnumResourceLanguages(IntPtr hModule, IntPtr lpType, IntPtr lpName, EnumResLangProc lpEnumFunc, IntPtr lParam);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr FindResourceEx(IntPtr hModule, IntPtr lpType, IntPtr lpName, ushort wLanguage);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint SizeofResource(IntPtr hModule, IntPtr hResInfo);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LoadResource(IntPtr hModule, IntPtr hResInfo);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LockResource(IntPtr hResData);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr BeginUpdateResource(string pFileName, bool bDeleteExistingResources);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool UpdateResource(IntPtr hUpdate, IntPtr lpType, IntPtr lpName, ushort wLanguage, byte[] lpData, uint cbData);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool EndUpdateResource(IntPtr hUpdate, bool fDiscard);

    public static ushort[] GetManifestLanguages(string fileName)
    {
        List<ushort> languages = new List<ushort>();
        IntPtr module = LoadLibraryEx(fileName, IntPtr.Zero, LOAD_LIBRARY_AS_DATAFILE);

        if (module == IntPtr.Zero) {
            ThrowLastWin32Error("LoadLibraryEx");
        }

        try {
            EnumResLangProc callback = (hModule, type, name, language, lParam) => {
                languages.Add(language);
                return true;
            };

            EnumResourceLanguages(module, RT_MANIFEST, MANIFEST_ID, callback, IntPtr.Zero);
            return languages.ToArray();
        }
        finally {
            FreeLibrary(module);
        }
    }

    public static byte[] ReadManifestResource(string fileName, ushort language)
    {
        IntPtr module = LoadLibraryEx(fileName, IntPtr.Zero, LOAD_LIBRARY_AS_DATAFILE);

        if (module == IntPtr.Zero) {
            ThrowLastWin32Error("LoadLibraryEx");
        }

        try {
            IntPtr resourceInfo = FindResourceEx(module, RT_MANIFEST, MANIFEST_ID, language);
            if (resourceInfo == IntPtr.Zero) {
                ThrowLastWin32Error("FindResourceEx");
            }

            uint size = SizeofResource(module, resourceInfo);
            IntPtr resourceHandle = LoadResource(module, resourceInfo);
            if (resourceHandle == IntPtr.Zero) {
                ThrowLastWin32Error("LoadResource");
            }

            IntPtr resourcePointer = LockResource(resourceHandle);
            if (resourcePointer == IntPtr.Zero) {
                ThrowLastWin32Error("LockResource");
            }

            byte[] bytes = new byte[size];
            Marshal.Copy(resourcePointer, bytes, 0, checked((int) size));
            return bytes;
        }
        finally {
            FreeLibrary(module);
        }
    }

    public static void UpdateManifestResource(string fileName, ushort language, byte[] manifestBytes)
    {
        IntPtr updateHandle = BeginUpdateResource(fileName, false);

        if (updateHandle == IntPtr.Zero) {
            ThrowLastWin32Error("BeginUpdateResource");
        }

        bool committed = false;

        try {
            if (!UpdateResource(updateHandle, RT_MANIFEST, MANIFEST_ID, language, manifestBytes, (uint) manifestBytes.Length)) {
                ThrowLastWin32Error("UpdateResource");
            }

            if (!EndUpdateResource(updateHandle, false)) {
                ThrowLastWin32Error("EndUpdateResource");
            }

            committed = true;
        }
        finally {
            if (!committed) {
                EndUpdateResource(updateHandle, true);
            }
        }
    }

    private static void ThrowLastWin32Error(string operation)
    {
        throw new Win32Exception(Marshal.GetLastWin32Error(), operation + " failed");
    }
}
'@
}

function Get-PortableExecutableOverlay {
    param([string]$Path)

    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    $reader = [System.IO.BinaryReader]::new($stream)

    try {
        if ($stream.Length -lt 0x40) {
            return [byte[]]::Empty
        }

        $stream.Position = 0x3C
        $peHeaderOffset = $reader.ReadInt32()

        if ($peHeaderOffset -le 0 -or $peHeaderOffset + 24 -gt $stream.Length) {
            return [byte[]]::Empty
        }

        $stream.Position = $peHeaderOffset
        $signature = $reader.ReadUInt32()

        if ($signature -ne 0x00004550) {
            return [byte[]]::Empty
        }

        $stream.Position = $peHeaderOffset + 6
        $sectionCount = $reader.ReadUInt16()

        $stream.Position = $peHeaderOffset + 20
        $optionalHeaderSize = $reader.ReadUInt16()

        $sectionTableOffset = $peHeaderOffset + 24 + $optionalHeaderSize
        $overlayOffset = 0L

        for ($index = 0; $index -lt $sectionCount; $index++) {
            $sectionOffset = $sectionTableOffset + ($index * 40)

            if ($sectionOffset + 24 -gt $stream.Length) {
                break
            }

            $stream.Position = $sectionOffset + 16
            $rawSize = [int64]$reader.ReadUInt32()
            $rawPointer = [int64]$reader.ReadUInt32()

            if ($rawPointer -gt 0 -and $rawSize -gt 0) {
                $sectionEnd = $rawPointer + $rawSize
                if ($sectionEnd -gt $overlayOffset) {
                    $overlayOffset = $sectionEnd
                }
            }
        }

        if ($overlayOffset -le 0 -or $overlayOffset -ge $stream.Length) {
            return [byte[]]::Empty
        }

        $overlayLength = $stream.Length - $overlayOffset

        if ($overlayLength -gt [int]::MaxValue) {
            throw "Setup executable payload overlay is too large to preserve."
        }

        $overlayBytes = [byte[]]::new([int]$overlayLength)
        $stream.Position = $overlayOffset
        $bytesRead = $stream.Read($overlayBytes, 0, $overlayBytes.Length)

        if ($bytesRead -ne $overlayBytes.Length) {
            throw "Could not read setup executable payload overlay."
        }

        return $overlayBytes
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

function Set-SetupRequiresAdministrator {
    param([string]$SetupPath)

    if (-not (Test-Path -LiteralPath $SetupPath)) {
        throw "Could not find setup executable to patch: $SetupPath"
    }

    Add-Win32ResourceEditor

    $originalLength = (Get-Item -LiteralPath $SetupPath).Length
    $overlayBytes = Get-PortableExecutableOverlay $SetupPath
    $languages = [Win32ResourceEditor]::GetManifestLanguages($SetupPath)

    if ($languages.Count -eq 0) {
        throw "Could not find a manifest resource in setup executable: $SetupPath"
    }

    foreach ($language in $languages) {
        $manifestBytes = [Win32ResourceEditor]::ReadManifestResource($SetupPath, $language)
        $manifest = [System.Text.Encoding]::UTF8.GetString($manifestBytes).TrimEnd([char]0)
        $updatedManifest = [regex]::Replace(
            $manifest,
            '(<requestedExecutionLevel\b[^>]*\blevel\s*=\s*["''])[^"''<>]+(["''])',
            '${1}requireAdministrator${2}',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )

        if ($updatedManifest -eq $manifest -and $updatedManifest -notmatch 'requestedExecutionLevel\b[^>]*\blevel\s*=\s*["'']requireAdministrator["'']') {
            throw "Could not find requestedExecutionLevel in setup manifest."
        }

        $updatedBytes = [System.Text.Encoding]::UTF8.GetBytes($updatedManifest)
        [Win32ResourceEditor]::UpdateManifestResource($SetupPath, $language, $updatedBytes)
    }

    $patchedLength = (Get-Item -LiteralPath $SetupPath).Length

    if ($overlayBytes.Length -gt 0 -and $patchedLength -lt $originalLength) {
        $appendStream = [System.IO.File]::Open($SetupPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

        try {
            $appendStream.Write($overlayBytes, 0, $overlayBytes.Length)
        }
        finally {
            $appendStream.Dispose()
        }
    }

    $verifiedManifest = [System.Text.Encoding]::UTF8.GetString(
        [Win32ResourceEditor]::ReadManifestResource($SetupPath, $languages[0])
    )

    if ($verifiedManifest -notmatch 'requestedExecutionLevel\b[^>]*\blevel\s*=\s*["'']requireAdministrator["'']') {
        throw "Setup executable manifest was not patched to require administrator."
    }

    Write-Host "Patched setup executable to request administrator privileges: $SetupPath"
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$projectPath = Join-Path $repoRoot "GoodbyeDPIManager\GoodbyeDPIManager.csproj"
$publishDir = Join-Path $repoRoot "publish\$Runtime"
$releaseDir = Join-Path $repoRoot $OutputDir
$iconPath = Join-Path $repoRoot "GoodbyeDPIManager\appicon.ico"

if (-not $Version) {
    [xml]$projectXml = Get-Content -Raw -LiteralPath $projectPath
    $Version = $projectXml.Project.PropertyGroup |
        ForEach-Object { $_.Version } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1
}

if (-not $Version) {
    throw "Could not determine the app version from '$projectPath'."
}

$packageVersion = ConvertTo-SemVer $Version

Write-Host "Building GoodbyeDPI Manager $Version for $Runtime..."
Write-Host "Velopack package version: $packageVersion"

Assert-PathInsideRepo $repoRoot $publishDir
Assert-PathInsideRepo $repoRoot $releaseDir

if (Test-Path -LiteralPath $publishDir) {
    Remove-Item -LiteralPath $publishDir -Recurse -Force
}

if ((Test-Path -LiteralPath $releaseDir) -and -not $PreserveReleaseOutput) {
    Remove-Item -LiteralPath $releaseDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $publishDir | Out-Null
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

Invoke-CommandChecked "dotnet" @("restore", $projectPath)
Invoke-CommandChecked "dotnet" @(
    "publish",
    $projectPath,
    "--configuration", $Configuration,
    "--runtime", $Runtime,
    "--self-contained", "true",
    "-p:DebugType=none",
    "-p:DebugSymbols=false",
    "--output", $publishDir
)

if ($SkipPackage) {
    Write-Host "Publish output created at: $publishDir"
    return
}

Invoke-CommandChecked "dotnet" @("tool", "restore")

$previousRollForward = $env:DOTNET_ROLL_FORWARD
$env:DOTNET_ROLL_FORWARD = "Major"

try {
    Invoke-CommandChecked "dotnet" @(
        "tool", "run", "vpk", "--",
        "pack",
        "--packId", "GoodbyeDPIManager",
        "--packVersion", $packageVersion,
        "--packDir", $publishDir,
        "--mainExe", "GoodbyeDPIManager.exe",
        "--packTitle", "GoodbyeDPI Manager",
        "--packAuthors", "Ataberk Tekin",
        "--outputDir", $releaseDir,
        "--runtime", $Runtime,
        "--channel", $Channel,
        "--icon", $iconPath
    )
}
finally {
    $env:DOTNET_ROLL_FORWARD = $previousRollForward
}

if (-not $SkipSetupElevationPatch) {
    $setupPath = Join-Path $releaseDir "GoodbyeDPIManager-$Channel-Setup.exe"
    Set-SetupRequiresAdministrator $setupPath
}

Write-Host "Velopack release output created under: $releaseDir"
