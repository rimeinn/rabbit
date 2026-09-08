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
RunTest("style snapshot reloads shadows and clears missing dark colors", TestStyleSnapshotShadows)
RunTest("style snapshot falls back independent preedit layout", TestStyleSnapshotPreeditFallback)

TestStyleSnapshotShadows() {
    local format, color, values, style, dark
    for format, color in Map("argb", "0x80402010", "abgr", "0x80102040", "rgba", "0x40201080") {
        values := Map("style/color_scheme", "light", "style/color_scheme_dark", "dark",
            "style/layout/shadow_radius", 8, "style/layout/shadow_offset_x", -4,
            "preset_color_schemes/light/color_format", format,
            "preset_color_schemes/light/shadow_color", color,
            "preset_color_schemes/light/candidate_shadow_color", "0x00000000")
        style := RabbitUIStyleSnapshot.FromConfig(RabbitUIStyleRimeProbe(values), {})
        AssertEqual(8, style.shadow_radius, "The configured shadow radius was lost.")
        AssertEqual(-4, style.shadow_offset_x, "Negative configured offsets were lost.")
        AssertEqual(0x80402010, style.shadow_color, "The configured shadow color changed.")
        AssertEqual(0, style.candidate_shadow_color, "Transparent configured shadows became opaque.")
        dark := style.WithColorSchemeFromConfig(RabbitUIStyleRimeProbe(values), {}, "dark")
        AssertEqual(0, dark.shadow_color, "Switching schemes retained a previous shadow color.")
    }
}

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
    AssertEqual(3, light_style.preedit_border_width, "The preedit border width was not parsed.")
    AssertEqual(9, light_style.margin_x, "The active horizontal margin was not parsed.")
    AssertEqual(11, light_style.margin_y, "The active vertical margin was not parsed.")
    AssertEqual(2, light_style.preedit_margin_x, "The preedit horizontal margin was not parsed.")
    AssertEqual(4, light_style.preedit_margin_y, "The preedit vertical margin was not parsed.")
    AssertEqual(4, light_style.preedit_corner_radius, "The preedit corner radius was not parsed.")
    AssertEqual(2, light_style.preedit_round_corner, "The preedit round corner was not parsed.")
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
    AssertEqual(0xff998877, light_style.preedit_border_color, "The preedit border color was not parsed.")
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
    AssertEqual(
        0xffe0e0e0,
        dark_style.preedit_border_color,
        "A missing dark preedit border color did not inherit the dark border color."
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
        "style/layout/preedit_border_width", 3,
        "style/layout/preedit_corner_radius", 4,
        "style/layout/preedit_round_corner", 2,
        "style/layout/preedit_margin_x", 2,
        "style/layout/preedit_margin_y", 4,
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
        "preset_color_schemes/light/preedit_border_color", "0x998877",
        "preset_color_schemes/dark/text_color", "0xddeeff",
        "preset_color_schemes/dark/back_color", "0x010203"
    )
}

TestStyleSnapshotPreeditFallback() {
    local style := RabbitUIStyleSnapshot(Map(
        "border_width", 7,
        "corner_radius", 9,
        "round_corner", 5,
        "margin_x", 8,
        "margin_y", 10,
        "border_color", 0xff123456
    ))
    AssertEqual(7, style.preedit_border_width, "A missing preedit border width did not follow border width.")
    AssertEqual(9, style.preedit_corner_radius, "A missing preedit corner radius did not follow corner radius.")
    AssertEqual(5, style.preedit_round_corner, "A missing preedit round corner did not follow round corner.")
    AssertEqual(8, style.preedit_margin_x, "A missing preedit horizontal margin did not follow margin_x.")
    AssertEqual(10, style.preedit_margin_y, "A missing preedit vertical margin did not follow margin_y.")
    AssertEqual(0xff123456, style.preedit_border_color,
        "A missing preedit border color did not follow border color.")

    local updated := style.With(Map(
        "border_width", 11,
        "corner_radius", 13,
        "round_corner", 7,
        "margin_x", 12,
        "margin_y", 14,
        "border_color", 0xffabcdef
    ))
    AssertEqual(11, updated.preedit_border_width, "A fallback preedit border width stopped following border_width.")
    AssertEqual(13, updated.preedit_corner_radius, "A fallback preedit corner radius stopped following corner_radius.")
    AssertEqual(7, updated.preedit_round_corner, "A fallback preedit round corner stopped following round_corner.")
    AssertEqual(12, updated.preedit_margin_x, "A fallback preedit horizontal margin stopped following margin_x.")
    AssertEqual(14, updated.preedit_margin_y, "A fallback preedit vertical margin stopped following margin_y.")
    AssertEqual(0xffabcdef, updated.preedit_border_color,
        "A fallback preedit border color stopped following border_color.")

    local cleared := style.With(Map(
        "preedit_border_width", "",
        "preedit_corner_radius", "",
        "preedit_round_corner", "",
        "preedit_margin_x", "",
        "preedit_margin_y", "",
        "preedit_border_color", ""
    ))
    AssertEqual(7, cleared.preedit_border_width, "An empty preedit border width did not follow border width.")
    AssertEqual(9, cleared.preedit_corner_radius, "An empty preedit corner radius did not follow corner radius.")
    AssertEqual(5, cleared.preedit_round_corner, "An empty preedit round corner did not follow round corner.")
    AssertEqual(8, cleared.preedit_margin_x, "An empty preedit horizontal margin did not follow margin_x.")
    AssertEqual(10, cleared.preedit_margin_y, "An empty preedit vertical margin did not follow margin_y.")
    AssertEqual(0xff123456, cleared.preedit_border_color,
        "An empty preedit border color did not follow border color.")
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
