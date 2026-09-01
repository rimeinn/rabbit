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

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\..\Lib\RabbitCommon.ahk
#Include ..\..\Lib\RabbitDeployerWorkflow.ahk
#Include ..\..\Lib\RabbitSettingsWindow.ahk
#Include ..\support\TestCommon.ahk

RunTest("settings window preview", RunSettingsWindowPreview.Bind())
ExitApp()

RunSettingsWindowPreview() {
    local repository_root := A_ScriptDir . "\..\.."
    local rime := RimeApi(repository_root . "\Lib\librime-ahk\rime.dll")
    local traits := RabbitCreateTraits()
    local window := 0
    traits.shared_data_dir := repository_root . "\Data"
    traits.user_data_dir := repository_root . "\Rime"
    traits.prebuilt_data_dir := traits.shared_data_dir
    rime.setup(traits)
    rime.deployer_initialize(0)

    try {
        window := RabbitSettingsWindow(RabbitDeployerWorkflow(rime))
        window.Show("Center")
        if A_Args.Length > 0 && A_Args[1] = "ci" {
            AssertColorSchemeBrowsingPreview(window)
            window.appearance_page.dialog_factory := RabbitSettingsAutoClosingColorSchemeDialog
            window.appearance_page.EditColorScheme(1)
            window.appearance_tabs.Choose(2)
            window.OnAppearanceTabChanged()
            window.appearance_layout_type.Choose(2)
            window.OnAppearanceControlsChanged()
            window.appearance_floating_preedit.Value := true
            window.OnAppearanceControlsChanged()
            window.SelectPage(2)
            window.switcher_tabs.Choose(2)
            window.OnSwitcherTabChanged()
            AssertTrue(window.switcher_caption.Visible, "The switcher menu tab did not become visible.")
            AssertTrue(
                window.switcher_save_list.GetCount() > 0,
                "The switcher menu tab did not discover any schema options."
            )
            window.SelectPage(3)
            SetTimer(window.Dispose.Bind(window), -100)
        }
        window.WaitClose()
    } finally {
        if window {
            window.Dispose()
        }
        rime.finalize()
    }
}

AssertColorSchemeBrowsingPreview(window) {
    local field_name := ""
    local initial_style := window.appearance_page.preview.style
    local selected_index := 0
    for index, info in window.appearance_page.presets {
        for field in RabbitColorScheme.EDITABLE_COLOR_FIELDS {
            if info.style.%field.key% != initial_style.%field.key% {
                selected_index := index
                field_name := field.key
                break
            }
        }
        if selected_index {
            break
        }
    }
    AssertTrue(selected_index, "The real settings data has no distinct color scheme for preview testing.")
    window.appearance_list.Modify(selected_index, "Select Focus")
    window.OnAppearanceSelectionChange()
    AssertEqual(
        window.appearance_page.presets[selected_index].style.%field_name%,
        window.appearance_page.preview.style.%field_name%,
        "Browsing the real color scheme list kept the startup preview colors."
    )
}

class RabbitSettingsAutoClosingColorSchemeDialog extends RabbitColorSchemeDialog {
    ShowModal() {
        SetTimer(this.Dispose.Bind(this), -200)
        return super.ShowModal()
    }
}
