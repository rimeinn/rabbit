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
RunTest("settings window uses page-specific heights", TestSettingsWindowUsesPageSpecificHeights.Bind())
RunTest("settings window rejects invalid page", TestSettingsWindowRejectsInvalidPage.Bind())
RunTest("settings window maintenance actions", TestSettingsWindowMaintenanceActions.Bind())
RunTest("settings window saves appearance settings", TestSettingsWindowSavesAppearanceSettings.Bind())
RunTest("settings window exposes appearance controls", TestSettingsWindowExposesAppearanceControls.Bind())
RunTest("settings window contains appearance preview failures", TestSettingsWindowContainsPreviewFailures.Bind())
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

TestSettingsWindowUsesPageSpecificHeights() {
    local apply_y, divider_height, footer_y, navigation_height, navigation_y
    local window := RabbitSettingsWindow(0, true)
    try {
        AssertEqual(660, window.GetPageWindowHeight(), "The appearance page used the wrong window height.")
        window.apply_button.GetPos(, &apply_y)
        window.navigation.GetPos(, &navigation_y, , &navigation_height)
        window.sidebar_divider.GetPos(, , , &divider_height)
        window.footer_status.GetPos(, &footer_y)
        AssertEqual(490, navigation_height, "The tall layout used the wrong navigation height.")
        AssertEqual(16, apply_y - navigation_y - navigation_height, "The tall navigation used the wrong bottom gap.")
        AssertEqual(594, apply_y, "The tall layout misplaced the global apply button.")
        AssertEqual(598, divider_height, "The tall layout used the wrong sidebar divider height.")
        AssertEqual(612, footer_y, "The tall layout misplaced the footer status.")

        window.SelectPage(2)
        AssertEqual(500, window.GetPageWindowHeight(), "A compact page used the wrong window height.")
        window.apply_button.GetPos(, &apply_y)
        window.navigation.GetPos(, &navigation_y, , &navigation_height)
        window.sidebar_divider.GetPos(, , , &divider_height)
        window.footer_status.GetPos(, &footer_y)
        AssertEqual(330, navigation_height, "The compact layout used the wrong navigation height.")
        AssertEqual(
            16,
            apply_y - navigation_y - navigation_height,
            "The compact navigation used the wrong bottom gap."
        )
        AssertEqual(434, apply_y, "The compact layout misplaced the global apply button.")
        AssertEqual(438, divider_height, "The compact layout used the wrong sidebar divider height.")
        AssertEqual(452, footer_y, "The compact layout misplaced the footer status.")

        window.SelectPage(1)
        AssertEqual(660, window.GetPageWindowHeight(), "Returning to appearance did not restore its height.")
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

TestSettingsWindowExposesAppearanceControls() {
    local calls := []
    local color_details_y, color_list_height, color_list_width
    local font_group_width, height_label_width, layout_group_width, opacity_label_width, tabs_width
    local window := RabbitSettingsWindow(RabbitSettingsAppearanceWorkflowProbe(calls), true)
    try {
        AssertEqual(1, window.appearance_tabs.Value, "The appearance page did not start on the color tab.")
        AssertTrue(
            !HasProp(window, "appearance_preview_img"),
            "The appearance page retained its embedded bitmap preview."
        )
        window.appearance_tabs.GetPos(, , &tabs_width)
        window.appearance_list.GetPos(, , &color_list_width, &color_list_height)
        window.appearance_details.GetPos(, &color_details_y)
        AssertEqual(570, tabs_width, "The appearance tabs did not fill the main content width.")
        AssertTrue(color_list_width >= 500, "The color scheme list did not use the available width.")
        AssertTrue(color_list_height >= 260, "The color scheme list did not fill the color tab.")
        AssertEqual(528, color_details_y, "The color scheme details did not follow the enlarged list.")
        window.appearance_tabs.Choose(2)
        window.OnAppearanceTabChanged()
        AssertTrue(window.appearance_font_group.Visible, "The typography tab did not show font controls.")
        AssertTrue(!window.appearance_list.Visible, "The typography tab left color controls visible.")
        window.appearance_font_group.GetPos(, , &font_group_width)
        window.appearance_layout_group.GetPos(, , &layout_group_width)
        AssertTrue(font_group_width >= 530, "The font group did not fill the appearance tab.")
        AssertTrue(layout_group_width >= 530, "The layout group did not fill the appearance tab.")
        window.appearance_floating_opacity_label.GetPos(, , &opacity_label_width)
        window.appearance_floating_height_label.GetPos(, , &height_label_width)
        AssertTrue(opacity_label_width >= 72, "The floating opacity label remained too narrow.")
        AssertTrue(height_label_width >= 72, "The floating height label remained too narrow.")
        AssertEqual(
            "候选及高亮圆角：",
            window.appearance_round_corner_label.Text,
            "The candidate and highlight corner label is inaccurate."
        )
        AssertTrue(window.appearance_min_width.Enabled, "Stacked layout did not enable its minimum width.")
        AssertTrue(!window.appearance_min_height.Enabled, "Stacked layout enabled vertical text minimum height.")

        window.appearance_layout_type.Choose(2)
        window.OnAppearanceControlsChanged()
        AssertTrue(window.appearance_align_type.Enabled, "Flow layout did not enable alignment.")
        AssertTrue(window.appearance_flow_rows.Enabled, "Flow layout did not enable expanded pages.")
        AssertTrue(!window.appearance_min_width.Enabled, "Flow layout enabled stacked minimum width.")
        AssertTrue(!window.appearance_min_height.Enabled, "Flow layout enabled vertical text minimum height.")
        AssertTrue(
            !window.appearance_vertical_direction.Enabled,
            "Flow layout enabled the vertical text direction setting."
        )

        window.appearance_layout_type.Choose(3)
        window.OnAppearanceControlsChanged()
        AssertTrue(!window.appearance_min_width.Enabled, "Vertical text layout enabled stacked minimum width.")
        AssertTrue(window.appearance_min_height.Enabled, "Vertical text layout did not enable its minimum height.")

        window.appearance_layout_type.Choose(2)
        window.OnAppearanceControlsChanged()

        window.appearance_floating_preedit.Value := true
        window.OnAppearanceControlsChanged()
        AssertTrue(
            window.appearance_floating_opacity.Enabled,
            "Floating preedit did not enable its opacity setting."
        )
        AssertTrue(
            window.appearance_settings.last_values["floating_preedit"],
            "The appearance page did not stage floating preedit."
        )
        AssertEqual(
            "flow",
            window.appearance_settings.last_values["layout_type"],
            "The appearance page staged the wrong layout type."
        )
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowContainsPreviewFailures() {
    local calls := []
    local window := RabbitSettingsWindow(
        RabbitSettingsAppearanceWorkflowProbe(calls),
        false,
        RabbitSettingsFailingAppearancePreview
    )
    try {
        AssertTrue(
            InStr(window.appearance_status.Value, "无法显示预览：") = 1,
            "The settings window did not report the initial preview failure."
        )
        window.appearance_target.Choose(2)
        window.OnAppearanceTargetChange()
        AssertTrue(
            InStr(window.appearance_status.Value, "无法显示预览：") = 1,
            "The settings window let an event-driven preview failure escape."
        )
    } finally {
        window.Dispose()
    }
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
    local window := RabbitSettingsWindow(0, true, RabbitAppearancePreview, (*) => "Cancel")
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
        RabbitAppearancePreview,
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
        this.last_values := Map()
    }

    GetActiveColorScheme() {
        return "theme_a"
    }

    GetPresetColorSchemes() {
        return [
            { color_scheme_id: "theme_a", name: "主题 A", author: "甲", style: RabbitUIStyleSnapshot() },
            { color_scheme_id: "theme_b", name: "主题 B", author: "乙", style: RabbitUIStyleSnapshot() },
        ]
    }

    SelectColorScheme(color_scheme_id) {
        this.calls.Push("select:" . color_scheme_id)
        return true
    }

    SetStyleValues(values) {
        this.last_values := values
    }

    Save() {
        this.calls.Push("save_style")
        return true
    }

    Dispose() {
        this.calls.Push("dispose_style")
    }
}

class RabbitSettingsFailingAppearancePreview {
    __New(ctrl) {
    }

    Render(style) {
        throw Error("preview probe failure")
    }

    Hide() {
    }

    Dispose() {
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
