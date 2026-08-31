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

#Include RabbitUIStyleSnapshot.ahk

class RabbitColorScheme {
    static EDITABLE_COLOR_FIELDS := [
        { key: "back_color", label: "窗口背景" },
        { key: "border_color", label: "窗口边框" },
        { key: "text_color", label: "编码文字" },
        { key: "preedit_back_color", label: "编码背景" },
        { key: "hilited_text_color", label: "高亮编码文字" },
        { key: "hilited_back_color", label: "高亮编码背景" },
        { key: "candidate_text_color", label: "候选文字" },
        { key: "candidate_back_color", label: "候选背景" },
        { key: "label_color", label: "候选序号" },
        { key: "comment_text_color", label: "候选注释" },
        { key: "hilited_candidate_text_color", label: "高亮候选文字" },
        { key: "hilited_candidate_back_color", label: "高亮候选背景" },
        { key: "hilited_label_color", label: "高亮候选序号" },
        { key: "hilited_comment_text_color", label: "高亮候选注释" },
    ]

    __New(color_scheme_id, values, origin := "builtin", style := 0) {
        this.color_scheme_id := color_scheme_id
        this.values := RabbitColorScheme.CloneValue(values is Map ? values : Map())
        this.origin := origin
        this.color_format := this.GetColorFormat()
        this.name := this.values.Has("name") && this.values["name"] != ""
            ? String(this.values["name"])
            : color_scheme_id
        this.author := this.values.Has("author") ? String(this.values["author"]) : ""
        this.colors := this.ReadArgbColors()
        this.style := style ? style.With(this.colors) : RabbitUIStyleSnapshot(0, this.colors)
    }

    IsCustom() {
        return this.origin = "custom"
    }

    WithEdits(name, author, colors) {
        local values := RabbitColorScheme.CloneValue(this.values)
        values["name"] := Trim(name)
        if Trim(author) {
            values["author"] := Trim(author)
        } else if values.Has("author") {
            values.Delete("author")
        }
        values["color_format"] := this.color_format
        for key, argb in colors {
            values[key] := RabbitColorScheme.FormatConfigColor(argb, this.color_format)
        }
        return RabbitColorScheme(this.color_scheme_id, values, this.origin, this.style)
    }

    CopyAs(color_scheme_id, name, author := "") {
        local argb, key
        RabbitColorScheme.ValidateId(color_scheme_id)
        local values := RabbitColorScheme.CloneValue(this.values)
        for key, value in values {
            if RegExMatch(key, "i)_color$") {
                if !RabbitColorScheme.TryParseConfigColor(value, this.color_format, &argb) {
                    throw Error("无法转换颜色字段：" . key)
                }
                values[key] := RabbitColorScheme.FormatConfigColor(argb, "argb")
            }
        }
        values["name"] := Trim(name)
        if Trim(author) {
            values["author"] := Trim(author)
        } else if values.Has("author") {
            values.Delete("author")
        }
        values["color_format"] := "argb"
        return RabbitColorScheme(color_scheme_id, values, "custom", this.style)
    }

    static CreateDefault(color_scheme_id, name, author := "") {
        this.ValidateId(color_scheme_id)
        local defaults := RabbitUIStyleSnapshot()
        local values := Map(
            "name", Trim(name),
            "color_format", "argb"
        )
        if Trim(author) {
            values["author"] := Trim(author)
        }
        for field in this.EDITABLE_COLOR_FIELDS {
            values[field.key] := this.FormatConfigColor(defaults.%field.key%, "argb")
        }
        return RabbitColorScheme(color_scheme_id, values, "custom", defaults)
    }

    GetColorFormat() {
        local format := this.values.Has("color_format")
            ? StrLower(String(this.values["color_format"]))
            : "argb"
        return format = "argb" || format = "abgr" || format = "rgba" ? format : "argb"
    }

    ReadArgbColors() {
        local argb, key
        local result := Map()
        for key, value in this.values {
            if RegExMatch(key, "i)_color$")
                && RabbitColorScheme.TryParseConfigColor(value, this.color_format, &argb) {
                result[key] := argb
            }
        }
        return result
    }

