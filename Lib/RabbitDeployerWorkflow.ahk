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
#Include RabbitApplicationSettingsModel.ahk
#Include RabbitBehaviorSettingsModel.ahk
#Include RabbitDictionarySettingsModel.ahk
#Include RabbitDictManagementDialog.ahk
#Include RabbitSwitcherSettingsModel.ahk
#Include RabbitSwitcherSettingsDialog.ahk
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

    CreateSwitcherSettingsModel() {
        return RabbitSwitcherSettingsModel(this.CreateLevers(), this.rime)
    }

    CreateBehaviorSettingsModel() {
        return RabbitBehaviorSettingsModel(this.CreateLevers(), this.rime)
    }

    ReadCandidateLabels() {
        local api := this.CreateLevers()
        local config, settings := 0
        if !api {
            throw Error("Failed to initialize Rime settings API.")
        }
        try {
            settings := api.custom_settings_init("default", "Rabbit.CandidateLabels")
            if !settings || !api.load_settings(settings) {
                throw Error("Failed to load candidate labels.")
            }
            if !(config := api.settings_get_config(settings)) {
                throw Error("Failed to read candidate label settings.")
            }
            return RabbitBehaviorSettingsModel.ReadStringList(
                this.rime,
                config,
                "menu/alternative_select_labels"
            )
        } finally {
            if settings {
                api.custom_settings_destroy(settings)
            }
        }
    }

    CreateApplicationSettingsModel() {
        return RabbitApplicationSettingsModel(this.CreateLevers(), this.rime)
    }

    CreateDictionarySettingsModel() {
        return RabbitDictionarySettingsModel(
            this.rime,
            this.CreateLevers(),
            this.CreateMutex.Bind(this)
        )
    }

    CreateUIStyleSettings() {
        local settings := UIStyleSettings(this.rime, this.CreateLevers())
        try {
            if !settings.Load() {
                throw Error("Failed to load UI style settings.")
            }
            return settings
        } catch {
            settings.Dispose()
            throw
        }
    }

    CreateMutex() {
        return RabbitMutex()
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

            if !this.rime.deploy() {
                return 1
            }
            if !this.rime.deploy_config_file("rabbit.yaml", "config_version") {
                return 1
            }
            return 0
        } finally {
            mutex.Close()
        }
    }

    DictManagement() {
        local dialog, model, result
        model := 0
        dialog := 0
        result := 1
        try {
            model := this.CreateDictionarySettingsModel()
            dialog := DictManagementDialog(model)
            dialog.Show()
            WinWaitClose(dialog)
            result := 0
        } catch as err {
            MsgBox("未能打开用户词典管理：`n" . err.Message, "【玉兔毫】", "Ok Iconx")
        } finally {
            try {
                if dialog {
                    dialog.Dispose()
                }
            } finally {
                if model {
                    model.Dispose()
                }
            }
        }
        return result
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
