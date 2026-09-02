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

class RabbitFontSpec {
    static MAX_CODE_POINT := 0x10ffff
    static FONT_WEIGHTS := Map(
        "thin", 100,
        "extra_light", 200,
        "ultra_light", 200,
        "light", 300,
        "semi_light", 350,
        "normal", 400,
        "medium", 500,
        "demi_bold", 600,
        "semi_bold", 600,
        "bold", 700,
        "extra_bold", 800,
        "ultra_bold", 800,
        "black", 900,
        "heavy", 900,
        "extra_black", 950,
        "ultra_black", 950
    )
    static FONT_STYLES := Map(
        "normal", 0,
        "oblique", 1,
        "italic", 2
    )

    __New(source, entries, font_weight, font_style, has_weight, has_style) {
        this.source := source
        this.entries := entries
        this.font_weight := font_weight
        this.font_style := font_style
        this.has_weight := has_weight
        this.has_style := has_style
        this.requires_custom_fallback := entries.Length > 1
            || entries[1].start_code_point != 0
            || entries[1].end_code_point != RabbitFontSpec.MAX_CODE_POINT
        this.legacy_family := this.FindLegacyFamily()
    }

    static Parse(value) {
        local entries := []
        local font_weight := 400
        local font_style := 0
        local has_weight := false
        local has_style := false
        local source := Trim(String(value))
        if !source {
            throw ValueError("Font setting cannot be empty.")
        }

        for index, unit in StrSplit(source, ",") {
            unit := Trim(unit)
            if !unit {
                throw ValueError("Font setting contains an empty fallback entry.")
            }
            entries.Push(this.ParseEntry(
                unit,
                index,
                &font_weight,
                &font_style,
                &has_weight,
                &has_style
            ))
        }
        return RabbitFontSpec(source, entries, font_weight, font_style, has_weight, has_style)
    }

    static ParseEntry(unit, index, &font_weight, &font_style, &has_weight, &has_style) {
        local fields := StrSplit(unit, ":")
        local family := Trim(fields.RemoveAt(1))
        local range_fields := []
        if !family {
            throw ValueError("Font family name cannot be empty.")
        }

        for field in fields {
            field := Trim(field)
            local normalized := StrLower(field)
            local is_weight := normalized && this.FONT_WEIGHTS.Has(normalized)
            local is_style := normalized && this.FONT_STYLES.Has(normalized)
            if is_weight || is_style {
                if index != 1 {
                    throw ValueError("Font weight and style are only allowed in the first fallback entry.")
                }
                ; "normal" names both default weight and style. Treat it as
                ; the first still-unspecified attribute; the result is the
                ; same when neither attribute was explicitly set.
                if is_weight && (!is_style || !has_weight) {
                    if has_weight {
                        throw ValueError("Font weight is specified more than once.")
                    }
                    font_weight := this.FONT_WEIGHTS[normalized]
                    has_weight := true
                    continue
                }
                if is_style {
                    if has_style {
                        throw ValueError("Font style is specified more than once.")
                    }
                    font_style := this.FONT_STYLES[normalized]
                    has_style := true
                    continue
                }
            }
            range_fields.Push(field)
        }

        if range_fields.Length > 2 {
            throw ValueError("Font fallback entry has more than two Unicode range fields.")
        }
        local start_code_point := range_fields.Length >= 1 && range_fields[1] != ""
            ? this.ParseCodePoint(range_fields[1])
            : 0
        local end_code_point := range_fields.Length >= 2 && range_fields[2] != ""
            ? this.ParseCodePoint(range_fields[2])
            : this.MAX_CODE_POINT
        if start_code_point > end_code_point {
            throw ValueError("Font fallback range start cannot exceed its end.")
        }
        return {
            family: family,
            start_code_point: start_code_point,
            end_code_point: end_code_point
        }
    }

    static ParseCodePoint(value) {
        if !RegExMatch(value, "i)^[0-9a-f]{1,6}$") {
            throw ValueError("Unicode code point must be an unprefixed hexadecimal value.")
        }
        local code_point := Integer("0x" . value)
        if code_point > this.MAX_CODE_POINT {
            throw ValueError("Unicode code point cannot exceed 10FFFF.")
        }
        return code_point
    }

    FindLegacyFamily() {
        for entry in this.entries {
            if entry.start_code_point = 0 && entry.end_code_point = RabbitFontSpec.MAX_CODE_POINT {
                return entry.family
            }
        }
        return this.entries[1].family
    }
}
