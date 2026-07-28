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
 *
 */

#Include <RabbitCommon>
#Include <RabbitUIStyleSnapshot>

RabbitIsUserDarkMode() {
    try {
        local data := RegRead(
            "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme"
        )
    }
    if IsSet(data) && IsInteger(data) {
        return !data
    }
    return false
}

class RabbitAppearanceController {
    __New(rime_api, candidate_box, style, dark_mode) {
        this.rime := rime_api
        this.candidate_box := candidate_box
        this.style := style
        this.dark_mode := dark_mode
        this.color_change_callback := this.OnColorChange.Bind(this)
        this.registered := false
    }

    Register() {
        if this.registered {
            return
        }
        OnMessage(WM_SETTINGCHANGE, this.color_change_callback)
        OnMessage(WM_DWMCOLORIZATIONCOLORCHANGED, this.color_change_callback)
        this.registered := true
    }

    Dispose() {
        if !this.registered {
            return
        }
        OnMessage(WM_SETTINGCHANGE, this.color_change_callback, 0)
        OnMessage(WM_DWMCOLORIZATIONCOLORCHANGED, this.color_change_callback, 0)
        this.registered := false
    }

    OnColorChange(wParam, lParam, msg, hWnd) {
        local config
        local new_dark_mode := RabbitIsUserDarkMode()
        if new_dark_mode != this.dark_mode {
            this.dark_mode := new_dark_mode
            if (config := this.rime.config_open("rabbit")) {
                this.style := RabbitUIStyleSnapshot.FromConfig(
                    this.rime,
                    config,
                    this.dark_mode
                )
                this.rime.config_close(config)
                this.candidate_box.UpdateStyle(this.style)
            }
            DarkMode.set(this.dark_mode)
        }
    }
}

; https://www.autohotkey.com/boards/viewtopic.php?p=515002&sid=859605067314b6d823a026658547b66f#p515002
class DarkMode {
    static set(mode) {
        DllCall(DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "uxtheme", "ptr"), "ptr", 135, "ptr"), "int", mode)
        DllCall(DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "uxtheme", "ptr"), "ptr", 136, "ptr"))
    }
}
