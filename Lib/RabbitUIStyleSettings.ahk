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
#Include <RabbitUIStyle>

class UIStyleSettings {
    __New() {
        this.api := RimeLeversApi()
        this.settings := this.api.custom_settings_init("rabbit", "Rabbit.UIStyleSettings")
    }

    GetPresetColorSchemes() {
        global rime
        local result := []
        if !config := this.api.settings_get_config(this.settings)
            return result
        if !rime || !preset := rime.config_begin_map(config, "preset_color_schemes")
            return result
        while rime.config_next(preset) {
            local name_key := preset.path . "/name"
            if !name := rime.config_get_cstring(config, name_key)
                continue
            local author_key := preset.path . "/author"
            local author := rime.config_get_cstring(config, author_key)
            UIStyle.UpdateColor(config, StrLower(preset.key))
            result.Push({
                color_scheme_id: preset.key,
                name: name,
                author: author,
                border_color: UIStyle.border_color,
                text_color: UIStyle.text_color,
                back_color: UIStyle.back_color,
                hilited_text_color: UIStyle.hilited_text_color,
                hilited_back_color: UIStyle.hilited_back_color,
                hilited_candidate_text_color: UIStyle.hilited_candidate_text_color,
                hilited_candidate_back_color: UIStyle.hilited_candidate_back_color,
                candidate_text_color: UIStyle.candidate_text_color,
                candidate_back_color: UIStyle.candidate_back_color,
                font_face: UIStyle.font_face,
                font_point: UIStyle.font_point,
            })
        }
        return result
    }

    GetActiveColorScheme() {
        global rime
        if !config := this.api.settings_get_config(this.settings)
            return ""
        if !rime || !value := rime.config_get_cstring(config, "style/color_scheme")
            return ""
        return value
    }

    SelectColorScheme(color_scheme_id) {
        this.api.customize_string(this.settings, "style/color_scheme", color_scheme_id)
        return true
    }
}
