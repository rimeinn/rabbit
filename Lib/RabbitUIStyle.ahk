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

class UIStyle {
    static use_dark := false
    static font_face := "Microsoft YaHei UI"
    static label_font_face := "Microsoft YaHei UI"
    static comment_font_face := "Microsoft YaHei UI"
    static font_point := 14
    static label_font_point := 14
    static comment_font_point := 14
    static label_format := "{}. "

    static border_width := 2
    static corner_radius := 6
    static round_corner := 4
    static margin_x := 6
    static margin_y := 6
    static min_width := 160

    static border_color := 0xffe0e0e0
    static text_color := 0xff000000
    static back_color := 0xffeeeeec
    static candidate_text_color := 0xff000000
    static candidate_back_color := 0xffeeeeec
    static label_color := 0xff000000
    static comment_text_color := 0xff000000
    static hilited_text_color := 0xff000000
    static hilited_back_color := 0xffd4d4d4
    static hilited_candidate_text_color := 0xffffffff
    static hilited_candidate_back_color := 0xff0a3afa
    static hilited_label_color := 0xffffffff
    static hilited_comment_text_color   := 0xff000000

    static Update(config, initialize) {
        global rime
        local fmt, cr, r, mx, my, w, color

        if !rime || !config {
            return
        }
        UIStyle.use_dark := false
        UIStyle.font_face := rime.config_get_string(config, "style/font_face")
        if !UIStyle.font_face {
            UIStyle.font_face := "Microsoft YaHei UI"
        }
        UIStyle.label_font_face := rime.config_get_string(config, "style/label_font_face")
        if !UIStyle.label_font_face {
            UIStyle.label_font_face := "Microsoft YaHei UI"
        }
        UIStyle.comment_font_face := rime.config_get_string(config, "style/comment_font_face")
        if !UIStyle.comment_font_face {
            UIStyle.comment_font_face := "Microsoft YaHei UI"
        }
        UIStyle.font_point := rime.config_get_int(config, "style/font_point")
        if UIStyle.font_point <= 0 {
            UIStyle.font_point := 14
        }
        UIStyle.label_font_point := rime.config_get_int(config, "style/label_font_point")
        if UIStyle.label_font_point <= 0 {
            UIStyle.label_font_point := 14
        }
        UIStyle.comment_font_point := rime.config_get_int(config, "style/comment_font_point")
        if UIStyle.comment_font_point <= 0 {
            UIStyle.comment_font_point := 14
        }
        if rime.config_test_get_string(config, "style/label_format", &fmt) && fmt {
            UIStyle.label_format := fmt
        }
        if rime.config_test_get_int(config, "style/layout/corner_radius", &cr) && cr >= 0 {
            UIStyle.corner_radius := cr
        }
        if rime.config_test_get_int(config, "style/layout/round_corner", &r) && r >= 0 {
            UIStyle.round_corner := r
        }
        if rime.config_test_get_int(config, "style/layout/margin_x", &mx) && mx >= 0 {
            UIStyle.margin_x := mx
        }
        if rime.config_test_get_int(config, "style/layout/margin_y", &my) && my >= 0 {
            UIStyle.margin_y := my
        }
        if rime.config_test_get_int(config, "style/layout/min_width", &w) && w >= 0 {
            UIStyle.min_width := w
        }
        if initialize && (color := rime.config_get_string(config, "style/color_scheme")) {
            UIStyle.UpdateColor(config, color)
        }
    }

    static UpdateColor(config, color) {
        global rime
        local buffer, cfmt

        if color || (buffer := rime.config_get_string(config, "style/color_scheme")) {
            local prefix := "preset_color_schemes/" . (color ? color : buffer)
            local fmt := "argb" ; different from Weasel
            if (cfmt := rime.config_get_string(config, prefix . "/color_format")) {
                if cfmt = "argb" || cfmt = "rgba" || cfmt = "abgr" {
                    fmt := cfmt
                }
            }

            UIStyle.border_color := UIStyle.GetColor(config, prefix . "/border_color", fmt, 0xffe0e0e0)
            UIStyle.text_color := UIStyle.GetColor(config, prefix . "/text_color", fmt, 0xff000000)
            UIStyle.back_color := UIStyle.GetColor(config, prefix . "/back_color", fmt, 0xffeceeee)
            UIStyle.candidate_text_color := UIStyle.GetColor(config, prefix . "/candidate_text_color", fmt, UIStyle.text_color)
            UIStyle.candidate_back_color := UIStyle.GetColor(config, prefix . "/candidate_back_color", fmt, UIStyle.back_color)
            UIStyle.label_color := UIStyle.GetColor(config, prefix . "/label_color", fmt, UIStyle.BlendColors(UIStyle.candidate_text_color, UIStyle.candidate_back_color))
            UIStyle.comment_text_color := UIStyle.GetColor(config, prefix . "/comment_text_color", fmt, UIStyle.label_color)
            UIStyle.hilited_text_color := UIStyle.GetColor(config, prefix . "/hilited_text_color", fmt, UIStyle.text_color)
            UIStyle.hilited_back_color := UIStyle.GetColor(config, prefix . "/hilited_back_color", fmt, UIStyle.back_color)
            UIStyle.hilited_candidate_text_color := UIStyle.GetColor(config, prefix . "/hilited_candidate_text_color", fmt, UIStyle.hilited_text_color)
            UIStyle.hilited_candidate_back_color := UIStyle.GetColor(config, prefix . "/hilited_candidate_back_color", fmt, UIStyle.hilited_back_color)
            UIStyle.hilited_label_color := UIStyle.GetColor(config, prefix . "/hilited_label_color", fmt, UIStyle.BlendColors(UIStyle.hilited_candidate_text_color, UIStyle.hilited_candidate_back_color))
            UIStyle.hilited_comment_text_color := UIStyle.GetColor(config, prefix . "/hilited_comment_text_color", fmt, UIStyle.hilited_label_color)

            return true
        }
        return false
    }

