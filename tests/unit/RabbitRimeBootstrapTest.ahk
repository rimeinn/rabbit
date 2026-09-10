/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitRimeBootstrap.ahk

RunTest("compiled resource marker transitions", TestCompiledResourceMarkerTransitions.Bind())
RunTest("compiled resource marker rejects empty and stale values", TestCompiledResourceMarkerRejectsStaleValues.Bind())
RunTest("rime candidate selection preserves source order", TestRimeCandidateSelectionOrder.Bind())
RunTest("numeric rime versions compare each component", TestNumericRimeVersionComparison.Bind())
RunTest("rime PE inspection rejects malformed and foreign images", TestRimePeInspection.Bind())
RunTest("source bootstrap does not release compiled resources", TestSourceBootstrap.Bind())

TestCompiledResourceMarkerTransitions() {
    local root := RabbitRimeBootstrapTestDirectory(), marker
    try {
        AssertTrue(RabbitCompiledResourcePolicy.ShouldExtract(root, "1.2.3"),
            "An absent marker did not request extraction.")
        RabbitCompiledResourcePolicy.Commit(root, "1.2.3")
        marker := root . "\.rabbit"
        AssertEqual("1.2.3", FileRead(marker, "UTF-8-RAW"),
            "The marker did not store the exact Rabbit version.")
        AssertTrue(InStr(FileGetAttrib(marker), "H") > 0,
            "The compiled resource marker was not hidden.")
        AssertTrue(!RabbitCompiledResourcePolicy.ShouldExtract(root, "1.2.3"),
            "A matching marker requested an unnecessary extraction.")
        RabbitCompiledResourcePolicy.Commit(root, "1.2.4")
        AssertEqual("1.2.4", FileRead(marker), "An existing hidden marker was not replaced.")
        AssertTrue(RabbitCompiledResourcePolicy.ShouldExtract(root, "1.2.3"),
            "A downgrade did not request extraction.")
        RabbitCompiledResourcePolicy.Commit(root, "dev-A")
        AssertTrue(RabbitCompiledResourcePolicy.ShouldExtract(root, "dev-a"),
            "Version comparison was not exact.")
    } finally {
        RabbitRimeBootstrapRemoveDirectory(root)
    }
}

TestCompiledResourceMarkerRejectsStaleValues() {
    local root := RabbitRimeBootstrapTestDirectory(), marker := root . "\.rabbit"
    try {
        FileAppend("", marker, "UTF-8-RAW")
        AssertTrue(RabbitCompiledResourcePolicy.ShouldExtract(root, "1.2.3"),
            "An empty marker was accepted.")
        FileDelete(marker)
        FileAppend("1.2.2", marker, "UTF-8-RAW")
        AssertTrue(RabbitCompiledResourcePolicy.ShouldExtract(root, "1.2.3"),
            "A stale marker was accepted.")
    } finally {
        RabbitRimeBootstrapRemoveDirectory(root)
    }
}

TestRimeCandidateSelectionOrder() {
    local calls := [], candidates := ["current", "environment", "weasel"]
    local inspector := (path) => RabbitRimeBootstrapTestInspect(path, calls)
    local selected := RabbitRimeBootstrap.SelectCandidate(candidates, "1.0", 64, inspector)
    AssertEqual("current,environment", RabbitRimeBootstrapJoin(calls),
        "Candidate selection did not stop after the first suitable source.")
    AssertEqual("environment", selected.path,
        "Candidate selection did not preserve current, environment, Weasel order.")
}

TestNumericRimeVersionComparison() {
    AssertTrue(RabbitRimeBootstrap.IsNumericVersion("1.17.0.0"),
        "A four component file version was rejected.")
    AssertTrue(!RabbitRimeBootstrap.IsNumericVersion("1.17-preview"),
        "A nonnumeric file version was accepted.")
    AssertEqual(1, RabbitRimeBootstrap.CompareNumericVersions("1.10", "1.9"),
        "Version comparison treated numeric components as text.")
    AssertEqual(0, RabbitRimeBootstrap.CompareNumericVersions("1.2", "1.2.0.0"),
        "Trailing zero version components changed equality.")
}

TestRimePeInspection() {
    local root := RabbitRimeBootstrapTestDirectory(), path := root . "\image.dll"
    local data := Buffer(0x80, 0), file, fixture
    try {
        NumPut("UShort", 0x5a4d, data, 0)
        NumPut("UInt", 0x40, data, 0x3c)
        NumPut("UInt", 0x4550, data, 0x40)
        for fixture in [[0x14c, 0x10b, 32], [0x8664, 0x20b, 64], [0xaa64, 0x20b, 0], [0x14c, 0x20b, 0]] {
            NumPut("UShort", fixture[1], data, 0x44)
            NumPut("UShort", fixture[2], data, 0x58)
            file := FileOpen(path, "w")
            file.RawWrite(data)
            file.Close()
            AssertEqual(fixture[3], RabbitRimeBootstrap.ReadPeBits(path), "Unexpected PE architecture.")
        }
        file := FileOpen(path, "w")
        file.Write("invalid")
        file.Close()
        AssertEqual(0, RabbitRimeBootstrap.ReadPeBits(path), "Truncated image was accepted.")
        AssertEqual(0, RabbitRimeBootstrap.InspectCandidate(path, "1.0", 64),
            "An unversioned invalid library was accepted.")
    } finally {
        RabbitRimeBootstrapRemoveDirectory(root)
    }
}

TestSourceBootstrap() {
    global rabbit_compiled_resource_extractor, rabbit_compiled_legacy_installer
    local previous_extractor := rabbit_compiled_resource_extractor
    local previous_installer := rabbit_compiled_legacy_installer
    try {
        rabbit_compiled_resource_extractor := (*) => ThrowUnexpectedSourceExtraction()
        rabbit_compiled_legacy_installer := rabbit_compiled_resource_extractor
        RabbitCompiledResourcePolicy.ExtractIfCompiled()
        RabbitCompiledResourcePolicy.EnsureLegacyInstaller()
        AssertEqual(A_ScriptDir . "\Lib\librime-ahk\rime.dll", RabbitRimeBootstrap.Prepare(),
            "Source DLL bootstrap changed its preferred path.")
    } finally {
        rabbit_compiled_resource_extractor := previous_extractor
        rabbit_compiled_legacy_installer := previous_installer
    }
}

ThrowUnexpectedSourceExtraction() {
    throw Error("Source mode attempted resource extraction.")
}

RabbitRimeBootstrapTestInspect(path, calls) {
    calls.Push(path)
    return path = "environment" ? {path: path, handle: 1} : 0
}

RabbitRimeBootstrapTestDirectory() {
    local root := A_Temp . "\rabbit-rime-bootstrap-" . A_TickCount . "-" . Random(1, 1000000)
    DirCreate(root)
    return root
}

RabbitRimeBootstrapRemoveDirectory(root) {
    if DirExist(root) {
        DirDelete(root, true)
    }
}

RabbitRimeBootstrapJoin(values) {
    local result := "", value
    for value in values {
        if result {
            result .= ","
        }
        result .= value
    }
    return result
}
