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
RunTest("appearance color layout grows with the page", TestAppearanceColorLayoutGrowsWithPage.Bind())
RunTest("settings window creates inactive pages on first use", TestSettingsWindowCreatesPagesLazily.Bind())
RunTest("settings window rejects invalid page", TestSettingsWindowRejectsInvalidPage.Bind())
RunTest("settings window maintenance actions", TestSettingsWindowMaintenanceActions.Bind())
RunTest("settings window saves appearance settings", TestSettingsWindowSavesAppearanceSettings.Bind())
RunTest("settings window exposes appearance controls", TestSettingsWindowExposesAppearanceControls.Bind())
RunTest("settings window loads font choices on first drop-down", TestSettingsWindowLoadsFontChoicesLazily.Bind())
RunTest("settings window opens one advanced font editor", TestSettingsWindowOpensAdvancedFontEditor.Bind())
RunTest("settings window browses color schemes without changing selection", TestSettingsWindowBrowsesColorSchemes.Bind())
RunTest("settings window previews the browsed color scheme", TestSettingsWindowPreviewsBrowsedColorScheme.Bind())
RunTest("settings window stages custom color schemes", TestSettingsWindowStagesCustomColorSchemes.Bind())
RunTest("color scheme dialog previews pending typesetting", TestColorSchemeDialogPreviewsPendingTypesetting.Bind())
RunTest("settings window restores dark scheme following", TestSettingsWindowRestoresDarkSchemeFollowing.Bind())
RunTest("settings window contains appearance preview failures", TestSettingsWindowContainsPreviewFailures.Bind())
RunTest("settings window defers its initial appearance preview", TestSettingsWindowDefersInitialPreview.Bind())
RunTest("settings window previews pending candidate labels", TestSettingsWindowPreviewsPendingLabels.Bind())
RunTest("settings window saves switcher settings", TestSettingsWindowSavesSwitcherSettings.Bind())
RunTest("settings window reorders selected schemas", TestSettingsWindowReordersSelectedSchemas.Bind())
RunTest("dark switcher uses themed option headers", TestDarkSwitcherUsesThemedOptionHeaders.Bind())
RunTest("settings window saves behavior settings", TestSettingsWindowSavesBehaviorSettings.Bind())
RunTest("settings window exposes default behavior controls", TestSettingsWindowDefaultBehaviorControls.Bind())
RunTest("key binding dialog preserves unknown fields", TestKeyBindingDialogPreservesUnknownFields.Bind())
RunTest("settings window saves application settings", TestSettingsWindowSavesApplicationSettings.Bind())
RunTest("settings window embeds dictionary management", TestSettingsWindowEmbedsDictionaryManagement.Bind())
RunTest("settings window uses a global apply action", TestSettingsWindowUsesGlobalApplyAction.Bind())
RunTest("settings window preserves canceled close", TestSettingsWindowPreservesCanceledClose.Bind())
RunTest("settings window saves all settings on close", TestSettingsWindowSavesAllSettingsOnClose.Bind())
RunTest("settings window completes first install in place", TestSettingsWindowCompletesFirstInstallInPlace.Bind())
RunTest("settings window keeps failed first install locked", TestSettingsWindowKeepsFailedFirstInstallLocked.Bind())

TestSettingsWindowNavigation() {
    local window := RabbitSettingsWindow()
    try {
        AssertEqual(1, RabbitSettingsWindow.PageIndex(), "The default page ID did not resolve to the first page.")
        AssertEqual(2, RabbitSettingsWindow.PageIndex("input-schemes"), "A stable page ID resolved incorrectly.")
        AssertEqual(0, RabbitSettingsWindow.PageIndex("missing"), "An unknown page ID resolved to a page.")
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
        AssertEqual(724, window.GetPageWindowHeight(), "The appearance page used the wrong window height.")
        window.apply_button.GetPos(, &apply_y)
        window.navigation.GetPos(, &navigation_y, , &navigation_height)
        window.sidebar_divider.GetPos(, , , &divider_height)
        window.footer_status.GetPos(, &footer_y)
        AssertEqual(554, navigation_height, "The tall layout used the wrong navigation height.")
        AssertEqual(16, apply_y - navigation_y - navigation_height, "The tall navigation used the wrong bottom gap.")
        AssertEqual(658, apply_y, "The tall layout misplaced the global apply button.")
        AssertEqual(662, divider_height, "The tall layout used the wrong sidebar divider height.")
        AssertEqual(676, footer_y, "The tall layout misplaced the footer status.")

        window.SelectPage(2)
        AssertEqual(660, window.GetPageWindowHeight(), "The switcher page used the wrong window height.")
        AssertTrue(window.switcher_tabs.Visible, "The switcher page did not show its tabs.")
        AssertEqual(1, window.switcher_tabs.Value, "The switcher page did not select the schema tab.")

        window.SelectPage(4)
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

        window.SelectPage(3)
        AssertEqual(660, window.GetPageWindowHeight(), "The behavior page used the wrong window height.")
        AssertTrue(window.behavior_tabs.Visible, "The behavior page did not show its tabs.")
        AssertEqual(1, window.behavior_tabs.Value, "The behavior page did not select the general tab.")

        window.SelectPage(1)
        AssertEqual(724, window.GetPageWindowHeight(), "Returning to appearance did not restore its height.")
    } finally {
        window.Dispose()
    }
}

