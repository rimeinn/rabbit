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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitApplication.ahk

RunTest("deployer launch after application shutdown", TestDeployerLaunchAfterShutdown.Bind())
RunTest("tray delegates deployer launch", TestTrayDelegatesDeployerLaunch.Bind())
RunTest("tray routes unified settings", TestTrayRoutesUnifiedSettings.Bind())
RunTest("tray routes legacy settings", TestTrayRoutesLegacySettings.Bind())
RunTest("first install uses platform settings", TestFirstInstallUsesPlatformSettings.Bind())

TestDeployerLaunchAfterShutdown() {
    local calls := []
    local application := RabbitApplicationDeployerProbe(
        RabbitApplicationRimeProbe(calls),
        calls
    )
    application.context.rime_initialized := true
    application.context.session_id := 42
    application.context.mutex := RabbitApplicationCloseProbe(calls)
    application.context.candidate_box := RabbitApplicationDisposeProbe(calls, "candidate")
    application.context.input := RabbitApplicationDisposeProbe(calls, "input")
    application.context.runtime_state := RabbitApplicationDisposeProbe(calls, "runtime")
    application.context.appearance := RabbitApplicationDisposeProbe(calls, "appearance")

    application.RunDeployer(
        "legacy-settings",
        "dictionary",
        "--return-to-rabbit",
        "--keyboard-layout",
        "0x0409"
    )
    application.OnExit("Exit", 1)

    AssertEqual(
        "input,runtime,appearance,candidate,destroy:42,finalize,close,"
            . "launch:legacy-settings:dictionary:--return-to-rabbit:--keyboard-layout:0x0409,exit:1",
        JoinApplicationCalls(calls),
        "The deployer started before the main application released Rime."
    )
}

TestTrayDelegatesDeployerLaunch() {
    local calls := []
    local callback := (args*) => calls.Push(JoinApplicationArguments(args))
    local tray := RabbitTrayController(0, 0, 0, 0, 0, 1033, callback)

    tray.StartDeployer("deploy")

    AssertEqual(
        "deploy:--return-to-rabbit:--keyboard-layout:0x0409",
        JoinApplicationCalls(calls),
        "The tray did not delegate deployment through the application owner."
    )
}

TestTrayRoutesUnifiedSettings() {
    local calls := []
    local tray := RabbitModernTrayProbe(0, 0, 0, 0, 0, 1033, (args*) => calls.Push(
        JoinApplicationArguments(args)
    ))

    tray.StartSettings()
    tray.StartSettings("dictionary")
    tray.StartSettings("maintenance")

    AssertEqual(
        "settings:--return-to-rabbit:--keyboard-layout:0x0409," .
            "settings:dictionary:--return-to-rabbit:--keyboard-layout:0x0409," .
            "settings:maintenance:--return-to-rabbit:--keyboard-layout:0x0409",
        JoinApplicationCalls(calls),
        "The modern tray did not route settings pages through the unified window."
    )
}

TestTrayRoutesLegacySettings() {
    local calls := []
    local tray := RabbitLegacyTrayProbe(0, 0, 0, 0, 0, 1033, (args*) => calls.Push(
        JoinApplicationArguments(args)
    ))

    tray.StartSettings()
    tray.StartSettings("dictionary")
    tray.StartSettings("maintenance")

    AssertEqual(
        "legacy-settings:--return-to-rabbit:--keyboard-layout:0x0409," .
            "legacy-settings:dictionary:--return-to-rabbit:--keyboard-layout:0x0409," .
            "sync:--return-to-rabbit:--keyboard-layout:0x0409",
        JoinApplicationCalls(calls),
        "The old-Windows tray did not use legacy settings and direct synchronization."
    )
}

TestFirstInstallUsesPlatformSettings() {
    local modern_calls := []
    local modern := RabbitApplicationInstallProbe(modern_calls, false)
    modern.context.keyboard_layout := 1033
    modern.RunFirstInstallation()
    AssertEqual(
        "settings:input-schemes:--install:--return-to-rabbit:--keyboard-layout:0x0409",
        JoinApplicationCalls(modern_calls),
        "Modern first install did not open the unified input-schemes page."
    )

    local legacy_calls := []
    local legacy := RabbitApplicationInstallProbe(legacy_calls, true)
    legacy.context.keyboard_layout := 1033
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

class RabbitApplicationCloseProbe {
    __New(calls) {
        this.calls := calls
    }

    Close() {
        this.calls.Push("close")
    }
}
