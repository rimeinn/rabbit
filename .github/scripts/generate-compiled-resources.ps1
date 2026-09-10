param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$RimeDllPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("x86", "x64")]
    [string]$Architecture,

    [string]$RepositoryRoot = ""
)

$ErrorActionPreference = "Stop"

function Convert-ToRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return $Path.Replace("/", "\")
}

function Assert-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $normalizedPath = Convert-ToRelativePath $Path
    if ([System.IO.Path]::IsPathRooted($normalizedPath) -or
        $normalizedPath -match '(^|\\)\.\.($|\\)') {
        throw "${Description} must stay inside the repository: ${Path}"
    }
    return $normalizedPath
}

function Quote-AhkString {
    param([Parameter(Mandatory = $true)][string]$Value)

    return '"' + $Value.Replace('`', '``').Replace('"', '`"') + '"'
}

function Get-ManifestFiles {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $files = [System.Collections.Generic.List[object]]::new()
    $destinations = @{}
    foreach ($resource in @($Manifest.resources)) {
        if (!$resource.source -or !$resource.destination) {
            throw "Every compiled resource needs source and destination fields."
        }

        $source = Assert-RelativePath ([string]$resource.source) "Resource source"
        $destination = Assert-RelativePath ([string]$resource.destination) "Resource destination"
        $sourcePath = Join-Path $Root $source
        $matches = @()
        if ([bool]$resource.recursive) {
            if (!(Test-Path -LiteralPath $sourcePath -PathType Container)) {
                throw "Recursive compiled resource directory was not found: ${source}"
            }
            $matches = @(Get-ChildItem -LiteralPath $sourcePath -Recurse -File | Sort-Object FullName)
            foreach ($match in $matches) {
                $relative = [System.IO.Path]::GetRelativePath($sourcePath, $match.FullName)
                $target = Convert-ToRelativePath (Join-Path $destination $relative)
                Add-ManifestFile $files $destinations $Root $match.FullName $target
            }
            continue
        }

        if ($source -match '[*?\[]') {
            $matches = @(Get-ChildItem -Path $sourcePath -File | Sort-Object FullName)
            if ($matches.Count -eq 0) {
                throw "Compiled resource pattern matched no files: ${source}"
            }
            foreach ($match in $matches) {
                $target = Convert-ToRelativePath (Join-Path $destination $match.Name)
                Add-ManifestFile $files $destinations $Root $match.FullName $target
            }
            continue
        }

        if (!(Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Compiled resource file was not found: ${source}"
        }
        Add-ManifestFile $files $destinations $Root $sourcePath $destination
    }
    if ($files.Count -eq 0) {
        throw "The compiled resource manifest did not produce any files."
    }
    return @($files | Sort-Object Destination)
}

function Add-ManifestFile {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IList]$Files,
        [Parameter(Mandatory = $true)][hashtable]$Destinations,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $normalizedDestination = Assert-RelativePath $Destination "Resource destination"
    $destinationKey = $normalizedDestination.ToLowerInvariant()
    if ($Destinations.ContainsKey($destinationKey)) {
        throw "Compiled resource destination is duplicated: ${normalizedDestination}"
    }
    $Destinations[$destinationKey] = $true
    $relativeSource = [System.IO.Path]::GetRelativePath($Root, $SourcePath)
    $Files.Add([pscustomobject]@{
        Source = Convert-ToRelativePath $relativeSource
        Destination = $normalizedDestination
    })
}

function Get-NumericFileVersion {
    param([Parameter(Mandatory = $true)][string]$Path)

    $versionInfo = (Get-Item -LiteralPath $Path).VersionInfo
    $rawVersion = $versionInfo.FileVersionRaw
    if ($null -eq $rawVersion) {
        $rawVersion = (Get-Item -LiteralPath $Path).VersionInfo.FileVersion
    }
    $version = if ($null -eq $rawVersion) { "" } else { $rawVersion.ToString() }
    # librime supplies the fixed numeric version without a FileVersion string.
    if ($version -notmatch '^\d+(\.\d+){0,3}$' -or $version -eq '0.0.0.0') {
        throw "The embedded librime DLL has no numeric file version: ${Path} (${version})"
    }
    return $version
}

function Get-PeBits {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 0x40 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "The embedded librime DLL is not a valid PE image: ${Path}"
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0x40 -or $peOffset + 0x1a -gt $bytes.Length -or
        [BitConverter]::ToUInt32($bytes, $peOffset) -ne 0x00004550) {
        throw "The embedded librime DLL has an invalid PE header: ${Path}"
    }
    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    $magic = [BitConverter]::ToUInt16($bytes, $peOffset + 0x18)
    if ($machine -eq 0x14c -and $magic -eq 0x10b) {
        return 32
    }
    if ($machine -eq 0x8664 -and $magic -eq 0x20b) {
        return 64
    }
    throw "The embedded librime DLL has an unknown PE architecture: ${Path}"
}

function Resolve-RepositoryPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Join-Path $Root $Path
    }
    return (Resolve-Path -LiteralPath $candidate).Path
}

if (!$RepositoryRoot) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
} else {
    $RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
}
$manifestPath = Resolve-RepositoryPath $RepositoryRoot $ManifestPath
$rimeDllPath = Resolve-RepositoryPath $RepositoryRoot $RimeDllPath
$outputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $OutputPath))
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if (!$manifest.resources) {
    throw "The compiled resource manifest has no resources: ${manifestPath}"
}
$files = Get-ManifestFiles $manifest $RepositoryRoot
$legacyInstaller = $manifest.legacy_installer
if (!$legacyInstaller.source -or !$legacyInstaller.destination) {
    throw "The compiled resource manifest has no legacy installer entry."
}
$legacySource = Assert-RelativePath ([string]$legacyInstaller.source) "Legacy installer source"
$legacyDestination = Assert-RelativePath ([string]$legacyInstaller.destination) "Legacy installer destination"
$legacySourcePath = Join-Path $RepositoryRoot $legacySource
if (!(Test-Path -LiteralPath $legacySourcePath -PathType Leaf)) {
    throw "The legacy installer source was not found: ${legacySource}"
}

