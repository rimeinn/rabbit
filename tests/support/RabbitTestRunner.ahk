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

#Include RabbitTestPlan.ahk

class RabbitTestRunner {
    static DEFAULT_TIMEOUT_MS := 120000

    static Main() {
        local options := this.ParseOptions(A_Args)
        if options.help {
            this.PrintUsage()
            ExitApp(0)
        }

        local repository_root := A_ScriptDir . "\.."
        options.junit_path := this.ResolvePath(options.junit_path, repository_root)
        local entries := RabbitTestPlan.Discover(repository_root)
        local selected := this.SelectEntries(entries, options)
        if options.list {
            this.PrintEntries(selected)
            ExitApp(0)
        }
        if selected.Length = 0 {
            throw Error("No tests matched the requested suite, filter, or tag.")
        }

        local results := []
        for entry in selected {
            if entry.kind = "external" {
                this.Write("SKIP: " . entry.name . " (external runner)`n")
                results.Push({
                    entry: entry,
                    skipped: true,
                    cases: [{ name: entry.name, passed: false, skipped: true,
                        message: "Requires its current external runner." }]
                })
                continue
            }
            results.Push(this.RunEntry(this.PrepareEntry(entry, options), repository_root, options.timeout_ms))
        }

        local failures := this.CountFailures(results)
        this.WriteJUnit(results, options.junit_path)
        this.WriteSummary(results, failures, options.junit_path)
        ExitApp(failures ? 1 : 0)
    }

    static ParseOptions(args) {
        local options := {
            suites: ["unit"],
            filter: "",
            tag: "",
            list: false,
            help: false,
            compiler_path: "",
            base_path: "",
            rime_dll_path: "",
            architecture: "x64",
            timeout_ms: this.DEFAULT_TIMEOUT_MS,
            junit_path: A_Temp . "\rabbit-test-" . A_TickCount . "-" . Random(100000, 999999) . ".xml"
        }
        local index := 1
        while index <= args.Length {
            local argument := args[index]
            if argument = "--help" || argument = "-h" {
                options.help := true
            } else if argument = "--list" {
                options.list := true
            } else if argument = "--suite" {
                index += 1
                options.suites := this.ParseSuites(this.RequireValue(args, index, argument))
            } else if SubStr(argument, 1, 8) = "--suite=" {
                options.suites := this.ParseSuites(SubStr(argument, 9))
            } else if argument = "--filter" {
                index += 1
                options.filter := this.RequireValue(args, index, argument)
            } else if SubStr(argument, 1, 9) = "--filter=" {
                options.filter := SubStr(argument, 10)
            } else if argument = "--tag" {
                index += 1
                options.tag := this.RequireValue(args, index, argument)
            } else if SubStr(argument, 1, 6) = "--tag=" {
                options.tag := SubStr(argument, 7)
            } else if argument = "--timeout" {
                index += 1
                options.timeout_ms := this.ParseTimeout(this.RequireValue(args, index, argument))
            } else if SubStr(argument, 1, 10) = "--timeout=" {
                options.timeout_ms := this.ParseTimeout(SubStr(argument, 11))
            } else if argument = "--junit" {
                index += 1
                options.junit_path := this.RequireValue(args, index, argument)
            } else if SubStr(argument, 1, 8) = "--junit=" {
                options.junit_path := SubStr(argument, 9)
            } else if argument = "--compiler" {
                index += 1
                options.compiler_path := this.RequireValue(args, index, argument)
            } else if SubStr(argument, 1, 11) = "--compiler=" {
                options.compiler_path := SubStr(argument, 12)
            } else if argument = "--base" {
                index += 1
                options.base_path := this.RequireValue(args, index, argument)
            } else if SubStr(argument, 1, 7) = "--base=" {
                options.base_path := SubStr(argument, 8)
            } else if argument = "--rime-dll" {
                index += 1
                options.rime_dll_path := this.RequireValue(args, index, argument)
            } else if SubStr(argument, 1, 11) = "--rime-dll=" {
                options.rime_dll_path := SubStr(argument, 12)
            } else if argument = "--architecture" {
                index += 1
                options.architecture := this.RequireValue(args, index, argument)
            } else if SubStr(argument, 1, 15) = "--architecture=" {
                options.architecture := SubStr(argument, 16)
            } else {
                throw Error("Unknown test runner option: " . argument)
            }
            index += 1
        }
        return options
    }

