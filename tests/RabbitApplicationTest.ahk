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

#Include <RabbitApplication>

RunTest("deployer launch after application shutdown", TestDeployerLaunchAfterShutdown.Bind())
RunTest("tray delegates deployer launch", TestTrayDelegatesDeployerLaunch.Bind())

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

    application.RunDeployer("dict", 1033)
    application.OnExit("Exit", 1)

    AssertEqual(
        "input,runtime,appearance,candidate,destroy:42,finalize,close,"
            . "launch:dict:1033,exit:1",
        JoinApplicationCalls(calls),
        "The deployer started before the main application released Rime."
    )
}

TestTrayDelegatesDeployerLaunch() {
    local calls := []
    local callback := (command, layout) => calls.Push(command . ":" . layout)
    local tray := RabbitTrayController(0, 0, 0, 0, 0, 1033, callback)

    tray.StartDeployer("deploy")

    AssertEqual(
        "deploy:1033",
        JoinApplicationCalls(calls),
        "The tray did not delegate deployment through the application owner."
    )
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
        this.calls.Push("launch:" . command . ":" . args[1])
    }

    ExitApplication(code) {
        this.calls.Push("exit:" . code)
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
