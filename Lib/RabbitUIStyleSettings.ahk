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

#Include <RabbitCommon>
#Include <RabbitUIStyleSnapshot>

class UIStyleSettings {
    rime := 0
    api := 0
    settings := 0
    disposed := false

    __New(rime_api, levers_api := 0) {
        this.rime := rime_api
        this.api := levers_api ? levers_api : RimeLeversApi(rime_api)
        this.settings := this.api.custom_settings_init("rabbit", "Rabbit.UIStyleSettings")
    }

    GetPresetColorSchemes() {
        local config, preset, name, style
        local result := []
        if !(config := this.api.settings_get_config(this.settings)) {
            return result
        }
        if !(preset := this.rime.config_begin_map(config, "preset_color_schemes")) {
            return result
        }
        try {
            while this.rime.config_next(preset) {
                local name_key := preset.path . "/name"
                if !(name := this.rime.config_get_cstring(config, name_key)) {
                    continue
                }
                local author_key := preset.path . "/author"
                local author := this.rime.config_get_cstring(config, author_key)
                style := RabbitUIStyleSnapshot.FromConfig(
                    this.rime,
                    config,
                    false,
                    StrLower(preset.key)
                )
                result.Push({
                    color_scheme_id: preset.key,
                    name: name,
                    author: author,
                    style: style,
                })
            }
        } finally {
            this.rime.config_end(preset)
        }
        return result
    }

    GetActiveColorScheme() {
        local config, value
        if !(config := this.api.settings_get_config(this.settings)) {
            return ""
        }
        if !(value := this.rime.config_get_cstring(config, "style/color_scheme")) {
            return ""
        }
        return value
    }

    SelectColorScheme(color_scheme_id) {
        this.api.customize_string(this.settings, "style/color_scheme", color_scheme_id)
        return true
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        if this.settings {
            this.api.custom_settings_destroy(this.settings)
            this.settings := 0
        }
    }

    __Delete() {
        this.Dispose()
    }
}
