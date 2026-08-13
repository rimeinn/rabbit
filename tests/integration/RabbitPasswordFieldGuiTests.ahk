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

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitInput.ahk

RunTest("native and UI Automation password field detection", TestPasswordFieldDetection.Bind())
RunTest("password field focus monitor lifecycle", TestPasswordFieldFocusMonitor.Bind())
ExitApp()

TestPasswordFieldDetection() {
    local test_gui := Gui("+AlwaysOnTop +ToolWindow", "Rabbit password field test")
    local plain_edit := test_gui.AddEdit("w240")
    local password_edit := test_gui.AddEdit("w240 Password")
    local detector := RabbitPasswordFieldDetector()

    try {
        test_gui.Show("AutoSize")
        WinActivate("ahk_id " . test_gui.Hwnd)
        if !WinWaitActive("ahk_id " . test_gui.Hwnd, , 2) {
            throw Error("The password-field test window could not be activated.")
        }

        password_edit.Focus()
        AssertTrue(
            WaitForPasswordState(detector, true),
            "A focused password Edit control was not detected."
        )
        AssertTrue(
            detector.IsNativePasswordField(password_edit.Hwnd),
            "EM_GETPASSWORDCHAR did not identify the password Edit control."
        )
        AssertTrue(
            detector.IsUIAutomationFocusedPasswordField(),
            "UI Automation did not expose IsPassword for the focused password control."
        )

        plain_edit.Focus()
        AssertTrue(
            WaitForPasswordState(detector, false),
            "A focused plain Edit control was classified as a password field."
        )
        AssertTrue(
            !detector.IsNativePasswordField(plain_edit.Hwnd),
            "EM_GETPASSWORDCHAR identified a plain Edit control as a password field."
        )
        AssertTrue(
            !detector.IsUIAutomationFocusedPasswordField(),
            "UI Automation exposed IsPassword for the focused plain control."
        )
    } finally {
        test_gui.Destroy()
    }
}

TestPasswordFieldFocusMonitor() {
    local test_gui := Gui("+AlwaysOnTop +ToolWindow", "Rabbit password focus test")
    local plain_edit := test_gui.AddEdit("w240")
    local password_edit := test_gui.AddEdit("w240 Password")
    local input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(),
        {},
        {}
    )

    try {
        test_gui.Show("AutoSize")
        WinActivate("ahk_id " . test_gui.Hwnd)
        if !WinWaitActive("ahk_id " . test_gui.Hwnd, , 2) {
            throw Error("The password-focus test window could not be activated.")
        }

        input.StartFocusMonitor()
        AssertTrue(input.focus_event_hook, "The password-field focus hook was not installed.")

        password_edit.Focus()
        AssertTrue(
            WaitForBypassState(input, true),
            "The focus monitor did not activate password-field bypass."
        )

        plain_edit.Focus()
        AssertTrue(
            WaitForBypassState(input, false),
            "The focus monitor did not restore normal input outside the password field."
        )
    } finally {
        input.Dispose()
        test_gui.Destroy()
    }

    AssertEqual(0, input.focus_event_hook, "The password-field focus hook was not released.")
    AssertEqual(0, input.focus_event_callback, "The password-field callback was not released.")
}

WaitForPasswordState(detector, expected, timeout_ms := 2000) {
    local start_time := A_TickCount
    while A_TickCount - start_time < timeout_ms {
        if detector.IsFocusedPasswordField() = expected {
            return true
        }
        Sleep(25)
    }
    return false
}

WaitForBypassState(input, expected, timeout_ms := 2000) {
    local start_time := A_TickCount
    while A_TickCount - start_time < timeout_ms {
        if input.password_bypass_active = expected {
            return true
        }
        Sleep(25)
    }
    return false
}
