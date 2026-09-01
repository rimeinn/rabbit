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
#Include ..\..\Lib\RabbitColorSchemeDialog.ahk

RunTest("color scheme dialog edits through ARGB", TestColorSchemeDialogEditsArgb.Bind())
RunTest("color scheme dialog copies to standard ARGB", TestColorSchemeDialogCopiesArgb.Bind())
RunTest("color scheme dialog attaches the real preview owner", TestColorSchemeDialogAttachesPreview.Bind())
RunTest("color scheme dialog prepares dark mode", TestColorSchemeDialogPreparesDarkMode.Bind())
ExitApp()

TestColorSchemeDialogEditsArgb() {
    local owner := Gui()
    local scheme := RabbitColorScheme("existing", Map(
        "name", "Existing",
        "color_format", "abgr",
        "back_color", "0x80102040"
    ), "custom")
    local dialog := RabbitColorSchemeDialog(
        owner,
        scheme,
        "edit",
        0,
        [],
        0,
        0,
        (*) => false,
        RabbitColorSchemeDialogThemeProbe
    )
    try {
        dialog.name_edit.Value := "Edited"
        dialog.color_controls["back_color"].edit.Value := "#80402010"
        AssertTrue(dialog.SaveScheme(), "The dialog rejected valid ARGB input.")
        AssertEqual("Edited", dialog.result.name, "The dialog did not save the scheme name.")
        AssertEqual("abgr", dialog.result.color_format, "Editing changed the original format.")
        AssertEqual(
            "0x80102040",
            dialog.result.values["back_color"],
            "The dialog did not convert ARGB back to ABGR."
        )
    } finally {
        dialog.Dispose()
        owner.Destroy()
    }
}

TestColorSchemeDialogCopiesArgb() {
    local owner := Gui()
    local scheme := RabbitColorScheme("copy_source", Map(
        "name", "Copy",
        "color_format", "abgr",
        "back_color", "0x80102040"
    ))
    local dialog := RabbitColorSchemeDialog(
        owner,
        scheme,
        "copy",
        0,
        [],
        0,
        (*) => true,
        (*) => false,
        RabbitColorSchemeDialogThemeProbe
    )
    try {
        dialog.id_edit.Value := "copy_result"
        AssertTrue(dialog.SaveScheme(), "The dialog rejected a valid copied scheme.")
        AssertEqual("argb", dialog.result.color_format, "The copied scheme did not use ARGB.")
        AssertEqual("0x80402010", dialog.result.values["back_color"], "The copy was not normalized.")
    } finally {
        dialog.Dispose()
        owner.Destroy()
    }
}

TestColorSchemeDialogAttachesPreview() {
    local close_callback
    local owner := Gui()
    local preview := RabbitColorSchemeDialogPreviewProbe()
    local dialog := RabbitColorSchemeDialog(
        owner,
        RabbitColorScheme.CreateDefault("preview", "Preview"),
        "edit",
        preview,
        ["一"],
        Map("floating_preedit", true),
        0,
        (*) => false,
        RabbitColorSchemeDialogThemeProbe
    )
    try {
        close_callback := (*) => preview.render_count ? dialog.Dispose() : 0
        SetTimer(close_callback, 10)
        try dialog.ShowModal()
        finally SetTimer(close_callback, 0)
        AssertEqual(2, preview.owners.Length, "The dialog did not attach and restore the preview owner.")
        AssertTrue(preview.owners[1] = dialog, "The preview was not attached to the editor window.")
        AssertTrue(preview.owners[2] = owner, "The preview owner was not restored after editing.")
        AssertTrue(preview.render_count > 0, "The editor did not render the real preview.")
        AssertTrue(preview.last_style.floating_preedit, "The editor preview ignored pending typesetting values.")
    } finally {
        dialog.Dispose()
        owner.Destroy()
    }
}

TestColorSchemeDialogPreparesDarkMode() {
    local owner := Gui()
    local dialog := RabbitColorSchemeDialog(
        owner,
        RabbitColorScheme.CreateDefault("dark", "Dark"),
        "view",
        0,
        [],
        0,
        0,
        (*) => true,
        RabbitColorSchemeDialogDarkThemeProbe
    )
    try {
        AssertEqual(
            RabbitWindowThemeController.DARK_BACKGROUND,
            dialog.BackColor,
            "The editor window did not prepare its dark background."
        )
        AssertTrue(!dialog.name_edit.Enabled, "The built-in view left metadata editable.")
        AssertTrue(
            !dialog.color_controls["back_color"].edit.Enabled,
            "The built-in view left colors editable."
        )
    } finally {
        dialog.Dispose()
        owner.Destroy()
    }
}

class RabbitColorSchemeDialogPreviewProbe {
    owners := []
    render_count := 0
    last_style := 0

    SetOwner(owner) {
        this.owners.Push(owner)
    }

    Render(style, labels) {
        this.render_count += 1
        this.last_style := style
        return true
    }
}

class RabbitColorSchemeDialogThemeProbe {
    static Prepare() {
        return false
    }

    __New(window, dark_mode_reader) {
    }

    RegisterError(controls*) {
    }

    Register() {
    }

    Dispose() {
    }
}

class RabbitColorSchemeDialogDarkThemeProbe extends RabbitColorSchemeDialogThemeProbe {
    static Prepare() {
        return true
    }
}
