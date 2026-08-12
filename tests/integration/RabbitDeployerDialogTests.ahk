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

#Include ..\..\Lib\RabbitCommon.ahk
#Include ..\..\Lib\RabbitDictManagementDialog.ahk
#Include ..\..\Lib\RabbitSwitcherSettingsDialog.ahk
#Include ..\support\TestCommon.ahk

RunTest("deployer dialog ownership", RunDeployerDialogTests.Bind())

RunDeployerDialogTests() {
    local repository_root := A_ScriptDir . "\..\.."
    local rime := RimeApi(A_ScriptDir . "\..\..\Lib\librime-ahk\rime.dll")
    local traits := RabbitCreateTraits()
    local levers := 0
    local switcher_settings := 0
    local switcher_dialog := 0
    local dict_dialog := 0
    traits.shared_data_dir := repository_root . "\Data"
    traits.user_data_dir := repository_root . "\Rime"
    traits.prebuilt_data_dir := traits.shared_data_dir
    rime.setup(traits)
    rime.deployer_initialize(0)

    try {
        levers := RimeLeversApi(rime)
        switcher_settings := levers.switcher_settings_init()
        if !levers.load_settings(switcher_settings) {
            throw Error("Failed to load switcher settings.")
        }

        switcher_dialog := SwitcherSettingsDialog(switcher_settings, levers)
        dict_dialog := DictManagementDialog(rime, levers)
    } finally {
        if dict_dialog {
            dict_dialog.Dispose()
        }
        if switcher_dialog {
            switcher_dialog.Dispose()
        }
        if switcher_settings {
            levers.custom_settings_destroy(switcher_settings)
        }
        rime.finalize()
    }
}
