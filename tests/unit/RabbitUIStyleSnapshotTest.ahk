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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitUIStyleSnapshot.ahk

RunTest("style snapshot copies constructor values", TestStyleSnapshotCopiesValues.Bind())
RunTest("style snapshot parses active and dark styles", TestStyleSnapshotParsing.Bind())
RunTest("style preview snapshot is independent", TestStylePreviewSnapshotIndependence.Bind())
RunTest("style snapshot blends transparent colors safely", TestStyleSnapshotBlendsTransparentColorsSafely.Bind())
RunTest("style snapshot loads transparent highlights", TestStyleSnapshotLoadsTransparentHighlights.Bind())

TestStyleSnapshotCopiesValues() {
    local values := Map(
        "font_face", "Snapshot Font",
        "preedit_font_face", "Snapshot Preedit Font",
        "font_point", 17
    )
    local style := RabbitUIStyleSnapshot(values)
    values["font_face"] := "Mutated Font"
    values["preedit_font_face"] := "Mutated Preedit Font"
    values["font_point"] := 19

    AssertEqual("Snapshot Font", style.font_face, "The snapshot retained its constructor Map.")
    AssertEqual(
        "Snapshot Preedit Font",
        style.preedit_font_face,
        "The snapshot retained its preedit font constructor value."
    )
    AssertEqual(17, style.font_point, "The snapshot retained its constructor Map value.")
    AssertEqual(
        "Microsoft YaHei UI",
        RabbitUIStyleSnapshot(Map("font_face", "Candidate Font")).preedit_font_face,
        "The default preedit font unexpectedly inherited the candidate font."
    )
    AssertEqual(2, style.border_width, "The default border width changed.")
    AssertEqual("stacked", style.layout_type, "The default candidate layout is not stacked.")
    AssertEqual(160, style.min_width, "The default stacked minimum width changed.")
    AssertEqual(160, style.min_height, "The default vertical text minimum height changed.")
    AssertEqual(0, style.candidate_padding_x, "The default horizontal candidate padding changed.")
    AssertEqual(0, style.candidate_padding_y, "The default vertical candidate padding changed.")
    AssertEqual(6, style.candidate_spacing, "The default candidate spacing changed.")
    AssertTrue(!style.vertical_text_left_to_right, "The default vertical text direction is not right to left.")
    AssertTrue(!style.floating_preedit, "Floating preedit is not disabled by default.")
    AssertEqual(0.8, style.floating_preedit_opacity, "The default floating preedit opacity changed.")
    AssertEqual(20, style.floating_preedit_min_height, "The default floating preedit minimum height changed.")

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
    AssertEqual("Configured Preedit Font", light_style.preedit_font_face, "The preedit font was not parsed.")
    AssertEqual(18, light_style.font_point, "The active font size was not parsed.")
    AssertEqual(5, light_style.border_width, "The active border width was not parsed.")
    AssertEqual(9, light_style.margin_x, "The active horizontal margin was not parsed.")
    AssertEqual(11, light_style.margin_y, "The active vertical margin was not parsed.")
    AssertEqual(3, light_style.candidate_padding_x, "The horizontal candidate padding was not parsed.")
    AssertEqual(4, light_style.candidate_padding_y, "The vertical candidate padding was not parsed.")
    AssertEqual(7, light_style.candidate_spacing, "The candidate spacing was not parsed.")
    AssertEqual(180, light_style.min_width, "The stacked minimum width was not parsed.")
    AssertEqual(240, light_style.min_height, "The vertical text minimum height was not parsed.")
    AssertEqual("flow", light_style.layout_type, "The active layout type was not parsed.")
    AssertTrue(light_style.vertical_text_left_to_right, "The vertical text direction was not parsed.")
    AssertTrue(light_style.floating_preedit, "Floating preedit was not parsed.")
    AssertEqual(0.25, light_style.floating_preedit_opacity, "Floating preedit opacity was not parsed.")
    AssertEqual(18, light_style.floating_preedit_min_height, "Floating preedit minimum height was not parsed.")
    AssertEqual(9, light_style.flow_rows, "Flow rows were not clamped to the supported range.")
    AssertEqual("center", light_style.align_type, "Candidate alignment was not parsed.")
    AssertEqual(0xff112233, light_style.text_color, "The active color scheme was not parsed.")
    AssertEqual(0xff778899, light_style.preedit_back_color, "The preedit background was not parsed.")
    AssertEqual(
        0xff445566,
        light_style.hilited_back_color,
        "The candidate-box preedit highlight did not retain the candidate background fallback."
    )
    AssertEqual(
        0xff778899,
        light_style.floating_preedit_hilited_back_color,
        "The floating preedit highlight did not inherit the floating background."
    )
    AssertEqual(false, light_style.use_dark, "The light snapshot was marked as dark.")

    AssertEqual("Configured Font", dark_style.font_face, "Dark selection changed the configured font.")
    AssertEqual(
        0xff010203,
        dark_style.preedit_back_color,
        "A missing dark preedit background did not inherit the dark candidate background."
    )
    AssertEqual(
        0xff010203,
        dark_style.floating_preedit_hilited_back_color,
        "A missing dark preedit highlight did not inherit the dark preedit background."
    )
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

TestStyleSnapshotBlendsTransparentColorsSafely() {
    AssertEqual(
        0x00000000,
        RabbitUIStyleSnapshot.BlendColors(0x00112233, 0x00445566),
        "Blending two transparent colors did not return transparent."
    )
    local blended := RabbitUIStyleSnapshot.BlendColors(0x80ff0000, 0x800000ff)
    AssertEqual(0xbf, (blended >> 24) & 0xff, "Blending translucent colors produced the wrong alpha.")
}

TestStyleSnapshotLoadsTransparentHighlights() {
    local rime_probe := RabbitUIStyleRimeProbe(Map(
        "style/color_scheme", "transparent",
        "preset_color_schemes/transparent/hilited_candidate_text_color", "0x00f6f6f6",
        "preset_color_schemes/transparent/hilited_candidate_back_color", "0x006dbcdb",
        "preset_color_schemes/transparent/hilited_label_color", "0xfff6f6f6"
    ))
    local style := RabbitUIStyleSnapshot.FromConfig(rime_probe, {})
    AssertEqual(0x00f6f6f6, style.hilited_candidate_text_color, "The transparent candidate text changed.")
    AssertEqual(0x006dbcdb, style.hilited_candidate_back_color, "The transparent candidate background changed.")
    AssertEqual(0xfff6f6f6, style.hilited_label_color, "The explicit highlighted label color was ignored.")
}

CreateStyleConfigValues() {
    return Map(
        "style/font_face", "Configured Font",
        "style/preedit_font_face", "Configured Preedit Font",
        "style/font_point", 18,
        "style/label_font_point", 16,
        "style/comment_font_point", 15,
        "style/layout/margin_x", 9,
        "style/layout/margin_y", 11,
        "style/layout/candidate_padding_x", 3,
        "style/layout/candidate_padding_y", 4,
        "style/layout/candidate_spacing", 7,
        "style/layout/border_width", 5,
        "style/layout/min_width", 180,
        "style/layout/min_height", 240,
        "style/layout/type", "flow",
        "style/vertical_text_left_to_right", true,
        "style/floating_preedit", true,
        "style/floating_preedit_opacity", 0.25,
        "style/floating_preedit_min_height", 18,
        "style/layout/flow_rows", 12,
        "style/layout/align_type", "center",
        "style/color_scheme", "light",
        "style/color_scheme_dark", "dark",
        "preset_color_schemes/light/text_color", "0x112233",
        "preset_color_schemes/light/back_color", "0x445566",
        "preset_color_schemes/light/preedit_back_color", "0x778899",
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

    config_test_get_double(config, key, &value) {
        if !this.values.Has(key) {
            return false
        }
        value := this.values[key]
        return true
    }

    config_test_get_bool(config, key, &value) {
        if !this.values.Has(key) {
            return false
        }
        value := this.values[key]
        return true
    }
}
