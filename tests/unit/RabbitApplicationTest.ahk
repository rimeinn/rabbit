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
 *
 */

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitApplication.ahk

RunTest("deployer launch after application shutdown", TestDeployerLaunchAfterShutdown.Bind())
RunTest("tray separates resident maintenance from deployer launch", TestTraySeparatesMaintenance.Bind())
RunTest("tray routes unified settings", TestTrayRoutesUnifiedSettings.Bind())
RunTest("tray routes legacy settings", TestTrayRoutesLegacySettings.Bind())
RunTest("first install uses platform settings", TestFirstInstallUsesPlatformSettings.Bind())
RunTest("frontend startup waits for deployment ownership", TestFrontendStartupWaitsForDeploymentOwnership.Bind())

TestDeployerLaunchAfterShutdown() {
    local calls := []
    local application := RabbitApplicationDeployerProbe(
        RabbitApplicationRimeProbe(calls),
        calls
    )
    application.runtime := RabbitApplicationStopProbe(calls)
    application.application_mutex := RabbitApplicationCloseProbe(calls)

    application.RunDeployer(
        "legacy-settings",
        "dictionary",
        "--return-to-rabbit",
        "--keyboard-layout",
        "0x0409"
    )
    application.OnExit("Exit", 1)

    AssertEqual(
        "runtime_stop,close,"
            . "launch:legacy-settings:dictionary:--return-to-rabbit:--keyboard-layout:0x0409,exit:1",
        JoinApplicationCalls(calls),
        "The deployer started before the main application released Rime."
    )
}

TestTraySeparatesMaintenance() {
    local calls := []
    local callback := (args*) => calls.Push(JoinApplicationArguments(args))
    local tray := RabbitTrayController(0, 0, 0, 0, 0, 1033, (*) => 0, callback)

    tray.StartDeployer("deploy")
    tray.StartDeployer("sync")
    tray.StartDeployer("legacy-settings", "dictionary")

    AssertEqual(
        "deploy,sync,legacy-settings:dictionary:--return-to-rabbit:--keyboard-layout:0x0409",
        JoinApplicationCalls(calls),
        "The tray mixed resident maintenance arguments with the legacy deployer protocol."
    )
}

TestTrayRoutesUnifiedSettings() {
    local calls := []
    local tray := RabbitModernTrayProbe(
        0,
        0,
        0,
        0,
        0,
        1033,
        (page_id := "") => calls.Push("settings:" . page_id),
        (*) => calls.Push("maintenance")
    )

    tray.StartSettings()
    tray.StartSettings("dictionary")
    tray.StartSettings("maintenance")

    AssertEqual(
        "settings:,settings:dictionary,settings:maintenance",
        JoinApplicationCalls(calls),
        "The modern tray did not route settings pages to the resident controller."
    )
}

TestTrayRoutesLegacySettings() {
    local calls := []
    local tray := RabbitLegacyTrayProbe(
        0,
        0,
        0,
        0,
        0,
        1033,
        (*) => calls.Push("settings"),
        (args*) => calls.Push(JoinApplicationArguments(args))
    )

    tray.StartSettings()
    tray.StartSettings("dictionary")
    tray.StartSettings("maintenance")

    AssertEqual(
        "legacy-settings:--return-to-rabbit:--keyboard-layout:0x0409," .
            "legacy-settings:dictionary:--return-to-rabbit:--keyboard-layout:0x0409," .
            "sync",
        JoinApplicationCalls(calls),
        "The old-Windows tray did not use legacy settings and direct synchronization."
    )
}

TestFirstInstallUsesPlatformSettings() {
    local modern_calls := []
    local modern := RabbitApplicationInstallProbe(modern_calls, false)
    modern.keyboard_layout := 1033
    modern.settings := RabbitApplicationSettingsProbe(modern_calls)
    modern.RunFirstInstallation()
    AssertEqual(
        "install:input-schemes",
        JoinApplicationCalls(modern_calls),
        "Modern first install did not stay in the resident frontend."
    )

    local legacy_calls := []
    local legacy := RabbitApplicationInstallProbe(legacy_calls, true)
    legacy.keyboard_layout := 1033
    legacy.RunFirstInstallation()
    AssertEqual(
        "legacy-settings:--install:--return-to-rabbit:--keyboard-layout:0x0409",
        JoinApplicationCalls(legacy_calls),
        "Old-Windows first install did not open the legacy settings flow."
    )
}

