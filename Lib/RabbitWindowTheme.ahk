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

#Include RabbitCommon.ahk
#Include RabbitUIStyle.ahk

class RabbitWindowThemeController {
    static DARK_BACKGROUND := "202020"
    static DARK_SURFACE := "2B2B2B"
    static DARK_TEXT := "F0F0F0"
    static DARK_MUTED_TEXT := "A0A0A0"
    static DARK_ERROR_TEXT := "FF8080"
    static DARK_LINK_TEXT := "4CC2FF"

    static Prepare() {
        ; Native common controls select their dark resources when they are created.
        local dark_mode := RabbitIsUserDarkMode()
        RabbitWindowThemeNative.SetPreferredAppMode(dark_mode)
        return dark_mode
    }

    __New(window, dark_mode_reader := RabbitIsUserDarkMode, native_api := RabbitWindowThemeNative) {
        this.window := window
        this.dark_mode_reader := dark_mode_reader
        this.native := native_api
        this.roles := Map()
        this.dark_mode := false
        this.registered := false
    }

    RegisterMuted(controls*) {
        for control in controls {
            this.roles[control.Hwnd] := "muted"
        }
    }

    RegisterError(controls*) {
        for control in controls {
            this.roles[control.Hwnd] := "error"
        }
    }

    RegisterSurface(controls*) {
        for control in controls {
            this.roles[control.Hwnd] := "surface"
        }
    }

    Register() {
        if this.registered {
            return
        }
        ; Keep one theme for the window lifetime; reopening follows a later system theme change.
        this.registered := true
        this.Apply()
    }

    Dispose() {
        this.registered := false
    }

    Apply() {
        local background, control, hwnd
        this.dark_mode := !!this.dark_mode_reader.Call()
        this.native.SetPreferredAppMode(this.dark_mode)
        this.native.ApplyWindow(this.window.Hwnd, this.dark_mode)
        background := this.dark_mode
            ? RabbitWindowThemeController.DARK_BACKGROUND
            : this.native.GetLightBackground()
        this.window.BackColor := background
        for hwnd, control in this.window {
            this.ApplyControl(control, this.dark_mode)
        }
        this.native.Redraw(this.window.Hwnd)
    }

    ApplyControl(control, dark_mode) {
        local background, color, role := this.roles.Get(control.Hwnd, "normal")
        color := this.ControlTextColor(control.Type, role, dark_mode)
        if !dark_mode {
            if role = "muted" || role = "error" {
                control.SetFont("c" . color)
            }
            return
        }
        background := RabbitWindowThemeController.DARK_SURFACE
        this.native.ApplyControl(control.Hwnd, control.Type, dark_mode)
        control.SetFont("c" . color)

        if role = "surface" {
            control.Opt("Background" . background)
        } else {
            switch control.Type {
                case "Edit", "ListBox", "ListView", "ComboBox", "DDL":
                    control.Opt("Background" . background)
                case "Tab3":
                    control.Opt("Background" . RabbitWindowThemeController.DARK_BACKGROUND)
            }
        }
    }

    ControlTextColor(control_type, role, dark_mode) {
        if !dark_mode {
            switch role {
                case "muted":
                    return "Gray"
                case "error":
                    return "Red"
                default:
                    return "Default"
            }
        }
        switch role {
            case "muted":
                return RabbitWindowThemeController.DARK_MUTED_TEXT
            case "error":
                return RabbitWindowThemeController.DARK_ERROR_TEXT
            default:
                return control_type = "Link"
                    ? RabbitWindowThemeController.DARK_LINK_TEXT
                    : RabbitWindowThemeController.DARK_TEXT
        }
    }
}

class RabbitWindowThemeNative {
    static SetPreferredAppMode(dark_mode) {
        local proc
        if (proc := this.GetUxThemeProc(135)) {
            DllCall(proc, "Int", dark_mode ? 1 : 0, "Int")
        }
        if (proc := this.GetUxThemeProc(104)) {
            DllCall(proc)
        }
        if (proc := this.GetUxThemeProc(136)) {
            DllCall(proc)
        }
    }