    static ParseSuites(value) {
        local suites := []
        for suite in StrSplit(value, ",") {
            suite := Trim(suite)
            if suite != "" {
                suites.Push(suite)
            }
        }
        if !suites.Length {
            throw Error("The suite selection cannot be empty.")
        }
        return suites
    }

    static ParseTimeout(value) {
        if !RegExMatch(value, "^\d+$") || Integer(value) <= 0 {
            throw Error("The test timeout must be a positive integer in milliseconds.")
        }
        return Integer(value)
    }

    static PrepareEntry(entry, options) {
        if entry.suite != "packaging" {
            return entry
        }
        if options.compiler_path = "" || options.base_path = "" || options.rime_dll_path = "" {
            throw Error("Packaging tests require --compiler, --base, and --rime-dll arguments.")
        }
        if options.architecture != "x86" && options.architecture != "x64" {
            throw Error("The packaging architecture must be x86 or x64.")
        }
        return {
            name: entry.name,
            suite: entry.suite,
            kind: entry.kind,
            path: entry.path,
            tags: entry.tags,
            arguments: [
                options.compiler_path,
                options.base_path,
                options.rime_dll_path,
                options.architecture
            ]
        }
    }

    static RequireValue(args, index, option) {
        if index > args.Length || args[index] = "" {
            throw Error("Missing value for " . option . ".")
        }
        return args[index]
    }

    static SelectEntries(entries, options) {
        local selected := []
        for entry in entries {
            if !this.MatchesSuite(entry.suite, options.suites) {
                continue
            }
            if options.filter != "" && !InStr(StrLower(entry.name . " " . entry.path), StrLower(options.filter)) {
                continue
            }
            if options.tag != "" && !this.HasTag(entry, options.tag) {
                continue
            }
            selected.Push(entry)
        }
        return selected
    }

    static MatchesSuite(suite, requested_suites) {
        for requested in requested_suites {
            if requested = "all" {
                if suite != "manual" && suite != "benchmark" && suite != "packaging" {
                    return true
                }
            } else if requested = suite {
                return true
            }
        }
        return false
    }

    static HasTag(entry, tag) {
        for candidate in entry.tags {
            if candidate = tag {
                return true
            }
        }
        return false
    }

    static PrintEntries(entries) {
        for entry in entries {
            this.Write(
                entry.suite . "`t" . entry.name . "`t[" . this.Join(entry.tags, ", ") . "]`t" . entry.path . "`n"
            )
        }
        this.Write("Listed " . entries.Length . " test entries.`n")
    }

    static RunEntry(entry, repository_root, timeout_ms) {
        local token := A_TickCount . "-" . Random(100000, 999999)
        local log_path := A_Temp . "\rabbit-test-" . token . ".log"

        local old_log_path := EnvGet("RABBIT_TEST_LOG_FILE")
        local process_result := 0
        local output := ""
        local cases := []
        try {
            EnvSet("RABBIT_TEST_LOG_FILE", log_path)
            process_result := this.RunProcess(
                this.BuildCommand(entry, repository_root),
                repository_root,
                timeout_ms
            )
            if FileExist(log_path) {
                output := FileRead(log_path, "UTF-8-RAW")
            }
            cases := this.ReadCases(output)
        } catch as err {
            process_result := {
                exit_code: 1,
                timed_out: false,
                error: this.ErrorText(err)
            }
            output .= process_result.error . "`n"
        } finally {
            this.RestoreEnvironment("RABBIT_TEST_LOG_FILE", old_log_path)
        }

        if output != "" {
            this.Write(output . (SubStr(output, -1) = "`n" ? "" : "`n"))
        }
        local failed := process_result.timed_out || process_result.exit_code != 0
        if !cases.Length {
            cases.Push({
                name: entry.name,
                passed: !failed,
                skipped: false,
                message: failed
                    ? (process_result.timed_out ? "Test process timed out." : output)
                    : ""
            })
        } else if failed {
            ; A top-level exception can terminate a script after its last
            ; successful callback.  Preserve that process-level failure in
            ; the report even when the callback log is incomplete.
            local has_failed_case := false
            for test_case in cases {
                if !test_case.passed {
                    has_failed_case := true
                    break
                }
            }
            if !has_failed_case {
                cases.Push({
                    name: entry.name . " (process)",
                    passed: false,
                    skipped: false,
                    message: process_result.timed_out
                        ? "Test process timed out."
                        : output
                })
            }
        }

        if failed {
            this.Write("FAIL: " . entry.name . " (exit " . process_result.exit_code . ")`n")
        } else {
            this.Write("PASS: " . entry.name . "`n")
        }
        local result := { entry: entry, skipped: false, cases: cases }
        if FileExist(log_path) {
            FileDelete(log_path)
        }
        return result
    }

