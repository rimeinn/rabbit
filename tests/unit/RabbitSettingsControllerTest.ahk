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
#Include ..\..\Lib\RabbitSettingsController.ahk

RunTest("settings controller owns one window", TestSettingsControllerOwnsOneWindow.Bind())
RunTest("settings controller releases a closed window", TestSettingsControllerReleasesClosedWindow.Bind())
RunTest("settings controller rebuilds for language changes", TestSettingsControllerLanguageReload.Bind())

TestSettingsControllerOwnsOneWindow() {
    local calls := []
    local controller := RabbitSettingsControllerProbe(calls)
    controller.Show("behavior")
    local first_window := controller.window
    controller.Show("dictionary")
    AssertTrue(controller.window = first_window, "Repeated settings opened a second window.")
    AssertEqual(
        "create:behavior,show:Center,select:5,activate",
        JoinSettingsControllerCalls(calls),
        "Repeated settings did not switch and activate the owned window."
    )
    controller.Dispose()
}

TestSettingsControllerReleasesClosedWindow() {
    local calls := []
    local controller := RabbitSettingsControllerProbe(calls)
    controller.Show()
    controller.window.Dispose()
    AssertTrue(!controller.window, "The controller retained a disposed window.")
    controller.Show("about")
    AssertEqual(
        "create:,show:Center,dispose,create:about,show:Center",
        JoinSettingsControllerCalls(calls),
        "The controller did not replace a closed settings window."
    )
    controller.Dispose()
}

TestSettingsControllerLanguageReload() {
    local calls := [], previous := RabbitI18n.locale
    local controller := RabbitSettingsLanguageControllerProbe(calls)
    try {
        RabbitI18n.locale := "en-US"
        controller.Show("behavior")
        AssertTrue(controller.ReloadLanguage(controller.window), "The language change was not applied.")
        AssertEqual(
            "create:behavior,show:Center,capture,dispose,language:zh-CN," .
                "create:behavior,restore:3,show:x125 y150",
            JoinSettingsControllerCalls(calls),
            "The settings window state was lost during language reconstruction."
        )
    } finally {
        RabbitI18n.locale := previous
        controller.Dispose()
    }
}

JoinSettingsControllerCalls(calls) {
    local call, result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitSettingsControllerProbe extends RabbitSettingsController {
    __New(calls, rime_api := 0) {
        this.calls := calls
        super.__New(rime_api, (*) => 0)
    }

    CreateWorkflow() {
        return 0
    }

    CreateWindow(page_id := "", installing := false) {
        this.calls.Push("create:" . page_id)
        return RabbitSettingsControllerWindowProbe(this.calls, page_id, installing)
    }

    ActivateWindow(window) {
        this.calls.Push("activate")
    }
}

class RabbitSettingsLanguageControllerProbe extends RabbitSettingsControllerProbe {
    __New(calls) {
        super.__New(calls, RabbitSettingsControllerRimeProbe())
    }

    ActivateLanguage(preference) {
        this.calls.Push("language:" . preference)
        RabbitI18n.locale := preference
    }
}

class RabbitSettingsControllerWindowProbe {
    __New(calls, page_id, installing) {
        this.calls := calls
        this.page_id := page_id
        this.installing := installing
        this.disposed := false
        this.closed_callback := 0
        this.language_reload_callback := 0
    }

    SelectPage(index) {
        this.calls.Push("select:" . index)
    }

    Show(options) {
        this.calls.Push("show:" . options)
    }

    CaptureLanguageReloadState() {
        this.calls.Push("capture")
        return {page_id: "behavior", installing: false, x: 125, y: 150, tab: 3}
    }

    RestoreLanguageReloadState(state) {
        this.calls.Push("restore:" . state.tab)
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        this.calls.Push("dispose")
        if this.closed_callback {
            this.closed_callback.Call(this)
        }
    }
}

class RabbitSettingsControllerRimeProbe {
    config_open(*) {
        return 1
    }

    config_get_string(*) {
        return "zh-CN"
    }

    config_close(*) {
    }
}
