param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$autoHotkeyUrl = "https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.19/AutoHotkey_2.0.19.zip"
$autoHotkeySha256 = "4e0d0e65655066a646a210951320feaef0729a3597177131adaec4066bef5869"
$ahk2ExeUrl = "https://github.com/AutoHotkey/Ahk2Exe/releases/download/Ahk2Exe1.1.37.02a2/Ahk2Exe1.1.37.02a2.zip"
$ahk2ExeSha256 = "c29b8c3a5124850d79fc9e66e2ca79677c377d7f31631ad3022ba159c5d9e3be"
$rcEditUrl = "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe"
$rcEditSha256 = "3e7801db1a5edbec91b49a24a094aad776cb4515488ea5a4ca2289c400eade2a"

function Assert-FileHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedSha256
    )

    $actualSha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $ExpectedSha256) {
        throw "SHA-256 mismatch for ${Path}: expected ${ExpectedSha256}, got ${actualSha256}"
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "${FilePath} exited with code ${LASTEXITCODE}"
    }
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$assetsDirectory = Join-Path $repositoryRoot "assets"
$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$temporaryDirectory = Join-Path $temporaryRoot ("rabbit-autohotkey-" + [System.Guid]::NewGuid())
$temporaryDirectory = [System.IO.Path]::GetFullPath($temporaryDirectory)

if (!$temporaryDirectory.StartsWith(
    $temporaryRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Temporary directory escaped the system temporary root: ${temporaryDirectory}"
}

New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null

try {
    $autoHotkeyArchive = Join-Path $temporaryDirectory "AutoHotkey_2.0.19.zip"
    $autoHotkeyDirectory = Join-Path $temporaryDirectory "autohotkey"
    $ahk2ExeArchive = Join-Path $temporaryDirectory "Ahk2Exe.zip"
    $ahk2ExeDirectory = Join-Path $temporaryDirectory "ahk2exe"
    $rcEditPath = Join-Path $temporaryDirectory "rcedit.exe"
    $preparedDirectory = Join-Path $temporaryDirectory "prepared"

    Invoke-WebRequest -Uri $autoHotkeyUrl -OutFile $autoHotkeyArchive
    Assert-FileHash -Path $autoHotkeyArchive -ExpectedSha256 $autoHotkeySha256
    Expand-Archive -LiteralPath $autoHotkeyArchive -DestinationPath $autoHotkeyDirectory

    Invoke-WebRequest -Uri $ahk2ExeUrl -OutFile $ahk2ExeArchive
    Assert-FileHash -Path $ahk2ExeArchive -ExpectedSha256 $ahk2ExeSha256
    Expand-Archive -LiteralPath $ahk2ExeArchive -DestinationPath $ahk2ExeDirectory

    Invoke-WebRequest -Uri $rcEditUrl -OutFile $rcEditPath
    Assert-FileHash -Path $rcEditPath -ExpectedSha256 $rcEditSha256

    New-Item -ItemType Directory -Path $preparedDirectory | Out-Null
    Copy-Item (Join-Path $autoHotkeyDirectory "AutoHotkey32.exe") $preparedDirectory
    Copy-Item (Join-Path $autoHotkeyDirectory "AutoHotkey64.exe") $preparedDirectory
    $compilerDirectory = Join-Path $preparedDirectory "Compiler"
    New-Item -ItemType Directory -Path $compilerDirectory | Out-Null
    Copy-Item (Join-Path $ahk2ExeDirectory "*") $compilerDirectory -Recurse -Force

    $iconDefinitions = @(
        @{
            Source = "zhuyin-t.svg"
            Destination = "rabbit.ico"
        },
        @{
            Source = "zhuyin-t-alt.svg"
            Destination = "rabbit-alt.ico"
        },
        @{
            Source = "pinyin-t.svg"
            Destination = "rabbit-ascii.ico"
        }
    )
    foreach ($iconDefinition in $iconDefinitions) {
        Invoke-Checked -FilePath "magick.exe" -ArgumentList @(
            "-background",
            "transparent",
            "-define",
            "icon:auto-resize=16,24,32,48,256",
            (Join-Path $assetsDirectory $iconDefinition.Source),
            (Join-Path $preparedDirectory $iconDefinition.Destination)
        )
    }

    $rabbitIcon = Join-Path $preparedDirectory "rabbit.ico"
    Invoke-Checked -FilePath $rcEditPath -ArgumentList @(
        (Join-Path $preparedDirectory "AutoHotkey32.exe"),
        "--set-icon",
        $rabbitIcon
    )
    Invoke-Checked -FilePath $rcEditPath -ArgumentList @(
        (Join-Path $preparedDirectory "AutoHotkey64.exe"),
        "--set-icon",
        $rabbitIcon
    )

    New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force | Out-Null
    Copy-Item (Join-Path $preparedDirectory "*") $resolvedOutputDirectory -Force
} finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}
