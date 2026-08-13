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

class RabbitPasswordFieldDetector {
    static UIA_IS_PASSWORD_PROPERTY_ID := 30019
    static VT_BOOL := 11
    static EM_GETPASSWORDCHAR := 0x00D2
    static SMTO_ABORTIFHUNG := 0x0002

    __New() {
        this.uia := 0
        this.uia_unavailable := false
    }

    IsFocusedPasswordField() {
        return this.IsUIAutomationFocusedPasswordField()
            || this.IsNativeFocusedPasswordField()
    }

    IsUIAutomationFocusedPasswordField() {
        local property_value
        local uia := this.GetUIAutomation()
        if !uia {
            return false
        }
        try {
            ComCall(8, uia, "Ptr*", focused_element := ComValue(13, 0))
            if !focused_element.Ptr {
                return false
            }

            property_value := Buffer(24, 0)
            ComCall(
                10,
                focused_element,
                "Int",
                RabbitPasswordFieldDetector.UIA_IS_PASSWORD_PROPERTY_ID,
                "Ptr",
                property_value
            )
            return NumGet(property_value, 0, "UShort") = RabbitPasswordFieldDetector.VT_BOOL
                && NumGet(property_value, 8, "Short") != 0
        } catch {
            return false
        } finally {
            if IsSet(property_value) {
                DllCall("OleAut32\VariantClear", "Ptr", property_value)
            }
        }
    }

    GetUIAutomation() {
        if this.uia || this.uia_unavailable {
            return this.uia
        }
        try {
            this.uia := ComObject(
                "{E22AD333-B25F-460C-83D0-0581107395C9}",
                "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
            )
        } catch {
            this.uia_unavailable := true
        }
        return this.uia
    }

    IsNativeFocusedPasswordField() {
        local foreground_hwnd := DllCall("GetForegroundWindow", "Ptr")
        if !foreground_hwnd {
            return false
        }
        local thread_id := DllCall(
            "GetWindowThreadProcessId",
            "Ptr",
            foreground_hwnd,
            "Ptr",
            0,
            "UInt"
        )
        if !thread_id {
            return false
        }

        local buffer_size := 8 + A_PtrSize * 6 + 16
        local gui_info := Buffer(buffer_size, 0)
        NumPut("UInt", buffer_size, gui_info, 0)
        if !DllCall("GetGUIThreadInfo", "UInt", thread_id, "Ptr", gui_info, "Int") {
            return false
        }
        local focus_hwnd := NumGet(gui_info, 8 + A_PtrSize, "Ptr")
        return focus_hwnd && this.IsNativePasswordField(focus_hwnd)
    }

    IsNativePasswordField(hwnd) {
        local class_name
        try {
            class_name := StrLower(WinGetClass("ahk_id " . hwnd))
        } catch {
            return false
        }
        if class_name != "edit" && InStr(class_name, "richedit") != 1 {
            return false
        }

        local password_character := 0
        return DllCall(
            "SendMessageTimeoutW",
            "Ptr",
            hwnd,
            "UInt",
            RabbitPasswordFieldDetector.EM_GETPASSWORDCHAR,
            "Ptr",
            0,
            "Ptr",
            0,
            "UInt",
            RabbitPasswordFieldDetector.SMTO_ABORTIFHUNG,
            "UInt",
            50,
            "Ptr*",
            &password_character,
            "Ptr"
        ) && password_character != 0
    }
}
