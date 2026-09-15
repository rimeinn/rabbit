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

#Include RabbitDialogPlacement.ahk
#Include RabbitRecognizerPatterns.ahk
#Include RabbitWindowTheme.ahk

#Include RabbitI18n.ahk

class RabbitRecognizerPatternsDialog extends Gui {
    static WINDOW_WIDTH := 700
    static WINDOW_HEIGHT := 470

    __New(
        owner,
        value := 0,
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local tag, pattern, factory, initial_dark_mode := false
        if !(value is Map) {
            value := Map()
        }
        value := RabbitRecognizerPatterns.Validate(value)
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        super.__New(
            "+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox",
            RabbitI18n.Text("recognizer.editor_title"),
            this
        )
        this.owner_window := owner
        this.entries := []
        for tag, pattern in value {
            this.entries.Push({key: tag, value: pattern})
        }
        this.result := 0
        this.disposed := false
        this.MarginX := 20
        this.MarginY := 18
        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )
        this.list := this.AddListView(
            "x20 y18 w660 h300 -Multi NoSort" . (initial_dark_mode ? " -Hdr" : ""),
            [RabbitI18n.Text("recognizer.pattern_tag"), RabbitI18n.Text("recognizer.pattern")]
        )
        this.list.OnEvent("DoubleClick", (ctrl, row) => this.EditEntry(row))
        if initial_dark_mode {
            this.tag_header := this.AddText(
                "x20 y18 w180 h24 +0x200 c" . RabbitWindowThemeController.DARK_TEXT
                    . " Background" . RabbitWindowThemeController.DARK_SURFACE,
                "  " . RabbitI18n.Text("recognizer.pattern_tag")
            )
            this.pattern_header := this.AddText(
                "x200 y18 w480 h24 +0x200 c" . RabbitWindowThemeController.DARK_TEXT
                    . " Background" . RabbitWindowThemeController.DARK_SURFACE,
                "  " . RabbitI18n.Text("recognizer.pattern")
            )
        }
        this.add_button := this.AddButton("x20 y326 w78 h32 +0x2000", RabbitI18n.Text("controls.add"))
        this.add_button.OnEvent("Click", (*) => this.AddEntry())
        this.edit_button := this.AddButton("x106 y326 w78 h32 +0x2000", RabbitI18n.Text("controls.edit"))
        this.edit_button.OnEvent("Click", (*) => this.EditEntry())
        this.delete_button := this.AddButton("x192 y326 w78 h32 +0x2000", RabbitI18n.Text("controls.delete"))
        this.delete_button.OnEvent("Click", (*) => this.DeleteEntry())
        this.status := this.AddText("x20 y370 w660 h24 cRed", "")
        this.save_button := this.AddButton("x512 y420 w80 h32 Default +0x2000", RabbitI18n.Text("common.ok"))
        this.save_button.OnEvent("Click", (*) => this.SavePatterns())
        this.cancel_button := this.AddButton("x600 y420 w80 h32 +0x2000", RabbitI18n.Text("common.cancel"))
        this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        factory := theme_factory
        this.window_theme := factory(this, dark_mode_reader)
        this.window_theme.RegisterError(this.status)
        if initial_dark_mode {
            this.window_theme.RegisterSurface(this.list)
            this.window_theme.RegisterSurface(this.tag_header, this.pattern_header)
        }
        this.window_theme.Register()
        this.RefreshList()
    }

    ShowModal() {
        RabbitDialogPlacement.ShowOnOwnerMonitor(
            this,
            this.owner_window.Hwnd,
            "w" . RabbitRecognizerPatternsDialog.WINDOW_WIDTH . " h" . RabbitRecognizerPatternsDialog.WINDOW_HEIGHT
        )
        WinWaitClose("ahk_id " . this.Hwnd)
        return this.result
    }

    RefreshList(selected_row := 0) {
        local entry
        this.list.Delete()
        for entry in this.entries {
            this.list.Add("", entry.key, RabbitRecognizerPatterns.DisplayValue(entry.value))
        }
        this.list.ModifyCol(1, 180)
        this.list.ModifyCol(2, 460)
        if selected_row && selected_row <= this.entries.Length {
            this.list.Modify(selected_row, "Select Focus Vis")
        }
    }

    AddEntry() {
        local entry := RabbitRecognizerPatternEntryDialog(
            this,
            "",
            "",
            this.window_theme.dark_mode_reader
        ).ShowModal()
        if !entry {
            return false
        }
        if this.HasEntryKey(entry.key) {
            this.status.Value := RabbitI18n.Text("recognizer.pattern_tag_duplicate")
            return false
        }
        this.entries.Push(entry)
        this.status.Value := ""
        this.RefreshList(this.entries.Length)
        return true
    }

    EditEntry(row := 0) {
        local entry, edited
        if !row {
            row := this.list.GetNext(0)
        }
        if row < 1 || row > this.entries.Length {
            this.status.Value := RabbitI18n.Text("recognizer.select_pattern")
            return false
        }
        entry := this.entries[row]
        edited := RabbitRecognizerPatternEntryDialog(
            this,
            entry.key,
            entry.value,
            this.window_theme.dark_mode_reader
        ).ShowModal()
        if !edited {
            return false
        }
        if this.HasEntryKey(edited.key, row) {
            this.status.Value := RabbitI18n.Text("recognizer.pattern_tag_duplicate")
            return false
        }
        this.entries[row] := edited
        this.status.Value := ""
        this.RefreshList(row)
        return true
    }

    DeleteEntry() {
        local row := this.list.GetNext(0)
        if row < 1 || row > this.entries.Length {
            this.status.Value := RabbitI18n.Text("recognizer.select_pattern")
            return false
        }
        this.entries.RemoveAt(row)
        this.status.Value := ""
        this.RefreshList(Min(row, this.entries.Length))
        return true
    }

    HasEntryKey(key, except_row := 0) {
        local index, entry
        for index, entry in this.entries {
            if index != except_row && entry.key = key {
                return true
            }
        }
        return false
    }

    SavePatterns() {
        local entry, value := Map()
        for entry in this.entries {
            value[entry.key] := entry.value
        }
        try {
            this.result := RabbitRecognizerPatterns.Validate(value)
        } catch as err {
            this.status.Value := err.Message
            return false
        }
        this.Dispose()
        return true
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try {
            if this.window_theme {
                this.window_theme.Dispose()
                this.window_theme := 0
            }
        } finally {
            try this.Destroy()
        }
    }
}

