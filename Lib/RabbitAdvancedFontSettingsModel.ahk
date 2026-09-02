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

#Include RabbitFontSpec.ahk

class RabbitAdvancedFontSettingsModel {
    static ROLES := [
        { key: "font_face", label: "候选文字" },
        { key: "preedit_font_face", label: "预编辑文字" },
        { key: "label_font_face", label: "候选序号" },
        { key: "comment_font_face", label: "候选注释" }
    ]

    __New(values) {
        this.specs := Map()
        for role in RabbitAdvancedFontSettingsModel.ROLES {
            this.specs[role.key] := RabbitFontSpec.Parse(this.GetValue(values, role.key))
        }
    }

    GetSpec(key) {
        if !this.specs.Has(key) {
            throw ValueError("Unknown font setting role: " . key)
        }
        return this.specs[key]
    }

    GetValues() {
        local values := Map()
        for role in RabbitAdvancedFontSettingsModel.ROLES {
            values[role.key] := this.specs[role.key].Serialize()
        }
        return values
    }

    SetSource(key, source) {
        this.GetSpec(key)
        this.specs[key] := RabbitFontSpec.Parse(source)
    }

    AddEntry(key, family := "Microsoft YaHei UI") {
        local spec := this.GetSpec(key)
        local entries := this.CloneEntries(spec.entries)
        entries.Push({
            family: family,
            start_code_point: 0,
            end_code_point: RabbitFontSpec.MAX_CODE_POINT
        })
        this.ReplaceEntries(key, entries)
        return entries.Length
    }

    UpdateEntry(key, index, family, start_code_point, end_code_point) {
        local spec := this.GetSpec(key)
        local entries := this.CloneEntries(spec.entries)
        family := Trim(family)
        if index < 1 || index > entries.Length {
            throw IndexError("Font fallback entry index is out of range.")
        }
        if !family {
            throw ValueError("字体名称不能为空。")
        }
        this.ValidateRange(start_code_point, end_code_point)
        entries[index] := {
            family: family,
            start_code_point: start_code_point,
            end_code_point: end_code_point
        }
        this.ReplaceEntries(key, entries)
    }

    DeleteEntry(key, index) {
        local spec := this.GetSpec(key)
        local entries := this.CloneEntries(spec.entries)
        if entries.Length = 1 {
            throw ValueError("每类文字至少需要保留一个字体。")
        }
        if index < 1 || index > entries.Length {
            throw IndexError("Font fallback entry index is out of range.")
        }
        entries.RemoveAt(index)
        this.ReplaceEntries(key, entries)
        return Min(index, entries.Length)
    }

    MoveEntry(key, index, offset) {
        local spec := this.GetSpec(key)
        local entries := this.CloneEntries(spec.entries)
        local target := index + offset
        if index < 1 || index > entries.Length || target < 1 || target > entries.Length {
            return index
        }
        local entry := entries.RemoveAt(index)
        entries.InsertAt(target, entry)
        this.ReplaceEntries(key, entries)
        return target
    }

    SetAttributes(key, font_weight, font_style) {
        local spec := this.GetSpec(key)
        this.specs[key] := this.CreateSpec(
            spec.entries,
            font_weight,
            font_style,
            font_weight != 400,
            font_style != 0
        )
    }

    ReplaceEntries(key, entries) {
        local spec := this.GetSpec(key)
        this.specs[key] := this.CreateSpec(
            entries,
            spec.font_weight,
            spec.font_style,
            spec.has_weight,
            spec.has_style
        )
    }

    CreateSpec(entries, font_weight, font_style, has_weight, has_style) {
        local spec := RabbitFontSpec(
            "",
            this.CloneEntries(entries),
            font_weight,
            font_style,
            has_weight,
            has_style
        )
        return RabbitFontSpec.Parse(spec.Serialize())
    }

    CloneEntries(entries) {
        local result := []
        for entry in entries {
            result.Push({
                family: entry.family,
                start_code_point: entry.start_code_point,
                end_code_point: entry.end_code_point
            })
        }
        return result
    }

    ValidateRange(start_code_point, end_code_point) {
        if start_code_point < 0 || end_code_point > RabbitFontSpec.MAX_CODE_POINT {
            throw ValueError("Unicode 码位必须在 0 到 10FFFF 之间。")
        }
        if start_code_point > end_code_point {
            throw ValueError("Unicode 范围起点不能大于终点。")
        }
    }

    GetValue(values, key) {
        if values is Map {
            if !values.Has(key) {
                throw ValueError("Missing font setting: " . key)
            }
            return values[key]
        }
        if !HasProp(values, key) {
            throw ValueError("Missing font setting: " . key)
        }
        return values.%key%
    }
}
