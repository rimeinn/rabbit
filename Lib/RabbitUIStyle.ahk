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

OnColorChange(wParam, lParam, msg, hWnd) {
    local config
    global rime, IS_DARK_MODE, box, ui_style
    local old_dark := IS_DARK_MODE
    IS_DARK_MODE := RabbitIsUserDarkMode()
    if old_dark != IS_DARK_MODE {
        if (config := rime.config_open("rabbit")) {
            ui_style := RabbitUIStyleSnapshot.FromConfig(rime, config, IS_DARK_MODE)
            rime.config_close(config)
            box.UpdateStyle(ui_style)
        }
        DarkMode.set(IS_DARK_MODE)
    }
}

; https://www.autohotkey.com/boards/viewtopic.php?p=515002&sid=859605067314b6d823a026658547b66f#p515002
class DarkMode {
    static set(mode) {
        DllCall(DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "uxtheme", "ptr"), "ptr", 135, "ptr"), "int", mode)
        DllCall(DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "uxtheme", "ptr"), "ptr", 136, "ptr"))
    }
}
