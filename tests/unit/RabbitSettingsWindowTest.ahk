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
#Include ..\..\Lib\RabbitSettingsWindow.ahk

RunTest("settings window navigation", TestSettingsWindowNavigation.Bind())
RunTest("settings window rejects invalid page", TestSettingsWindowRejectsInvalidPage.Bind())
RunTest("settings window maintenance actions", TestSettingsWindowMaintenanceActions.Bind())
RunTest("settings window saves appearance settings", TestSettingsWindowSavesAppearanceSettings.Bind())
RunTest("settings window saves switcher settings", TestSettingsWindowSavesSwitcherSettings.Bind())
RunTest("settings window saves behavior settings", TestSettingsWindowSavesBehaviorSettings.Bind())

TestSettingsWindowNavigation() {
    local window := RabbitSettingsWindow()
    try {
        AssertEqual(1, window.selected_page, "The settings window did not select its first page.")
        AssertEqual("外观", window.page_title.Value, "The settings window showed the wrong first page.")
        AssertTrue(window.SelectPage(4), "The settings window rejected a valid page.")
        AssertEqual(4, window.selected_page, "The settings window did not update its selected page.")
        AssertEqual("应用适配", window.page_title.Value, "The settings window showed the wrong selected page.")
        AssertTrue(window.SelectPage(7), "The settings window rejected the about page.")
        AssertTrue(window.about_group.Visible, "The settings window did not show the about page.")
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowRejectsInvalidPage() {
    local window := RabbitSettingsWindow()
    try {
        AssertTrue(!window.SelectPage(0), "The settings window accepted an invalid page.")
        AssertEqual(1, window.selected_page, "An invalid page changed the settings selection.")
    } finally {
        window.Dispose()
        window.Dispose()
    }
}

TestSettingsWindowMaintenanceActions() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsWorkflowProbe(calls))
    try {
        AssertTrue(window.RunDeploy(), "The settings window reported a deployment failure.")
        AssertTrue(window.RunSync(), "The settings window reported a synchronization failure.")
        AssertTrue(window.RunDictionaryManagement(), "The settings window reported a dictionary failure.")
        AssertEqual(
            "deploy,sync,dict",
            JoinSettingsWorkflowCalls(calls),
            "The settings window invoked the wrong maintenance actions."
        )
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowSavesAppearanceSettings() {
    local calls := []
    local workflow := RabbitSettingsAppearanceWorkflowProbe(calls)
    local window := RabbitSettingsWindow(workflow, true)
    try {
        AssertEqual(2, window.appearance_presets.Length, "The appearance page showed the wrong preset count.")
        AssertEqual(1, window.appearance_list.Value, "The appearance page did not select the active preset.")
        window.appearance_list.Choose(2)
        window.OnAppearanceSelectionChange()
        AssertTrue(window.ApplyAppearanceSettings(), "The appearance page failed to save valid settings.")
    } finally {
        window.Dispose()
    }
    AssertEqual(
        "create_style,select:theme_b,save_style,deploy,dispose_style",
        JoinSettingsWorkflowCalls(calls),
        "The appearance page did not save, deploy, and dispose in order."
    )
}

TestSettingsWindowSavesSwitcherSettings() {
    local calls := []
    local workflow := RabbitSettingsSwitcherWorkflowProbe(calls)
    local window := RabbitSettingsWindow(workflow)
    try {
        AssertTrue(window.SelectPage(2), "The settings window rejected the switcher page.")
        AssertEqual(2, window.switcher_list.GetCount(), "The switcher page showed the wrong schema count.")
        window.switcher_list.Modify(1, "-Check")
        window.switcher_list.Modify(2, "Check")
        window.switcher_hotkeys.Value := "F4"
        window.MarkSwitcherDirty()
        AssertTrue(window.ApplySwitcherSettings(), "The switcher page failed to save valid settings.")
    } finally {
        window.Dispose()
    }
    AssertEqual(
        "create_model,save:schema_b:F4,deploy,dispose_model",
        JoinSettingsWorkflowCalls(calls),
        "The switcher page did not save, deploy, and dispose in order."
    )
}

TestSettingsWindowSavesBehaviorSettings() {
    local calls := []
    local workflow := RabbitSettingsBehaviorWorkflowProbe(calls)
    local window := RabbitSettingsWindow(workflow)
    try {
        AssertTrue(window.SelectPage(3), "The settings window rejected the behavior page.")
        window.show_tips.Value := false
        window.global_ascii.Value := true
        window.OnBehaviorChanged()
        AssertTrue(window.ApplyBehaviorSettings(), "The behavior page failed to save valid settings.")
    } finally {
        window.Dispose()
    }
    AssertEqual(
        "create_behavior,save_behavior:0:1,deploy,dispose_behavior",
        JoinSettingsWorkflowCalls(calls),
        "The behavior page did not save, deploy, and dispose in order."
    )
}

JoinSettingsWorkflowCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitSettingsWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return 0
    }

    SyncUserData() {
        this.calls.Push("sync")
        return 0
    }

    DictManagement() {
        this.calls.Push("dict")
        return 0
    }
}

class RabbitSettingsSwitcherWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    CreateSwitcherSettingsModel() {
        this.calls.Push("create_model")
        return RabbitSettingsSwitcherModelProbe(this.calls)
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return 0
    }
}

class RabbitSettingsAppearanceWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    CreateUIStyleSettings() {
        this.calls.Push("create_style")
        return RabbitSettingsAppearanceModelProbe(this.calls)
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return 0
    }
}

class RabbitSettingsBehaviorWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    CreateBehaviorSettingsModel() {
        this.calls.Push("create_behavior")
        return RabbitSettingsBehaviorModelProbe(this.calls)
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return 0
    }
}

class RabbitSettingsBehaviorModelProbe {
    __New(calls) {
        this.calls := calls
        this.show_tips := true
        this.show_tips_time := 1200
        this.global_ascii := false
        this.fix_candidate_box := false
        this.use_legacy_candidate_box := false
        this.bypass_password_fields := true
    }

    Save(values) {
        this.calls.Push("save_behavior:" . values.show_tips . ":" . values.global_ascii)
        return true
    }

    Dispose() {
        this.calls.Push("dispose_behavior")
    }
}

class RabbitSettingsAppearanceModelProbe {
    __New(calls) {
        this.calls := calls
    }

    GetActiveColorScheme() {
        return "theme_a"
    }

    GetPresetColorSchemes() {
        return [
            { color_scheme_id: "theme_a", name: "主题 A", author: "甲", style: 0 },
            { color_scheme_id: "theme_b", name: "主题 B", author: "乙", style: 0 },
        ]
    }

    SelectColorScheme(color_scheme_id) {
        this.calls.Push("select:" . color_scheme_id)
        return true
    }

    Save() {
        this.calls.Push("save_style")
        return true
    }

    Dispose() {
        this.calls.Push("dispose_style")
    }
}

class RabbitSettingsSwitcherModelProbe {
    __New(calls) {
        this.calls := calls
        this.hotkeys := "Control+grave"
        this.items := [
            { id: "schema_a", name: "方案 A", author: "", description: "A", selected: true },
            { id: "schema_b", name: "方案 B", author: "", description: "B", selected: false },
        ]
    }

    Save(schema_ids, hotkeys) {
        this.calls.Push("save:" . schema_ids[1] . ":" . hotkeys)
        return true
    }

    Dispose() {
        this.calls.Push("dispose_model")
    }
}
