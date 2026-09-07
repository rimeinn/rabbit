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
#SingleInstance Ignore

;@Ahk2Exe-SetInternalName rabbit
;@Ahk2Exe-SetProductName 玉兔毫
;@Ahk2Exe-SetOrigFilename Rabbit.ahk

#Include <RabbitApplication>
#Include <RabbitCommon>
#Include <RabbitCommandLine>
#Include <RabbitDeployerApplication>

global rabbit_entry_options := RabbitEntryOptions.Parse(A_Args)
global rabbit_application := rabbit_entry_options.is_deployer
    ? RabbitDeployerApplication(RimeApi(A_ScriptDir . "\Lib\librime-ahk\rime.dll"))
    : RabbitApplication(RimeApi(A_ScriptDir . "\Lib\librime-ahk\rime.dll"))
rabbit_application.Run(rabbit_entry_options.application_args)
