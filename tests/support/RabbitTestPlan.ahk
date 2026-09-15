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

class RabbitTestPlan {
    static Discover(repository_root) {
        local entries := []
        this.AddDirectory(entries, repository_root . "\tests\unit", "unit", "ahk")
        this.AddDirectory(entries, repository_root . "\tests\component", "component", "ahk")
        this.AddDirectory(entries, repository_root . "\tests\integration", "integration", "ahk")
        this.AddDirectory(entries, repository_root . "\tests\packaging", "packaging", "ahk")
        this.AddDirectory(entries, repository_root . "\tests\manual", "manual", "ahk")
        this.AddDirectory(entries, repository_root . "\tests\benchmark", "benchmark", "benchmark")

        ; Submodules own their test implementations and runners.  These
        ; adapters make the supported entry points discoverable without
        ; merging submodule source into Rabbit's test aggregate.
        entries.Push(this.CreateEntry(
            "librime-ahk bindings",
            "submodule",
            "ahk",
            "Lib\librime-ahk\tests\rime_test_main.ahk",
            ["submodule", "binding", "rime"]
        ))
        entries.Push(this.CreateEntry(
            "RimeDepot core",
            "submodule",
            "ahk",
            "Lib\RimeDepot\tests\RimeDepotCoreProbe.ahk",
            ["submodule", "rimedepot", "core"]
        ))
        entries.Push(this.CreateEntry(
            "RimeDepot GUI smoke",
            "submodule",
            "ahk",
            "Lib\RimeDepot\tests\integration\RimeDepotGuiSmokeTest.ahk",
            ["submodule", "rimedepot", "component", "gui"]
        ))
        entries.Push(this.CreateEntry(
            "RimeDepot application lifecycle",
            "submodule",
            "ahk",
            "Lib\RimeDepot\tests\integration\RimeDepotAppLifecycleTest.ahk",
            ["submodule", "rimedepot", "component", "gui"]
        ))
        entries.Push(this.CreateEntry(
            "RimeDepot live RPPI probe",
            "manual",
            "ahk",
            "Lib\RimeDepot\tests\RimeDepotRppiLiveProbe.ahk",
            ["manual", "submodule", "rimedepot", "network"]
        ))
        return entries
    }

    static AddDirectory(entries, directory, suite, kind) {
        if !DirExist(directory) {
            return
        }
        Loop Files, directory . "\*.ahk", "F" {
            if suite = "unit" && A_LoopFileName = "RabbitTests.ahk" {
                ; The legacy aggregate remains available as a compatibility
                ; entry point, but the new runner executes suites per file.
                continue
            }
            local relative_path := "tests\" . suite . "\" . A_LoopFileName
            if suite = "manual" && A_LoopFileName = "RabbitCandidateBoxGuiTests.ahk" {
                entries.Push(this.CreateEntry(
                    "candidate box modern preview",
                    suite,
                    kind,
                    relative_path,
                    ["manual", "visual", "candidate"],
                    ["visual-modern"]
                ))
                entries.Push(this.CreateEntry(
                    "candidate box legacy preview",
                    suite,
                    kind,
                    relative_path,
                    ["manual", "visual", "candidate", "legacy"],
                    ["visual-legacy"]
                ))
                continue
            }
            local tags := this.TagsFor(suite, A_LoopFileName)
            entries.Push(this.CreateEntry(
                RegExReplace(A_LoopFileName, "\.ahk$"),
                suite,
                kind,
                relative_path,
                tags
            ))
        }
    }

    static CreateEntry(name, suite, kind, path, tags, arguments := []) {
        return {
            name: name,
            suite: suite,
            kind: kind,
            path: path,
            tags: tags,
            arguments: arguments
        }
    }

    static TagsFor(suite, file_name) {
        local tags := [suite]
        if suite = "unit" {
            tags.Push("headless")
            tags.Push("ci")
        } else if suite = "component" {
            tags.Push("windows")
            if InStr(file_name, "RimeDepot") {
                tags.Push("rimedepot")
                tags.Push("ci")
            }
            if InStr(file_name, "Dialog") || InStr(file_name, "Window") || InStr(file_name, "Gui")
                || InStr(file_name, "Font") || InStr(file_name, "Shadow") || InStr(file_name, "ListView") {
                tags.Push("gui")
            }
        } else if suite = "integration" {
            tags.Push("rime")
            if InStr(file_name, "Dialog") || InStr(file_name, "Preview") {
                tags.Push("gui")
            }
        } else if suite = "packaging" {
            tags.Push("compiled")
            tags.Push("ci")
        } else if suite = "manual" {
            tags.Push("visual")
        } else if suite = "benchmark" {
            tags.Push("performance")
        }
        return tags
    }
}
