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
 *
 */

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\..\Lib\RabbitCommon.ahk

try {
    Main()
} catch as err {
    FileAppend(
        "Uncaught exception: " . err.Message . "`n  at " . err.What . "`n  " . err.Line .
        "`nStack:`n" . err.Stack . "`n",
        "*"
    )
    ExitApp(1)
}

Main() {
    local iterations := A_Args.Length ? Integer(A_Args[1]) : 3
    local repository_root := A_ScriptDir . "\..\.."
    local test_dir := A_Temp . "\rabbit-deployment-benchmark-" .
        DllCall("GetCurrentProcessId", "UInt") . "-" . A_TickCount
    local rime := 0, traits
    if iterations < 1 || iterations > 10 {
        throw ValueError("Iteration count must be between 1 and 10.")
    }

    DirCreate(test_dir)
    DirCreate(test_dir . "\log")
    try {
        rime := RimeApi()
        traits := RabbitCreateTraits()
        traits.shared_data_dir := repository_root . "\Data"
        traits.user_data_dir := test_dir
        traits.prebuilt_data_dir := traits.shared_data_dir
        traits.staging_dir := test_dir . "\build"
        traits.log_dir := test_dir . "\log"
        rime.setup(traits)
        rime.deployer_initialize(0)

        WriteCustomConfig(test_dir . "\default.custom.yaml", "patch:`n  switcher/caption: warmup`n")
        WriteCustomConfig(test_dir . "\rabbit.custom.yaml", "patch:`n  benchmark_marker: warmup`n")
        RequireSuccess(rime.deploy(), "Initial workspace deployment")
        RequireSuccess(rime.deploy_config_file("rabbit.yaml", "config_version"), "Initial Rabbit deployment")

        FileAppend(
            "Rabbit deployment benchmark`n" .
            "librime=" . rime.get_version() . " iterations=" . iterations . "`n" .
            "shared_data=" . traits.shared_data_dir . "`n" .
            "user_data=" . traits.user_data_dir . "`n`n",
            "*"
        )

        BenchmarkRabbitConfig(rime, test_dir, iterations)
        BenchmarkDefaultConfig(rime, test_dir, iterations)
    } finally {
        if rime {
            rime.finalize()
            rime := 0
        }
        ; The production binding intentionally keeps librime loaded for process lifetime. The benchmark
        ; unloads it at shutdown so its isolated log directory can be removed before the process exits.
        if RimeApi.rimeDll {
            DllCall("FreeLibrary", "Ptr", RimeApi.rimeDll)
            RimeApi.rimeDll := 0
        }
        if DirExist(test_dir) {
            DirDelete(test_dir, true)
        }
    }
}

BenchmarkRabbitConfig(rime, test_dir, iterations) {
    local old_times := [], granular_times := [], sequence := 0
    loop iterations {
        sequence += 1
        TouchCustomConfig(
            test_dir . "\rabbit.custom.yaml",
            "patch:`n  benchmark_marker: old-" . sequence . "`n"
        )
        old_times.Push(Measure(() => OldDeployment(rime)))

        sequence += 1
        TouchCustomConfig(
            test_dir . "\rabbit.custom.yaml",
            "patch:`n  benchmark_marker: granular-" . sequence . "`n"
        )
        granular_times.Push(Measure(() => DeployRabbitConfig(rime)))
    }
    PrintComparison("rabbit.custom.yaml change", old_times, granular_times)
}

BenchmarkDefaultConfig(rime, test_dir, iterations) {
    local old_times := [], granular_times := [], sequence := 0
    loop iterations {
        sequence += 1
        TouchCustomConfig(
            test_dir . "\default.custom.yaml",
            "patch:`n  switcher/caption: old-" . sequence . "`n"
        )
        old_times.Push(Measure(() => OldDeployment(rime)))

        sequence += 1
        TouchCustomConfig(
            test_dir . "\default.custom.yaml",
            "patch:`n  switcher/caption: granular-" . sequence . "`n"
        )
        granular_times.Push(Measure(() => DeployDefaultConfig(rime)))
    }
    PrintComparison("default.custom.yaml switcher change", old_times, granular_times)
}

OldDeployment(rime) {
    RequireSuccess(rime.deploy(), "Workspace deployment")
    RequireSuccess(rime.deploy_config_file("rabbit.yaml", "config_version"), "Rabbit deployment")
}

DeployRabbitConfig(rime) {
    RequireSuccess(rime.deploy_config_file("rabbit.yaml", "config_version"), "Rabbit deployment")
}

DeployDefaultConfig(rime) {
    RequireSuccess(rime.deploy_config_file("default.yaml", "config_version"), "Default deployment")
}

Measure(action) {
    static frequency := 0
    local finished_at := 0, started_at := 0
    if !frequency {
        DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
    }
    DllCall("QueryPerformanceCounter", "Int64*", &started_at)
    action.Call()
    DllCall("QueryPerformanceCounter", "Int64*", &finished_at)
    return (finished_at - started_at) * 1000 / frequency
}

TouchCustomConfig(path, contents) {
    ; Rime compares second-resolution modification times when deciding whether to rebuild.
    Sleep(1100)
    WriteCustomConfig(path, contents)
}

WriteCustomConfig(path, contents) {
    local file := FileOpen(path, "w", "UTF-8-RAW")
    if !file {
        throw OSError("Failed to open benchmark config: " . path)
    }
    try {
        file.Write(contents)
    } finally {
        file.Close()
    }
}

RequireSuccess(result, operation) {
    if !result {
        throw Error(operation . " failed.")
    }
}

PrintComparison(name, old_times, granular_times) {
    local old_mean := Mean(old_times)
    local granular_mean := Mean(granular_times)
    local speedup := granular_mean ? old_mean / granular_mean : 0
    FileAppend(
        name . "`n" .
        "  old full workspace + rabbit: " . FormatSamples(old_times) . " mean=" . Round(old_mean, 1) . " ms`n" .
        "  granular config deployment:  " . FormatSamples(granular_times) . " mean=" .
            Round(granular_mean, 1) . " ms`n" .
        "  speedup: " . Round(speedup, 2) . "x`n`n",
        "*"
    )
}

Mean(values) {
    local total := 0
    for value in values {
        total += value
    }
    return total / values.Length
}

FormatSamples(values) {
    local result := "["
    for index, value in values {
        result .= (index > 1 ? ", " : "") . Round(value, 2)
    }
    return result . "] ms"
}
