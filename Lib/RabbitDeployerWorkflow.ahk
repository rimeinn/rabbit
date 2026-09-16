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
#Include RabbitUIStyleSettingsDialog.ahk
#Include RabbitI18n.ahk
#Include RabbitMaintenanceWorkflow.ahk
#Include RabbitSettingsWorkflow.ahk

class RabbitDeployerWorkflow extends RabbitMaintenanceWorkflow {
    __New(rime_api, lock_operations := true) {
        super.__New(rime_api, lock_operations)
        this.settings_workflow := RabbitSettingsWorkflow(rime_api)
    }

    CreateLevers() {
        return this.settings_workflow.CreateLevers()
    }

    CreateRimeDepotSettings() {
        return this.settings_workflow.CreateRimeDepotSettings()
    }

    SaveRimeDepotSettings(values) {
        return this.settings_workflow.SaveRimeDepotSettings(values)
    }

    CreateSwitcherSettingsModel() {
        return this.settings_workflow.CreateSwitcherSettingsModel()
    }

    CreateBehaviorSettingsModel() {
        return this.settings_workflow.CreateBehaviorSettingsModel()
    }

    CreateSchemaSettingsModel(schema_id) {
        return this.settings_workflow.CreateSchemaSettingsModel(schema_id)
    }

    ReadCandidateLabels() {
        return this.settings_workflow.ReadCandidateLabels()
    }

    CreateApplicationSettingsModel() {
        return this.settings_workflow.CreateApplicationSettingsModel()
    }

    CreateDictionarySettingsModel() {
        return this.settings_workflow.CreateDictionarySettingsModel(this.CreateMutex.Bind(this))
    }

    CreateUIStyleSettings() {
        return this.settings_workflow.CreateUIStyleSettings()
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

}
