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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitRuntimeState.ahk
#Include ..\..\Lib\RabbitTrayMenu.ahk

RunTest("tray click clears composition and updates ASCII state", TestTrayClickUpdatesAscii.Bind())
RunTest("tray click releases its state after an error", TestTrayClickReleasesStateAfterError.Bind())
RunTest("global ASCII tray click leaves process modes unchanged", TestGlobalAsciiTrayClickDoesNotCacheProcess.Bind())
RunTest("tray click uses the cached pre-click window", TestTrayClickUsesCachedPreClickWindow.Bind())

TestTrayClickUpdatesAscii() {
    local calls := []
    local runtime_state := RabbitTrayClickRuntimeProbe(calls)
    local tray := RabbitTrayController(
        RabbitTrayClickRimeProbe(calls),
        1,
        RabbitTrayClickCandidateProbe(calls),
        RabbitConfigSnapshot(Map("show_tips", false)),
        runtime_state,
        (*) => 0
    )

    tray.OnClick(0, WM_LBUTTONDOWN, 0, 0)
    tray.OnClick(0, WM_LBUTTONUP, 0, 0)

    AssertEqual(
        "begin,hide,clear,set:1,apply:1,restore,end",
        JoinTrayClickCalls(calls),
        "The tray click did not atomically apply the ASCII switch."
    )
}

TestTrayClickReleasesStateAfterError() {
    local calls := []
    local runtime_state := RabbitTrayClickRuntimeProbe(calls)
    local tray := RabbitTrayController(
        RabbitTrayClickRimeProbe(calls, true),
        1,
        RabbitTrayClickCandidateProbe(calls),
        RabbitConfigSnapshot(Map("show_tips", false)),
        runtime_state,
        (*) => 0
    )

    tray.OnClick(0, WM_LBUTTONDOWN, 0, 0)
    AssertThrows(
        () => tray.OnClick(0, WM_LBUTTONUP, 0, 0),
        "The tray click did not surface the simulated Rime failure."
    )

    AssertEqual("begin,hide,clear,end", JoinTrayClickCalls(calls), "The tray click lock was not released.")
}

TestGlobalAsciiTrayClickDoesNotCacheProcess() {
    local calls := []
    local runtime_state := RabbitRuntimeState(
        RabbitTrayClickRimeProbe(calls),
        1,
        RabbitConfigSnapshot(Map("global_ascii", true))
    )
    runtime_state.tray_click_process := "code.exe"
    runtime_state.SetTray(RabbitTrayClickPresentationProbe(calls))

    runtime_state.ApplyTrayAscii(true)

    AssertTrue(
        !runtime_state.process_ascii.Has("code.exe"),
        "Global ASCII mode retained a per-process tray click value."
    )
    AssertEqual("tip:1,icon", JoinTrayClickCalls(calls), "Global ASCII mode did not refresh tray presentation.")
}

TestTrayClickUsesCachedPreClickWindow() {
    local runtime_state := RabbitRuntimeState(
        RabbitTrayClickRimeProbe([]),
        1,
        RabbitConfigSnapshot(Map())
    )
    runtime_state.active_win := "notepad.exe"
    runtime_state.active_window := 12345

    runtime_state.BeginTrayIconClick()
    try {
        AssertEqual(
            "notepad.exe",
            runtime_state.tray_click_process,
            "The tray click used the notification area's process instead of the cached input process."
        )
        AssertEqual(
            12345,
            runtime_state.tray_click_window,
            "The tray click did not retain the cached pre-click window."
        )
    } finally {
        runtime_state.EndTrayIconClick()
    }
}

JoinTrayClickCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitTrayClickRimeProbe {
    __New(calls, fail_on_set := false) {
        this.calls := calls
        this.fail_on_set := fail_on_set
        this.ascii_mode := false
    }

    clear_composition(session_id) {
        this.calls.Push("clear")
    }

    get_option(session_id, option) {
        return this.ascii_mode
    }

    set_option(session_id, option, value) {
        if this.fail_on_set {
            throw Error("Simulated Rime failure")
        }
        this.ascii_mode := !!value
        this.calls.Push("set:" . this.ascii_mode)
    }
}

class RabbitTrayClickCandidateProbe {
    __New(calls) {
        this.calls := calls
    }

    Hide() {
        this.calls.Push("hide")
    }
}

class RabbitTrayClickRuntimeProbe {
    __New(calls) {
        this.calls := calls
        this.on_tray_icon_click := false
        this.ascii_mode_false_label_abbr := "中"
        this.ascii_mode_true_label_abbr := "西"
    }

    BeginTrayIconClick() {
        this.on_tray_icon_click := true
        this.calls.Push("begin")
    }

    ApplyTrayAscii(target) {
        this.calls.Push("apply:" . !!target)
    }

    RestoreTrayClickWindow() {
        this.calls.Push("restore")
    }

    EndTrayIconClick() {
        this.on_tray_icon_click := false
        this.calls.Push("end")
    }
}

class RabbitTrayClickPresentationProbe {
    __New(calls) {
        this.calls := calls
    }

    UpdateTip(schema_name := "", ascii_mode := false, full_shape := false, ascii_punct := false) {
        this.calls.Push("tip:" . !!ascii_mode)
    }

    UpdateIcon() {
        this.calls.Push("icon")
    }
}