TestAppearanceColorLayoutGrowsWithPage() {
    local compact := RabbitSettingsWindow.CalculateAppearanceLayout(false, 660)
    local expanded := RabbitSettingsWindow.CalculateAppearanceLayout(false, 724)
    local dark := RabbitSettingsWindow.CalculateAppearanceLayout(true, 724)
    AssertEqual(64, expanded.tabs_height - compact.tabs_height,
        "The appearance tabs did not grow with the page.")
    AssertEqual(64, expanded.color_list_height - compact.color_list_height,
        "The color list did not absorb the additional page height.")
    AssertEqual(12, expanded.color_actions_y - expanded.color_list_y - expanded.color_list_height,
        "The color list did not preserve its gap above the action row.")
    AssertEqual(42, expanded.color_details_y - expanded.color_actions_y,
        "The color details did not remain below the action row.")
    AssertEqual(24, expanded.color_list_height - dark.color_list_height,
        "The dark list header offset changed the color list bottom edge.")
}

TestSettingsWindowCreatesPagesLazily() {
    local window := RabbitSettingsWindow(0, true)
    try {
        AssertEqual(1, window.page_controls_created.Count,
            "The settings window eagerly created inactive pages.")
        AssertTrue(!HasProp(window, "switcher_group"),
            "The settings window created switcher controls before first use.")
        AssertTrue(!HasProp(window, "behavior_tabs"),
            "The settings window created behavior controls before first use.")
        AssertTrue(window.SelectPage(7), "The settings window rejected its lazy about page.")
        AssertTrue(HasProp(window, "about_group"),
            "Opening the about page did not create its controls.")
        AssertEqual(2, window.page_controls_created.Count,
            "Opening one page created unrelated page controls.")
        AssertTrue(!HasProp(window, "behavior_tabs"),
            "Opening the about page also created behavior controls.")
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
        AssertEqual(2, window.appearance_page.presets.Length, "The appearance page showed the wrong preset count.")
        AssertEqual(1, window.appearance_list.GetNext(0), "The appearance page did not select the active preset.")
        window.appearance_list.Modify(2, "Select Focus")
        window.OnAppearanceSelectionChange()
        window.appearance_page.UseSelectedColorScheme()
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
    local color_actions_y, color_details_y, color_list_height, color_list_width, color_list_y
    local color_layout
    local font_group_width, height_label_width, layout_group_width, opacity_label_width, tabs_width
    local window := RabbitSettingsWindow(RabbitSettingsAppearanceWorkflowProbe(calls), true)
    try {
        color_layout := RabbitSettingsWindow.CalculateAppearanceLayout(window.initial_dark_mode)
        AssertEqual(1, window.appearance_tabs.Value, "The appearance page did not start on the color tab.")
        AssertTrue(!window.appearance_typesetting_created,
            "The appearance page eagerly created its inactive typesetting controls.")
        AssertTrue(!HasProp(window, "appearance_font"),
            "The inactive typesetting tab exposed controls before first use.")
        AssertTrue(
            !HasProp(window, "appearance_preview_img"),
            "The appearance page retained its embedded bitmap preview."
        )
        window.appearance_tabs.GetPos(, , &tabs_width)
        window.appearance_list.GetPos(, &color_list_y, &color_list_width, &color_list_height)
        window.appearance_add.GetPos(, &color_actions_y)
        window.appearance_details.GetPos(, &color_details_y)
        AssertEqual(570, tabs_width, "The appearance tabs did not fill the main content width.")
        AssertTrue(color_list_width >= 500, "The color scheme list did not use the available width.")
        AssertEqual(color_layout.color_list_height, color_list_height,
            "The color scheme list did not absorb the taller page.")
        AssertEqual(12, color_actions_y - color_list_y - color_list_height,
            "The color scheme list did not stop before the action row.")
        AssertEqual(42, color_details_y - color_actions_y,
            "The color scheme details did not follow the action row.")
        window.appearance_tabs.Choose(2)
        window.OnAppearanceTabChanged()
        AssertTrue(window.appearance_typesetting_created,
            "The typesetting controls were not created when their tab was opened.")
        AssertTrue(window.appearance_font_group.Visible, "The typography tab did not show font controls.")
        AssertTrue(!window.appearance_list.Visible, "The typography tab left color controls visible.")
        AssertEqual(0, GetComboBoxItemCount(window.appearance_font),
            "The typography tab eagerly populated the candidate font list.")
        AssertEqual(0, GetComboBoxItemCount(window.appearance_preedit_font),
            "The typography tab eagerly populated the preedit font list.")
        AssertEqual(0, GetComboBoxItemCount(window.appearance_label_font),
            "The typography tab eagerly populated the label font list.")
        AssertEqual(0, GetComboBoxItemCount(window.appearance_comment_font),
            "The typography tab eagerly populated the comment font list.")
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
        AssertEqual("窗口水平边距：", window.appearance_margin_x_label.Text,
            "The horizontal margin label is unclear.")
        AssertEqual("窗口垂直边距：", window.appearance_margin_y_label.Text,
            "The vertical margin label is unclear.")
        AssertEqual("候选水平内边距：", window.appearance_candidate_padding_x_label.Text,
            "The horizontal candidate padding control is missing.")
        AssertEqual("候选垂直内边距：", window.appearance_candidate_padding_y_label.Text,
            "The vertical candidate padding control is missing.")
        AssertEqual("候选间距：", window.appearance_candidate_spacing_label.Text,
            "The candidate spacing control is missing.")
        AssertTrue(window.appearance_align_type.Enabled, "Stacked layout did not enable alignment.")
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
        AssertTrue(!window.appearance_align_type.Enabled, "Vertical text layout enabled alignment.")
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
            window.appearance_page.settings.last_values["floating_preedit"],
            "The appearance page did not stage floating preedit."
        )
        AssertEqual(
            "flow",
            window.appearance_page.settings.last_values["layout_type"],
            "The appearance page staged the wrong layout type."
        )
        AssertEqual(
            6,
            window.appearance_page.settings.last_values["candidate_spacing"],
            "The appearance page did not stage candidate spacing."
        )
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowBrowsesColorSchemes() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsAppearanceWorkflowProbe(calls), true)
    try {
        window.appearance_list.Modify(2, "Select Focus")
        window.OnAppearanceSelectionChange()
        AssertTrue(!window.appearance_page.dirty, "Browsing a scheme changed the pending settings.")
        AssertTrue(window.appearance_page.UseSelectedColorScheme(), "The selected scheme could not be activated.")
        AssertTrue(window.appearance_page.dirty, "Activating a scheme did not mark the page dirty.")
        AssertEqual("theme_b", window.appearance_page.light_scheme, "The wrong light scheme was staged.")
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowStagesCustomColorSchemes() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsAppearanceWorkflowProbe(calls), true)
    try {
        RabbitSettingsColorSchemeDialogProbe.last_color_scheme := 0
        window.appearance_page.dialog_factory := RabbitSettingsColorSchemeDialogProbe
        AssertTrue(window.appearance_page.AddColorScheme(), "The appearance page rejected a new scheme.")
        AssertEqual(
            window.appearance_page.style.font_face,
            RabbitSettingsColorSchemeDialogProbe.last_color_scheme.style.font_face,
            "The new scheme preview did not inherit the active font."
        )
        AssertEqual(
            window.appearance_page.style.min_width,
            RabbitSettingsColorSchemeDialogProbe.last_color_scheme.style.min_width,
            "The new scheme preview did not inherit the active candidate width."
        )
        AssertEqual(3, window.appearance_page.presets.Length, "The new scheme was not added to the catalog.")
        AssertTrue(
            InStr(JoinSettingsWorkflowCalls(calls), "upsert:custom"),
            "The new scheme was not staged at the settings model."
        )
        AssertTrue(window.appearance_page.dirty, "Adding a scheme did not mark the page dirty.")
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowRestoresDarkSchemeFollowing() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsAppearanceWorkflowProbe(calls), true)
    try {
        window.appearance_target.Choose(2)
        window.OnAppearanceTargetChange()
        AssertTrue(window.appearance_follow_light.Value, "Dark mode did not start by following the light scheme.")
        window.appearance_list.Modify(2, "Select Focus")
        AssertTrue(window.appearance_page.UseSelectedColorScheme(), "A dark scheme could not be staged.")
        AssertEqual("theme_b", window.appearance_page.dark_scheme, "The wrong dark scheme was staged.")
        window.appearance_follow_light.Value := true
        window.appearance_page.OnFollowLightChange()
        AssertEqual("", window.appearance_page.dark_scheme, "Dark mode did not return to following light mode.")
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
            InStr(window.appearance_status.Value, "无法显示预览：") != 1,
            "The settings window rendered its preview before it was shown."
        )
        AssertTrue(!window.PreviewAppearance(), "The appearance page ignored a preview failure.")
        AssertTrue(
            InStr(window.appearance_status.Value, "无法显示预览：") = 1,
            "The settings window did not report a requested preview failure."
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

TestSettingsWindowLoadsFontChoicesLazily() {
    static CB_GETDROPPEDSTATE := 0x0157
    static LB_GETCOUNT := 0x018B
    local expected_font, item_count, list_height, list_hwnd
    local window := RabbitSettingsWindow(RabbitSettingsAppearanceWorkflowProbe([]), true)
    try {
        window.appearance_tabs.Choose(2)
        window.OnAppearanceTabChanged()
        Gui.Prototype.Show.Call(window, "NA x-32000 y-32000")
        expected_font := window.appearance_page.style.font_face
        AssertEqual(
            expected_font,
            window.appearance_font.Text,
            "The unloaded font list did not preserve the configured font text."
        )
        ControlShowDropDown(window.appearance_font)
        item_count := GetComboBoxItemCount(window.appearance_font)
        AssertTrue(item_count > 0, "The first drop-down did not populate the candidate font list.")
        AssertEqual(1, SendMessage(CB_GETDROPPEDSTATE, 0, 0, window.appearance_font.Hwnd),
            "The candidate font list did not remain expanded after lazy loading.")
        list_hwnd := RabbitWindowThemeNative.GetComboBoxListHwnd(window.appearance_font.Hwnd)
        AssertTrue(list_hwnd, "The expanded font combo box did not expose its list window.")
        AssertEqual(item_count, SendMessage(LB_GETCOUNT, 0, 0, list_hwnd),
            "The visible font list did not receive the combo box items.")
        WinGetPos(, , , &list_height, "ahk_id " . list_hwnd)
        AssertTrue(list_height > 30,
            Format("The populated font list remained too short to show items: {} px.", list_height))
        AssertEqual(
            expected_font,
            window.appearance_font.Text,
            "Populating the candidate font list changed the configured font text."
        )
        AssertTrue(
            window.appearance_page.loaded_font_controls.Has(window.appearance_font.Hwnd),
            "The populated font list was not marked as loaded."
        )
        AssertEqual(0, GetComboBoxItemCount(window.appearance_preedit_font),
            "Opening one font list populated another font control.")
        ControlHideDropDown(window.appearance_font)
        ControlShowDropDown(window.appearance_font)
        AssertEqual(
            item_count,
            GetComboBoxItemCount(window.appearance_font),
            "Opening an already loaded font list populated it again."
        )
    } finally {
        window.Dispose()
    }
}

GetComboBoxItemCount(ctrl) {
    static CB_GETCOUNT := 0x0146
    return SendMessage(CB_GETCOUNT, 0, 0, ctrl.Hwnd)
}

TestSettingsWindowOpensAdvancedFontEditor() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsAppearanceWorkflowProbe(calls), true)
    try {
        window.appearance_tabs.Choose(2)
        window.OnAppearanceTabChanged()
        AssertEqual(
            "高级字体设置…",
            window.appearance_advanced_font.Text,
            "The typography page used the wrong advanced font action."
        )
        RabbitSettingsAdvancedFontDialogProbe.last_values := 0
        window.appearance_page.font_dialog_factory := RabbitSettingsAdvancedFontDialogProbe
        AssertTrue(window.OpenAdvancedFontSettings(), "The appearance page rejected advanced font edits.")
        AssertEqual(
            "Segoe UI Emoji:1f300:1faff, Microsoft YaHei UI",
            window.appearance_font.Text,
            "The advanced font result did not update the candidate font control."
        )
        AssertEqual(
            "Microsoft YaHei UI",
            RabbitSettingsAdvancedFontDialogProbe.last_values["comment_font_face"],
            "The font editor did not receive all four current font settings."
        )
        AssertEqual(
            "Segoe UI Emoji:1f300:1faff, Microsoft YaHei UI",
            window.appearance_page.settings.last_values["font_face"],
            "The advanced font result was not staged for saving."
        )
    } finally {
        window.Dispose()
    }
}

