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

class RabbitUIStyleSnapshot {
    __New(values := 0, overrides := 0) {
        ; Copy supported scalar values so published snapshots do not retain mutable input containers.
        this.use_dark := this.GetValue(overrides, "use_dark", this.GetValue(values, "use_dark", false))
        this.font_face := this.GetValue(
            overrides, "font_face", this.GetValue(values, "font_face", "Microsoft YaHei UI"))
        this.preedit_font_face := this.GetValue(
            overrides,
            "preedit_font_face",
            this.GetValue(values, "preedit_font_face", "Microsoft YaHei UI")
        )
        this.label_font_face := this.GetValue(
            overrides, "label_font_face", this.GetValue(values, "label_font_face", "Microsoft YaHei UI"))
        this.comment_font_face := this.GetValue(
            overrides, "comment_font_face", this.GetValue(values, "comment_font_face", "Microsoft YaHei UI"))
        this.font_point := this.GetValue(overrides, "font_point", this.GetValue(values, "font_point", 14))
        this.label_font_point := this.GetValue(
            overrides, "label_font_point", this.GetValue(values, "label_font_point", 14))
        this.comment_font_point := this.GetValue(
            overrides, "comment_font_point", this.GetValue(values, "comment_font_point", 14))
        this.label_format := this.GetValue(overrides, "label_format", this.GetValue(values, "label_format", "{}. "))

        this.border_width := this.GetValue(overrides, "border_width", this.GetValue(values, "border_width", 2))
        this.corner_radius := this.GetValue(overrides, "corner_radius", this.GetValue(values, "corner_radius", 6))
        this.round_corner := this.GetValue(overrides, "round_corner", this.GetValue(values, "round_corner", 4))
        this.margin_x := this.GetValue(overrides, "margin_x", this.GetValue(values, "margin_x", 6))
        this.margin_y := this.GetValue(overrides, "margin_y", this.GetValue(values, "margin_y", 6))
        this.min_width := this.GetValue(overrides, "min_width", this.GetValue(values, "min_width", 160))
        this.min_height := this.GetValue(overrides, "min_height", this.GetValue(values, "min_height", 160))
        this.layout_type := this.GetValue(overrides, "layout_type", this.GetValue(values, "layout_type", "stacked"))
        this.vertical_text_left_to_right := this.GetValue(
            overrides,
            "vertical_text_left_to_right",
            this.GetValue(values, "vertical_text_left_to_right", false)
        )
        this.floating_preedit := this.GetValue(
            overrides,
            "floating_preedit",
            this.GetValue(values, "floating_preedit", false)
        )
        this.floating_preedit_opacity := Min(1, Max(0, this.GetValue(
            overrides,
            "floating_preedit_opacity",
            this.GetValue(values, "floating_preedit_opacity", 0.8)
        )))
        this.floating_preedit_min_height := Max(0, this.GetValue(
            overrides,
            "floating_preedit_min_height",
            this.GetValue(values, "floating_preedit_min_height", 20)
        ))
        this.flow_rows := this.GetValue(overrides, "flow_rows", this.GetValue(values, "flow_rows", 5))
        this.align_type := this.GetValue(overrides, "align_type", this.GetValue(values, "align_type", "top"))

        this.border_color := this.GetValue(
            overrides, "border_color", this.GetValue(values, "border_color", 0xffe0e0e0))
        this.text_color := this.GetValue(
            overrides, "text_color", this.GetValue(values, "text_color", 0xff000000))
        this.back_color := this.GetValue(
            overrides, "back_color", this.GetValue(values, "back_color", 0xffeeeeec))
        this.preedit_back_color := this.GetValue(
            overrides,
            "preedit_back_color",
            this.GetValue(values, "preedit_back_color", this.back_color)
        )
        this.candidate_text_color := this.GetValue(
            overrides, "candidate_text_color", this.GetValue(values, "candidate_text_color", 0xff000000))
        this.candidate_back_color := this.GetValue(
            overrides, "candidate_back_color", this.GetValue(values, "candidate_back_color", 0xffeeeeec))
        this.label_color := this.GetValue(
            overrides, "label_color", this.GetValue(values, "label_color", 0xff000000))
        this.comment_text_color := this.GetValue(
            overrides, "comment_text_color", this.GetValue(values, "comment_text_color", 0xff000000))
        this.hilited_text_color := this.GetValue(
            overrides, "hilited_text_color", this.GetValue(values, "hilited_text_color", 0xff000000))
        this.hilited_back_color := this.GetValue(
            overrides, "hilited_back_color", this.GetValue(values, "hilited_back_color", 0xffd4d4d4))
        this.floating_preedit_hilited_back_color := this.GetValue(
            overrides,
            "floating_preedit_hilited_back_color",
            this.GetValue(values, "floating_preedit_hilited_back_color", this.preedit_back_color)
        )
        this.hilited_candidate_text_color := this.GetValue(
            overrides,
            "hilited_candidate_text_color",
            this.GetValue(values, "hilited_candidate_text_color", 0xffffffff)
        )
        this.hilited_candidate_back_color := this.GetValue(
            overrides,
            "hilited_candidate_back_color",
            this.GetValue(values, "hilited_candidate_back_color", 0xff0a3afa)
        )
        this.hilited_label_color := this.GetValue(
            overrides, "hilited_label_color", this.GetValue(values, "hilited_label_color", 0xffffffff))
        this.hilited_comment_text_color := this.GetValue(
            overrides,
            "hilited_comment_text_color",
            this.GetValue(values, "hilited_comment_text_color", 0xff000000)
        )
    }

