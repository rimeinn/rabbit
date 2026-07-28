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

#Include <RabbitUIStyleSnapshot>

RunTest("style snapshot copies constructor values", TestStyleSnapshotCopiesValues.Bind())
RunTest("style snapshot parses active and dark styles", TestStyleSnapshotParsing.Bind())
RunTest("style preview snapshot is independent", TestStylePreviewSnapshotIndependence.Bind())

TestStyleSnapshotCopiesValues() {
    local values := Map("font_face", "Snapshot Font", "font_point", 17)
    local style := RabbitUIStyleSnapshot(values)
    values["font_face"] := "Mutated Font"
    values["font_point"] := 19

    AssertEqual("Snapshot Font", style.font_face, "The snapshot retained its constructor Map.")
    AssertEqual(17, style.font_point, "The snapshot retained its constructor Map value.")

    local overrides := Map("font_point", 21)
    local updated_style := style.With(overrides)
    overrides["font_point"] := 23
    AssertEqual(17, style.font_point, "With() mutated the source snapshot.")
    AssertEqual(21, updated_style.font_point, "With() retained its override Map.")
}

TestStyleSnapshotParsing() {
    local rime_probe := RabbitUIStyleRimeProbe(CreateStyleConfigValues())
    local config := {}
    local light_style := RabbitUIStyleSnapshot.FromConfig(rime_probe, config)
    local dark_style := RabbitUIStyleSnapshot.FromConfig(rime_probe, config, true)

    AssertEqual("Configured Font", light_style.font_face, "The active font was not parsed.")
    AssertEqual(18, light_style.font_point, "The active font size was not parsed.")
    AssertEqual(9, light_style.margin_x, "The active horizontal margin was not parsed.")
    AssertEqual(0xff112233, light_style.text_color, "The active color scheme was not parsed.")
    AssertEqual(false, light_style.use_dark, "The light snapshot was marked as dark.")

    AssertEqual("Configured Font", dark_style.font_face, "Dark selection changed the configured font.")
    AssertEqual(0xffddeeff, dark_style.text_color, "The dark color scheme was not parsed.")
    AssertEqual(true, dark_style.use_dark, "The dark snapshot was not marked as dark.")
}

TestStylePreviewSnapshotIndependence() {
    local rime_probe := RabbitUIStyleRimeProbe(CreateStyleConfigValues())
    local config := {}
    local active_style := RabbitUIStyleSnapshot.FromConfig(rime_probe, config)
    local preview_style := RabbitUIStyleSnapshot.FromConfig(rime_probe, config, false, "dark")

    AssertEqual(0xff112233, active_style.text_color, "Preview parsing mutated the active snapshot.")
    AssertEqual(0xffddeeff, preview_style.text_color, "The requested preview scheme was not parsed.")
    AssertEqual(false, preview_style.use_dark, "An explicit preview scheme was marked as system dark mode.")
}

CreateStyleConfigValues() {
    return Map(
        "style/font_face", "Configured Font",
        "style/font_point", 18,
        "style/label_font_point", 16,
        "style/comment_font_point", 15,
        "style/layout/margin_x", 9,
        "style/color_scheme", "light",
        "style/color_scheme_dark", "dark",
        "preset_color_schemes/light/text_color", "0x112233",
        "preset_color_schemes/light/back_color", "0x445566",
        "preset_color_schemes/dark/text_color", "0xddeeff",
        "preset_color_schemes/dark/back_color", "0x010203"
    )
}

class RabbitUIStyleRimeProbe {
    __New(values) {
        this.values := values
    }

    config_get_string(config, key) {
        return this.values.Has(key) ? this.values[key] : ""
    }

    config_get_int(config, key) {
        return this.values.Has(key) ? this.values[key] : 0
    }

    config_test_get_string(config, key, &value) {
        if !this.values.Has(key) {
            return false
        }
        value := this.values[key]
        return true
    }

    config_test_get_int(config, key, &value) {
        if !this.values.Has(key) {
            return false
        }
        value := this.values[key]
        return true
    }
}
