/*
 * Copyright (c) 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#Requires AutoHotkey v2.0

#Include ..\support\RabbitTestCommon.ahk

try {
    Main()
} catch as err {
    ReportUnhandled(err)
}

Main() {
    if A_Args.Length < 3 {
        throw Error(
            "Usage: RabbitCompiledResourcesTest.ahk <compiler> <base> <rime-dll> [x86|x64]"
        )
    }
    local architecture := A_Args.Length >= 4 ? A_Args[4] : "x64"
    if architecture != "x86" && architecture != "x64" {
        throw Error("The packaging architecture must be x86 or x64.")
    }
    RunTest(
        "compiled resources, extraction lifecycle, and DLL fallback",
        TestCompiledResources.Bind(A_Args[1], A_Args[2], A_Args[3], architecture)
    )
}

TestCompiledResources(compiler, base, rime_dll, architecture) {
    local repository := RegExReplace(A_ScriptDir, "\\tests\\packaging$", "")
    compiler := ResolvePath(compiler, repository)
    base := ResolvePath(base, repository)
    rime_dll := ResolvePath(rime_dll, repository)
    RequireFile(compiler, "Ahk2Exe compiler")
    RequireFile(base, "AutoHotkey base executable")
    RequireFile(rime_dll, "librime DLL")

    local run_id := A_TickCount . "-" . Random(100000, 999999)
    local test_root := repository . "\dist\compiled-test-" . run_id
    local probe_directory := test_root . "\probe 空格 space"
    local probe := probe_directory . "\probe.exe"
    local harness := repository . "\RabbitCompiledSmoke-" . run_id . ".ahk"
    local generated := repository . "\Lib\RabbitCompiledResources.ahk"
    local generated_zip := RegExReplace(generated, "\.ahk$", ".zip")
    local saved_generated := FileExist(generated) ? ReadBytes(generated) : 0
    local saved_zip := FileExist(generated_zip) ? ReadBytes(generated_zip) : 0
    local saved_environment := EnvGet("LIBRIME_LIB_DIR")
    try {
        DirCreate(probe_directory)
        GenerateResources(repository, generated, rime_dll, architecture)
        FileAppend(BuildProbeSource(), harness, "UTF-8-RAW")
        CompileProbe(compiler, base, harness, probe, repository)

        local marker := probe_directory . "\.rabbit"
        local readme := probe_directory . "\README.md"
        local original_readme := 0

        InvokeProbe(probe, test_root, "resources")
        AssertTrue(FileExist(readme), "The compiled README resource was not extracted.")
        original_readme := ReadBytes(readme)
        AssertTrue(!FileExist(probe_directory . "\resources.zip"),
            "Temporary ZIP remained beside the executable.")
        AssertTrue(InStr(FileGetAttrib(marker), "H"), "The version marker is not hidden.")
        AssertTrue(!FileExist(test_root . "\.rabbit"), "Extraction used the working directory.")
        AssertTrue(!FileExist(probe_directory . "\rime-install.bat"),
            "The legacy installer was extracted on startup.")

        FileDelete(readme)
        InvokeProbe(probe, test_root, "resources")
        AssertTrue(!FileExist(readme), "A same-version run restored a deleted resource.")

        WriteText(marker, "old-version")
        WriteBytes(readme, Buffer(original_readme.Size))
        InvokeProbe(probe, test_root, "resources")
        AssertTrue(BuffersEqual(ReadBytes(readme), original_readme),
            "A version change did not overwrite resources.")

        WriteText(marker, "corrupt-retry")
        InvokeProbe(probe, test_root, "corrupt", true)
        local corrupt_output := ReadText(test_root . "\probe.log")
        AssertTrue(InStr(corrupt_output, "Cannot open the embedded resource ZIP")
            || InStr(corrupt_output, "Invalid extracted resource")
            || InStr(corrupt_output, "RabbitZipResources.Extract"),
            "The corrupt ZIP probe failed for an unexpected reason.")
        AssertEqual("corrupt-retry", ReadText(marker), "A corrupt ZIP committed a version marker.")
        AssertTrue(BuffersEqual(ReadBytes(readme), original_readme),
            "A corrupt ZIP changed installed resources.")
        InvokeProbe(probe, test_root, "resources")

        WriteText(marker, "retry-version")
        FileDelete(readme)
        DirCreate(readme)
        InvokeProbe(probe, test_root, "resources", true)
        AssertEqual("retry-version", ReadText(marker), "A failed extraction committed a new version.")
        FileRemove(readme)
        InvokeProbe(probe, test_root, "resources")

        InvokeProbe(probe, test_root, "legacy")
        local bat := probe_directory . "\rime-install.bat"
        AssertTrue(FileExist(bat), "The legacy installer was not extracted on demand.")
        WriteText(bat, "preserve-user-bat")
        InvokeProbe(probe, test_root, "legacy")
        AssertEqual("preserve-user-bat", ReadText(bat), "An existing BAT was overwritten.")

        local environment_directory := test_root . "\environment"
        DirCreate(environment_directory)
        FileCopy(rime_dll, environment_directory . "\rime.dll", true)
        EnvSet("LIBRIME_LIB_DIR", environment_directory)
        InvokeProbe(probe, test_root, "inspect")
        InvokeProbe(probe, test_root, "dll")
        local local_dll := probe_directory . "\rime.dll"
        AssertTrue(!FileExist(local_dll),
            "A suitable environment DLL did not suppress embedded extraction.")

        WriteText(local_dll, "invalid PE")
        InvokeProbe(probe, test_root, "dll")
        AssertEqual("invalid PE", ReadText(local_dll),
            "An invalid local DLL blocked the environment fallback.")

        EnvSet("LIBRIME_LIB_DIR", test_root . "\missing")
        InvokeProbe(probe, test_root, "dll")
        local weasel_root := ReadWeaselRoot()
        if weasel_root = "" {
            AssertTrue(BuffersEqual(ReadBytes(local_dll), ReadBytes(rime_dll)),
                "The final fallback did not install the embedded DLL.")
        }
        FileCopy(rime_dll, local_dll, true)
        EnvSet("LIBRIME_LIB_DIR", environment_directory)
        local output := InvokeProbe(probe, test_root, "dll")
        AssertTrue(InStr(output, "Selected DLL: " . local_dll . " API:"),
            "A suitable local DLL did not take priority over the environment DLL.")
    } finally {
        EnvSet("LIBRIME_LIB_DIR", saved_environment)
        RestoreFile(generated, saved_generated)
        RestoreFile(generated_zip, saved_zip)
        if FileExist(harness) {
            FileDelete(harness)
        }
    }
}

GenerateResources(repository, generated, rime_dll, architecture) {
    local command := QuoteArgument("pwsh.exe") . " -NoProfile -File "
        . QuoteArgument(repository . "\.github\scripts\generate-compiled-resources.ps1")
        . " -ManifestPath " . QuoteArgument("scripts\compiled-resource-manifest.json")
        . " -OutputPath " . QuoteArgument("Lib\RabbitCompiledResources.ahk")
        . " -RimeDllPath " . QuoteArgument(rime_dll)
        . " -Architecture " . QuoteArgument(architecture)
    local exit_code := RunWait(command, repository, "Hide")
    if exit_code != 0 {
        throw Error("The compiled resource generator exited with code " . exit_code . ".")
    }
    RequireFile(generated, "generated compiled resource include")
}

CompileProbe(compiler, base, harness, probe, repository) {
    local command := QuoteArgument(compiler) . " /in " . QuoteArgument(harness)
        . " /out " . QuoteArgument(probe) . " /base " . QuoteArgument(base)
        . " /silent verbose"
    local exit_code := RunWait(command, repository, "Hide")
    if exit_code != 0 || !FileExist(probe) {
        throw Error("The compiled resource probe failed with code " . exit_code . ".")
    }
}

InvokeProbe(probe, test_root, mode, should_fail := false) {
    local log_path := test_root . "\probe.log"
    local saved_log := EnvGet("RABBIT_COMPILED_PROBE_LOG")
    if FileExist(log_path) {
        FileDelete(log_path)
    }
    try {
        EnvSet("RABBIT_COMPILED_PROBE_LOG", log_path)
        local exit_code := RunWait(
            QuoteArgument(probe) . " /ErrorStdOut " . QuoteArgument(mode),
            test_root,
            "Hide"
        )
        local output := FileExist(log_path) ? ReadText(log_path) : ""
        if should_fail {
            if exit_code = 0 {
                throw Error("Probe " . mode . " unexpectedly succeeded: " . output)
            }
        } else if exit_code != 0 {
            throw Error("Probe " . mode . " exited " . exit_code . ": " . output)
        }
        return output
    } finally {
        EnvSet("RABBIT_COMPILED_PROBE_LOG", saved_log)
    }
}

BuildProbeSource() {
    local tick := Chr(96)
    local lines := [
        '#Requires AutoHotkey v2.0',
        '#Include Lib\RabbitRimeBootstrap.ahk',
        '/*@Ahk2Exe-Keep',
        '#Include Lib\RabbitCompiledResources.ahk',
        '*/',
        'FileEncoding("UTF-8-RAW")',
        'try {',
        '    Main()',
        '} catch as err {',
        '    ReportUnhandled(err)',
        '}',
        'ExitApp()',
        '',
        'ReportUnhandled(err, *) {',
        '    ProbeWrite("Uncaught exception: " . err.Message . "' . tick
            . 'n  at " . err.What . "' . tick . 'n  " . err.Line',
        '        . "' . tick . 'nStack:' . tick . 'n" . err.Stack . "' . tick . 'n")',
        '    ExitApp(1)',
        '}',
        '',
        'Main() {',
        '    local path, api, selected, mode := A_Args.Length ? A_Args[A_Args.Length] : "resources"',
        '    /*@Ahk2Exe-Keep',
        '    if mode = "corrupt" {',
        '        RabbitCompiledResourceInstaller.DefineProp("InstallArchive", {',
        '            Call: CorruptArchive.Bind('
            . 'RabbitCompiledResourceInstaller.InstallArchive.Bind(RabbitCompiledResourceInstaller))',
        '        })',
        '    }',
        '    */',
        '    RabbitCompiledResourcePolicy.ExtractIfCompiled()',
        '    if mode = "legacy" {',
        '        RabbitCompiledResourcePolicy.EnsureLegacyInstaller()',
        '    } else if mode = "dll" {',
        '        path := RabbitRimeBootstrap.Prepare()',
        '        api := RimeApi(path)',
        '        ProbeWrite("Selected DLL: " . path . " API: " . api.get_version() . "' . tick . 'n")',
        '    } else if mode = "inspect" {',
        '        path := EnvGet("LIBRIME_LIB_DIR") . "\rime.dll"',
        '        if RabbitRimeBootstrap.InspectCandidate(path, "65535.65535.65535.65535", A_PtrSize * 8) {',
        '            throw Error("Too-old DLL accepted.")',
        '        }',
        '        if RabbitRimeBootstrap.InspectCandidate(path, "0", A_PtrSize = 8 ? 32 : 64) {',
        '            throw Error("Wrong-width DLL accepted.")',
        '        }',
        '        selected := RabbitRimeBootstrap.InspectCandidate(path, "0", A_PtrSize * 8)',
        '        if !selected {',
        '            throw Error("Real DLL API inspection failed.")',
        '        }',
        '        DllCall("FreeLibrary", "Ptr", selected.handle)',
        '    }',
        '    ProbeWrite("PASS: compiled " . mode . "' . tick . 'n")',
        '}',
        '',
        'CorruptArchive(original, installer_class, destination) {',
        '    original.Call(destination)',
        '    local file := FileOpen(destination, "w")',
        '    file.Write("invalid ZIP")',
        '    file.Close()',
        '}',
        '',
        'ProbeWrite(message) {',
        '    local path := EnvGet("RABBIT_COMPILED_PROBE_LOG")',
        '    FileAppend(message, path != "" ? path : "*", "UTF-8-RAW")',
        '}'
    ]
    return JoinLines(lines, "`n") . "`n"
}

