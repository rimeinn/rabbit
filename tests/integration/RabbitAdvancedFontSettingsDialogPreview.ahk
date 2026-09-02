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

RunTest("advanced font settings dialog preview", RunAdvancedFontSettingsDialogPreview.Bind())

RunAdvancedFontSettingsDialogPreview() {
    local owner := Gui()
    local dialog := RabbitAdvancedFontSettingsDialog(
        owner,
        Map(
            "font_face", "Segoe UI Emoji:1f300:1faff, Microsoft YaHei UI, Segoe UI Emoji",
            "preedit_font_face", "Microsoft YaHei UI",
            "label_font_face", "Consolas:30:39, Microsoft YaHei UI",
            "comment_font_face", "Segoe UI Symbol:2000:2bff, Microsoft YaHei UI"
        ),
        ["Microsoft YaHei UI", "Segoe UI", "Segoe UI Emoji", "Segoe UI Symbol", "Consolas"],
        (*) => true,
        RabbitAdvancedFontSettingsDialogPreviewTheme
    )
    try {
        dialog.ShowModal()
    } finally {
        dialog.Dispose()
        owner.Destroy()
    }
}

class RabbitAdvancedFontSettingsDialogPreviewTheme extends RabbitWindowThemeController {
    static Prepare() {
        RabbitWindowThemeNative.SetPreferredAppMode(true)
        return true
    }
}