JoinApplicationArguments(args) {
    local argument, result := ""
    for argument in args {
        result .= (result ? ":" : "") . argument
    }
    return result
}

JoinApplicationCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitApplicationDeployerProbe extends RabbitApplication {
    __New(rime_api, calls) {
        super.__New(rime_api)
        this.calls := calls
    }

    LaunchDeployer(command, args*) {
        local all_args := [command]
        for argument in args {
            all_args.Push(argument)
        }
        this.calls.Push("launch:" . JoinApplicationArguments(all_args))
    }

    ExitApplication(code) {
        this.calls.Push("exit:" . code)
    }
}

class RabbitApplicationInstallProbe extends RabbitApplication {
    __New(calls, legacy) {
        super.__New(0)
        this.calls := calls
        this.legacy := legacy
    }

    UseLegacySettings() {
        return this.legacy
    }

    RunDeployer(command, args*) {
        local all_args := [command]
        for argument in args {
            all_args.Push(argument)
        }
        this.calls.Push(JoinApplicationArguments(all_args))
    }
}

class RabbitModernTrayProbe extends RabbitTrayController {
    UseLegacySettings() {
        return false
    }
}

class RabbitLegacyTrayProbe extends RabbitTrayController {
    UseLegacySettings() {
        return true
    }
}

class RabbitApplicationRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    destroy_session(session_id) {
        this.calls.Push("destroy:" . session_id)
    }

    finalize() {
        this.calls.Push("finalize")
    }
}

class RabbitApplicationDisposeProbe {
    __New(calls, label) {
        this.calls := calls
        this.label := label
    }

    Dispose() {
        this.calls.Push(this.label)
    }
}

TestFrontendStartupWaitsForDeploymentOwnership() {
    local calls := []
    local application := RabbitApplicationStartupProbe(calls)

    AssertTrue(application.StartFrontendRuntime(), "The frontend runtime did not start.")
    AssertEqual(
        "gate_create:busy,gate_close:busy,wait,gate_create:free,runtime_create,runtime_start,gate_close:free",
        JoinApplicationCalls(calls),
        "The frontend initialized while a deployment worker still owned Rime."
    )
}

class RabbitApplicationStopProbe {
    __New(calls) {
        this.calls := calls
    }

    Stop() {
        this.calls.Push("runtime_stop")
    }
}

class RabbitApplicationSettingsProbe {
    __New(calls) {
        this.calls := calls
    }

    ShowInstallation(page_id) {
        this.calls.Push("install:" . page_id)
        return true
    }
}

class RabbitApplicationCloseProbe {
    __New(calls) {
        this.calls := calls
    }

    Close() {
        this.calls.Push("close")
    }
}

class RabbitApplicationStartupProbe extends RabbitApplication {
    __New(calls) {
        super.__New(0)
        this.calls := calls
        this.gate_index := 0
    }

    CreateDeploymentStartupGate() {
        this.gate_index += 1
        return RabbitApplicationDeploymentGateProbe(this.calls, this.gate_index = 1)
    }

    WaitForDeploymentStartupGate() {
        this.calls.Push("wait")
    }

    CreateFrontendRuntime() {
        this.calls.Push("runtime_create")
        return RabbitApplicationRuntimeStartProbe(this.calls)
    }
}

class RabbitApplicationDeploymentGateProbe {
    __New(calls, busy) {
        this.calls := calls
        this.busy := busy
        this.lasterr := 0
    }

    Create() {
        this.lasterr := this.busy ? ERROR_ALREADY_EXISTS : 0
        this.calls.Push("gate_create:" . (this.busy ? "busy" : "free"))
        return true
    }

    Close() {
        this.calls.Push("gate_close:" . (this.busy ? "busy" : "free"))
    }
}

class RabbitApplicationRuntimeStartProbe {
    started := false

    __New(calls) {
        this.calls := calls
    }

    Start(*) {
        this.calls.Push("runtime_start")
        this.started := true
        return true
    }
}
