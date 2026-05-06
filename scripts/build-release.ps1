param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$Version,
    [string]$OutputDir = "Releases",
    [string]$Channel = "win",
    [switch]$PreserveReleaseOutput,
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

    if ($InputVersion -match '^\d+\.\d+\.\d+([\-+][0-9A-Za-z\-.+]+)?$') {
        return $InputVersion
    }

    throw "Version '$InputVersion' is not compatible with Velopack. Use v1.4 tags and project versions like 1.4, or package versions like 1.4.0."
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

Write-Host "Velopack release output created under: $releaseDir"