    With(overrides) {
        return RabbitUIStyleSnapshot(this, overrides)
    }

    static FromConfig(rime_api, config, dark_mode := false, color_scheme?) {
        local fmt, bw, cr, r, mx, my, w, h, vertical_text_left_to_right, floating_preedit
        local floating_preedit_opacity
        local floating_preedit_min_height
        local flow_rows, layout_type, align_type
        local selected_color_scheme, dark_color_scheme
        local values := Map()

        if !rime_api || !config {
            return RabbitUIStyleSnapshot()
        }

        values["font_face"] := rime_api.config_get_string(config, "style/font_face")
        if !values["font_face"] {
            values["font_face"] := "Microsoft YaHei UI"
        }
        values["preedit_font_face"] := rime_api.config_get_string(config, "style/preedit_font_face")
        if !values["preedit_font_face"] {
            values["preedit_font_face"] := "Microsoft YaHei UI"
        }
        values["label_font_face"] := rime_api.config_get_string(config, "style/label_font_face")
        if !values["label_font_face"] {
            values["label_font_face"] := "Microsoft YaHei UI"
        }
        values["comment_font_face"] := rime_api.config_get_string(config, "style/comment_font_face")
        if !values["comment_font_face"] {
            values["comment_font_face"] := "Microsoft YaHei UI"
        }

        values["font_point"] := rime_api.config_get_int(config, "style/font_point")
        if values["font_point"] <= 0 {
            values["font_point"] := 14
        }
        values["label_font_point"] := rime_api.config_get_int(config, "style/label_font_point")
        if values["label_font_point"] <= 0 {
            values["label_font_point"] := 14
        }
        values["comment_font_point"] := rime_api.config_get_int(config, "style/comment_font_point")
        if values["comment_font_point"] <= 0 {
            values["comment_font_point"] := 14
        }

        if rime_api.config_test_get_string(config, "style/label_format", &fmt) && fmt {
            values["label_format"] := fmt
        }
        if rime_api.config_test_get_int(config, "style/layout/border_width", &bw) && bw >= 0 {
            values["border_width"] := bw
        }
        if rime_api.config_test_get_int(config, "style/layout/corner_radius", &cr) && cr >= 0 {
            values["corner_radius"] := cr
        }
        if rime_api.config_test_get_int(config, "style/layout/round_corner", &r) && r >= 0 {
            values["round_corner"] := r
        }
        if rime_api.config_test_get_int(config, "style/layout/margin_x", &mx) && mx >= 0 {
            values["margin_x"] := mx
        }
        if rime_api.config_test_get_int(config, "style/layout/margin_y", &my) && my >= 0 {
            values["margin_y"] := my
        }
        if rime_api.config_test_get_int(config, "style/layout/min_width", &w) && w >= 0 {
            values["min_width"] := w
        }
        if rime_api.config_test_get_int(config, "style/layout/min_height", &h) && h >= 0 {
            values["min_height"] := h
        }
        if rime_api.config_test_get_string(config, "style/layout/type", &layout_type) {
            layout_type := StrLower(layout_type)
            if layout_type = "stacked" || layout_type = "flow" || layout_type = "vertical_text" {
                values["layout_type"] := layout_type
            }
        }
        if rime_api.config_test_get_bool(
            config,
            "style/vertical_text_left_to_right",
            &vertical_text_left_to_right
        ) {
            values["vertical_text_left_to_right"] := vertical_text_left_to_right
        }
        if rime_api.config_test_get_bool(config, "style/floating_preedit", &floating_preedit) {
            values["floating_preedit"] := floating_preedit
        }
        if rime_api.config_test_get_double(
            config,
            "style/floating_preedit_opacity",
            &floating_preedit_opacity
        ) {
            values["floating_preedit_opacity"] := Min(1, Max(0, floating_preedit_opacity))
        }
        if rime_api.config_test_get_int(
            config,
            "style/floating_preedit_min_height",
            &floating_preedit_min_height
        ) && floating_preedit_min_height >= 0 {
            values["floating_preedit_min_height"] := floating_preedit_min_height
        }
        if rime_api.config_test_get_int(config, "style/layout/flow_rows", &flow_rows) {
            values["flow_rows"] := Min(9, Max(1, flow_rows))
        }
        if rime_api.config_test_get_string(config, "style/layout/align_type", &align_type) {
            align_type := StrLower(align_type)
            if align_type = "top" || align_type = "center" || align_type = "bottom" {
                values["align_type"] := align_type
            }
        }

        selected_color_scheme := IsSet(color_scheme)
            ? color_scheme
            : rime_api.config_get_string(config, "style/color_scheme")
        if selected_color_scheme {
            this.ApplyColorScheme(rime_api, config, selected_color_scheme, values)
        }
        if dark_mode && !IsSet(color_scheme) {
            dark_color_scheme := rime_api.config_get_string(config, "style/color_scheme_dark")
            if dark_color_scheme {
                this.ApplyColorScheme(rime_api, config, dark_color_scheme, values)
                values["use_dark"] := true
            }
        }

        return RabbitUIStyleSnapshot(values)
    }