    GetEditableColors() {
        local result := Map()
        for field in RabbitColorScheme.EDITABLE_COLOR_FIELDS {
            result[field.key] := this.colors.Has(field.key)
                ? this.colors[field.key]
                : this.style.%field.key%
        }
        return result
    }

    static ValidateId(color_scheme_id) {
        if !RegExMatch(color_scheme_id, "^[a-z0-9][a-z0-9_-]*$") {
            throw ValueError("配色标识只能包含小写字母、数字、下划线和连字符。")
        }
        return color_scheme_id
    }

    static ParseArgbText(text) {
        local normalized := StrUpper(Trim(text))
        if RegExMatch(normalized, "^#[0-9A-F]{6}$") {
            normalized := "#FF" . SubStr(normalized, 2)
        }
        if !RegExMatch(normalized, "^#[0-9A-F]{8}$") {
            throw ValueError("颜色必须使用 #RRGGBB 或 #AARRGGBB 格式。")
        }
        return Integer("0x" . SubStr(normalized, 2)) & 0xffffffff
    }

    static FormatArgbText(argb) {
        return Format("#{:08X}", argb & 0xffffffff)
    }

    static TryParseConfigColor(value, color_format, &argb) {
        local digits, number
        if Type(value) = "Integer" {
            number := value & 0xffffffff
            if number <= 0xffffff {
                switch color_format {
                    case "rgba":
                        number := ((number << 8) | 0xff) & 0xffffffff
                    default:
                        number := number | 0xff000000
                }
            }
            argb := this.ConvertToArgb(number, color_format)
            return true
        }
        if Type(value) != "String" || !RegExMatch(Trim(value), "i)^0x([0-9a-f]+)$", &match) {
            return false
        }
        digits := match[1]
        switch StrLen(digits) {
            case 3:
                digits := Format(
                    "{1}{1}{2}{2}{3}{3}",
                    SubStr(digits, 1, 1),
                    SubStr(digits, 2, 1),
                    SubStr(digits, 3, 1)
                )
            case 4:
                digits := Format(
                    "{1}{1}{2}{2}{3}{3}{4}{4}",
                    SubStr(digits, 1, 1),
                    SubStr(digits, 2, 1),
                    SubStr(digits, 3, 1),
                    SubStr(digits, 4, 1)
                )
            case 6, 8:
            default:
                return false
        }
        number := Integer("0x" . digits) & 0xffffffff
        if StrLen(digits) = 6 {
            switch color_format {
                case "rgba":
                    number := ((number << 8) | 0xff) & 0xffffffff
                default:
                    number := number | 0xff000000
            }
        }
        argb := this.ConvertToArgb(number, color_format)
        return true
    }

    static ConvertToArgb(value, color_format) {
        local alpha, blue, green, red
        switch color_format {
            case "abgr":
                alpha := value & 0xff000000
                blue := (value >> 16) & 0xff
                green := (value >> 8) & 0xff
                red := value & 0xff
                return (alpha | (red << 16) | (green << 8) | blue) & 0xffffffff
            case "rgba":
                red := (value >> 24) & 0xff
                green := (value >> 16) & 0xff
                blue := (value >> 8) & 0xff
                alpha := value & 0xff
                return ((alpha << 24) | (red << 16) | (green << 8) | blue) & 0xffffffff
            default:
                return value & 0xffffffff
        }
    }

    static ConvertFromArgb(argb, color_format) {
        local alpha := (argb >> 24) & 0xff
        local red := (argb >> 16) & 0xff
        local green := (argb >> 8) & 0xff
        local blue := argb & 0xff
        switch color_format {
            case "abgr":
                return ((alpha << 24) | (blue << 16) | (green << 8) | red) & 0xffffffff
            case "rgba":
                return ((red << 24) | (green << 16) | (blue << 8) | alpha) & 0xffffffff
            default:
                return argb & 0xffffffff
        }
    }

    static FormatConfigColor(argb, color_format) {
        return Format("0x{:08x}", this.ConvertFromArgb(argb, color_format))
    }

    static CloneValue(value) {
        local copy, item, key
        if value is Map {
            copy := Map()
            for key, item in value {
                copy[key] := this.CloneValue(item)
            }
            return copy
        }
        if value is Array {
            copy := []
            for item in value {
                copy.Push(this.CloneValue(item))
            }
            return copy
        }
        return value
    }
}
