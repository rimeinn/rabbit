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
#Include RabbitDictManagementDialog.ahk
#Include RabbitSwitcherSettingsDialog.ahk
#Include RabbitSystemInputDialog.ahk
#Include RabbitSystemInputProfiles.ahk
#Include RabbitSystemInputSettings.ahk
#Include RabbitUIStyleSettings.ahk
#Include RabbitUIStyleSettingsDialog.ahk

class RabbitDeployerWorkflow {
    __New(rime_api) {
        this.rime := rime_api
        this.CreateFileIfNotExist("default.custom.yaml")
        this.CreateFileIfNotExist("rabbit.custom.yaml")
    }

    CreateFileIfNotExist(filename) {
        local user_data_dir, filepath
        user_data_dir := RabbitUserDataPath() . "\"
        if !InStr(DirExist(user_data_dir), "D") {
            DirCreate(user_data_dir)
        }
        filepath := user_data_dir . filename
        if !InStr(FileExist(filepath), "N") {
            FileAppend("", filepath)
        }
    }

    CreateLevers() {
        return RimeLeversApi(this.rime)
    }

    CreateMutex() {
        return RabbitMutex()
    }

    CreateSystemInputProfiles() {
        return RabbitSystemInputProfiles()
    }

    CreateSystemInputSettings(levers) {
        return RabbitSystemInputSettings(this.rime, levers)
    }

    CreateSystemInputDialog(enabled, available, configured_klid) {
        return RabbitSystemInputDialog(enabled, available, configured_klid)
    }

    Run(installing) {
        local levers, switcher_settings, ui_style_settings
        local skip_switcher_settings, skip_ui_style_settings, reconfigured
        levers := this.CreateLevers()
        if !levers {
            return 1
        }

        switcher_settings := 0
        ui_style_settings := 0
        reconfigured := false
        try {
            switcher_settings := levers.switcher_settings_init()
            ui_style_settings := UIStyleSettings(this.rime, levers)
            skip_switcher_settings := installing && !levers.is_first_run(switcher_settings)
            skip_ui_style_settings := installing && !levers.is_first_run(ui_style_settings.settings)

            if !skip_switcher_settings {
                if !this.ConfigureSwitcher(levers, switcher_settings, &reconfigured) {
                    skip_ui_style_settings := true ; user cancelled
                }
            }
            if !skip_ui_style_settings {
                this.ConfigureUI(levers, ui_style_settings, &reconfigured)
            }
        } finally {
            try {
                if ui_style_settings {
                    ui_style_settings.Dispose()
                }
            } finally {
                if switcher_settings {
                    levers.custom_settings_destroy(switcher_settings)
                }
            }
        }

        if installing || reconfigured {
            return this.UpdateWorkspace()
        }
        return 0
    }

    ConfigureSwitcher(levers, switcher_settings, &reconfigured) {
        local dialog
        if !IsSet(reconfigured) {
            reconfigured := false
        }
        if !levers.load_settings(switcher_settings) {
            return false
        }

        dialog := SwitcherSettingsDialog(switcher_settings, levers)
        try {
            dialog.Show()
            WinWaitClose(dialog)
        } finally {
            dialog.Dispose()
        }

        if dialog.accepted {
            if levers.save_settings(switcher_settings) {
                reconfigured := true
            }
            return true
        }
        return false
    }

    ConfigureUI(levers, ui_style_settings, &reconfigured) {
        local dialog
        if !IsSet(reconfigured) {
            reconfigured := false
        }
        if !levers.load_settings(ui_style_settings.settings) {
            return false
        }

        dialog := UIStyleSettingsDialog(ui_style_settings)
        try {
            dialog.Show()
            WinWaitClose(dialog)
        } finally {
            dialog.Dispose()
        }

        if dialog.accepted {
            if levers.save_settings(ui_style_settings.settings) {
                reconfigured := true
            }
            return true
        }
        return false
    }

