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
RunTest("color scheme preserves existing fields", TestColorSchemePreservesExistingFields.Bind())
RunTest("color scheme copies as standard ARGB", TestColorSchemeCopiesAsArgb.Bind())
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
        "back_color", "0x80102040",
        "shadow_color", "0xff030201",
        "extension", "kept"
    ))
    local copied := scheme.CopyAs("copy", "Copy")
    AssertEqual("argb", copied.color_format, "A copied scheme did not use ARGB.")
    AssertEqual("0x80402010", copied.values["back_color"], "The copied background was not converted.")
    AssertEqual("0xff010203", copied.values["shadow_color"], "An extension color was not converted.")
    AssertEqual("kept", copied.values["extension"], "Copying dropped an unknown field.")
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
