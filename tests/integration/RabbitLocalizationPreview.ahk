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
 */

#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ..\..\Lib\RabbitDeployerWorkflow.ahk
#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitSettingsWindow.ahk
#Include ..\..\Lib\RabbitI18n.ahk

RunTest("localized settings preview", ShowLocalizedSettingsPreview.Bind())

ShowLocalizedSettingsPreview() {
    global localization_preview
    RabbitI18n.Initialize(A_ScriptDir . "\..\..\locales", "en-US")
    localization_preview := RabbitSettingsWindow(, , , , "about")
    localization_preview.Show("Center")
    SetTimer(() => ExitApp(), -60000)
}