    static BuildCommand(entry, repository_root) {
        local script := repository_root . "\" . entry.path
        if !FileExist(script) {
            throw Error("Test entry was not found: " . script)
        }
        local command := this.QuoteArgument(this.ResolveAutoHotkeyPath()) . " /ErrorStdOut "
            . this.QuoteArgument(script)
        for argument in entry.arguments {
            command .= " " . this.QuoteArgument(argument)
        }
        return command
    }

    static QuoteArgument(value) {
        return '"' . StrReplace(value, '"', '\\"') . '"'
    }

    static ResolveAutoHotkeyPath() {
        ; AutoHotkey's UX launcher remains alive while the actual script runs,
        ; so waiting on it can report success before the test process exits.
        if InStr(StrLower(A_AhkPath), "\ux\autohotkeyux.exe") {
            local executable := RegExReplace(
                A_AhkPath,
                "i)\\ux\\autohotkeyux\.exe$",
                "\v2\" . (A_PtrSize = 8 ? "AutoHotkey64.exe" : "AutoHotkey32.exe")
            )
            if FileExist(executable) {
                return executable
            }
        }
        return A_AhkPath
    }

    static RunProcess(command, working_directory, timeout_ms) {
        local pid := 0
        Run(command, working_directory, "Hide", &pid)
        local handle := DllCall(
            "OpenProcess",
            "UInt",
            0x00100000 | 0x00001000,
            "Int",
            false,
            "UInt",
            pid,
            "Ptr"
        )
        if !handle {
            throw Error("Could not open the test process for monitoring: " . pid)
        }
        try {
            local wait_result := DllCall("WaitForSingleObject", "Ptr", handle, "UInt", timeout_ms, "UInt")
            local timed_out := wait_result = 0x102
            if timed_out {
                ProcessClose(pid)
                DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 5000, "UInt")
            } else if wait_result != 0 {
                throw Error("WaitForSingleObject failed with code " . wait_result . ".")
            }
            local exit_code := 1
            if !DllCall("GetExitCodeProcess", "Ptr", handle, "UInt*", &exit_code) {
                throw Error("Could not read the test process exit code.")
            }
            return { exit_code: exit_code, timed_out: timed_out, error: "" }
        } finally {
            DllCall("CloseHandle", "Ptr", handle)
        }
    }

    static ReadCases(output) {
        local cases := []
        for line in StrSplit(output, "`n", "`r") {
            if SubStr(line, 1, 6) = "PASS: " {
                cases.Push({
                    name: SubStr(line, 7),
                    passed: true,
                    skipped: false,
                    message: ""
                })
                continue
            }
            if SubStr(line, 1, 6) != "FAIL: " {
                continue
            }
            cases.Push({
                name: SubStr(line, 7),
                passed: false,
                skipped: false,
                message: "Test callback failed."
            })
        }
        return cases
    }

    static RestoreEnvironment(name, value) {
        EnvSet(name, value)
    }

    static ResolvePath(path, repository_root) {
        if RegExMatch(path, "i)^(?:[A-Z]:\\|\\\\)") {
            return path
        }
        return repository_root . "\" . path
    }

    static CountFailures(results) {
        local failures := 0
        for result in results {
            if result.skipped {
                continue
            }
            for test_case in result.cases {
                if !test_case.passed && !test_case.skipped {
                    failures += 1
                }
            }
        }
        return failures
    }

    static WriteSummary(results, failures, junit_path) {
        local tests := 0, skipped := 0, scripts := results.Length
        for result in results {
            for test_case in result.cases {
                tests += 1
                skipped += test_case.skipped ? 1 : 0
            }
        }
        this.Write(Format(
            "Rabbit tests: {} test cases in {} entries, {} failed, {} skipped.`n",
            tests,
            scripts,
            failures,
            skipped
        ))
        this.Write("JUnit report: " . junit_path . "`n")
    }

    static WriteJUnit(results, path) {
        local directory := RegExReplace(path, "\\[^\\]+$")
        if directory != "" {
            DirCreate(directory)
        }
        local tests := 0, failures := 0, skipped := 0
        for result in results {
            for test_case in result.cases {
                tests += 1
                failures += !test_case.passed && !test_case.skipped ? 1 : 0
                skipped += test_case.skipped ? 1 : 0
            }
        }
        local xml := '<?xml version="1.0" encoding="UTF-8"?>`r`n'
        xml .= Format(
            '<testsuites tests="{}" failures="{}" skipped="{}">`r`n',
            tests,
            failures,
            skipped
        )
        xml .= '  <testsuite name="Rabbit" tests="' . tests . '" failures="' . failures
            . '" skipped="' . skipped . '">`r`n'
        for result in results {
            for test_case in result.cases {
                local classname := result.entry.suite . "." . result.entry.name
                xml .= '    <testcase classname="' . this.XmlEscape(classname)
                    . '" name="' . this.XmlEscape(test_case.name) . '">'
                if test_case.skipped {
                    xml .= "<skipped/>"
                } else if !test_case.passed {
                    xml .= '<failure message="' . this.XmlEscape(test_case.message) . '"/>'
                }
                xml .= "</testcase>`r`n"
            }
        }
        xml .= "  </testsuite>`r`n</testsuites>`r`n"
        if FileExist(path) {
            FileDelete(path)
        }
        FileAppend(xml, path, "UTF-8")
    }

    static XmlEscape(value) {
        value := StrReplace(value, "&", "&amp;")
        value := StrReplace(value, "<", "&lt;")
        value := StrReplace(value, ">", "&gt;")
        value := StrReplace(value, '"', "&quot;")
        return StrReplace(value, "'", "&apos;")
    }

    static Join(values, separator) {
        local result := ""
        for index, value in values {
            result .= (index > 1 ? separator : "") . value
        }
        return result
    }

    static ErrorText(err) {
        local message := "Uncaught runner error: " . err.Message . "`n"
        if HasProp(err, "What") && err.What {
            message .= "  at " . err.What . "`n"
        }
        if HasProp(err, "File") && err.File {
            message .= "  Location: " . err.File
            if HasProp(err, "Line") && err.Line {
                message .= ":" . err.Line
            }
            message .= "`n"
        }
        if HasProp(err, "Stack") && err.Stack {
            message .= "Stack:`n" . err.Stack . "`n"
        }
        return message
    }

    static Write(message) {
        try {
            FileAppend(message, "*")
        } catch as err {
            OutputDebug(message)
        }
    }

    static PrintUsage() {
        this.Write(
            "Usage: AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk [options]`n"
                . "  --suite unit|component|integration|packaging|submodule|manual|benchmark|all`n"
                . "  --filter text       Run matching entry names or paths`n"
                . "  --tag tag           Run entries carrying a tag`n"
                . "  --list              List matching entries without running them`n"
                . "  --timeout ms        Kill a test process after the timeout`n"
                . "  --junit path        Write a JUnit report to path`n"
                . "  --compiler path     Ahk2Exe path for packaging tests`n"
                . "  --base path         AutoHotkey base executable for packaging tests`n"
                . "  --rime-dll path     librime DLL for packaging tests`n"
                . "  --architecture x86|x64  Packaging architecture`n"
        )
    }
}
