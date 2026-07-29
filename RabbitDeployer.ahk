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

;@Ahk2Exe-SetInternalName rabbit-deployer
;@Ahk2Exe-SetProductName 玉兔毫部署应用
;@Ahk2Exe-SetOrigFilename RabbitDeployer.ahk

#Include <RabbitCommon>
#Include <RabbitDeployerApplication>

;@Ahk2Exe-SetMainIcon Lib\rabbit-alt.ico
rabbit_deployer_application := RabbitDeployerApplication(
    RimeApi(A_ScriptDir . "\Lib\librime-ahk\rime.dll")
)
rabbit_deployer_application.Run(A_Args)
