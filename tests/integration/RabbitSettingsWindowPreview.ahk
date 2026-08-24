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

#Include ..\..\Lib\RabbitSettingsWindow.ahk
#Include ..\support\TestCommon.ahk

RunTest("settings window preview", RunSettingsWindowPreview.Bind())
ExitApp()

RunSettingsWindowPreview() {
    local window := RabbitSettingsWindow()
    try {
        window.Show("w820 h500 Center")
        if A_Args.Length > 0 && A_Args[1] = "ci" {
            SetTimer(window.OnClose.Bind(window), -100)
        }
        window.WaitClose()
    } finally {
        window.Dispose()
    }
}