ResolvePath(path, repository) {
    if RegExMatch(path, "i)^(?:[A-Z]:\\|\\\\)") {
        return path
    }
    return repository . "\" . path
}

ReadWeaselRoot() {
    try {
        return RegRead("HKEY_LOCAL_MACHINE\Software\Rime\Weasel", "WeaselRoot", "")
    } catch {
        return ""
    }
}

RequireFile(path, description) {
    if !FileExist(path) || DirExist(path) {
        throw Error(description . " was not found: " . path)
    }
}

ReadText(path) {
    return FileExist(path) ? FileRead(path, "UTF-8-RAW") : ""
}

WriteText(path, text) {
    if FileExist(path) {
        FileDelete(path)
    }
    FileAppend(text, path, "UTF-8-RAW")
}

ReadBytes(path) {
    local file := FileOpen(path, "r")
    local data := Buffer(file.Length)
    if data.Size {
        file.RawRead(data)
    }
    file.Close()
    return data
}

WriteBytes(path, data) {
    local file := FileOpen(path, "w")
    if data.Size {
        file.RawWrite(data)
    }
    file.Close()
}

RestoreFile(path, data) {
    if IsObject(data) {
        WriteBytes(path, data)
    } else if FileExist(path) {
        FileDelete(path)
    }
}

BuffersEqual(left, right) {
    if left.Size != right.Size {
        return false
    }
    Loop left.Size {
        if NumGet(left, A_Index - 1, "UChar") != NumGet(right, A_Index - 1, "UChar") {
            return false
        }
    }
    return true
}

FileRemove(path) {
    if DirExist(path) {
        DirDelete(path)
    } else if FileExist(path) {
        FileDelete(path)
    }
}

JoinLines(lines, separator) {
    local result := ""
    for index, line in lines {
        result .= (index > 1 ? separator : "") . line
    }
    return result
}

QuoteArgument(value) {
    return '"' . StrReplace(value, '"', '\\"') . '"'
}

ReportUnhandled(err) {
    FileAppend(
        "Uncaught exception: " . err.Message . "`n  at " . err.What . "`n  " . err.Line
            . "`nStack:`n" . err.Stack . "`n",
        "*"
    )
    ExitApp(1)
}
