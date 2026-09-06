[CmdletBinding()]
param(
    [string]$OutputDirectory = "release"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$manifestPath = Join-Path $projectRoot "manifest"
if (-not (Test-Path $manifestPath)) {
    throw "manifest was not found at $manifestPath"
}

$manifest = Get-Content $manifestPath
$requiredEntries = @(
    "manifest",
    "source",
    "components",
    "images",
    "audio"
)

foreach ($entry in $requiredEntries) {
    if (-not (Test-Path (Join-Path $projectRoot $entry))) {
        throw "Required package entry is missing: $entry"
    }
}

if ($manifest -match "(?im)^\s*openweather_api_key\s*=") {
    throw "Refusing to package: manifest contains openweather_api_key. Store provider credentials in Supabase Edge Function secrets."
}

$buildVersionLine = $manifest | Where-Object { $_ -match "^build_version=" } | Select-Object -First 1
if (-not $buildVersionLine) {
    throw "manifest does not define build_version"
}

$buildVersion = ($buildVersionLine -split "=", 2)[1]
$outputPath = Join-Path $projectRoot $OutputDirectory
$packagePath = Join-Path $outputPath ("BrokenBowVacationCabins-build{0}.zip" -f $buildVersion)

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
Remove-Item $packagePath -Force -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($packagePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entry in $requiredEntries) {
        $entryPath = Join-Path $projectRoot $entry
        if (Test-Path $entryPath -PathType Leaf) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $entryPath, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            continue
        }

        Get-ChildItem -Path $entryPath -File -Recurse | ForEach-Object {
            $archivePath = $_.FullName.Substring($projectRoot.Length + 1).Replace("\", "/")
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $archivePath, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
} finally {
    $archive.Dispose()
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
try {
    $archiveEntries = $archive.Entries.FullName
    foreach ($entry in @("manifest", "source/", "components/", "images/", "audio/")) {
        if (-not ($archiveEntries | Where-Object { $_ -eq $entry -or $_ -like "$entry*" })) {
            throw "Package validation failed: $entry is missing from the ZIP root"
        }
    }
} finally {
    $archive.Dispose()
}

Write-Output "Release package created: $packagePath"
