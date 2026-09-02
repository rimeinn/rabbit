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

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitAdvancedFontSettingsDialog.ahk

RunTest("advanced font dialog edits every font role", TestAdvancedFontDialogEditsRoles.Bind())
RunTest("advanced font dialog switches simple font tabs", TestAdvancedFontDialogSwitchesSimpleTabs.Bind())
RunTest("advanced font dialog prepares dark native controls", TestAdvancedFontDialogDarkMode.Bind())

TestAdvancedFontDialogEditsRoles() {
    local owner := Gui()
    local dialog := RabbitAdvancedFontSettingsDialog(
        owner,
        CreateAdvancedFontDialogValues(),
        ["Microsoft YaHei UI", "Segoe UI Emoji"],
        (*) => false,
        RabbitAdvancedFontDialogThemeProbe
    )
    try {
        dialog.family.Text := "Segoe UI Emoji"
        dialog.range_preset.Choose(4)
        dialog.OnRangePresetChanged()
        AssertTrue(dialog.ApplyEntry(), "The dialog rejected a valid Emoji range.")
        dialog.font_weight.Choose(8)
        dialog.font_style.Choose(3)
        dialog.OnAttributesChanged()

        dialog.role_tabs.Choose(4)
        dialog.OnRoleChanged()
        dialog.raw_source.Value := "Segoe UI Symbol:2000:2bff, Microsoft YaHei UI"
        AssertTrue(dialog.ParseRawSource(), "The dialog rejected a valid raw fallback setting.")
        AssertTrue(dialog.SaveSettings(), "The dialog did not save valid font settings.")
        AssertEqual(
            "Segoe UI Emoji:1f300:1faff:bold:italic",
            dialog.result["font_face"],
            "The dialog did not save the structured candidate font edits."
        )
        AssertEqual(
            "Segoe UI Symbol:2000:2bff, Microsoft YaHei UI",
            dialog.result["comment_font_face"],
            "The dialog did not save raw comment font edits."
        )
    } finally {
        dialog.Dispose()
        owner.Destroy()
    }
}

TestAdvancedFontDialogSwitchesSimpleTabs() {
    local owner := Gui()
    local dialog := RabbitAdvancedFontSettingsDialog(
        owner,
        CreateAdvancedFontDialogValues(),
        ["Microsoft YaHei UI"],
        (*) => false,
        RabbitAdvancedFontDialogThemeProbe
    )
    try {
        AssertEqual(1, dialog.range_preset.Value, "A simple font did not use the full-range preset.")
        dialog.range_start.Value := ""
        dialog.range_end.Value := ""
        dialog.role_tabs.Choose(2)
        dialog.OnRoleChanged()
        AssertEqual(2, dialog.current_role_index, "Empty disabled range edits blocked the tab switch.")
        AssertEqual("", dialog.status.Value, "The tab switch reported an unexpected validation error.")
        AssertEqual(
            "Microsoft YaHei UI",
            dialog.model.GetValues()["font_face"],
            "The tab switch changed a simple font setting."
        )
    } finally {
        dialog.Dispose()
        owner.Destroy()
    }
}

TestAdvancedFontDialogDarkMode() {
    local close_callback
    local owner := Gui()
    local dialog := RabbitAdvancedFontSettingsDialog(
        owner,
        CreateAdvancedFontDialogValues(),
        ["Microsoft YaHei UI"],
        (*) => true,
        RabbitAdvancedFontDialogDarkThemeFactory
    )
    try {
        AssertEqual(
            RabbitWindowThemeController.DARK_BACKGROUND,
            dialog.BackColor,
            "The advanced font dialog did not prepare its dark background."
        )
        AssertTrue(dialog.order_header.Visible, "Dark mode did not show the replacement list header.")
        AssertTrue(dialog.family_header.Visible, "Dark mode did not show the font list header.")
        AssertTrue(dialog.range_header.Visible, "Dark mode did not show the range list header.")
        AssertTrue(dialog.window_theme.dark_mode, "The native theme controller did not enter dark mode.")
        close_callback := (*) => dialog.Dispose()
        SetTimer(close_callback, 30)
        try dialog.ShowModal()
        finally SetTimer(close_callback, 0)
    } finally {
        dialog.Dispose()
        owner.Destroy()
    }
}

CreateAdvancedFontDialogValues() {
    return Map(
        "font_face", "Microsoft YaHei UI",
        "preedit_font_face", "Microsoft YaHei UI",
        "label_font_face", "Microsoft YaHei UI",
        "comment_font_face", "Microsoft YaHei UI"
    )
}

class RabbitAdvancedFontDialogThemeProbe {
    static Prepare() {
        return false
    }

    __New(window, dark_mode_reader) {
    }

    RegisterMuted(controls*) {
    }

    RegisterError(controls*) {
    }

    RegisterSurface(controls*) {
    }

    Register() {
    }

    Dispose() {
    }
}

class RabbitAdvancedFontDialogDarkThemeFactory extends RabbitWindowThemeController {
    static Prepare() {
        RabbitWindowThemeNative.SetPreferredAppMode(true)
        return true
    }
}