    static ApplyColorScheme(rime_api, config, color_scheme, values) {
        local cfmt
        local prefix := "preset_color_schemes/" . color_scheme
        local fmt := "argb" ; different from Weasel
        if (cfmt := rime_api.config_get_string(config, prefix . "/color_format")) {
            if cfmt = "argb" || cfmt = "rgba" || cfmt = "abgr" {
                fmt := cfmt
            }
        }

        values["border_color"] := this.GetColor(
            rime_api, config, prefix . "/border_color", fmt, 0xffe0e0e0)
        values["text_color"] := this.GetColor(
            rime_api, config, prefix . "/text_color", fmt, 0xff000000)
        values["back_color"] := this.GetColor(
            rime_api, config, prefix . "/back_color", fmt, 0xffeceeee)
        values["preedit_back_color"] := this.GetColor(
            rime_api, config, prefix . "/preedit_back_color", fmt, values["back_color"])
        values["candidate_text_color"] := this.GetColor(
            rime_api, config, prefix . "/candidate_text_color", fmt, values["text_color"])
        values["candidate_back_color"] := this.GetColor(
            rime_api, config, prefix . "/candidate_back_color", fmt, values["back_color"])
        values["label_color"] := this.GetColor(
            rime_api,
            config,
            prefix . "/label_color",
            fmt,
            this.BlendColors(values["candidate_text_color"], values["candidate_back_color"])
        )
        values["comment_text_color"] := this.GetColor(
            rime_api, config, prefix . "/comment_text_color", fmt, values["label_color"])
        values["hilited_text_color"] := this.GetColor(
            rime_api, config, prefix . "/hilited_text_color", fmt, values["text_color"])
        values["hilited_back_color"] := this.GetColor(
            rime_api, config, prefix . "/hilited_back_color", fmt, values["back_color"])
        values["floating_preedit_hilited_back_color"] := this.GetColor(
            rime_api,
            config,
            prefix . "/hilited_back_color",
            fmt,
            values["preedit_back_color"]
        )
        values["hilited_candidate_text_color"] := this.GetColor(
            rime_api,
            config,
            prefix . "/hilited_candidate_text_color",
            fmt,
            values["hilited_text_color"]
        )
        values["hilited_candidate_back_color"] := this.GetColor(
            rime_api,
            config,
            prefix . "/hilited_candidate_back_color",
            fmt,
            values["hilited_back_color"]
        )
        values["hilited_label_color"] := this.GetColor(
            rime_api,
            config,
            prefix . "/hilited_label_color",
            fmt,
            this.BlendColors(
                values["hilited_candidate_text_color"],
                values["hilited_candidate_back_color"]
            )
        )
        values["hilited_comment_text_color"] := this.GetColor(
            rime_api,
            config,
            prefix . "/hilited_comment_text_color",
            fmt,
            values["hilited_label_color"]
        )
    }

