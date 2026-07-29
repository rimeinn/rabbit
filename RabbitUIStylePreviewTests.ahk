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

#Include <RabbitCommon>
#Include <RabbitUIStyleSettings>
#Include <RabbitUIStyleSettingsDialog>

RunUIStylePreviewTest()

RunUIStylePreviewTest() {
    local dialog := 0
    local settings := 0
    local rime := RimeApi(A_ScriptDir . "\Lib\librime-ahk\rime.dll")
    local traits := RabbitCreateTraits()
    rime.setup(traits)
    rime.deployer_initialize(0)

    try {
        local levers := RimeLeversApi(rime)
        settings := UIStyleSettings(rime, levers)
        if !levers.load_settings(settings.settings) {
            throw Error("Failed to load UI style settings.")
        }

        dialog := UIStyleSettingsDialog(settings)
        if RabbitIsOldWindows() {
            if dialog.candidate_box {
                throw Error("The old-Windows style page constructed a Direct2D preview.")
            }
        } else {
            if !dialog.candidate_box {
                throw Error("The supported style page did not construct its preview.")
            }
            if dialog.preset.Length == 0 {
                throw Error("The style page did not load any preview snapshots.")
            }
            dialog.Preview(1)
            if dialog.candidate_box.previewWidth <= 0 || dialog.candidate_box.previewHeight <= 0 {
                throw Error("The style preview did not build positive dimensions.")
            }
        }

        FileAppend("PASS: UI style preview snapshots`n", "*")
    } finally {
        if dialog {
            dialog.Dispose()
            dialog := 0
        }
        if settings {
            settings.Dispose()
            settings := 0
        }
        rime.finalize()
    }
}
