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
#Include ..\..\Lib\RabbitAppearancePreview.ahk

RunTest("appearance preview uses the production candidate renderer", TestAppearancePreviewUsesCandidateRenderer.Bind())
RunTest("appearance preview builds standard placeholders", TestAppearancePreviewBuildsStandardPlaceholders.Bind())
RunTest("appearance preview builds expanded flow placeholders", TestAppearancePreviewBuildsFlowPlaceholders.Bind())
RunTest("appearance preview uses configured candidate labels", TestAppearancePreviewUsesConfiguredLabels.Bind())
RunTest("appearance preview aligns beside the client area", TestAppearancePreviewAlignsBesideClientArea.Bind())

TestAppearancePreviewUsesCandidateRenderer() {
    AssertTrue(
        !HasMethod(RabbitAppearancePreview.Prototype, "DrawCandidateRow"),
        "The appearance preview retained a separate candidate renderer."
    )
    AssertTrue(
        !HasMethod(RabbitAppearancePreview.Prototype, "DrawFloatingPreedit"),
        "The appearance preview retained a separate floating-preedit renderer."
    )
}

TestAppearancePreviewBuildsStandardPlaceholders() {
    local presentation := RabbitAppearancePreview.CreatePresentation(RabbitUIStyleSnapshot())
    local groups := RabbitGetPreeditGroups(presentation.preedit)
    local expected_texts := ["输入", "书", "数", "树", "输"]
    local expected_comments := ["shū rù", "shū", "shǔ", "shù", "shū"]

    AssertEqual("玉兔毫", presentation.preedit.before_selection, "The standard preedit prefix is incorrect.")
    AssertEqual("shu ru", presentation.preedit.selected, "The standard highlighted preedit is incorrect.")
    AssertEqual("fa", presentation.preedit.after_selection, "The standard preedit suffix is incorrect.")
    AssertEqual(2, groups[3].segments.Length, "The standard caret did not split the suffix.")
    AssertTrue(groups[3].segments[1].cursor, "The standard caret was not before the suffix.")
    AssertEqual("fa", groups[3].segments[2].text, "The standard suffix was not after the caret.")
    AssertEqual(5, presentation.candidates.Length, "The standard preview used the wrong candidate count.")
    for index, candidate in presentation.candidates {
        AssertEqual(expected_texts[index], candidate.text, "A standard candidate used the wrong text.")
        AssertEqual(expected_comments[index], candidate.comment, "A standard candidate used the wrong comment.")
        AssertEqual(index = 1, candidate.highlighted, "The standard preview highlighted the wrong candidate.")
    }
}

TestAppearancePreviewBuildsFlowPlaceholders() {
    local style := RabbitUIStyleSnapshot({ layout_type: "flow" })
    local presentation := RabbitAppearancePreview.CreatePresentation(style)
    local groups := RabbitGetPreeditGroups(presentation.preedit)
    local expected_texts := [
        "输入法", "输入", "书", "数", "树",
        "输", "属", "熟", "术", "舒",
        "鼠", "叔", "淑", "束", "疏",
        "署", "述", "竖", "俞", "蜀",
        "梳", "孰", "殊", "姝", "恕",
    ]

    AssertEqual("玉兔毫", presentation.preedit.before_selection, "The flow preedit prefix is incorrect.")
    AssertEqual("shu", presentation.preedit.selected, "The flow highlighted preedit is incorrect.")
    AssertEqual("rufa", presentation.preedit.after_selection, "The flow preedit suffix is incorrect.")
    AssertEqual(2, groups[3].segments.Length, "The flow caret did not split the suffix.")
    AssertEqual("rufa", groups[3].segments[1].text, "The flow caret was not after the suffix.")
    AssertTrue(groups[3].segments[2].cursor, "The flow caret was not at the end.")
    AssertEqual(5, presentation.flow_page_size, "The flow preview used the wrong page size.")
    AssertEqual(25, presentation.candidates.Length, "The flow preview did not contain five pages.")
    for index, candidate in presentation.candidates {
        local current := 6 <= index && index <= 10
        AssertEqual(expected_texts[index], candidate.text, "A flow candidate used the wrong text.")
        AssertEqual(current, !candidate.preview, "A flow candidate used the wrong page state.")
        AssertEqual(index = 6, candidate.highlighted, "The flow preview highlighted the wrong candidate.")
        AssertEqual(current, !!candidate.label, "A flow candidate used the wrong label visibility.")
    }
}

TestAppearancePreviewUsesConfiguredLabels() {
    local labels := ["①", "②", "③", "④", "⑤"]
    local style := RabbitUIStyleSnapshot()
    local standard := RabbitAppearancePreview.CreatePresentation(style, labels)
    AssertEqual("①. ", standard.candidates[1].label, "The standard preview ignored custom labels.")
    AssertEqual("⑤. ", standard.candidates[5].label, "The standard preview used the wrong custom label.")

    style := RabbitUIStyleSnapshot({ layout_type: "flow" })
    local flow := RabbitAppearancePreview.CreatePresentation(style, labels)
    AssertEqual("①. ", flow.candidates[6].label, "The flow preview ignored custom labels.")
    AssertEqual("⑤. ", flow.candidates[10].label, "The flow preview used the wrong custom label.")
}

TestAppearancePreviewAlignsBesideClientArea() {
    local monitor_info := { work: { left: 0, top: 0, right: 1200, bottom: 900 } }
    local right := RabbitAppearancePreview.AlignBesidePositionToClient(
        { x: 824, y: 100, side: "right" },
        132,
        240,
        300,
        monitor_info
    )
    local above := RabbitAppearancePreview.AlignBesidePositionToClient(
        { x: 824, y: 100, side: "right" },
        760,
        240,
        300,
        monitor_info
    )
    local top := RabbitAppearancePreview.AlignBesidePositionToClient(
        { x: 300, y: 20, side: "above", above: true },
        132,
        240,
        300,
        monitor_info
    )

    AssertEqual(132, right.y, "A side preview remained aligned to the title bar.")
    AssertTrue(!right.above, "An unclamped side preview used upward animation anchoring.")
    AssertEqual(600, above.y, "A side preview was not clamped to the monitor work area.")
    AssertTrue(above.above, "A clamped side preview did not use upward animation anchoring.")
    AssertEqual(20, top.y, "A preview above the window was incorrectly aligned to the client area.")
}