    static BlendColors(foreground_color, background_color) {
        local foreground_a := (foreground_color >> 24) & 0xff
        if foreground_a == 0xff {
            return foreground_color
        }
        local foreground_r := (foreground_color >> 16) & 0xff
        local foreground_g := (foreground_color >> 8) & 0xff
        local foreground_b := foreground_color & 0xff
        local background_a := (background_color >> 24) & 0xff
        local background_r := (background_color >> 16) & 0xff
        local background_g := (background_color >> 8) & 0xff
        local background_b := background_color & 0xff

        local foreground_alpha := foreground_a / 255.0
        local background_alpha := background_a / 255.0
        local result_alpha := foreground_alpha + background_alpha * (1 - foreground_alpha)
        if result_alpha == 0 {
            return 0x00000000
        }
        local result_r := Integer(
            (foreground_r * foreground_alpha + background_r * background_alpha * (1 - foreground_alpha))
            / result_alpha
        )
        local result_g := Integer(
            (foreground_g * foreground_alpha + background_g * background_alpha * (1 - foreground_alpha))
            / result_alpha
        )
        local result_b := Integer(
            (foreground_b * foreground_alpha + background_b * background_alpha * (1 - foreground_alpha))
            / result_alpha
        )

        return (Integer(result_alpha * 255) << 24) | (result_r << 16) | (result_g << 8) | result_b
    }

    static GetColor(rime_api, config, key, fmt, fallback) {
        local color, tmp
        if !rime_api.config_test_get_string(config, key, &color) {
            return fallback
        }
        local value := fallback
        MakeOpaque() {
            value := (fmt != "rgba") ? (value | 0xff000000) : ((value << 8) | 0x000000ff)
        }
        ConvertColorToArgb(color_value, format) {
            if format = "argb" {
                return color_value & 0xffffffff
            } else if format = "abgr" {
                return ((color_value & 0x00ff0000) >> 16)
                    | (color_value & 0x0000ff00)
                    | ((color_value & 0x000000ff) << 16)
                    | (color_value & 0xff000000)
            } else if format = "rgba" {
                return ((color_value & 0x00ff00) << 8)
                    | (color_value & 0xff0000)
                    | ((color_value & 0x0000ff) >> 8)
                    | (color_value & 0xff000000)
            } else {
                return color_value & 0xffffffff
            }
        }

        if RegExMatch(color, "i)^0x[0-9a-f]+$") {
            tmp := SubStr(RegExReplace(color, "i)0x"), 1, 8)
            switch StrLen(tmp) {
                case 6:
                    value := Integer("0x" . tmp)
                    MakeOpaque()
                case 3:
                    tmp := Format(
                        "{1}{1}{2}{2}{3}{3}",
                        SubStr(tmp, 1, 1),
                        SubStr(tmp, 2, 1),
                        SubStr(tmp, 3, 1)
                    )
                    value := Integer("0x" . tmp)
                    MakeOpaque()
                case 4:
                    tmp := Format(
                        "{1}{1}{2}{2}{3}{3}{4}{4}",
                        SubStr(tmp, 1, 1),
                        SubStr(tmp, 2, 1),
                        SubStr(tmp, 3, 1),
                        SubStr(tmp, 4, 1)
                    )
                    value := Integer("0x" . tmp)
                case 8:
                    value := Integer("0x" . tmp)
                default:
                    return fallback
            }
        } else {
            tmp := 0
            if !rime_api.config_test_get_int(config, key, &tmp) {
                return fallback
            }
            value := tmp
            MakeOpaque()
        }
        return ConvertColorToArgb(value, fmt)
    }

    GetValue(values, name, fallback) {
        if !values {
            return fallback
        }
        if values is Map {
            return values.Has(name) ? values[name] : fallback
        }
        return HasProp(values, name) ? values.%name% : fallback
    }
}
