# Standalone caret-hook build and test

This directory contains a hook-only probe. The injected callback does not call
TSF, MSAA, UIA, or any caret API. It writes a fixed marker to the shared data
block, so the test answers one question: can the generated shellcode install a
thread hook and receive the message in the target process?

The controller and target must have the same bitness:

| Controller | Target | Payload |
| --- | --- | --- |
| `AutoHotkey64.exe` | `AutoHotkey64.exe` | x64 |
| `AutoHotkey32.exe` | `AutoHotkey32.exe` | x86 |

Do not mix an x86 payload with a 64-bit target, or vice versa.

## 1. Open a PowerShell window

Run the following commands from the repository root:

```powershell
$ErrorActionPreference = "Stop"
$vsdev = "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat"
New-Item -ItemType Directory -Force -Path ".codex-caret-hook" | Out-Null
New-Item -ItemType Directory -Force -Path "tests\CaretHook\generated" | Out-Null
```

If Visual Studio is installed in another edition or directory, update
`$vsdev` to the installed `VsDevCmd.bat` path.

## 2. Build and extract the x64 payload

```powershell
$cmd = 'call "' + $vsdev + '" -arch=x64 && cl /nologo /O2 /Ob1 /c /GS- /std:c++20 /Fo.codex-caret-hook\CaretHookProbe-x64.obj tests\CaretHook\CaretHookProbe.cpp'
cmd.exe /d /s /c $cmd
python tests\CaretHook\build_caret_hook.py .codex-caret-hook\CaretHookProbe-x64.obj .codex-caret-hook\CaretHookProbe-x64.bin tests\CaretHook\generated\CaretHookPayloadX64.ahk .codex-caret-hook\CaretHookProbe-x64.json
Get-Content .codex-caret-hook\CaretHookProbe-x64.json
```

The metadata should report `machine: 34404`, `pointer_size: 8`, and
`rect_offset: 56`.

## 3. Run the x64 test

```powershell
$proc = Start-Process -FilePath "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "tests\CaretHook\CaretHookTest.ahk" -WindowStyle Hidden -Wait -PassThru
$proc.ExitCode
```

The exit code must be `0`. The test log is written to
`$env:TEMP\RabbitCaretHookTest-<controller-pid>.log`. The final line contains
`passed ptr=8` and the fixed marker:

```text
passed ptr=8, home=[324508639,610839776,195948557,12648430], end=[324508639,610839776,195948557,12648430]
```

## 4. Build and run the x86 test

Use the same PowerShell window:

```powershell
$cmd = 'call "' + $vsdev + '" -arch=x86 && cl /nologo /O2 /Ob1 /c /GS- /std:c++20 /Fo.codex-caret-hook\CaretHookProbe-x86.obj tests\CaretHook\CaretHookProbe.cpp'
cmd.exe /d /s /c $cmd
python tests\CaretHook\build_caret_hook.py .codex-caret-hook\CaretHookProbe-x86.obj .codex-caret-hook\CaretHookProbe-x86.bin tests\CaretHook\generated\CaretHookPayloadX86.ahk .codex-caret-hook\CaretHookProbe-x86.json
Get-Content .codex-caret-hook\CaretHookProbe-x86.json

$proc = Start-Process -FilePath "C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe" -ArgumentList "tests\CaretHook\CaretHookTest.ahk" -WindowStyle Hidden -Wait -PassThru
$proc.ExitCode
```

The x86 metadata should report `machine: 332`, `pointer_size: 4`, and
`rect_offset: 32`. The test log must end with `passed ptr=4` and the same
marker values.

## 5. Clean local build output

The object files, flattened shellcode, metadata, generated AHK payloads, and
Python cache are local test output. They can be removed after the test:

```powershell
Remove-Item -LiteralPath ".codex-caret-hook" -Recurse -Force
Remove-Item -LiteralPath "tests\CaretHook\generated" -Recurse -Force
Remove-Item -LiteralPath "tests\CaretHook\__pycache__" -Recurse -Force -ErrorAction SilentlyContinue
```
