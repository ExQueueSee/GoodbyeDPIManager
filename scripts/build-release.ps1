param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$Version,
    [string]$InnoSetupPath,
    [switch]$SkipInstaller
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

function Resolve-InnoSetupCompiler {
    param([string]$CandidatePath)

    if ($CandidatePath) {
        if (Test-Path -LiteralPath $CandidatePath) {
            return (Resolve-Path -LiteralPath $CandidatePath).Path
        }

        throw "Inno Setup compiler was not found at '$CandidatePath'."
    }

    $fromPath = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($fromPath) {
        return $fromPath.Source
    }

    $defaultPaths = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )

    foreach ($path in $defaultPaths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }

    throw "Inno Setup compiler was not found. Install Inno Setup 6 or pass -InnoSetupPath 'C:\Path\To\ISCC.exe'."
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$projectPath = Join-Path $repoRoot "GoodbyeDPIManager\GoodbyeDPIManager.csproj"
$installerScript = Join-Path $repoRoot "installer\GoodbyeDPIManager.iss"
$publishDir = Join-Path $repoRoot "publish\$Runtime"

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

Write-Host "Building GoodbyeDPI Manager $Version for $Runtime..."

if (Test-Path -LiteralPath $publishDir) {
    Remove-Item -LiteralPath $publishDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $publishDir | Out-Null

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

if ($SkipInstaller) {
    Write-Host "Publish output created at: $publishDir"
    return
}

$isccPath = Resolve-InnoSetupCompiler $InnoSetupPath
$versionInfo = "{0}.0.0" -f $Version
Invoke-CommandChecked $isccPath @("/DMyAppVersion=$Version", "/DMyAppVersionInfo=$versionInfo", $installerScript)

Write-Host "Installer output created under: $(Join-Path $repoRoot 'installer\Output')"
