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
#Include ..\..\Lib\RabbitDeployerApplication.ahk

RunTest("settings window ownership", TestSettingsWindowOwnership.Bind())
RunTest("deployer defers the initial settings page load", TestDeployerDefersInitialSettingsLoad.Bind())
RunTest("old Windows uses legacy deployer", TestOldWindowsUsesLegacyDeployer.Bind())
RunTest("deployer validates settings page IDs", TestDeployerValidatesSettingsPageIds.Bind())
RunTest("old Windows redirects dictionary settings", TestOldWindowsRedirectsDictionarySettings.Bind())

TestSettingsWindowOwnership() {
    local calls := []
    local application := RabbitDeployerApplicationProbe(calls)

    AssertEqual(0, application.ShowSettings("input-schemes", true), "The settings window returned a failure result.")
    AssertEqual(
        "create:input-schemes:1,show,wait,dispose",
        JoinSettingsWindowCalls(calls),
        "The deployer application did not own the settings window for its complete lifetime."
    )
}

TestDeployerDefersInitialSettingsLoad() {
    local application := RabbitDeployerApplication(0)
    local window := application.CreateSettingsWindow()
    try {
        AssertTrue(window.initial_page_load_pending,
            "The deployer loaded settings before showing its window.")
        AssertTrue(!window.appearance_page.settings,
            "The deployer initialized the appearance model during window construction.")
    } finally {
        window.Dispose()
    }
}

TestDeployerValidatesSettingsPageIds() {
    local application := RabbitDeployerApplicationProbe([])
    local options := application.ParseOptions([])
    AssertEqual("settings", options.command, "No arguments did not select unified settings.")
    AssertEqual("", options.target, "No arguments were mapped to a named page.")

    options := application.ParseOptions(["settings", "about"])
    AssertEqual("about", options.target, "A stable settings page ID was rejected.")
    AssertThrows(
        application.ParseOptions.Bind(application, ["settings", "missing-page"]),
        "The deployer accepted an unknown settings page."
    )
}

TestOldWindowsRedirectsDictionarySettings() {
    local calls := []
    local application := RabbitLegacyDeployerApplicationProbe(calls)

    AssertEqual(8, application.ShowSettings("dictionary"), "The legacy dictionary result was not returned.")
    AssertEqual(
        "dictionary",
        JoinSettingsWindowCalls(calls),
        "Old Windows did not redirect unified dictionary settings to the legacy dialog."
    )
}

TestOldWindowsUsesLegacyDeployer() {
    local calls := []
    local application := RabbitLegacyDeployerApplicationProbe(calls)

    AssertEqual(7, application.ShowSettings(), "The legacy deployer result was not returned.")
    AssertEqual(
        "legacy:0",
        JoinSettingsWindowCalls(calls),
        "The old-Windows settings path constructed the new settings window."
    )
}

JoinSettingsWindowCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitDeployerApplicationProbe extends RabbitDeployerApplication {
    __New(calls) {
        this.calls := calls
        super.__New(0)
    }

    CreateSettingsWindow(page_id := "", installing := false) {
        this.calls.Push("create:" . page_id . ":" . installing)
        return RabbitSettingsWindowProbe(this.calls)
    }

    UseLegacySettings() {
        return false
    }
}

class RabbitLegacyDeployerApplicationProbe extends RabbitDeployerApplication {
    __New(calls) {
        this.calls := calls
        super.__New(0)
        this.workflow := RabbitLegacySettingsWorkflowProbe(calls)
    }

    CreateSettingsWindow() {
        this.calls.Push("create")
        throw Error("The new settings window must not be created on old Windows.")
    }

    UseLegacySettings() {
        return true
    }
}

class RabbitLegacySettingsWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    Run(installing) {
        this.calls.Push("legacy:" . installing)
        return 7
    }

    DictManagement() {
        this.calls.Push("dictionary")
        return 8
    }
}

class RabbitSettingsWindowProbe {
    language_reload_state := 0
    __New(calls) {
        this.calls := calls
    }

    Show(options) {
        this.calls.Push("show")
    }

    WaitClose() {
        this.calls.Push("wait")
    }

    Dispose() {
        this.calls.Push("dispose")
    }
}

RunTest("settings rebuild only for a resolved language change", TestSettingsLanguageChange.Bind())
RunTest("settings session continues after language reconstruction", TestSettingsLanguageSession.Bind())

TestSettingsLanguageChange() {
    local application := RabbitLanguageApplicationProbe([])
    local window := RabbitLanguageWindowProbe([], 0), previous := RabbitI18n.locale
    try {
        RabbitI18n.locale := "en-US"
        application.context.rime.value := "en-GB"
        AssertTrue(!application.ReloadSettingsLanguage(window), "Equivalent language triggered reconstruction.")
        AssertTrue(!window.language_reload_state, "Unchanged language disposed the window.")
        application.context.rime.value := "zh-CN"
        AssertTrue(application.ReloadSettingsLanguage(window), "Changed language did not request reconstruction.")
        AssertEqual("behavior", window.language_reload_state.page_id, "Current page was lost.")
        AssertEqual(3, window.language_reload_state.tab, "Interface tab was lost.")
        AssertEqual(125, window.language_reload_state.x, "Window position was lost.")
        AssertEqual("zh-CN", RabbitI18n.locale, "New locale was not activated.")
    } finally {
        RabbitI18n.locale := previous
    }
}

TestSettingsLanguageSession() {
    local calls := [], application := RabbitLanguageApplicationProbe(calls)
    application.ShowSettings("behavior")
    AssertEqual("create:behavior,show,wait,dispose,create:behavior,restore:3,show,wait,dispose",
        JoinSettingsWindowCalls(calls), "The application exited or lost state during reconstruction.")
}

class RabbitLanguageApplicationProbe extends RabbitDeployerApplication {
    __New(calls) {
        super.__New(RabbitLanguageConfigProbe())
        this.calls := calls
        this.created := 0
    }

    UseLegacySettings() {
        return false
    }

    CreateSettingsWindow(page_id := "", installing := false) {
        this.created += 1
        this.calls.Push("create:" . page_id)
        return RabbitLanguageWindowProbe(this.calls, this.created = 1)
    }

    ActivateSettingsLanguage(preference) {
        RabbitI18n.locale := RabbitI18n.ResolveLocale(preference)
    }
}

class RabbitLanguageConfigProbe {
    value := "en-US"
    config_open(*) {
        return 1
    }
    config_get_string(*) {
        return this.value
    }
    config_close(*) {
    }
}

class RabbitLanguageWindowProbe {
    language_reload_state := 0
    __New(calls, reload) {
        this.calls := calls
        this.reload := reload
    }
    CaptureLanguageReloadState() {
        return {page_id: "behavior", installing: false, tab: 3, x: 125, y: 150}
    }
    RestoreLanguageReloadState(state) {
        this.calls.Push("restore:" . state.tab)
    }
    Show(*) {
        this.calls.Push("show")
    }
    WaitClose() {
        this.calls.Push("wait")
        if this.reload {
            this.language_reload_state := this.CaptureLanguageReloadState()
        }
    }
    Dispose() {
        this.calls.Push("dispose")
    }
}