    ConfigureSystemInput(serialized_state) {
        local profiles := this.CreateSystemInputProfiles()
        local levers := this.CreateLevers()
        local settings := this.CreateSystemInputSettings(levers)
        local configured_value := ""
        if !settings.Load(&configured_value) {
            this.ShowSystemInputError("未能读取系统键盘布局设置。")
            return this.SystemInputOutcome(1, false, serialized_state)
        }

        local configured_klid := this.NormalizeSystemInputKlid(configured_value)
        local enabled := []
        for profile in profiles.EnumerateProfiles() {
            if profile.IsEnabled() && profiles.IsRabbitCompatible(profile) {
                enabled.Push(profile)
            }
        }
        if this.FindSystemInputByKlid(enabled, configured_klid) {
            local deploy_result := this.UpdateWorkspace(true)
            return this.SystemInputOutcome(
                deploy_result,
                deploy_result == 0,
                serialized_state
            )
        }

        local available := profiles.EnumerateAvailableLayouts(enabled)
        local dialog := this.CreateSystemInputDialog(enabled, available, configured_klid)
        try {
            dialog.accept_callback := (profile, window) => profiles.Activate(
                profile,
                !profile.IsEnabled(),
                window
            )
            this.ShowSystemInputDialog(dialog)
        } finally {
            dialog.Dispose()
        }

        if !dialog.accepted {
            MsgBox(
                "必须选择一个键盘布局，否则系统输入法会与玉兔毫冲突。",
                "【玉兔毫】",
                "Ok Icon!"
            )
            return this.SystemInputOutcome(1, false, serialized_state)
        }
        if !dialog.activation_attempted || !dialog.activation_succeeded {
            this.ShowSystemInputError("Windows 未能切换到所选键盘布局。")
            return this.SystemInputOutcome(1, false, serialized_state)
        }

        local selected_klid := StrUpper(dialog.selected_profile.klid)
        if !settings.Save(selected_klid) {
            this.RestoreSystemInput(profiles, serialized_state)
            this.ShowSystemInputError("未能保存系统键盘布局设置。")
            return this.SystemInputOutcome(1, false, serialized_state)
        }

        deploy_result := this.UpdateWorkspace(true)
        if deploy_result != 0 {
            this.RestoreSystemInput(profiles, serialized_state)
            return this.SystemInputOutcome(deploy_result, false, serialized_state)
        }
        return this.SystemInputOutcome(
            0,
            true,
            this.MarkSystemInputRestorePending(serialized_state)
        )
    }

    ShowSystemInputDialog(dialog) {
        dialog.Show()
        WinWaitClose(dialog)
    }

    SystemInputOutcome(result, restart, serialized_state) {
        return {
            result: result,
            restart: restart,
            serialized_state: serialized_state
        }
    }

    MarkSystemInputRestorePending(serialized_state) {
        local state := RabbitSystemInputRestoreState.Deserialize(serialized_state)
        if state.profile {
            state.pending := true
        }
        return state.Serialize()
    }

    RestoreSystemInput(profiles, serialized_state) {
        try {
            local state := RabbitSystemInputRestoreState.Deserialize(serialized_state)
            if state.profile {
                profiles.Activate(state.profile)
            }
        }
    }

    FindSystemInputByKlid(profiles, klid) {
        if !klid {
            return 0
        }
        for profile in profiles {
            if StrUpper(profile.klid) = klid {
                return profile
            }
        }
        return 0
    }

    NormalizeSystemInputKlid(value) {
        local klid := StrUpper(value)
        return RegExMatch(klid, "^[0-9A-F]{8}$") ? klid : ""
    }

    ShowSystemInputError(message) {
        MsgBox(
            "无法配置系统键盘布局。`r`n`r`n" . message,
            "【玉兔毫】",
            "Ok Iconx"
        )
    }

    UpdateWorkspace(report_errors := false) {
        local mutex
        mutex := this.CreateMutex()
        if !mutex.Create() {
            ; TODO: log error
            return 1
        }

        try {
            if mutex.lasterr == ERROR_ALREADY_EXISTS {
                ; TODO: log error
                if report_errors {
                    MsgBox(
                        "正在执行另一项部署任务，方才所做的修改将在输入法再次启动后生效。",
                        "【玉兔毫】",
                        "Ok Iconi"
                    )
                }
                return 1
            }

            this.rime.deploy()
            this.rime.deploy_config_file("rabbit.yaml", "config_version")
            return 0
        } finally {
            mutex.Close()
        }
    }

    DictManagement() {
        local mutex, levers, dialog
        mutex := this.CreateMutex()
        if !mutex.Create() {
            ; TODO: log error
            return 1
        }

        try {
            if mutex.lasterr == ERROR_ALREADY_EXISTS {
                ; TODO: log error
                MsgBox("正在执行另一项部署任务，请稍后再试。", "【玉兔毫】", "Ok Iconi")
                return 1
            }

            if this.rime.api_available("run_task") {
                this.rime.run_task("installation_update")
            }
            levers := this.CreateLevers()
            dialog := DictManagementDialog(this.rime, levers)
            try {
                dialog.Show()
                WinWaitClose(dialog)
            } finally {
                dialog.Dispose()
            }
            return 0
        } finally {
            mutex.Close()
        }
    }

    SyncUserData() {
        local mutex
        mutex := this.CreateMutex()
        if !mutex.Create() {
            ; TODO: log error
            return 1
        }

        try {
            if mutex.lasterr == ERROR_ALREADY_EXISTS {
                ; TODO: log error
                MsgBox("正在执行另一项部署任务，请稍后再试。", "【玉兔毫】", "Ok Iconi")
                return 1
            }

            if !this.rime.sync_user_data() {
                return 1
            }
            this.rime.join_maintenance_thread()
            return 0
        } finally {
            mutex.Close()
        }
    }
}
