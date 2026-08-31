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
#Include RabbitColorScheme.ahk
#Include RabbitConfigValue.ahk
#Include RabbitUIStyleSnapshot.ahk

class UIStyleSettings {
    rime := 0
    api := 0
    settings := 0
    selected_color_scheme := ""
    selected_color_scheme_dark := ""
    color_scheme_dark_changed := false
    color_scheme_changes := Map()
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
        local config, preset, name, scheme_item, style, values
        local custom_ids := this.GetCustomColorSchemeIds()
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
                values := Map(
                    "name", name,
                    "author", author
                )
                if HasMethod(this.rime, "config_get_item") && HasMethod(this.rime, "config_begin_list") {
                    scheme_item := this.rime.config_get_item(config, preset.path)
                    try {
                        if scheme_item && RabbitConfigValue.Read(this.rime, scheme_item, "/", &values) {
                            if !values.Has("name") {
                                values["name"] := name
                            }
                            if author && !values.Has("author") {
                                values["author"] := author
                            }
                        }
                    } finally {
                        if scheme_item {
                            this.rime.config_close(scheme_item)
                            scheme_item := 0
                        }
                    }
                }
                style := RabbitUIStyleSnapshot.FromConfig(
                    this.rime,
                    config,
                    false,
                    StrLower(preset.key)
                )
                result.Push(RabbitColorScheme(
                    preset.key,
                    values,
                    custom_ids.Has(preset.key) ? "custom" : "builtin",
                    style
                ))
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

    GetCustomColorSchemeIds() {
        local config := 0
        local item := 0
        local iter := 0
        local nested := 0
        local match
        local result := Map()
        if !this.rime || !HasMethod(this.rime, "user_config_open") {
            return result
        }
        if !(config := this.rime.user_config_open("rabbit.custom")) {
            return result
        }
        try {
            if !(iter := this.rime.config_begin_map(config, "patch")) {
                return result
            }
            try {
                while this.rime.config_next(iter) {
                    if RegExMatch(iter.key, "^preset_color_schemes/([^/]+)", &match) {
                        result[match[1]] := true
                    } else if iter.key = "preset_color_schemes" {
                        item := this.rime.config_get_item(config, iter.path)
                        if item && (nested := this.rime.config_begin_map(item, "/")) {
                            try {
                                while this.rime.config_next(nested) {
                                    result[nested.key] := true
                                }
                            } finally {
                                this.rime.config_end(nested)
                            }
                        }
                        if item {
                            this.rime.config_close(item)
                            item := 0
                        }
                    }
                }
            } finally {
                this.rime.config_end(iter)
            }
        } finally {
            if item {
                this.rime.config_close(item)
            }
            this.rime.config_close(config)
        }
        return result
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

    FollowLightColorScheme() {
        this.selected_color_scheme_dark := ""
        this.color_scheme_dark_changed := true
        return !!this.api.customize_item(this.settings, "style/color_scheme_dark", 0)
    }

    StageColorSchemeSelection(light_color_scheme_id, dark_color_scheme_id := "") {
        this.selected_color_scheme := light_color_scheme_id
        this.selected_color_scheme_dark := dark_color_scheme_id
        this.color_scheme_dark_changed := true
    }

    UpsertColorScheme(color_scheme) {
        if !(color_scheme is RabbitColorScheme) || !color_scheme.IsCustom() {
            throw TypeError("只能保存自定义配色方案。")
        }
        RabbitColorScheme.ValidateId(color_scheme.color_scheme_id)
        this.color_scheme_changes[color_scheme.color_scheme_id] := color_scheme
    }

    DeleteColorScheme(color_scheme_id) {
        RabbitColorScheme.ValidateId(color_scheme_id)
        this.color_scheme_changes[color_scheme_id] := 0
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
            "candidate_padding_x",
            "candidate_padding_y",
            "candidate_spacing",
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
            "candidate_padding_x", "style/layout/candidate_padding_x",
            "candidate_padding_y", "style/layout/candidate_padding_y",
            "candidate_spacing", "style/layout/candidate_spacing",
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
        if this.color_scheme_dark_changed {
            if this.selected_color_scheme_dark {
                if !this.api.customize_string(
                    this.settings,
                    "style/color_scheme_dark",
                    this.selected_color_scheme_dark
                ) {
                    return false
                }
            } else if !this.api.customize_item(this.settings, "style/color_scheme_dark", 0) {
                return false
            }
        }
        if !this.CustomizeStyleValues() {
            return false
        }
        if !this.CustomizeColorSchemes() {
            return false
        }
        if !this.api.save_settings(this.settings) {
            return false
        }
        this.color_scheme_changes := Map()
        return true
    }

    CustomizeColorSchemes() {
        local color_scheme, config, path
        for color_scheme_id, color_scheme in this.color_scheme_changes {
            path := "preset_color_schemes/" . color_scheme_id
            if !color_scheme {
                if !this.api.customize_item(this.settings, path, 0) {
                    return false
                }
                continue
            }
            config := this.rime.config_load_string(RabbitConfigValue.ToYaml(color_scheme.values))
            if !config {
                return false
            }
            try {
                if !this.api.customize_item(this.settings, path, config) {
                    return false
                }
            } finally {
                this.rime.config_close(config)
            }
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
