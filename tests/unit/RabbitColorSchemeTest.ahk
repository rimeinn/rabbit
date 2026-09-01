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
#Include ..\..\Lib\RabbitColorScheme.ahk

RunTest("color scheme converts formats through ARGB", TestColorSchemeConvertsFormats.Bind())
RunTest("color scheme makes numeric RGB colors opaque", TestColorSchemeMakesNumericRgbOpaque.Bind())
RunTest("color scheme preserves existing fields", TestColorSchemePreservesExistingFields.Bind())
RunTest("color scheme copies as standard ARGB", TestColorSchemeCopiesAsArgb.Bind())
RunTest("color scheme preview combines shared style and colors", TestColorSchemePreviewCombinesStyleAndColors.Bind())
RunTest("color scheme validates identifiers and ARGB text", TestColorSchemeValidatesInput.Bind())

TestColorSchemeConvertsFormats() {
    local argb
    for format, encoded in Map(
        "argb", "0x80402010",
        "abgr", "0x80102040",
        "rgba", "0x40201080"
    ) {
        AssertTrue(
            RabbitColorScheme.TryParseConfigColor(encoded, format, &argb),
            "The " . format . " color could not be parsed."
        )
        AssertEqual(0x80402010, argb, "The " . format . " color produced the wrong ARGB value.")
        AssertEqual(
            StrLower(encoded),
            RabbitColorScheme.FormatConfigColor(argb, format),
            "The ARGB value did not round-trip through " . format . "."
        )
    }
}

TestColorSchemeMakesNumericRgbOpaque() {
    local argb
    AssertTrue(
        RabbitColorScheme.TryParseConfigColor("0xbf7817", "abgr", &argb),
        "The Smurfs ABGR background color could not be parsed."
    )
    AssertEqual(0xff1778bf, argb, "The Smurfs ABGR background color was not made opaque.")
    for format, encoded in Map(
        "argb", 0x402010,
        "abgr", 0x102040,
        "rgba", 0x402010
    ) {
        AssertTrue(
            RabbitColorScheme.TryParseConfigColor(encoded, format, &argb),
            "The numeric " . format . " RGB color could not be parsed."
        )
        AssertEqual(0xff402010, argb, "The numeric " . format . " RGB color was not made opaque.")
    }
    AssertTrue(
        RabbitColorScheme.TryParseConfigColor("0x00000000", "argb", &argb),
        "An explicitly transparent ARGB color could not be parsed."
    )
    AssertEqual(0x00000000, argb, "An explicitly transparent ARGB color was made opaque.")
    AssertTrue(
        RabbitColorScheme.TryParseConfigColor(0x20000000, "argb", &argb),
        "A numeric translucent ARGB color could not be parsed."
    )
    AssertEqual(0x20000000, argb, "A numeric translucent ARGB color lost its alpha.")
}

TestColorSchemePreservesExistingFields() {
    local scheme := RabbitColorScheme("existing", Map(
        "name", "Existing",
        "author", "Before",
        "color_format", "abgr",
        "back_color", "0x80102040",
        "shadow_color", "0x11223344",
        "extension", Map("kept", true)
    ), "custom")
    local edited := scheme.WithEdits(
        "Edited",
        "After",
        Map("back_color", 0x80402010)
    )
    AssertEqual("abgr", edited.color_format, "Editing changed the original color format.")
    AssertEqual("0x80102040", edited.values["back_color"], "Editing wrote the wrong ABGR value.")
    AssertEqual("0x11223344", edited.values["shadow_color"], "Editing changed an untouched color.")
    AssertTrue(edited.values["extension"]["kept"], "Editing dropped an unknown field.")
}

TestColorSchemeCopiesAsArgb() {
    local scheme := RabbitColorScheme("source", Map(
        "name", "Source",
        "color_format", "abgr",
        "back_color", 0x102040,
        "shadow_color", "0xff030201",
        "extension", "kept"
    ))
    local copied := scheme.CopyAs("copy", "Copy")
    AssertEqual("argb", copied.color_format, "A copied scheme did not use ARGB.")
    AssertEqual("0xff402010", copied.values["back_color"], "The copied numeric RGB color was not opaque.")
    AssertEqual("0xff010203", copied.values["shadow_color"], "An extension color was not converted.")
    AssertEqual("kept", copied.values["extension"], "Copying dropped an unknown field.")
}

TestColorSchemePreviewCombinesStyleAndColors() {
    local base_style := RabbitUIStyleSnapshot(0, Map(
        "font_face", "Preview Font",
        "font_point", 23,
        "min_width", 420,
        "back_color", 0xff123456
    ))
    local scheme := RabbitColorScheme.CreateDefault("new_scheme", "New Scheme", "", base_style)
    local preview_style := scheme.BuildPreviewStyle(
        Map("font_point", 27, "floating_preedit", true),
        Map("back_color", 0xff654321, "hilited_back_color", 0xff112233)
    )
    AssertEqual("Preview Font", preview_style.font_face, "The preview did not inherit the shared font.")
    AssertEqual(27, preview_style.font_point, "The preview did not apply the pending font size.")
    AssertEqual(420, preview_style.min_width, "The preview did not inherit the shared minimum width.")
    AssertEqual(0xff654321, preview_style.back_color, "The preview did not apply the edited color.")
    AssertTrue(preview_style.floating_preedit, "The preview did not apply the pending floating preedit mode.")
    AssertEqual(
        0xff112233,
        preview_style.floating_preedit_hilited_back_color,
        "The floating preedit preview did not use the edited highlighted background."
    )
}

TestColorSchemeValidatesInput() {
    AssertEqual(0xff123456, RabbitColorScheme.ParseArgbText("#123456"), "RGB text did not become opaque ARGB.")
    AssertEqual("#80123456", RabbitColorScheme.FormatArgbText(0x80123456), "ARGB text was formatted incorrectly.")
    AssertThrows(
        (*) => RabbitColorScheme.ValidateId("contains/slash"),
        "A slash-containing scheme ID was accepted."
    )
    AssertThrows(
        (*) => RabbitColorScheme.ParseArgbText("#12345"),
        "An invalid ARGB value was accepted."
    )
}
