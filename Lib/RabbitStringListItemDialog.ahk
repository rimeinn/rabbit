/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
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
#Include RabbitWindowTheme.ahk

#Include RabbitI18n.ahk

class RabbitStringListItemDialog extends Gui {
    __New(
        owner,
        value := "",
        editing := false,
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local factory, initial_dark_mode := false
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        super.__New(
            "+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox",
            editing ? RabbitI18n.Text("controls.edit") : RabbitI18n.Text("controls.add"),
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

        this.AddText("x20 y22 w72 h22", RabbitI18n.Text("controls.list_item"))
        this.value_edit := this.AddEdit("x100 y18 w320 r1 -Multi", value)
        this.save_button := this.AddButton("x252 y60 w80 h32 Default +0x2000", RabbitI18n.Text("common.ok"))
        this.save_button.OnEvent("Click", (*) => this.SaveItem())
        this.cancel_button := this.AddButton("x340 y60 w80 h32 +0x2000", RabbitI18n.Text("common.cancel"))
        this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        factory := theme_factory
        this.window_theme := factory(this, dark_mode_reader)
        this.window_theme.Register()
    }

    ShowModal() {
        RabbitDialogPlacement.ShowOnOwnerMonitor(this, this.owner_window.Hwnd, "w440 h116")
        WinWaitClose("ahk_id " . this.Hwnd)
        return this.result
    }

    SaveItem() {
        this.result := Map("value", this.value_edit.Value)
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
