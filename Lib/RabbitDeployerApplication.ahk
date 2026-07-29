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

#Include <RabbitDeployerContext>
#Include <RabbitDeployerWorkflow>
#Include <RabbitTrayMenu>

class RabbitDeployerApplication {
    __New(rime_api) {
        this.context := RabbitDeployerContext(rime_api)
        this.workflow := 0
        this.exit_callback := this.OnExit.Bind(this)
        this.shutting_down := false
    }

    Run(args) {
        this.context.command := args.Length > 0 ? args[1] : ""
        this.context.keyboard_layout := args.Length >= 2 ? Number(args[2]) : 0

        TrayTip()
        TrayTip("维护中", RABBIT_IME_NAME)
        RabbitSetupMaintenanceTray()

        OnExit(this.exit_callback)
        this.workflow := RabbitDeployerWorkflow(this.context.rime)
        this.context.Initialize()

        switch this.context.command {
            case "deploy":
                this.context.result := this.workflow.UpdateWorkspace()
                this.context.maintenance_mode := RABBIT_NO_MAINTENANCE
            case "dict":
                this.context.result := this.workflow.DictManagement()
                this.context.maintenance_mode := RABBIT_PARTIAL_MAINTENANCE
            case "sync":
                this.context.result := this.workflow.SyncUserData()
                this.context.maintenance_mode := RABBIT_PARTIAL_MAINTENANCE
            default:
                this.context.result := this.workflow.Run(this.context.command = "install")
                this.context.maintenance_mode := RABBIT_NO_MAINTENANCE
        }

        if args.Length > 1 {
            this.Shutdown()
            this.RestartRabbit()
            ExitApp()
        }
        return this.context.result
    }

    RestartRabbit() {
        if A_IsCompiled {
            Run(Format(
                "`"{}\Rabbit.exe`" {} {} {}",
                A_ScriptDir,
                this.context.maintenance_mode,
                this.context.result,
                this.context.keyboard_layout
            ))
        } else {
            Run(Format(
                "{} `"{}\Rabbit.ahk`" {} {} {}",
                A_AhkPath,
                A_ScriptDir,
                this.context.maintenance_mode,
                this.context.result,
                this.context.keyboard_layout
            ))
        }
    }

    OnExit(reason, code) {
        this.Shutdown()
    }

    Shutdown() {
        if this.shutting_down {
            return
        }
        this.shutting_down := true
        TrayTip()
        this.context.Dispose()
    }
}
