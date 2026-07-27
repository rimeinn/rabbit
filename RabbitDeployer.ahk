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
#Include <RabbitTrayMenu>
#Include <RabbitConfigurator>

;@Ahk2Exe-SetMainIcon Lib\rabbit-alt.ico
global IN_MAINTENANCE := true
global rime
global INVALID_FILE_ATTRIBUTES := -1
global FILE_ATTRIBUTE_DIRECTORY := 0x00000010

OnExit(ExitRabbitDeployer)

RabbitDeployerMain(A_Args)

; args[1]: command
; args[2]: keyboard layout
RabbitDeployerMain(args) {
    local layout, command, conf, res, opt
    if args.Length >= 2 {
        layout := Number(args[2])
    } else {
        layout := 0
    }
    IN_MAINTENANCE := true
    UpdateTrayIcon()
    TrayTip()
    TrayTip("维护中", RABBIT_IME_NAME)
    SetupTrayMenu()

    command := args.Length > 0 ? args[1] : ""
    conf := Configurator()
    conf.Initialize()
    switch command {
        case "deploy":
            res := conf.UpdateWorkspace()
            opt := RABBIT_NO_MAINTENANCE
        case "dict":
            res := conf.DictManagement()
            opt := RABBIT_PARTIAL_MAINTENANCE
        case "sync":
            res := conf.SyncUserData()
            opt := RABBIT_PARTIAL_MAINTENANCE
        default:
            res := conf.Run(command = "install")
            opt := RABBIT_NO_MAINTENANCE
    }

    if args.Length > 1 {
        if A_IsCompiled {
            Run(Format("`"{}\Rabbit.exe`" {} {} {}", A_ScriptDir, opt, res, layout))
        } else {
            Run(Format("{} `"{}\Rabbit.ahk`" {} {} {}", A_AhkPath, A_ScriptDir, opt, res, layout))
        }
        ExitApp()
    }
    return res
}

ExitRabbitDeployer(reason, code) {
    TrayTip()
}