class RabbitRecognizerPatternEntryDialog extends Gui {
    static WINDOW_WIDTH := 700
    static WINDOW_HEIGHT := 250

    __New(
        owner,
        tag := "",
        pattern := "",
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local initial_dark_mode := false, factory
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        super.__New(
            "+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox",
            tag ? RabbitI18n.Text("recognizer.edit_pattern") : RabbitI18n.Text("recognizer.add_pattern"),
            this
        )
        this.owner_window := owner
        this.result := 0
        this.disposed := false
        this.MarginX := 20
        this.MarginY := 18
        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )
        this.AddText("x20 y22 w132 h22", RabbitI18n.Text("recognizer.pattern_tag"))
        this.tag_edit := this.AddEdit("x164 y18 w516 r1 -Multi", tag)
        this.AddText("x20 y62 w132 h22", RabbitI18n.Text("recognizer.pattern"))
        this.pattern_edit := this.AddEdit("x164 y58 w516 r4", pattern)
        this.status := this.AddText("x20 y170 w660 h24 cRed", "")
        this.save_button := this.AddButton("x512 y208 w80 h32 Default +0x2000", RabbitI18n.Text("common.ok"))
        this.save_button.OnEvent("Click", (*) => this.SaveEntry())
        this.cancel_button := this.AddButton("x600 y208 w80 h32 +0x2000", RabbitI18n.Text("common.cancel"))
        this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        factory := theme_factory
        this.window_theme := factory(this, dark_mode_reader)
        this.window_theme.RegisterError(this.status)
        this.window_theme.Register()
    }

    ShowModal() {
        RabbitDialogPlacement.ShowOnOwnerMonitor(
            this,
            this.owner_window.Hwnd,
            "w" . RabbitRecognizerPatternEntryDialog.WINDOW_WIDTH
                . " h" . RabbitRecognizerPatternEntryDialog.WINDOW_HEIGHT
        )
        WinWaitClose("ahk_id " . this.Hwnd)
        return this.result
    }

    SaveEntry() {
        try {
            RabbitRecognizerPatterns.ValidateTag(this.tag_edit.Value)
            this.result := {
                key: this.tag_edit.Value,
                value: this.pattern_edit.Value,
            }
        } catch as err {
            this.status.Value := err.Message
            return false
        }
        this.Dispose()
        return true
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try {
            if this.window_theme {
                this.window_theme.Dispose()
                this.window_theme := 0
            }
        } finally {
            try this.Destroy()
        }
    }
}