TestColorSchemeDialogPreviewsPendingTypesetting() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsAppearanceWorkflowProbe(calls), true)
    try {
        window.appearance_tabs.Choose(2)
        window.OnAppearanceTabChanged()
        window.appearance_floating_preedit.Value := true
        window.OnAppearanceControlsChanged()
        RabbitSettingsCancelingColorSchemeDialogProbe.last_preview_style_overrides := 0
        window.appearance_page.dialog_factory := RabbitSettingsCancelingColorSchemeDialogProbe
        AssertTrue(!window.appearance_page.EditColorScheme(), "The canceling color scheme dialog returned a result.")
        AssertTrue(
            RabbitSettingsCancelingColorSchemeDialogProbe.last_preview_style_overrides["floating_preedit"],
            "The color scheme dialog did not receive the pending floating preedit mode."
        )
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowPreviewsBrowsedColorScheme() {
    local calls := []
    local window := RabbitSettingsWindow(
        RabbitSettingsAppearanceWorkflowProbe(calls),
        false,
        RabbitSettingsCapturingAppearancePreview
    )
    try {
        AssertTrue(!window.appearance_typesetting_created,
            "The regression test unexpectedly created the typesetting controls.")
        window.appearance_list.Modify(2, "Select Focus")
        window.OnAppearanceSelectionChange()
        AssertEqual(
            0xff202020,
            RabbitSettingsCapturingAppearancePreview.last_style.back_color,
            "Browsing a color scheme kept the startup preview colors."
        )
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowDefersInitialPreview() {
    local calls := []
    local window := RabbitSettingsWindow(
        RabbitSettingsCombinedWorkflowProbe(calls),
        false,
        RabbitSettingsCapturingAppearancePreview
    )
    try {
        AssertEqual(0, RabbitSettingsCapturingAppearancePreview.render_count,
            "The settings window rendered its preview during construction.")
        AssertEqual("create_style", JoinSettingsWorkflowCalls(calls),
            "Constructing the appearance page loaded unrelated settings.")
        local labels := window.GetAppearancePreviewLabels()
        AssertEqual("①", labels[1], "The lightweight preview label reader returned the wrong label.")
        window.GetAppearancePreviewLabels()
        AssertEqual("create_style,read_labels", JoinSettingsWorkflowCalls(calls),
            "The preview labels were not cached independently of the behavior model.")
        AssertTrue(!window.behavior_model, "Reading preview labels initialized the behavior model.")
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowPreviewsPendingLabels() {
    local calls := []
    local window := RabbitSettingsWindow(
        RabbitSettingsCombinedWorkflowProbe(calls),
        false,
        RabbitSettingsCapturingAppearancePreview
    )
    try {
        window.SelectPage(3)
        window.SelectPage(1)
        window.menu_labels.Value := "壹, 贰, 叁, 肆, 伍"
        AssertTrue(window.PreviewAppearance(), "The appearance page failed to refresh its preview.")
        AssertEqual(
            "壹",
            RabbitSettingsCapturingAppearancePreview.last_labels[1],
            "The appearance preview ignored a pending candidate label."
        )
        AssertEqual(
            "伍",
            RabbitSettingsCapturingAppearancePreview.last_labels[5],
            "The appearance preview used the wrong pending candidate label."
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
        window.switcher_tabs.Choose(2)
        window.OnSwitcherTabChanged()
        AssertTrue(window.switcher_caption.Visible, "The switcher menu tab did not show its caption field.")
        AssertEqual(1, window.switcher_save_list.GetCount(), "The switcher menu tab lost discovered options.")
        AssertTrue(window.switcher_prefix.Enabled, "Folded option formatting was unexpectedly disabled.")
        window.switcher_fold_options.Value := false
        window.OnSwitcherFoldChanged()
        AssertTrue(!window.switcher_prefix.Enabled, "Disabling folding left folded formatting enabled.")
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

TestSettingsWindowReordersSelectedSchemas() {
    local calls := []
    local schema_ids
    local window := RabbitSettingsWindow(RabbitSettingsSwitcherWorkflowProbe(calls))
    try {
        AssertTrue(window.SelectPage(2), "The settings window rejected the switcher page.")
        window.switcher_list.Modify(2, "Check Select Focus")
        window.UpdateSwitcherMoveButtons(2, 1)
        AssertTrue(window.switcher_move_up.Enabled, "The second selected schema could not move up.")
        AssertTrue(window.MoveSwitcherSchema(-1), "The selected schema failed to move up.")
        schema_ids := window.SelectedSchemaIds()
        AssertEqual("schema_b", schema_ids[1], "Moving up did not update the first schema.")
        AssertEqual("schema_a", schema_ids[2], "Moving up did not update the second schema.")
        AssertTrue(!window.switcher_move_up.Enabled, "The first selected schema could still move up.")
        AssertTrue(window.switcher_move_down.Enabled, "The first selected schema could not move down.")
    } finally {
        window.Dispose()
    }
}

TestDarkSwitcherUsesThemedOptionHeaders() {
    local calls := []
    local list_y, name_y
    local window := RabbitSettingsWindow(
        RabbitSettingsSwitcherWorkflowProbe(calls),
        true,
        RabbitAppearancePreview,
        0,
        "input-schemes",
        false,
        RabbitSettingsDarkThemeProbe
    )
    try {
        window.switcher_tabs.Choose(2)
        window.OnSwitcherTabChanged()
        AssertTrue(window.switcher_option_name_header.Visible, "The dark option-name header stayed hidden.")
        AssertTrue(window.switcher_option_source_header.Visible, "The dark option-source header stayed hidden.")
        window.switcher_option_name_header.GetPos(, &name_y)
        window.switcher_save_list.GetPos(, &list_y)
        AssertEqual(24, list_y - name_y, "The dark option list did not start below its themed header.")
    } finally {
        window.Dispose()
    }
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
        window.appearance_page.dirty := true
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
        window.appearance_page.dirty := true
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

TestSettingsWindowCompletesFirstInstallInPlace() {
    local calls := []
    local window := RabbitSettingsWindow(
        RabbitSettingsInstallWorkflowProbe(calls),
        true,
        RabbitAppearancePreview,
        0,
        "input-schemes",
        true
    )
    try {
        AssertEqual(2, window.selected_page, "Install mode did not open the input-schemes page directly.")
        AssertEqual("create_model", JoinSettingsWorkflowCalls(calls), "Install mode eagerly loaded another page.")
        AssertTrue(!window.navigation.Enabled, "Install mode left other settings pages enabled.")
        AssertTrue(window.apply_button.Enabled, "Install mode disabled its mandatory deployment action.")
        AssertEqual("完成安装并部署", window.apply_button.Text, "Install mode used the regular apply label.")
        AssertTrue(!window.SelectPage(1), "Install mode allowed navigation before deployment.")

        AssertTrue(window.ApplyAllPendingSettings(), "Install mode failed to deploy without pending edits.")
        AssertTrue(!window.installing, "A successful deployment left the window in install mode.")
        AssertTrue(window.navigation.Enabled, "A successful deployment did not unlock settings navigation.")
        AssertEqual("应用并重新部署", window.apply_button.Text, "The unlocked window kept the install action label.")
        AssertTrue(window.SelectPage(7), "The unlocked window could not open another settings page.")
        AssertEqual(
            "create_model,save:schema_a:Control+grave,dispose_model,deploy,create_model",
            JoinSettingsWorkflowCalls(calls),
            "Install mode did not dispose, deploy, and recreate its model in order."
        )
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowKeepsFailedFirstInstallLocked() {
    local calls := []
    local window := RabbitSettingsWindow(
        RabbitSettingsInstallWorkflowProbe(calls, 1),
        true,
        RabbitAppearancePreview,
        0,
        "input-schemes",
        true
    )
    try {
        AssertTrue(!window.CompleteInstallation(), "Install mode reported a failed deployment as successful.")
        AssertTrue(window.installing, "A failed deployment unlocked the settings window.")
        AssertTrue(!window.navigation.Enabled, "A failed deployment enabled settings navigation.")
        AssertTrue(window.OnClose(), "Install mode did not handle an early close request.")
        AssertTrue(!window.disposed, "Install mode closed before its mandatory deployment completed.")
    } finally {
        window.Dispose()
    }
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

    ReadCandidateLabels() {
        this.calls.Push("read_labels")
        return ["①", "②", "③", "④", "⑤"]
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

class RabbitSettingsInstallWorkflowProbe {
    __New(calls, deploy_result := 0) {
        this.calls := calls
        this.deploy_result := deploy_result
    }

    CreateSwitcherSettingsModel() {
        this.calls.Push("create_model")
        return RabbitSettingsSwitcherModelProbe(this.calls)
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return this.deploy_result
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
        this.suspend_hotkey := ""
        this.send_by_clipboard_length := 8
        this.global_ascii := false
        this.fix_candidate_box := false
        this.use_legacy_candidate_box := false
        this.bypass_password_fields := true
        this.switch_key := Map(
            "Shift_L", "inline_ascii",
            "Shift_R", "commit_text",
            "Control_L", "noop",
            "Control_R", "noop",
            "Caps_Lock", "clear",
            "Eisu_toggle", "clear"
        )
        this.page_size := 5
        this.alternative_select_labels := []
        this.bindings := [Map("accept", "Control+p", "send", "Up", "when", "composing")]
    }

    GetBindings() {
        return RabbitBehaviorSettingsModel.CloneValue(this.bindings)
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

    GetCurrentStyle() {
        return RabbitUIStyleSnapshot(0, Map(
            "font_face", "Current Preview Font",
            "font_point", 23,
            "min_width", 420,
            "back_color", 0xff101010
        ))
    }

    GetPresetColorSchemes() {
        return [
            RabbitColorScheme(
                "theme_a",
                Map("name", "主题 A", "author", "甲", "color_format", "argb", "back_color", "0xff101010"),
                "builtin"
            ),
            RabbitColorScheme(
                "theme_b",
                Map("name", "主题 B", "author", "乙", "color_format", "argb", "back_color", "0xff202020"),
                "builtin"
            ),
        ]
    }

    SelectColorScheme(color_scheme_id) {
        this.calls.Push("select:" . color_scheme_id)
        return true
    }

    SetStyleValues(values) {
        this.last_values := values
    }

    UpsertColorScheme(color_scheme) {
        this.calls.Push("upsert:" . color_scheme.color_scheme_id)
    }

    DeleteColorScheme(color_scheme_id) {
        this.calls.Push("delete:" . color_scheme_id)
    }

    Save() {
        this.calls.Push("save_style")
        return true
    }

    Dispose() {
        this.calls.Push("dispose_style")
    }
}

class RabbitSettingsColorSchemeDialogProbe {
    static last_color_scheme := 0

    __New(owner, color_scheme, mode, preview, labels, preview_style_overrides, id_validator, dark_mode_reader) {
        RabbitSettingsColorSchemeDialogProbe.last_color_scheme := color_scheme
        this.result := color_scheme
    }

    ShowModal() {
        return this.result
    }

    Dispose() {
    }
}

class RabbitSettingsCancelingColorSchemeDialogProbe {
    static last_preview_style_overrides := 0

    __New(owner, color_scheme, mode, preview, labels, preview_style_overrides, id_validator, dark_mode_reader) {
        RabbitSettingsCancelingColorSchemeDialogProbe.last_preview_style_overrides := preview_style_overrides
    }

    ShowModal() {
        return 0
    }

    Dispose() {
    }
}

class RabbitSettingsAdvancedFontDialogProbe {
    static last_values := 0

    __New(owner, values, installed_fonts, dark_mode_reader) {
        RabbitSettingsAdvancedFontDialogProbe.last_values := values
        this.result := values.Clone()
        this.result["font_face"] := "Segoe UI Emoji:1f300:1faff, Microsoft YaHei UI"
    }

    ShowModal() {
        return this.result
    }

    Dispose() {
    }
}

TestSettingsWindowDefaultBehaviorControls() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsBehaviorWorkflowProbe(calls))
    try {
        AssertTrue(window.SelectPage(3), "The settings window rejected the behavior page.")
        AssertEqual(5, window.menu_page_size.Value, "The behavior page showed the wrong page size.")
        AssertEqual(1, window.binding_list.GetCount(), "The behavior page showed the wrong binding count.")
        AssertEqual("5", RabbitSettingsEditCue(window.menu_page_size), "The page-size placeholder was wrong.")
        AssertEqual(
            "例如：Control+Shift+F12",
            RabbitSettingsEditCue(window.suspend_hotkey),
            "The suspend-hotkey placeholder was wrong."
        )
        AssertEqual(
            "1, 2, 3, 4, 5, 6, 7, 8, 9, 10",
            RabbitSettingsEditCue(window.menu_labels),
            "The candidate-label placeholder was wrong."
        )
        window.behavior_tabs.Choose(2)
        window.OnBehaviorTabChanged()
        AssertTrue(window.binding_list.Visible, "The key-binding tab did not show the binding list.")
        AssertTrue(!window.menu_page_size.Visible, "The key-binding tab left general controls visible.")
        window.behavior_tabs.Choose(1)
        window.OnBehaviorTabChanged()
        window.menu_page_size.Value := 7
        window.menu_labels.Value := "①, ②"
        window.suspend_hotkey.Value := "Control+Shift+F12"
        window.clipboard_mode.Choose(2)
        window.OnClipboardModeChanged()
        local values := window.GetBehaviorValues()
        AssertEqual(7, values.page_size, "The behavior page returned the wrong page size.")
        AssertEqual(
            2,
            values.alternative_select_labels.Length,
            "The behavior page parsed candidate labels incorrectly."
        )
        AssertEqual("inline_ascii", values.switch_key["Shift_L"], "The behavior page returned the wrong switch action.")
        AssertEqual(
            "Control+Shift+F12",
            values.suspend_hotkey,
            "The behavior page returned the wrong suspend hotkey."
        )
        AssertEqual(0, values.send_by_clipboard_length, "The always-use clipboard mode was encoded incorrectly.")
        AssertTrue(!window.clipboard_length.Enabled, "The always-use mode left the threshold enabled.")
        window.menu_page_size.Value := ""
        window.menu_labels.Value := ""
        values := window.GetBehaviorValues()
        AssertEqual(5, values.page_size, "An empty page size did not use its placeholder value.")
        AssertEqual(0, values.alternative_select_labels.Length, "An empty label field created custom labels.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsEditCue(ctrl) {
    static EM_GETCUEBANNER := 0x1502
    local buf := Buffer(256, 0)
    DllCall(
        "User32\SendMessageW",
        "Ptr",
        ctrl.Hwnd,
        "UInt",
        EM_GETCUEBANNER,
        "Ptr",
        buf.Ptr,
        "Ptr",
        buf.Size / 2,
        "Ptr"
    )
    return StrGet(buf, "UTF-16")
}

TestKeyBindingDialogPreservesUnknownFields() {
    local owner := Gui()
    local dialog := RabbitKeyBindingDialog(
        owner,
        Map("accept", "Control+p", "send", "Up", "when", "composing", "custom_field", "kept")
    )
    try {
        AssertEqual("send", dialog.action_key.Text, "The binding dialog selected the wrong action field.")
        dialog.action_value.Value := "Down"
        AssertTrue(dialog.SaveBinding(), "The binding dialog rejected a valid rule.")
        AssertEqual("Down", dialog.result["send"], "The binding dialog did not update the action value.")
        AssertEqual("kept", dialog.result["custom_field"], "The binding dialog dropped an unknown field.")
    } finally {
        try dialog.Dispose()
        owner.Destroy()
    }
}

class RabbitSettingsFailingAppearancePreview {
    __New(ctrl) {
    }

    Render(style, select_labels := 0) {
        throw Error("preview probe failure")
    }

    Hide() {
    }

    Dispose() {
    }
}

class RabbitSettingsCapturingAppearancePreview {
    static last_labels := []
    static last_style := 0
    static render_count := 0

    __New(ctrl) {
        RabbitSettingsCapturingAppearancePreview.last_labels := []
        RabbitSettingsCapturingAppearancePreview.last_style := 0
        RabbitSettingsCapturingAppearancePreview.render_count := 0
    }

    Render(style, select_labels := 0) {
        RabbitSettingsCapturingAppearancePreview.render_count += 1
        RabbitSettingsCapturingAppearancePreview.last_style := style
        RabbitSettingsCapturingAppearancePreview.last_labels := select_labels is Array
            ? select_labels.Clone()
            : []
        return true
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
        this.caption := "〔方案选单〕"
        this.save_options := ["full_shape"]
        this.fold_options := true
        this.abbreviate_options := true
        this.option_list_prefix := ""
        this.option_list_suffix := ""
        this.option_list_separator := "／"
        this.fix_schema_list_order := false
        this.items := [
            { id: "schema_a", name: "方案 A", author: "", description: "A", selected: true },
            { id: "schema_b", name: "方案 B", author: "", description: "B", selected: false },
        ]
    }

    GetOptionItems(schema_ids) {
        return [{
            name: "full_shape",
            source: "方案 A",
            custom: false,
            selected: true,
        }]
    }

    Save(values) {
        this.calls.Push("save:" . values.schema_ids[1] . ":" . values.hotkeys)
        return true
    }

    Dispose() {
        this.calls.Push("dispose_model")
    }
}

class RabbitSettingsDarkThemeProbe {
    static Prepare() {
        return true
    }

    __New(window) {
        this.dark_mode_reader := (*) => true
    }

    RegisterMuted(controls*) {
    }

    RegisterSurface(controls*) {
    }

    Register() {
    }

    Apply() {
    }

    Dispose() {
    }
}
