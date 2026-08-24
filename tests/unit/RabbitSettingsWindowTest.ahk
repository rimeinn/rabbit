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
RunTest("settings window saves application settings", TestSettingsWindowSavesApplicationSettings.Bind())
RunTest("settings window embeds dictionary management", TestSettingsWindowEmbedsDictionaryManagement.Bind())
RunTest("settings window uses a global apply action", TestSettingsWindowUsesGlobalApplyAction.Bind())
RunTest("settings window preserves canceled close", TestSettingsWindowPreservesCanceledClose.Bind())
RunTest("settings window saves all settings on close", TestSettingsWindowSavesAllSettingsOnClose.Bind())

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

TestSettingsWindowSavesApplicationSettings() {
    local calls := []
    local workflow := RabbitSettingsApplicationWorkflowProbe(calls)
    local window := RabbitSettingsWindow(workflow)
    try {
        AssertTrue(window.SelectPage(4), "The settings window rejected the application page.")
        AssertEqual(1, window.application_list.GetCount(), "The application page showed the wrong rule count.")
        AssertEqual(
            "cmd.exe",
            window.application_process.Value,
            "The application page did not show the selected process."
        )
        AssertTrue(
            window.ResetSelectedApplicationRule(),
            "The application page failed to stage a rule reset."
        )
        window.application_process.Value := "NOTEPAD.EXE"
        window.application_mode.Choose(1)
        AssertTrue(window.StageApplicationRule(), "The application page rejected a valid rule.")
        AssertTrue(window.ApplyApplicationSettings(), "The application page failed to save valid settings.")
    } finally {
        window.Dispose()
    }
    AssertEqual(
        "create_application,save_application:cmd.exe:reset,save_application:notepad.exe:0," .
            "deploy,load_application,dispose_application",
        JoinSettingsWorkflowCalls(calls),
        "The application page did not save, deploy, reload, and dispose in order."
    )
}

TestSettingsWindowEmbedsDictionaryManagement() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsDictionaryWorkflowProbe(calls))
    try {
        AssertTrue(window.SelectPage(5), "The settings window rejected the dictionary page.")
        AssertEqual(
            2,
            ControlGetItems(window.dictionary_list).Length,
            "The dictionary page showed the wrong item count."
        )
        AssertTrue(window.apply_button.Visible, "The dictionary page hid the global apply button.")
        AssertTrue(!window.apply_button.Enabled, "The dictionary page enabled apply without pending changes.")
        AssertTrue(!window.dictionary_backup.Enabled, "The dictionary page enabled backup without a selection.")
        AssertTrue(window.dictionary_restore.Enabled, "The dictionary page disabled snapshot restore.")
        window.dictionary_list.Choose(1)
        window.OnDictionarySelectionChange()
        AssertTrue(window.dictionary_backup.Enabled, "The dictionary page did not enable backup for a selection.")
        AssertTrue(window.dictionary_export.Enabled, "The dictionary page did not enable export for a selection.")
        AssertTrue(window.dictionary_import.Enabled, "The dictionary page did not enable import for a selection.")
    } finally {
        window.Dispose()
    }
    AssertEqual(
        "create_dictionary,dispose_dictionary",
        JoinSettingsWorkflowCalls(calls),
        "The dictionary page did not own its model."
    )
}

TestSettingsWindowUsesGlobalApplyAction() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsCombinedWorkflowProbe(calls), true)
    try {
        AssertEqual(
            "应用并重新部署",
            window.apply_button.Text,
            "The global apply button used the wrong label."
        )
        AssertTrue(!HasProp(window, "close_button"), "The settings window retained a redundant close button.")
        AssertTrue(window.SelectPage(2), "The settings window rejected the switcher page.")
        window.switcher_dirty := true
        AssertTrue(window.SelectPage(5), "The settings window rejected the dictionary page.")
        AssertTrue(window.apply_button.Visible, "Changing pages hid the global apply button.")
        AssertTrue(window.apply_button.Enabled, "A dirty non-current page did not enable apply.")
        AssertTrue(window.ApplyAllPendingSettings(), "The settings window failed to save all dirty pages.")
        AssertTrue(!window.apply_button.Enabled, "Applying all changes left the global button enabled.")
    } finally {
        window.Dispose()
    }
    AssertEqual(
        "create_style,create_model,save:schema_a:Control+grave,deploy,dispose_style,dispose_model",
        JoinSettingsWorkflowCalls(calls),
        "Save all did not save the dirty page and deploy exactly once."
    )
}

