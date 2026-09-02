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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitFontSpec.ahk

RunTest("font spec parses fallback order and ranges", TestFontSpecFallbackRanges.Bind())
RunTest("font spec parses open Unicode ranges", TestFontSpecOpenRanges.Bind())
RunTest("font spec parses weight and style", TestFontSpecWeightAndStyle.Bind())
RunTest("font spec selects a legacy family", TestFontSpecLegacyFamily.Bind())
RunTest("font spec rejects invalid settings", TestFontSpecValidation.Bind())

TestFontSpecFallbackRanges() {
    local spec := RabbitFontSpec.Parse(
        "Segoe UI Emoji:30:39, Arial:600:6ff, Microsoft YaHei UI, Segoe UI Emoji")
    AssertEqual(4, spec.entries.Length, "The parser changed the fallback entry count.")
    AssertEqual("Segoe UI Emoji", spec.entries[1].family, "The first fallback family changed.")
    AssertEqual(0x30, spec.entries[1].start_code_point, "The first range start was not hexadecimal.")
    AssertEqual(0x39, spec.entries[1].end_code_point, "The first range end was not hexadecimal.")
    AssertEqual(0x600, spec.entries[2].start_code_point, "The second range start changed.")
    AssertEqual(0x6ff, spec.entries[2].end_code_point, "The second range end changed.")
    AssertEqual(0, spec.entries[3].start_code_point, "An unrestricted font did not start at zero.")
    AssertEqual(
        RabbitFontSpec.MAX_CODE_POINT,
        spec.entries[3].end_code_point,
        "An unrestricted font did not cover all Unicode code points."
    )
    AssertTrue(spec.requires_custom_fallback, "Multiple fonts did not request a custom fallback.")
}

TestFontSpecOpenRanges() {
    local from_start := RabbitFontSpec.Parse("Font A:80")
    local through_end := RabbitFontSpec.Parse("Font B::6ff")
    AssertEqual(0x80, from_start.entries[1].start_code_point, "A start-only range used the wrong start.")
    AssertEqual(
        RabbitFontSpec.MAX_CODE_POINT,
        from_start.entries[1].end_code_point,
        "A start-only range did not extend through Unicode."
    )
    AssertEqual(0, through_end.entries[1].start_code_point, "An end-only range did not start at zero.")
    AssertEqual(0x6ff, through_end.entries[1].end_code_point, "An end-only range used the wrong end.")
    AssertTrue(from_start.requires_custom_fallback, "A scoped font did not request custom fallback.")
    AssertTrue(
        !RabbitFontSpec.Parse("Microsoft YaHei UI").requires_custom_fallback,
        "A simple font family unnecessarily requested custom fallback."
    )
}

TestFontSpecWeightAndStyle() {
    local spec := RabbitFontSpec.Parse("Microsoft YaHei UI:600:6ff:italic:bold, Segoe UI")
    AssertEqual(700, spec.font_weight, "The named font weight was not converted for DirectWrite.")
    AssertEqual(2, spec.font_style, "The named font style was not converted for DirectWrite.")
    AssertTrue(spec.has_weight, "The explicit font weight was not recorded.")
    AssertTrue(spec.has_style, "The explicit font style was not recorded.")
    AssertEqual(0x600, spec.entries[1].start_code_point, "An attribute displaced the range start.")
    AssertEqual(0x6ff, spec.entries[1].end_code_point, "An attribute displaced the range end.")
}

TestFontSpecLegacyFamily() {
    local spec := RabbitFontSpec.Parse("Segoe UI Emoji:1f300:1faff, Microsoft YaHei UI, Segoe UI Emoji")
    AssertEqual(
        "Microsoft YaHei UI",
        spec.legacy_family,
        "Legacy degradation selected a scoped fallback instead of the primary family."
    )
    AssertEqual(
        "Segoe UI Emoji",
        RabbitFontSpec.Parse("Segoe UI Emoji:1f300:1faff").legacy_family,
        "A fully scoped setting did not retain a usable legacy family."
    )
}

TestFontSpecValidation() {
    for value in [
        "",
        "Microsoft YaHei UI,",
        ":30:39",
        "Font:xyz",
        "Font:110000",
        "Font:100:20",
        "Font:1:2:3",
        "Font, Other:bold"
    ] {
        AssertThrows(
            RabbitFontSpec.Parse.Bind(value),
            "The parser accepted an invalid font setting: " . value
        )
    }
}
