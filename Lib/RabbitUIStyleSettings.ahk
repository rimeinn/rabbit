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
#Include RabbitUIStyleSnapshot.ahk

class UIStyleSettings {
    rime := 0
    api := 0
    settings := 0
    selected_color_scheme := ""
    selected_color_scheme_dark := ""
    color_scheme_dark_changed := false
    style_values := 0
    disposed := false

    __New(rime_api, levers_api := 0) {
        this.rime := rime_api
        this.api := levers_api ? levers_api : RimeLeversApi(rime_api)
        this.settings := this.api.custom_settings_init("rabbit", "Rabbit.UIStyleSettings")
    }

    Load() {
        return this.api.load_settings(this.settings)
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
        this.selected_color_scheme := value
        return value
    }

    GetActiveColorSchemeDark() {
        local config, value
        if !(config := this.api.settings_get_config(this.settings)) {
            return ""
        }
        if !(value := this.rime.config_get_cstring(config, "style/color_scheme_dark")) {
            return ""
        }
        this.selected_color_scheme_dark := value
        return value
    }

    GetCurrentStyle() {
        local config
        if !(config := this.api.settings_get_config(this.settings)) {
            return RabbitUIStyleSnapshot()
        }
        return RabbitUIStyleSnapshot.FromConfig(this.rime, config)
    }

    SelectColorScheme(color_scheme_id) {
        this.selected_color_scheme := color_scheme_id
        return !!this.api.customize_string(this.settings, "style/color_scheme", color_scheme_id)
    }

    SelectDarkColorScheme(color_scheme_id) {
        this.selected_color_scheme_dark := color_scheme_id
        this.color_scheme_dark_changed := true
        return !!this.api.customize_string(this.settings, "style/color_scheme_dark", color_scheme_id)
    }

    SetStyleValues(values) {
        this.style_values := Map()
        for name in [
            "font_face",
            "preedit_font_face",
            "label_font_face",
            "comment_font_face",
            "font_point",
            "label_font_point",
            "comment_font_point",
            "label_format",
            "layout_type",
            "align_type",
            "border_width",
            "corner_radius",
            "round_corner",
            "margin_x",
            "margin_y",
            "min_width",
            "min_height",
            "flow_rows",
            "vertical_text_left_to_right",
            "floating_preedit",
            "floating_preedit_opacity",
            "floating_preedit_min_height",
        ] {
            if values is Map {
                if values.Has(name) {
                    this.style_values[name] := values[name]
                }
            } else if HasProp(values, name) {
                this.style_values[name] := values.%name%
            }
        }
    }

    CustomizeStyleValues() {
        local key, name
        if !this.style_values {
            return true
        }
        for name, key in Map(
            "font_face", "style/font_face",
            "preedit_font_face", "style/preedit_font_face",
            "label_font_face", "style/label_font_face",
            "comment_font_face", "style/comment_font_face",
            "label_format", "style/label_format",
            "layout_type", "style/layout/type",
            "align_type", "style/layout/align_type"
        ) {
            if this.style_values.Has(name)
                && !this.api.customize_string(this.settings, key, this.style_values[name]) {
                return false
            }
        }
        for name, key in Map(
            "font_point", "style/font_point",
            "label_font_point", "style/label_font_point",
            "comment_font_point", "style/comment_font_point",
            "border_width", "style/layout/border_width",
            "corner_radius", "style/layout/corner_radius",
            "round_corner", "style/layout/round_corner",
            "margin_x", "style/layout/margin_x",
            "margin_y", "style/layout/margin_y",
            "min_width", "style/layout/min_width",
            "min_height", "style/layout/min_height",
            "flow_rows", "style/layout/flow_rows",
            "floating_preedit_min_height", "style/floating_preedit_min_height"
        ) {
            if this.style_values.Has(name)
                && !this.api.customize_int(this.settings, key, this.style_values[name]) {
                return false
            }
        }
        for name, key in Map(
            "vertical_text_left_to_right", "style/vertical_text_left_to_right",
            "floating_preedit", "style/floating_preedit"
        ) {
            if this.style_values.Has(name)
                && !this.api.customize_bool(this.settings, key, this.style_values[name]) {
                return false
            }
        }
        if this.style_values.Has("floating_preedit_opacity")
            && !this.api.customize_double(
                this.settings,
                "style/floating_preedit_opacity",
                this.style_values["floating_preedit_opacity"]
            ) {
            return false
        }
        return true
    }

    Save() {
        if !this.selected_color_scheme || !this.api.load_settings(this.settings) {
            return false
        }
        if !this.api.customize_string(this.settings, "style/color_scheme", this.selected_color_scheme) {
            return false
        }
        if this.color_scheme_dark_changed
            && !this.api.customize_string(
                this.settings,
                "style/color_scheme_dark",
                this.selected_color_scheme_dark
            ) {
            return false
        }
        if !this.CustomizeStyleValues() {
            return false
        }
        if !this.api.save_settings(this.settings) {
            return false
        }
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
