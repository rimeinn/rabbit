param(
    [Parameter(Mandatory = $true)][string]$Compiler,
    [Parameter(Mandatory = $true)][string]$Base,
    [Parameter(Mandatory = $true)][string]$RimeDll,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)

$ErrorActionPreference = 'Stop'
$RimeDll = (Resolve-Path -LiteralPath $RimeDll).Path
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$Base = (Resolve-Path -LiteralPath $Base).Path
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$runId = [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $repository "dist/compiled-test-$runId"
$harness = Join-Path $repository "RabbitCompiledSmoke-$runId.ahk"
$generated = Join-Path $repository 'Lib/RabbitCompiledResources.ahk'
$savedGenerated = if (Test-Path -LiteralPath $generated) { [IO.File]::ReadAllBytes($generated) } else { $null }
$generatedZip = [IO.Path]::ChangeExtension($generated, '.zip')
$savedZip = if (Test-Path -LiteralPath $generatedZip) { [IO.File]::ReadAllBytes($generatedZip) } else { $null }
$savedEnvironment = $env:LIBRIME_LIB_DIR
$probeDirectory = Join-Path $testRoot 'probe 空格 space'
$probe = Join-Path $probeDirectory 'probe.exe'
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-Condition($Condition, [string]$Message) {
    if (!$Condition) { throw $Message }
}

function Invoke-Probe([string]$Mode = 'resources', [bool]$ShouldFail = $false) {
    $log = Join-Path $testRoot 'probe.log'
    $errorLog = Join-Path $testRoot 'probe-error.log'
    $process = Start-Process -FilePath $probe -ArgumentList @('/ErrorStdOut', $Mode) `
        -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $errorLog
    $output = (Get-Content -LiteralPath $log -Raw) + (Get-Content -LiteralPath $errorLog -Raw)
    $code = $process.ExitCode
    if (($ShouldFail -and $code -eq 0) -or (!$ShouldFail -and $code -ne 0)) {
        throw "Probe $Mode exited $code`: $output"
    }
    if (!$ShouldFail) { Write-Host ($output -join "`n") }
}

