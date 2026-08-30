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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitWindowTheme.ahk

RunTest("window theme applies system appearance", TestWindowThemeAppliesSystemAppearance.Bind())
RunTest("light window keeps native control rendering", TestLightWindowKeepsNativeControlRendering.Bind())
RunTest("window theme preserves semantic text roles", TestWindowThemePreservesSemanticTextRoles.Bind())

TestWindowThemeAppliesSystemAppearance() {
    local window := Gui()
    local reader := RabbitWindowThemeModeProbe(true)
    local native := RabbitWindowThemeNativeProbe()
    local controller := RabbitWindowThemeController(window, reader, native)
    window.AddText(, "Text")
    window.AddEdit(, "Edit")
    try {
        controller.Register()
        AssertTrue(controller.registered, "The theme controller did not register the window.")
        AssertTrue(controller.dark_mode, "The theme controller ignored the initial dark mode.")
        AssertEqual(1, native.app_modes.Length, "The initial theme did not set the preferred app mode.")
        AssertEqual(true, native.app_modes[1], "The initial app mode was not dark.")
        AssertEqual(1, native.window_modes.Length, "The initial theme did not update the window.")
        AssertEqual(2, native.control_modes.Length, "The initial theme did not update every control.")

        controller.Register()
        AssertEqual(1, native.app_modes.Length, "Registering twice reapplied the window theme.")
    } finally {
        controller.Dispose()
        window.Destroy()
    }
    AssertTrue(!controller.registered, "The theme controller did not dispose its window state.")
}

TestLightWindowKeepsNativeControlRendering() {
    local window := Gui()
    local native := RabbitWindowThemeNativeProbe()
    local controller := RabbitWindowThemeController(window, RabbitWindowThemeModeProbe(false), native)
    window.AddText(, "Text")
    window.AddEdit(, "Edit")
    try {
        controller.Register()
        AssertTrue(!controller.dark_mode, "The theme controller ignored the initial light mode.")
        AssertEqual(1, native.window_modes.Length, "The light theme did not update the window.")
        AssertEqual(0, native.control_modes.Length, "The light theme replaced native control rendering.")
    } finally {
        controller.Dispose()
        window.Destroy()
    }
}

TestWindowThemePreservesSemanticTextRoles() {
    local window := Gui()
    local muted := window.AddText(, "Muted")
    local error_text := window.AddText(, "Error")
    local controller := RabbitWindowThemeController(
        window,
        RabbitWindowThemeModeProbe(true),
        RabbitWindowThemeNativeProbe()
    )
    try {
        controller.RegisterMuted(muted)
        controller.RegisterError(error_text)
        AssertEqual(
            RabbitWindowThemeController.DARK_MUTED_TEXT,
            controller.ControlTextColor("Text", "muted", true),
            "Dark mode lost the muted text role."
        )
        AssertEqual(
            RabbitWindowThemeController.DARK_ERROR_TEXT,
            controller.ControlTextColor("Text", "error", true),
            "Dark mode lost the error text role."
        )
        AssertEqual(
            "Gray",
            controller.ControlTextColor("Text", "muted", false),
            "Light mode did not restore muted text."
        )
        AssertEqual(
            "Red",
            controller.ControlTextColor("Text", "error", false),
            "Light mode did not restore error text."
        )
        controller.Register()
    } finally {
        controller.Dispose()
        window.Destroy()
    }
}

class RabbitWindowThemeModeProbe {
    __New(dark_mode) {
        this.dark_mode := dark_mode
    }

    Call() {
        return this.dark_mode
    }
}

class RabbitWindowThemeNativeProbe {
    __New() {
        this.app_modes := []
        this.window_modes := []
        this.control_modes := []
        this.redraw_count := 0
    }

    SetPreferredAppMode(dark_mode) {
        this.app_modes.Push(dark_mode)
    }

    ApplyWindow(hwnd, dark_mode) {
        this.window_modes.Push(dark_mode)
    }

    ApplyControl(hwnd, control_type, dark_mode) {
        this.control_modes.Push({ type: control_type, dark_mode: dark_mode })
    }

    GetLightBackground() {
        return "F0F0F0"
    }

    Redraw(hwnd) {
        this.redraw_count += 1
    }
}
