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
#Include ..\..\Lib\RabbitFrontendRuntime.ahk

RunTest("frontend runtime supports repeated replacement", TestFrontendRuntimeReplacement.Bind())
RunTest("frontend runtime rolls back startup failures", TestFrontendRuntimeStartupRollback.Bind())
RunTest("frontend runtime can defer first installation", TestFrontendRuntimeDefersInstallation.Bind())

TestFrontendRuntimeReplacement() {
    local calls := []
    local rime := RabbitFrontendRuntimeRimeProbe(calls)
    local tray := RabbitFrontendRuntimeTrayProbe(calls)
    local first := RabbitFrontendRuntimeProbe(rime, tray, calls)
    AssertTrue(first.Start(), "The first frontend runtime did not start.")
    first.Stop()
    first.Stop()

    local second := RabbitFrontendRuntimeProbe(rime, tray, calls)
    AssertTrue(second.Start(), "The replacement frontend runtime did not start.")
    second.Stop()

    AssertEqual(2, CountRuntimeCalls(calls, "setup"), "Rime was not initialized for each runtime.")
    AssertEqual(2, CountRuntimeCalls(calls, "finalize"), "Rime was not finalized for each runtime.")
    AssertEqual(2, CountRuntimeCalls(calls, "bind"), "The persistent tray was not rebound.")
    AssertEqual(2, CountRuntimeCalls(calls, "unbind"), "The persistent tray retained a stopped runtime.")
    AssertEqual(2, CountRuntimeCalls(calls, "register_hotkeys"), "Hotkeys were not registered exactly once per runtime.")
    AssertEqual(2, CountRuntimeCalls(calls, "input_dispose"), "Input owners were not disposed exactly once.")
    AssertEqual(2, CountRuntimeCalls(calls, "timer_start"), "Runtime timers were not recreated.")
    AssertEqual(2, CountRuntimeCalls(calls, "state_dispose"), "Runtime timers were not disposed.")
}

TestFrontendRuntimeStartupRollback() {
    local calls := []
    local rime := RabbitFrontendRuntimeRimeProbe(calls, false)
    local tray := RabbitFrontendRuntimeTrayProbe(calls)
    local runtime := RabbitFrontendRuntimeProbe(rime, tray, calls)
    AssertThrows(runtime.Start.Bind(runtime), "A missing Rime session did not fail startup.")
    AssertEqual(1, CountRuntimeCalls(calls, "finalize"), "Failed startup did not finalize Rime.")
    AssertEqual(1, CountRuntimeCalls(calls, "unbind"), "Failed startup did not detach the tray.")
    runtime.Stop()
    AssertEqual(1, CountRuntimeCalls(calls, "finalize"), "Failed startup cleanup was not idempotent.")
}

TestFrontendRuntimeDefersInstallation() {
    local calls := []
    local runtime := RabbitDeferredFrontendRuntimeProbe(
        RabbitFrontendRuntimeRimeProbe(calls),
        RabbitFrontendRuntimeTrayProbe(calls),
        calls
    )
    AssertTrue(
        !runtime.Start(RABBIT_PARTIAL_MAINTENANCE, true, (*) => (calls.Push("install"), false)),
        "First installation continued into a normal input session."
    )
    AssertEqual(0, CountRuntimeCalls(calls, "create_session"), "Deferred installation created an input session.")
    runtime.Stop()
    AssertEqual(1, CountRuntimeCalls(calls, "finalize"), "Deferred installation did not release Rime.")
}

CountRuntimeCalls(calls, expected) {
    local call, count := 0
    for call in calls {
        if call = expected {
            count += 1
        }
    }
    return count
}

class RabbitFrontendRuntimeProbe extends RabbitFrontendRuntime {
    __New(rime_api, tray, calls) {
        this.calls := calls
        super.__New(rime_api, tray, 1033, (*) => 0)
    }

    CreateTraits() {
        return 1
    }

    RunStartupMaintenance(*) {
        return true
    }

    PrepareRuntimeFiles() {
    }

    LoadRuntimeLocale() {
    }

    LoadConfig() {
        return {
            config: {use_legacy_candidate_box: false},
            style: 0,
            dark_mode: false
        }
    }

    CreateCandidateBox(*) {
        return RabbitFrontendRuntimeOwnerProbe(this.calls, "candidate_dispose")
    }

    CreateStatusTip(*) {
        return RabbitFrontendRuntimeOwnerProbe(this.calls, "status_dispose")
    }

    CreateRuntimeState(*) {
        return RabbitFrontendRuntimeStateProbe(this.calls)
    }

    CreateInputController(*) {
        return RabbitFrontendRuntimeInputProbe(this.calls)
    }

    CreateAppearanceController(*) {
        return RabbitFrontendRuntimeAppearanceProbe(this.calls)
    }
}

class RabbitDeferredFrontendRuntimeProbe extends RabbitFrontendRuntimeProbe {
    RunStartupMaintenance(maintenance, first_run, first_install_callback) {
        return first_install_callback.Call()
    }
}

class RabbitFrontendRuntimeRimeProbe {
    __New(calls, create_session := true) {
        this.calls := calls
        this.create_session_result := create_session ? 42 : 0
    }

    setup(*) {
        this.calls.Push("setup")
    }

    set_notification_handler(*) {
        this.calls.Push("notify")
    }

    initialize(*) {
        this.calls.Push("initialize")
    }

    create_session() {
        this.calls.Push("create_session")
        return this.create_session_result
    }

    get_status(*) {
        return 0
    }

    destroy_session(*) {
        this.calls.Push("destroy_session")
    }

    finalize() {
        this.calls.Push("finalize")
    }
}

class RabbitFrontendRuntimeTrayProbe {
    __New(calls) {
        this.calls := calls
    }

    BindRuntime(*) {
        this.calls.Push("bind")
    }

    UnbindRuntime() {
        this.calls.Push("unbind")
    }
}

class RabbitFrontendRuntimeOwnerProbe {
    __New(calls, label) {
        this.calls := calls
        this.label := label
    }

    Dispose() {
        this.calls.Push(this.label)
    }
}

class RabbitFrontendRuntimeStateProbe extends RabbitFrontendRuntimeOwnerProbe {
    __New(calls) {
        super.__New(calls, "state_dispose")
    }

    SetTray(*) {
        this.calls.Push("set_tray")
    }

    UpdateStateLabels() {
        this.calls.Push("state_labels")
    }

    StartTimer() {
        this.calls.Push("timer_start")
    }
}

class RabbitFrontendRuntimeInputProbe extends RabbitFrontendRuntimeOwnerProbe {
    __New(calls) {
        super.__New(calls, "input_dispose")
    }

    RegisterHotKeys() {
        this.calls.Push("register_hotkeys")
    }

    StartFocusMonitor() {
        this.calls.Push("focus_start")
    }
}

class RabbitFrontendRuntimeAppearanceProbe extends RabbitFrontendRuntimeOwnerProbe {
    __New(calls) {
        super.__New(calls, "appearance_dispose")
    }

    Register() {
        this.calls.Push("appearance_register")
    }
}
