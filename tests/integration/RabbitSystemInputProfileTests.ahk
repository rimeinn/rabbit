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

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\..\Lib\RabbitSystemInputProfiles.ahk
#Include ..\support\TestCommon.ahk

RunTest("Windows system input profile binding", TestWindowsSystemInputProfiles.Bind())

TestWindowsSystemInputProfiles() {
    local profiles_api := RabbitSystemInputProfiles()
    local active := profiles_api.GetActiveProfile()
    AssertTrue(
        active.profile_type == RabbitSystemInputProfile.INPUT_PROCESSOR
            || active.profile_type == RabbitSystemInputProfile.KEYBOARD_LAYOUT,
        "Windows returned an unknown active system input profile type."
    )

    local enabled := profiles_api.EnumerateProfiles()
    AssertTrue(enabled.Length > 0, "Windows returned no enabled keyboard layouts.")
    for profile in enabled {
        AssertTrue(profile.IsKeyboardLayout(), "The safe layout list included an input processor.")
        AssertTrue(
            RegExMatch(profile.klid, "^[0-9A-F]{8}$"),
            "An enabled keyboard layout did not resolve to a KLID."
        )
    }

    local available := profiles_api.EnumerateAvailableLayouts(enabled)
    for profile in available {
        AssertTrue(profile.IsKeyboardLayout(), "The available list included an input processor.")
        AssertTrue(
            profiles_api.IsRabbitCompatible(profile),
            "The available list included a layout incompatible with Rabbit."
        )
        AssertTrue(
            RegExMatch(profile.klid, "^[0-9A-F]{8}$"),
            "An available keyboard layout did not have a KLID."
        )
    }
}
