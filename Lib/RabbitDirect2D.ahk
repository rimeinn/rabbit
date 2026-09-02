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
#Include Direct2D/Direct2D.ahk

class RabbitDirect2D extends Direct2D {
    static INVALID_FALLBACK_FAMILY := "_RabbitInvalidFallbackFont_"

    __New(target?) {
        this.font_specs := Map()
        if IsSet(target) {
            super.__New(target)
        } else {
            super.__New()
        }
    }

    GetSavedOrCreateTextFormat(
        font_name,
        font_size,
        font_weight := 400,
        font_style := 0,
        horizon_align := 0,
        vertical_align := 0,
        reading_direction := 0,
        flow_direction := 0
    ) {
        local spec := this.GetFontSpec(font_name)
        local resolved_weight := spec.has_weight ? spec.font_weight : font_weight
        local resolved_style := spec.has_style ? spec.font_style : font_style
        local base_family := spec.requires_custom_fallback
            ? RabbitDirect2D.INVALID_FALLBACK_FAMILY
            : spec.entries[1].family
        return super.GetSavedOrCreateTextFormat(
            base_family,
            font_size,
            resolved_weight,
            resolved_style,
            horizon_align,
            vertical_align,
            reading_direction,
            flow_direction,
            spec.requires_custom_fallback ? spec.entries : 0,
            spec.source
        )
    }

    GetFontSpec(font_name) {
        local key := String(font_name)
        if !this.font_specs.Has(key) {
            this.font_specs[key] := RabbitFontSpec.Parse(key)
        }
        return this.font_specs[key]
    }
}
