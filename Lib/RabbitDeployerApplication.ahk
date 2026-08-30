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
#Include RabbitCommandLine.ahk
#Include RabbitDeployerContext.ahk
#Include RabbitDeployerWorkflow.ahk
#Include RabbitSettingsWindow.ahk
#Include RabbitTrayMenu.ahk

class RabbitDeployerApplication {
    __New(rime_api) {
        this.context := RabbitDeployerContext(rime_api)
        this.workflow := 0
        this.exit_callback := this.OnExit.Bind(this)
        this.shutting_down := false
    }

    Run(args) {
        local options := this.ParseOptions(args)
        this.context.command := options.command
        this.context.keyboard_layout := options.keyboard_layout

        TrayTip()
        TrayTip("维护中", RABBIT_IME_NAME)
        RabbitSetupMaintenanceTray()

        OnExit(this.exit_callback)
        this.context.Initialize()
        this.workflow := RabbitDeployerWorkflow(this.context.rime)

        switch options.command {
            case "deploy":
                this.context.result := this.workflow.UpdateWorkspace()
                this.context.maintenance_mode := RABBIT_NO_MAINTENANCE
            case "sync":
                this.context.result := this.workflow.SyncUserData()
                this.context.maintenance_mode := RABBIT_PARTIAL_MAINTENANCE
            case "settings":
                this.context.result := this.ShowSettings(options.target, options.installing)
                this.context.maintenance_mode := RABBIT_NO_MAINTENANCE
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
        if options.command = "settings" && options.target
            && !RabbitSettingsWindow.PageIndex(options.target) {
            throw ValueError("未知的设置页面：" . options.target)
        }
        return options
    }

    CreateSettingsWindow(page_id := "", installing := false) {
        return RabbitSettingsWindow(
            this.workflow,
            false,
            RabbitAppearancePreview,
            0,
            page_id,
            installing
        )
    }

    UseLegacySettings() {
        return RabbitIsOldWindows()
    }

    ShowSettings(page_id := "", installing := false) {
        if this.UseLegacySettings() {
            if page_id = "dictionary" {
                return this.workflow.DictManagement()
            }
            return this.workflow.Run(installing)
        }

        local window := this.CreateSettingsWindow(page_id, installing)
        try {
            window.Show("Center")
            window.WaitClose()
        } finally {
            window.Dispose()
        }
        return 0
    }

    RestartRabbit(maintenance_mode) {
        local command_line := []
        if A_IsCompiled {
            command_line.Push(A_ScriptDir . "\Rabbit.exe")
        } else {
            command_line.Push(A_AhkPath, A_ScriptDir . "\Rabbit.ahk")
        }
        command_line.Push(
            "--maintenance",
            RabbitMaintenanceModeName(maintenance_mode),
            "--keyboard-layout",
            RabbitFormatKeyboardLayout(this.context.keyboard_layout)
        )
        Run(RabbitBuildCommandLine(command_line))
    }

    ExitApplication() {
        ExitApp()
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
