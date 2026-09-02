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
#Include ..\..\Lib\RabbitAppearanceSettingsPage.ahk

RunTest("DirectWrite enumerates installed font families", TestInstalledFontFamilies.Bind())
ExitApp(test_failure_count ? 1 : 0)

TestInstalledFontFamilies() {
    local user_font_path := EnvGet("LOCALAPPDATA")
        . "\Microsoft\Windows\Fonts\LXGWWenKaiMonoGB-Regular.ttf"
    local names := RabbitAppearanceSettingsPage.GetInstalledFontFaces()
    AssertTrue(ArrayContains(names, "Segoe UI"), "DirectWrite did not enumerate the Segoe UI family.")
    if FileExist(user_font_path) {
        AssertTrue(
            ArrayContains(names, "LXGW WenKai Mono GB"),
            "DirectWrite did not expose the installed per-user LXGW WenKai Mono GB family."
        )
    }
}

ArrayContains(values, expected) {
    for value in values {
        if value = expected {
            return true
        }
    }
    return false
}