    static ApplyWindow(hwnd, dark_mode) {
        local caption_color, result, text_color
        this.AllowDarkModeForWindow(hwnd, dark_mode)
        if dark_mode {
            DllCall("UxTheme\SetWindowTheme", "Ptr", hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
        } else {
            DllCall("UxTheme\SetWindowTheme", "Ptr", hwnd, "Ptr", 0, "Ptr", 0)
        }
        try {
            result := DllCall(
                "Dwmapi\DwmSetWindowAttribute",
                "Ptr",
                hwnd,
                "UInt",
                20,
                "Int*",
                dark_mode,
                "UInt",
                4,
                "Int"
            )
            if result < 0 {
                DllCall(
                    "Dwmapi\DwmSetWindowAttribute",
                    "Ptr",
                    hwnd,
                    "UInt",
                    19,
                    "Int*",
                    dark_mode,
                    "UInt",
                    4,
                    "Int"
                )
            }
            caption_color := dark_mode ? 0x202020 : 0xFFFFFFFF
            text_color := dark_mode ? 0xF0F0F0 : 0xFFFFFFFF
            DllCall(
                "Dwmapi\DwmSetWindowAttribute",
                "Ptr",
                hwnd,
                "UInt",
                35,
                "UInt*",
                caption_color,
                "UInt",
                4,
                "Int"
            )
            DllCall(
                "Dwmapi\DwmSetWindowAttribute",
                "Ptr",
                hwnd,
                "UInt",
                36,
                "UInt*",
                text_color,
                "UInt",
                4,
                "Int"
            )
        }
    }

    static ApplyControl(hwnd, control_type, dark_mode) {
        local theme
        this.AllowDarkModeForWindow(hwnd, dark_mode)
        if dark_mode {
            if control_type = "Text" || control_type = "Link" || control_type = "GroupBox"
                || control_type = "Tab3" {
                DllCall("UxTheme\SetWindowTheme", "Ptr", hwnd, "WStr", "", "WStr", "")
                DllCall("User32\SendMessageW", "Ptr", hwnd, "UInt", WM_THEMECHANGED, "Ptr", 0, "Ptr", 0)
                return
            }
            theme := control_type = "Edit" || control_type = "ComboBox" || control_type = "DDL"
                ? "DarkMode_CFD"
                : "DarkMode_Explorer"
            DllCall("UxTheme\SetWindowTheme", "Ptr", hwnd, "WStr", theme, "Ptr", 0)
        } else {
            DllCall("UxTheme\SetWindowTheme", "Ptr", hwnd, "Ptr", 0, "Ptr", 0)
        }
        DllCall("User32\SendMessageW", "Ptr", hwnd, "UInt", WM_THEMECHANGED, "Ptr", 0, "Ptr", 0)
    }

    static AllowDarkModeForWindow(hwnd, dark_mode) {
        local proc
        if (proc := this.GetUxThemeProc(133)) {
            DllCall(proc, "Ptr", hwnd, "Int", dark_mode, "Int")
        }
    }

    static GetLightBackground() {
        local color := DllCall("User32\GetSysColor", "Int", 15, "UInt")
        return Format(
            "{:02X}{:02X}{:02X}",
            color & 0xFF,
            (color >> 8) & 0xFF,
            (color >> 16) & 0xFF
        )
    }

    static Redraw(hwnd) {
        static RDW_INVALIDATE := 0x0001
        static RDW_FRAME := 0x0400
        static RDW_ALLCHILDREN := 0x0080
        DllCall(
            "User32\RedrawWindow",
            "Ptr",
            hwnd,
            "Ptr",
            0,
            "Ptr",
            0,
            "UInt",
            RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN
        )
    }

    static GetUxThemeProc(ordinal) {
        local module := DllCall("Kernel32\GetModuleHandleW", "WStr", "uxtheme.dll", "Ptr")
        return module
            ? DllCall("Kernel32\GetProcAddress", "Ptr", module, "Ptr", ordinal, "Ptr")
            : 0
    }
}