TestSettingsWindowPreservesCanceledClose() {
    local window := RabbitSettingsWindow(0, true, CandidatePreview, (*) => "Cancel")
    try {
        window.appearance_dirty := true
        AssertTrue(window.OnClose(), "The settings window did not handle a canceled close.")
        AssertTrue(!window.disposed, "The settings window closed after the user canceled.")
        window.close_prompt := (*) => "No"
        AssertTrue(window.OnClose(), "The settings window did not handle discarded changes.")
        AssertTrue(window.disposed, "The settings window stayed open after changes were discarded.")
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowSavesAllSettingsOnClose() {
    local calls := []
    local workflow := RabbitSettingsCombinedWorkflowProbe(calls)
    local window := RabbitSettingsWindow(
        workflow,
        true,
        CandidatePreview,
        RabbitSettingsClosePrompt.Bind(calls, "Yes")
    )
    try {
        AssertTrue(window.SelectPage(2), "The settings window rejected the switcher page.")
        AssertTrue(window.SelectPage(3), "The settings window rejected the behavior page.")
        AssertTrue(window.SelectPage(4), "The settings window rejected the application page.")
        window.appearance_dirty := true
        window.switcher_dirty := true
        window.behavior_dirty := true
        window.application_dirty := true
        window.application_changes["code.exe"] := { reset: false, ascii_mode: false }
        AssertTrue(window.OnClose(), "The settings window did not handle a saved close.")
        AssertTrue(window.disposed, "The settings window stayed open after saving all settings.")
    } finally {
        window.Dispose()
    }
    AssertEqual(
        "create_style,create_model,create_behavior,create_application,prompt," .
            "save_style,save:schema_a:Control+grave,save_behavior:1:0," .
            "save_application:code.exe:0,deploy,dispose_style,dispose_model," .
            "dispose_behavior,dispose_application",
        JoinSettingsWorkflowCalls(calls),
        "The settings window did not save every dirty page before one deployment."
    )
}

RabbitSettingsClosePrompt(calls, decision) {
    calls.Push("prompt")
    return decision
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

class RabbitSettingsApplicationWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    CreateApplicationSettingsModel() {
        this.calls.Push("create_application")
        return RabbitSettingsApplicationModelProbe(this.calls)
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return 0
    }
}

class RabbitSettingsCombinedWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    CreateUIStyleSettings() {
        this.calls.Push("create_style")
        return RabbitSettingsAppearanceModelProbe(this.calls)
    }

    CreateSwitcherSettingsModel() {
        this.calls.Push("create_model")
        return RabbitSettingsSwitcherModelProbe(this.calls)
    }

    CreateBehaviorSettingsModel() {
        this.calls.Push("create_behavior")
        return RabbitSettingsBehaviorModelProbe(this.calls)
    }

    CreateApplicationSettingsModel() {
        this.calls.Push("create_application")
        return RabbitSettingsApplicationModelProbe(this.calls)
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return 0
    }
}

class RabbitSettingsDictionaryWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    CreateDictionarySettingsModel() {
        this.calls.Push("create_dictionary")
        return RabbitSettingsDictionaryModelProbe(this.calls)
    }
}

class RabbitSettingsDictionaryModelProbe {
    __New(calls) {
        this.calls := calls
        this.dictionaries := ["rabbit", "luna"]
    }

    Dispose() {
        this.calls.Push("dispose_dictionary")
    }
}

class RabbitSettingsApplicationModelProbe {
    __New(calls) {
        this.calls := calls
        this.rules := Map("cmd.exe", true)
    }

    Save(changes) {
        local change, process_name
        for process_name, change in changes {
            this.calls.Push(
                "save_application:" . process_name . ":" . (change.reset ? "reset" : change.ascii_mode)
            )
        }
        return true
    }

    Load() {
        this.calls.Push("load_application")
        return true
    }

    Dispose() {
        this.calls.Push("dispose_application")
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