    static BlendColors(fcolor, bcolor) {
        local foreground_a := (fcolor >> 24) & 0xff
        if foreground_a == 0xff {
            return fcolor
        }
        local foreground_r := (fcolor >> 16) & 0xff
        local foreground_g := (fcolor >> 8) & 0xff
        local foreground_b := fcolor & 0xff
        local background_a := (bcolor >> 24) & 0xff
        local background_r := (bcolor >> 16) & 0xff
        local background_g := (bcolor >> 8) & 0xff
        local background_b := bcolor & 0xff

        local foreground_alpha := foreground_a / 255.0
        local background_alpha := background_a / 255.0

        local result_alpha := foreground_alpha + background_alpha * (1 - foreground_alpha)

        local result_r := Integer((foreground_r * foreground_alpha + background_r * background_alpha * (1 - foreground_alpha)) / result_alpha)
        local result_g := Integer((foreground_g * foreground_alpha + background_g * background_alpha * (1 - foreground_alpha)) / result_alpha)
        local result_b := Integer((foreground_b * foreground_alpha + background_b * background_alpha * (1 - foreground_alpha)) / result_alpha)

        return (Integer(result_alpha) * 255 << 24) | (result_r << 16) | (result_g << 8) | result_b
    }

    static GetColor(config, key, fmt, fallback) {
        global rime
        local color, tmp

        if !rime.config_test_get_string(config, key, &color) {
            return fallback
        }
        local val := fallback
        make_opaque() {
            val := (fmt != "rgba") ? (val | 0xff000000) : ((val << 8) | 0x000000ff)
        }
        convert_color_to_argb(clr, format) {
            if format = "argb" {
                return clr & 0xffffffff
            } else if format = "abgr" {
                return ((clr & 0x00ff0000) >> 16) | (clr & 0x0000ff00) | ((clr & 0x000000ff) << 16) | (clr & 0xff000000)
            } else if format = "rgba" {
                return ((clr & 0x00ff00) << 8) | (clr & 0xff0000) | ((clr & 0x0000ff) >> 8) | (clr & 0xff000000)
            } else {
                return clr & 0xffffffff
            }
        }

        if RegExMatch(color, "i)^0x[0-9a-f]+$") {
            tmp := SubStr(RegExReplace(color, "i)0x"), 1, 8)
            switch StrLen(tmp) {
                case 6:
                    val := Integer("0x" . tmp)
                    make_opaque()
                case 3:
                    tmp := Format(
                        "{1}{1}{2}{2}{3}{3}",
                        SubStr(tmp, 1, 1),
                        SubStr(tmp, 2, 1),
                        SubStr(tmp, 3, 1)
                    )
                    val := Integer("0x" . tmp)
                    make_opaque()
                case 4:
                    tmp := Format(
                        "{1}{1}{2}{2}{3}{3}{4}{4}",
                        SubStr(tmp, 1, 1),
                        SubStr(tmp, 2, 1),
                        SubStr(tmp, 3, 1),
                        SubStr(tmp, 4, 1)
                    )
                    val := Integer("0x" . tmp)
                case 8:
                    val := Integer("0x" . tmp)
                default:
                    return fallback
            }
        } else {
            tmp := 0
            if !rime.config_test_get_int(config, key, &tmp) {
                return fallback
            }
            val := tmp
            make_opaque()
        }
        return convert_color_to_argb(val, fmt)
    }
}

RabbitIsUserDarkMode() {
    try {
        local data := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
    }
    if IsSet(data) && IsInteger(data) {
        return !data
    }
    return false
}

OnColorChange(wParam, lParam, msg, hWnd) {
    local config, color_name
    global rime, IS_DARK_MODE, box
    local old_dark := IS_DARK_MODE
    IS_DARK_MODE := RabbitIsUserDarkMode()
    if old_dark != IS_DARK_MODE {
        if (config := rime.config_open("rabbit")) {
            UIStyle.Update(config, true)
            if IS_DARK_MODE {
                if (color_name := rime.config_get_string(config, "style/color_scheme_dark")) {
                    UIStyle.use_dark := UIStyle.UpdateColor(config, color_name)
                }
            }

            rime.config_close(config)
            box.UpdateStyle(UIStyle)
        }
        DarkMode.set(IS_DARK_MODE)
    }
}

; https://www.autohotkey.com/boards/viewtopic.php?p=515002&sid=859605067314b6d823a026658547b66f#p515002
class DarkMode {
    static set(mode) {
        DllCall(DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "uxtheme", "ptr"), "ptr", 135, "ptr"), "int", mode)
        DllCall(DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "uxtheme", "ptr"), "ptr", 136, "ptr"))
    }
}
