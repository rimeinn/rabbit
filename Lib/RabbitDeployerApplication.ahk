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

#Include RabbitCommon.ahk
#Include RabbitI18n.ahk
#Include RabbitCommandLine.ahk
#Include RabbitDeployerContext.ahk
#Include RabbitDeployerWorkflow.ahk
#Include RabbitMaintenanceIpc.ahk
#Include RabbitTrayMenu.ahk

class RabbitDeployerApplication {
    __New(rime_api) {
        this.context := RabbitDeployerContext(rime_api)
        this.application_gate := 0
        this.workflow := 0
        this.exit_callback := this.OnExit.Bind(this)
        this.shutting_down := false
    }

    Run(args) {
        RabbitI18n.LoadStartupConfig(this.context.rime, RabbitUserDataPath() . "\build\rabbit.yaml")
        A_IconTip := RabbitI18n.Text("tray.maintenance")
        local options := this.ParseOptions(args)
        this.context.command := options.command
        this.context.keyboard_layout := options.keyboard_layout
        OnExit(this.exit_callback)

        if options.command = "deploy" || options.command = "sync" {
            local ipc_result := RabbitMaintenanceIpcClient.Submit(
                options.command,
                options.command = "deploy" ? RabbitDeploymentPlan.FullRedeploy() : 0
            )
            if ipc_result.found {
                this.context.result := ipc_result.result = RabbitMaintenanceIpcServer.ACCEPTED ? 0 : 1
                this.ExitApplication(this.context.result)
                return this.context.result
            }
            this.application_gate := RabbitAcquireApplicationStartupGate()
            if !this.application_gate {
                this.context.result := 1
                this.ExitApplication(1)
                return 1
            }
        }

        TrayTip()
        TrayTip(RabbitI18n.Text("frontend.maintenance"), RabbitI18n.Text("settings.product"))

        this.context.Initialize()
        RabbitI18n.LoadConfig(this.context.rime)
        RabbitSetupMaintenanceTray()
        this.workflow := RabbitDeployerWorkflow(this.context.rime, false)

        switch options.command {
            case "deploy":
                this.context.result := this.workflow.UpdateWorkspace()
                this.context.maintenance_mode := RABBIT_NO_MAINTENANCE
            case "sync":
                this.context.result := this.workflow.SyncUserData()
                this.context.maintenance_mode := RABBIT_PARTIAL_MAINTENANCE
            case "legacy-settings":
                if options.target = "dictionary" {
                    this.context.result := this.workflow.DictManagement()
                    this.context.maintenance_mode := RABBIT_PARTIAL_MAINTENANCE
                } else {
                    this.context.result := this.workflow.Run(options.installing)
                    this.context.maintenance_mode := RABBIT_NO_MAINTENANCE
                }
        }

        if options.return_to_rabbit {
            this.Shutdown()
            this.RestartRabbit(this.context.maintenance_mode)
            this.ExitApplication()
        }
        return this.context.result
    }

    ParseOptions(args) {
        local options := RabbitDeployerOptions.Parse(args)
        if options.command = "settings" {
            throw ValueError("Modern settings are owned by the Rabbit frontend.")
        }
        return options
    }

    RestartRabbit(maintenance_mode) {
        local command_line := []
        if A_IsCompiled {
            command_line.Push(A_ScriptFullPath)
        } else {
            command_line.Push(A_AhkPath, A_ScriptFullPath)
        }
        command_line.Push(
            "--maintenance",
            RabbitMaintenanceModeName(maintenance_mode),
            "--keyboard-layout",
            RabbitFormatKeyboardLayout(this.context.keyboard_layout)
        )
        Run(RabbitBuildCommandLine(command_line))
    }

    ExitApplication(code := 0) {
        ExitApp(code)
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
        try {
            this.context.Dispose()
        } finally {
            if this.application_gate {
                this.application_gate.Close()
                this.application_gate := 0
            }
        }
    }
}