try {
    New-Item -ItemType Directory -Path $probeDirectory -Force | Out-Null
    & (Join-Path $repository '.github/scripts/generate-compiled-resources.ps1') `
        -ManifestPath scripts/compiled-resource-manifest.json -OutputPath $generated `
        -RimeDllPath $RimeDll -Architecture $Architecture
    $source = @'
#Requires AutoHotkey v2.0
#Include Lib\RabbitRimeBootstrap.ahk
/*@Ahk2Exe-Keep
#Include Lib\RabbitCompiledResources.ahk
*/
OnError(ReportUnhandled)
FileEncoding("UTF-8-RAW")
try {
    Main()
} catch as err {
    ReportUnhandled(err)
}
ExitApp()

ReportUnhandled(err, *) {
    FileAppend("Uncaught exception: " . err.Message . "`n  at " . err.What . "`n  " . err.Line
        . "`nStack:`n" . err.Stack . "`n", "*")
    ExitApp(1)
}

Main() {
    local path, api, selected, mode := A_Args.Length ? A_Args[A_Args.Length] : "resources"
    /*@Ahk2Exe-Keep
    if mode = "corrupt" {
        RabbitCompiledResourceInstaller.DefineProp("InstallArchive", {
            Call: CorruptArchive.Bind(RabbitCompiledResourceInstaller.InstallArchive.Bind(RabbitCompiledResourceInstaller))
        })
    }
    */
    RabbitCompiledResourcePolicy.ExtractIfCompiled()
    if mode = "legacy" {
        RabbitCompiledResourcePolicy.EnsureLegacyInstaller()
    } else if mode = "dll" {
        path := RabbitRimeBootstrap.Prepare()
        api := RimeApi(path)
        FileAppend("Selected DLL: " . path . " API: " . api.get_version() . "`n", "*")
    } else if mode = "inspect" {
        path := EnvGet("LIBRIME_LIB_DIR") . "\rime.dll"
        if RabbitRimeBootstrap.InspectCandidate(path, "65535.65535.65535.65535", A_PtrSize * 8) {
            throw Error("Too-old DLL accepted.")
        }
        if RabbitRimeBootstrap.InspectCandidate(path, "0", A_PtrSize = 8 ? 32 : 64) {
            throw Error("Wrong-width DLL accepted.")
        }
        selected := RabbitRimeBootstrap.InspectCandidate(path, "0", A_PtrSize * 8)
        if !selected {
            throw Error("Real DLL API inspection failed.")
        }
        DllCall("FreeLibrary", "Ptr", selected.handle)
    }
    FileAppend("PASS: compiled " . mode . "`n", "*")
}

CorruptArchive(original, installer_class, destination) {
    local file
    original.Call(destination)
    file := FileOpen(destination, "w")
    file.Write("invalid ZIP")
    file.Close()
}
'@
    [IO.File]::WriteAllText($harness, $source, $utf8)
    Push-Location $repository
    try {
        $compileLog = Join-Path $testRoot 'compiler.log'
        $compileError = Join-Path $testRoot 'compiler-error.log'
        $compileProcess = Start-Process -FilePath $Compiler -ArgumentList @(
            '/in', ('"' + $harness + '"'), '/out', ('"' + $probe + '"'),
            '/base', ('"' + $Base + '"'), '/silent', 'verbose'
        ) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $compileLog -RedirectStandardError $compileError
        Assert-Condition ($compileProcess.ExitCode -eq 0 -and (Test-Path -LiteralPath $probe)) `
            "Compilation failed ($($compileProcess.ExitCode)): $(Get-Content $compileLog -Raw) $(Get-Content $compileError -Raw)"
    } finally { Pop-Location }

    # The process inherits an unrelated working directory; extraction must use its own directory.
    Push-Location $testRoot
    try {
        Invoke-Probe
        $marker = Join-Path $probeDirectory '.rabbit'
        $readme = Join-Path $probeDirectory 'README.md'
        $originalHash = (Get-FileHash -LiteralPath $readme).Hash
        $originalSize = (Get-Item -LiteralPath $readme).Length
        Assert-Condition (!(Test-Path -LiteralPath (Join-Path $probeDirectory 'resources.zip'))) 'Temporary ZIP remained beside the EXE.'
        Assert-Condition ((Get-Item -Force -LiteralPath $marker).Attributes.HasFlag([IO.FileAttributes]::Hidden)) 'Marker is not hidden.'
        Assert-Condition (!(Test-Path -LiteralPath (Join-Path $testRoot '.rabbit'))) 'Extraction used the working directory.'
        Assert-Condition (!(Test-Path -LiteralPath (Join-Path $probeDirectory 'rime-install.bat'))) 'BAT extracted on startup.'
        Remove-Item -LiteralPath $readme
        Invoke-Probe
        Assert-Condition (!(Test-Path -LiteralPath $readme)) 'Same-version run restored a deleted resource.'
        Set-Content -LiteralPath $marker -Value 'old-version' -Encoding utf8 -NoNewline -Force
        [IO.File]::WriteAllBytes($readme, [byte[]]::new($originalSize))
        Invoke-Probe
        Assert-Condition ((Get-FileHash -LiteralPath $readme).Hash -eq $originalHash) 'Version change did not overwrite resources.'

        Set-Content -LiteralPath $marker -Value 'corrupt-retry' -Encoding utf8 -NoNewline -Force
        Invoke-Probe corrupt $true
        Assert-Condition ((Get-Content (Join-Path $testRoot 'probe.log') -Raw) -match 'Cannot open the embedded resource ZIP|Invalid extracted resource|RabbitZipResources.Extract') `
            'Corrupt ZIP probe failed for an unexpected reason.'
        Assert-Condition ([IO.File]::ReadAllText($marker) -eq 'corrupt-retry') 'Corrupt ZIP committed a version marker.'
        Assert-Condition ((Get-FileHash -LiteralPath $readme).Hash -eq $originalHash) 'Corrupt ZIP changed installed resources.'
        Invoke-Probe

        Set-Content -LiteralPath $marker -Value 'retry-version' -Encoding utf8 -NoNewline -Force
        Remove-Item -LiteralPath $readme
        New-Item -ItemType Directory -Path $readme | Out-Null
        Invoke-Probe resources $true
        Assert-Condition ([IO.File]::ReadAllText($marker) -eq 'retry-version') 'Failure committed the new version.'
        Remove-Item -LiteralPath $readme
        Invoke-Probe
        Invoke-Probe legacy
        $bat = Join-Path $probeDirectory 'rime-install.bat'
        Assert-Condition (Test-Path -LiteralPath $bat) 'BAT was not extracted on demand.'
        [IO.File]::WriteAllText($bat, 'preserve-user-bat', $utf8)
        Invoke-Probe legacy
        Assert-Condition ([IO.File]::ReadAllText($bat) -eq 'preserve-user-bat') 'Existing BAT was overwritten.'

        $env:LIBRIME_LIB_DIR = Split-Path -Parent (Resolve-Path -LiteralPath $RimeDll).Path
        Invoke-Probe inspect
        Invoke-Probe dll
        $localDll = Join-Path $probeDirectory 'rime.dll'
        Assert-Condition (!(Test-Path -LiteralPath $localDll)) 'Suitable environment DLL did not suppress extraction.'
        [IO.File]::WriteAllText($localDll, 'invalid PE', $utf8)
        Invoke-Probe dll
        Assert-Condition ([IO.File]::ReadAllText($localDll) -eq 'invalid PE') 'Invalid local DLL blocked the environment fallback.'

        # Exercise the real final fallback when this machine has no suitable Weasel installation.
        $env:LIBRIME_LIB_DIR = Join-Path $testRoot 'missing'
        Invoke-Probe dll
        $weasel = Get-ItemProperty 'HKLM:\Software\Rime\Weasel' -ErrorAction SilentlyContinue
        if (!$weasel -or !$weasel.WeaselRoot) {
            Assert-Condition ((Get-FileHash -LiteralPath $localDll).Hash -eq (Get-FileHash -LiteralPath $RimeDll).Hash) `
                'Final fallback did not install the embedded DLL.'
        }
        Copy-Item -LiteralPath $RimeDll -Destination $localDll -Force
        $env:LIBRIME_LIB_DIR = Split-Path -Parent (Resolve-Path -LiteralPath $RimeDll).Path
        Invoke-Probe dll
        Assert-Condition ((Get-Content (Join-Path $testRoot 'probe.log') -Raw).Contains("Selected DLL: $localDll API:")) `
            'A suitable local DLL did not take priority over the environment DLL.'
        Write-Host 'PASS: compiled resource lifecycle and real DLL fallback'
    } finally { Pop-Location }
} finally {
    $env:LIBRIME_LIB_DIR = $savedEnvironment
    if ($null -ne $savedGenerated) { [IO.File]::WriteAllBytes($generated, $savedGenerated) }
    elseif (Test-Path -LiteralPath $generated) { Remove-Item -LiteralPath $generated }
    if ($null -ne $savedZip) { [IO.File]::WriteAllBytes($generatedZip, $savedZip) }
    elseif (Test-Path -LiteralPath $generatedZip) { Remove-Item -LiteralPath $generatedZip }
    if (Test-Path -LiteralPath $harness) { Remove-Item -LiteralPath $harness }
    # Keep the isolated artifacts for inspection; never remove user resource directories.
}
