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

#Include ..\..\Lib\RabbitApplicationSettingsModel.ahk
#Include ..\..\Lib\RabbitBehaviorSettingsModel.ahk
#Include ..\..\Lib\RabbitCommon.ahk
#Include ..\..\Lib\RabbitSwitcherSettingsModel.ahk
#Include ..\..\Lib\RabbitUIStyleSettings.ahk
#Include ..\support\TestCommon.ahk

RunTest("switcher hotkeys persist through generic customization", TestSwitcherHotkeyPersistence.Bind())
RunTest("shared rabbit settings preserve earlier saves", TestSharedRabbitSettingsPersistence.Bind())
ExitApp()

TestSwitcherHotkeyPersistence() {
    local model := 0
    local rime := 0
    local schema_ids := []
    local test_dir := RabbitSettingsPersistenceTestDirectory("switcher")
    try {
        FileAppend("patch: {}`n", test_dir . "\default.custom.yaml", "UTF-8")
        rime := RabbitSettingsPersistenceRime(test_dir)
        model := RabbitSwitcherSettingsModel(RimeLeversApi(rime), rime)
        for item in model.items {
            if item.selected {
                schema_ids.Push(item.id)
            }
        }
        if schema_ids.Length = 0 && model.items.Length > 0 {
            schema_ids.Push(model.items[1].id)
        }

        AssertTrue(schema_ids.Length > 0, "The integration data did not provide an input schema.")
        AssertTrue(
            model.Save(schema_ids, "F4, Control+grave"),
            "The bundled librime failed to save switcher hotkeys through customize_item."
        )
        local saved := FileRead(test_dir . "\default.custom.yaml", "UTF-8")
        AssertTrue(InStr(saved, "switcher/hotkeys"), "The saved config omitted switcher hotkeys.")
        AssertTrue(InStr(saved, "Control+grave"), "The saved config omitted a configured hotkey.")
    } finally {
        if model {
            model.Dispose()
        }
        if rime {
            rime.finalize()
        }
        if DirExist(test_dir) {
            DirDelete(test_dir, true)
        }
    }
}

TestSharedRabbitSettingsPersistence() {
    local application := 0
    local behavior := 0
    local levers := 0
    local rime := 0
    local style := 0
    local test_dir := RabbitSettingsPersistenceTestDirectory("rabbit")
    try {
        FileAppend("patch: {}`n", test_dir . "\default.custom.yaml", "UTF-8")
        FileAppend("patch: {}`n", test_dir . "\rabbit.custom.yaml", "UTF-8")
        rime := RabbitSettingsPersistenceRime(test_dir)
        levers := RimeLeversApi(rime)
        style := UIStyleSettings(rime, levers)
        AssertTrue(style.Load(), "The integration test could not load UI style settings.")
        behavior := RabbitBehaviorSettingsModel(levers, rime)
        application := RabbitApplicationSettingsModel(levers, rime)

        AssertTrue(
            style.SelectColorScheme(style.GetActiveColorScheme()),
            "The integration test could not stage a color scheme."
        )
        local current_style := style.GetCurrentStyle()
        style.SetStyleValues(Map(
            "font_point", current_style.font_point + 1,
            "margin_x", current_style.margin_x + 1,
            "floating_preedit", !current_style.floating_preedit,
            "floating_preedit_opacity", 0.65
        ))
        local source_scheme := style.GetPresetColorSchemes()[1]
        style.UpsertColorScheme(source_scheme.CopyAs(
            "settings_test",
            "Settings Test",
            "Rabbit Integration Test"
        ))
        AssertTrue(style.Save(), "The integration test could not save UI style settings.")
        local color_saved := FileRead(test_dir . "\rabbit.custom.yaml", "UTF-8")
        AssertTrue(
            InStr(color_saved, "preset_color_schemes/settings_test"),
            "The custom color scheme was not saved at its individual patch path."
        )
        AssertTrue(
            !InStr(color_saved, '"preset_color_schemes":'),
            "Saving one color scheme replaced the complete preset map."
        )
        AssertTrue(
            style.GetCustomColorSchemeIds().Has("settings_test"),
            "The saved path was not recognized as a custom color scheme."
        )
        local behavior_values := behavior.GetCurrentValues()
        behavior_values.show_tips := !behavior.show_tips
        AssertTrue(
            behavior.Save(behavior_values),
            "The integration test could not save behavior settings."
        )
        AssertTrue(
            application.Save(Map(
                "rabbit-settings-test.exe",
                { reset: false, ascii_mode: true }
            )),
            "The integration test could not save application settings."
        )

        local saved := FileRead(test_dir . "\rabbit.custom.yaml", "UTF-8")
        AssertTrue(InStr(saved, "style/color_scheme"), "A later save removed the UI style setting.")
        AssertTrue(InStr(saved, "style/font_point"), "The saved config omitted the candidate font size.")
        AssertTrue(InStr(saved, "style/layout/margin_x"), "The saved config omitted the horizontal margin.")
        AssertTrue(InStr(saved, "style/floating_preedit"), "The saved config omitted floating preedit.")
        AssertTrue(InStr(saved, "show_tips"), "A later save removed the behavior setting.")
        AssertTrue(InStr(saved, "rabbit-settings-test.exe"), "The application setting was not saved.")

        style.DeleteColorScheme("settings_test")
        AssertTrue(style.Save(), "The integration test could not delete a custom color scheme.")
        saved := FileRead(test_dir . "\rabbit.custom.yaml", "UTF-8")
        AssertTrue(
            !InStr(saved, "preset_color_schemes/settings_test"),
            "Deleting the custom color scheme left its patch path behind."
        )
        AssertTrue(
            !style.GetCustomColorSchemeIds().Has("settings_test"),
            "The deleted path was still recognized as a custom color scheme."
        )
    } finally {
        if application {
            application.Dispose()
        }
        if behavior {
            behavior.Dispose()
        }
        if style {
            style.Dispose()
        }
        if rime {
            rime.finalize()
        }
        if DirExist(test_dir) {
            DirDelete(test_dir, true)
        }
    }
}

RabbitSettingsPersistenceRime(user_data_dir) {
    local repository_root := A_ScriptDir . "\..\.."
    local rime := RimeApi(repository_root . "\Lib\librime-ahk\rime.dll")
    local traits := RabbitCreateTraits()
    traits.shared_data_dir := repository_root . "\Data"
    traits.user_data_dir := user_data_dir
    traits.prebuilt_data_dir := traits.shared_data_dir
    rime.setup(traits)
    rime.deployer_initialize(0)
    return rime
}

RabbitSettingsPersistenceTestDirectory(name) {
    local path := A_Temp . "\rabbit-settings-" . name . "-" .
        DllCall("GetCurrentProcessId", "UInt") . "-" . A_TickCount
    DirCreate(path)
    return path
}
