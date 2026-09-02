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

#Requires AutoHotkey v2.0

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitCandidateBox.ahk
#Include ..\..\Lib\RabbitDirect2D.ahk

RunTest("DirectWrite applies scoped font fallback mappings", TestScopedFontFallback.Bind())
RunTest("DirectWrite applies parsed font attributes", TestParsedFontAttributes.Bind())
RunTest("modern candidate box renders configured font fallbacks", TestCandidateBoxFontFallback.Bind())

TestScopedFontFallback() {
    local d2d := RabbitDirect2D()
    local digit_fallback := d2d.GetMetrics("0000", "Consolas:30:39, Segoe UI", 30)
    local digit_direct := d2d.GetMetrics("0000", "Consolas", 30)
    local letter_fallback := d2d.GetMetrics("WWWW", "Consolas:30:39, Segoe UI", 30)
    local letter_direct := d2d.GetMetrics("WWWW", "Segoe UI", 30)
    local missing_fallback := d2d.GetMetrics("WWWW", "Rabbit Missing Font, Segoe UI", 30)
    AssertMetricClose(digit_direct, digit_fallback, "The digit range did not use Consolas.")
    AssertMetricClose(letter_direct, letter_fallback, "The unrestricted fallback did not use Segoe UI.")
    AssertMetricClose(letter_direct, missing_fallback, "A missing family did not advance to the next fallback.")

    d2d.SetRenderTarget("wic", 320, 80)
    d2d.BeginDraw()
    try {
        d2d.DrawText("0000 WWWW", 0, 0, 30, 0xff000000, "Consolas:30:39, Segoe UI")
    } finally {
        d2d.EndDraw()
    }
}

TestParsedFontAttributes() {
    local d2d := RabbitDirect2D()
    local parsed := d2d.GetMetrics("MMMM", "Segoe UI:bold:italic", 30)
    local direct := d2d.GetMetrics("MMMM", "Segoe UI", 30, 700, 2)
    AssertMetricClose(direct, parsed, "The parsed font weight or style was not applied.")
}

TestCandidateBoxFontFallback() {
    local width, height
    local style := RabbitUIStyleSnapshot(Map(
        "font_face", "Segoe UI Emoji:1f300:1faff, Microsoft YaHei UI, Segoe UI Emoji",
        "preedit_font_face", "Consolas:30:39, Microsoft YaHei UI",
        "label_font_face", "Consolas:30:39, Microsoft YaHei UI",
        "comment_font_face", "Segoe UI Symbol:2000:2bff, Microsoft YaHei UI"
    ))
    local candidate_box := CandidateBox(style)
    local context := {
        composition: {
            length: 4,
            preedit: "1234",
            cursor_pos: 4,
            sel_start: 0,
            sel_end: 0
        },
        menu: {
            candidates: [{ text: "😀输入", comment: "※ 测试" }],
            highlighted_candidate_index: 0,
            num_candidates: 1,
            page_size: 5,
            select_keys: "12345"
        },
        select_labels: Map(0, "", 1, "")
    }
    try {
        candidate_box.Build(context, &width, &height)
        candidate_box.Show(10, 10)
        AssertTrue(width > 0 && height > 0, "The fallback candidate box did not build positive dimensions.")
    } finally {
        candidate_box.Dispose()
    }
}

AssertMetricClose(expected, actual, message) {
    if Abs(expected.w - actual.w) > 0.01 || Abs(expected.h - actual.h) > 0.01 {
        throw Error(Format(
            "{} Expected: ({}, {}). Actual: ({}, {}).",
            message,
            expected.w,
            expected.h,
            actual.w,
            actual.h
        ))
    }
}
