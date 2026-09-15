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

#Include ..\support\RabbitTestCommon.ahk
#Include ..\support\RabbitTestRunner.ahk

RunTest("test runner parses suite, filter, tag, timeout, and report options", TestRunnerParsesOptions.Bind())
RunTest("test runner discovers the classified Rabbit suites", TestRunnerDiscoversClassifiedSuites.Bind())
RunTest("test runner assigns semantic tags", TestRunnerAssignsTags.Bind())
RunTest("test runner parses callback results from the child log", TestRunnerParsesChildLog.Bind())
RunTest("test runner escapes XML output", TestRunnerEscapesXml.Bind())

TestRunnerParsesOptions() {
    local options := RabbitTestRunner.ParseOptions([
        "--suite", "unit,component",
        "--filter", "Window",
        "--tag", "gui",
        "--timeout", "2500",
        "--junit", "report.xml",
        "--compiler", "compiler.exe",
        "--base", "base.exe",
        "--rime-dll", "rime.dll",
        "--architecture", "x86"
    ])
    AssertEqual(2, options.suites.Length, "The runner parsed the wrong suite count.")
    AssertEqual("unit", options.suites[1], "The runner changed the first suite.")
    AssertEqual("component", options.suites[2], "The runner changed the second suite.")
    AssertEqual("Window", options.filter, "The runner lost the name filter.")
    AssertEqual("gui", options.tag, "The runner lost the tag filter.")
    AssertEqual(2500, options.timeout_ms, "The runner parsed the wrong timeout.")
    AssertEqual("report.xml", options.junit_path, "The runner lost the JUnit path.")
    AssertEqual("compiler.exe", options.compiler_path, "The runner lost the compiler path.")
    AssertEqual("base.exe", options.base_path, "The runner lost the base executable path.")
    AssertEqual("rime.dll", options.rime_dll_path, "The runner lost the Rime DLL path.")
    AssertEqual("x86", options.architecture, "The runner parsed the wrong packaging architecture.")
}

TestRunnerDiscoversClassifiedSuites() {
    local entries := RabbitTestPlan.Discover(A_ScriptDir . "\..\..")
    local unit := 0, component := 0, integration := 0, packaging := 0, manual := 0, external := 0
    for entry in entries {
        if entry.suite = "unit" {
            unit += 1
        } else if entry.suite = "component" {
            component += 1
        } else if entry.suite = "integration" {
            integration += 1
        } else if entry.suite = "packaging" {
            packaging += 1
        } else if entry.suite = "manual" {
            manual += 1
        }
        external += entry.kind = "external" ? 1 : 0
    }
    AssertTrue(unit > 20, "The runner discovered too few unit entries.")
    AssertTrue(component > 15, "The runner discovered too few component entries.")
    AssertTrue(integration >= 3, "The runner did not discover the integration suite.")
    AssertEqual(1, packaging, "The compiled-resource packaging entry was not discovered.")
    AssertTrue(manual >= 6, "The runner did not discover manual probes and previews.")
    AssertEqual(0, external, "The migrated plan still contains an external test entry.")
}

TestRunnerEscapesXml() {
    local value := "<tag> & " . Chr(34) . "quoted" . Chr(34) . " 'single'"
    AssertEqual("&lt;tag&gt; &amp; &quot;quoted&quot; &apos;single&apos;",
        RabbitTestRunner.XmlEscape(value), "The runner did not escape XML entities.")
}

TestRunnerParsesChildLog() {
    local cases := RabbitTestRunner.ReadCases("PASS: first callback`nFAIL: second callback`n")
    AssertEqual(2, cases.Length, "The runner parsed the wrong callback count.")
    AssertEqual("first callback", cases[1].name, "The runner changed a passing callback name.")
    AssertTrue(cases[1].passed, "The runner marked a passing callback as failed.")
    AssertEqual("second callback", cases[2].name, "The runner changed a failing callback name.")
    AssertTrue(!cases[2].passed, "The runner marked a failing callback as passed.")
}

TestRunnerAssignsTags() {
    local entries := RabbitTestPlan.Discover(A_ScriptDir . "\..\..")
    local found_rimedepot_ci := false, found_packaging := false
    for entry in entries {
        if entry.suite = "unit" {
            AssertTrue(RabbitTestRunner.HasTag(entry, "headless"),
                "A unit test is missing the headless tag.")
            AssertTrue(RabbitTestRunner.HasTag(entry, "ci"),
                "A unit test is missing the CI tag.")
        } else if entry.suite = "manual" && InStr(entry.path, "tests\manual\") {
            AssertTrue(RabbitTestRunner.HasTag(entry, "visual"),
                "A manual test is missing the visual tag.")
        } else if entry.suite = "packaging" {
            found_packaging := true
            AssertTrue(RabbitTestRunner.HasTag(entry, "compiled"),
                "The packaging test is missing the compiled tag.")
            AssertTrue(RabbitTestRunner.HasTag(entry, "ci"),
                "The packaging test is missing the CI tag.")
        } else if entry.name = "RabbitRimeDepotWindowTest" {
            found_rimedepot_ci := RabbitTestRunner.HasTag(entry, "ci")
        }
    }
    AssertTrue(found_rimedepot_ci, "The RimeDepot component test is missing the CI tag.")
    AssertTrue(found_packaging, "The packaging tag test did not see the packaging entry.")
}