$expectedBits = if ($Architecture -eq "x86") { 32 } else { 64 }
$actualBits = Get-PeBits $rimeDllPath
if ($actualBits -ne $expectedBits) {
    throw "The embedded librime DLL architecture (${actualBits}-bit) does not match ${Architecture}."
}
$rimeVersion = Get-NumericFileVersion $rimeDllPath

$outputDirectory = [System.IO.Path]::GetDirectoryName($outputPath)
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$archivePath = [System.IO.Path]::ChangeExtension($outputPath, '.zip')
$archiveStream = [System.IO.File]::Open($archivePath, [System.IO.FileMode]::Create)
try {
    $archive = [System.IO.Compression.ZipArchive]::new($archiveStream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $files) {
            $sourcePath = Join-Path $RepositoryRoot $file.Source
            $file | Add-Member -NotePropertyName Length -NotePropertyValue (Get-Item -LiteralPath $sourcePath).Length
            $file | Add-Member -NotePropertyName Hash -NotePropertyValue (Get-FileHash -LiteralPath $sourcePath).Hash
            $entry = $archive.CreateEntry($file.Destination.Replace('\', '/'), [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $entryStream = $entry.Open()
            try {
                $inputStream = [System.IO.File]::OpenRead($sourcePath)
                try { $inputStream.CopyTo($entryStream) } finally { $inputStream.Dispose() }
            } finally { $entryStream.Dispose() }
        }
    } finally { $archive.Dispose() }
} finally { $archiveStream.Dispose() }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("; This file is generated by .github/scripts/generate-compiled-resources.ps1.")
$lines.Add("; Do not edit it by hand; regenerate it during the compiled build.")
$lines.Add("#Include RabbitCompiledResourcePolicy.ahk")
$lines.Add("#Include RabbitZipResources.ahk")
$lines.Add("")
$lines.Add("global RABBIT_EMBEDDED_RIME_VERSION := " + (Quote-AhkString $rimeVersion))
$lines.Add("global RABBIT_EMBEDDED_RIME_BITS := " + $expectedBits)
$lines.Add("")
$lines.Add("class RabbitCompiledResourceInstaller {")
$lines.Add("    static Extract() {")
$lines.Add("        if !A_IsCompiled {")
$lines.Add("            return")
$lines.Add("        }")
$lines.Add("        if !RabbitCompiledResourcePolicy.ShouldExtract(A_ScriptDir, RABBIT_VERSION) {")
$lines.Add("            return")
$lines.Add("        }")
$lines.Add("        local files := [")
foreach ($file in $files) {
    $lines.Add('            [' + (Quote-AhkString $file.Destination) + ', ' + $file.Length + ', ' + (Quote-AhkString $file.Hash) + '],')
}
$lines.Add("        ]")
$lines.Add('        RabbitZipResources.Install(this.InstallArchive.Bind(this), files, A_ScriptDir)')
$lines.Add("        RabbitCompiledResourcePolicy.Commit(A_ScriptDir, RABBIT_VERSION)")
$lines.Add("    }")
$lines.Add("")
$lines.Add("    static InstallArchive(destination) {")
$lines.Add("        if !A_IsCompiled {")
$lines.Add("            return")
$lines.Add("        }")
$lines.Add('        FileInstall ' + (Quote-AhkString (Convert-ToRelativePath ([System.IO.Path]::GetRelativePath($RepositoryRoot, $archivePath)))) + ', destination, 1')
$lines.Add("    }")
$lines.Add("")
$lines.Add("    static InstallRimeDll() {")
$lines.Add("        if !A_IsCompiled {")
$lines.Add("            return")
$lines.Add("        }")
$lines.Add("        FileInstall " + (Quote-AhkString (Convert-ToRelativePath ([System.IO.Path]::GetRelativePath($RepositoryRoot, $rimeDllPath)))) + ", A_ScriptDir . " + (Quote-AhkString "\rime.dll") + ", 1")
$lines.Add("    }")
$lines.Add("")
$lines.Add("    static InstallLegacyScript() {")
$lines.Add("        if !A_IsCompiled {")
$lines.Add("            return")
$lines.Add("        }")
$lines.Add("        FileInstall " + (Quote-AhkString $legacySource) + ", A_ScriptDir . " + (Quote-AhkString ("\" + $legacyDestination)) + ", 0")
$lines.Add("    }")
$lines.Add("}")
$lines.Add("")
$lines.Add('global rabbit_compiled_resource_extractor := ObjBindMethod(RabbitCompiledResourceInstaller, "Extract")')
$lines.Add('global rabbit_compiled_legacy_installer := ObjBindMethod(RabbitCompiledResourceInstaller, "InstallLegacyScript")')
$lines.Add('global rabbit_compiled_rime_installer := ObjBindMethod(RabbitCompiledResourceInstaller, "InstallRimeDll")')

$outputDirectory = [System.IO.Path]::GetDirectoryName($outputPath)
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($outputPath, ($lines -join "`r`n") + "`r`n", $utf8)
Write-Host ("Generated one ZIP with {0} resources and separate librime {1} for {2}: {3}" -f `
    $files.Count, $rimeVersion, $Architecture, $outputPath)
