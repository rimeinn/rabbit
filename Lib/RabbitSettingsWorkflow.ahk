/*
 * Copyright (c) 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
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

#Include RabbitApplicationSettingsModel.ahk
#Include RabbitBehaviorSettingsModel.ahk
#Include RabbitCommon.ahk
#Include RabbitDictionarySettingsModel.ahk
#Include RabbitI18n.ahk
#Include RabbitRimeDepotSettings.ahk
#Include RabbitSchemaSettingsModel.ahk
#Include RabbitSwitcherSettingsModel.ahk
#Include RabbitUIStyleSettings.ahk

class RabbitSettingsWorkflow {
    __New(rime_api) {
        this.rime := rime_api
        this.CreateFileIfNotExist("default.custom.yaml")
        this.CreateFileIfNotExist("rabbit.custom.yaml")
    }

    CreateFileIfNotExist(filename) {
        local user_data_dir := RabbitUserDataPath() . "\"
        if !InStr(DirExist(user_data_dir), "D") {
            DirCreate(user_data_dir)
        }
        local filepath := user_data_dir . filename
        if !InStr(FileExist(filepath), "N") {
            FileAppend("", filepath)
        }
    }

    CreateLevers() {
        return RimeLeversApi(this.rime)
    }

    CreateRimeDepotSettings() {
        return RabbitRimeDepotSettings.Load(this.rime)
    }

    SaveRimeDepotSettings(values) {
        return RabbitRimeDepotSettings.Save(this.rime, values)
    }

    CreateSwitcherSettingsModel() {
        return RabbitSwitcherSettingsModel(this.CreateLevers(), this.rime)
    }

    CreateBehaviorSettingsModel() {
        return RabbitBehaviorSettingsModel(this.CreateLevers(), this.rime)
    }

    CreateSchemaSettingsModel(schema_id) {
        return RabbitSchemaSettingsModel(this.rime, this.CreateLevers(), schema_id)
    }

    ReadCandidateLabels() {
        local api := this.CreateLevers()
        local config, settings := 0
        if !api {
            throw Error(RabbitI18n.Text("frontend.settings_api"))
        }
        try {
            settings := api.custom_settings_init("default", RABBIT_CUSTOMIZATION_GENERATOR_ID)
            if !settings || !api.load_settings(settings) {
                throw Error(RabbitI18n.Text("frontend.labels_load"))
            }
            if !(config := api.settings_get_config(settings)) {
                throw Error(RabbitI18n.Text("frontend.labels_read"))
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

    CreateDictionarySettingsModel(mutex_factory := 0) {
        if !mutex_factory {
            mutex_factory := (*) => RabbitDeploymentMutex()
        }
        return RabbitDictionarySettingsModel(this.rime, this.CreateLevers(), mutex_factory)
    }

    CreateUIStyleSettings() {
        local settings := UIStyleSettings(this.rime, this.CreateLevers())
        try {
            if !settings.Load() {
                throw Error(RabbitI18n.Text("frontend.style_load"))
            }
            return settings
        } catch {
            settings.Dispose()
            throw
        }
    }
}
