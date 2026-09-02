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
#Include ..\..\Lib\RabbitAdvancedFontSettingsModel.ahk

RunTest("advanced font model edits fallback chains", TestAdvancedFontModelEdits.Bind())
RunTest("advanced font model keeps global attributes", TestAdvancedFontModelAttributes.Bind())
RunTest("advanced font model validates destructive edits", TestAdvancedFontModelValidation.Bind())

TestAdvancedFontModelEdits() {
    local model := RabbitAdvancedFontSettingsModel(CreateAdvancedFontValues())
    local key := "font_face"
    local added := model.AddEntry(key, "Segoe UI Emoji")
    AssertEqual(3, added, "The model added a fallback at the wrong position.")
    model.UpdateEntry(key, added, "Segoe UI Emoji", 0x1f300, 0x1faff)
    AssertEqual(
        "Microsoft YaHei UI, Segoe UI, Segoe UI Emoji:1f300:1faff",
        model.GetValues()[key],
        "The model did not serialize the edited fallback."
    )
    AssertEqual(2, model.MoveEntry(key, 3, -1), "The model did not move the fallback up.")
    AssertEqual(
        "Microsoft YaHei UI, Segoe UI Emoji:1f300:1faff, Segoe UI",
        model.GetValues()[key],
        "The model changed the wrong fallback order."
    )
    AssertEqual(2, model.DeleteEntry(key, 2), "The model selected the wrong row after deletion.")
    AssertEqual(
        "Microsoft YaHei UI, Segoe UI",
        model.GetValues()[key],
        "The model did not delete the selected fallback."
    )
}

TestAdvancedFontModelAttributes() {
    local model := RabbitAdvancedFontSettingsModel(CreateAdvancedFontValues())
    model.SetAttributes("comment_font_face", 700, 2)
    AssertEqual(
        "Microsoft YaHei UI:bold:italic",
        model.GetValues()["comment_font_face"],
        "The model did not store global weight and style on the first entry."
    )
    model.SetAttributes("comment_font_face", 400, 0)
    AssertEqual(
        "Microsoft YaHei UI",
        model.GetValues()["comment_font_face"],
        "The model did not omit default global attributes."
    )
}

TestAdvancedFontModelValidation() {
    local model := RabbitAdvancedFontSettingsModel(CreateAdvancedFontValues())
    AssertThrows(
        model.UpdateEntry.Bind("font_face", 1, "", 0, RabbitFontSpec.MAX_CODE_POINT),
        "The model accepted an empty font family."
    )
    AssertThrows(
        model.UpdateEntry.Bind("font_face", 1, "Font", 0x100, 0x20),
        "The model accepted a reversed Unicode range."
    )
    model.SetSource("font_face", "Microsoft YaHei UI")
    AssertThrows(
        model.DeleteEntry.Bind("font_face", 1),
        "The model deleted the last font family."
    )
}

CreateAdvancedFontValues() {
    return Map(
        "font_face", "Microsoft YaHei UI, Segoe UI",
        "preedit_font_face", "Microsoft YaHei UI",
        "label_font_face", "Microsoft YaHei UI",
        "comment_font_face", "Microsoft YaHei UI"
    )
}
