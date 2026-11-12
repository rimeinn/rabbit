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

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitCandidatePresentation.ahk

RunTest("UTF-8 candidate presentation", TestUtf8CandidatePresentation.Bind())
RunTest("candidate preview preedit presentation", TestCandidatePreviewPreeditPresentation.Bind())
RunTest("empty candidate preview falls back to composition", TestEmptyCandidatePreviewFallback.Bind())
RunTest("candidate label fallback presentation", TestCandidateLabelFallbackPresentation.Bind())
RunTest("candidate labels reuse page metadata", TestCandidateLabelsReusePageMetadata.Bind())
RunTest("empty candidate presentation", TestEmptyCandidatePresentation.Bind())
RunTest("candidate presentation content comparison", TestCandidatePresentationContentComparison.Bind())

TestUtf8CandidatePresentation() {
    local context := CreatePresentationContext()
    context.composition := {
        length: 3,
        preedit: "输入法",
        cursor_pos: 6,
        sel_start: 3,
        sel_end: 6
    }
    local presentation := RabbitCandidatePresentation(context, "{}")

    AssertEqual("输", presentation.preedit.before_selection, "UTF-8 text before selection is incorrect.")
    AssertEqual("入", presentation.preedit.selected, "UTF-8 selected text is incorrect.")
    AssertEqual("法", presentation.preedit.after_selection, "UTF-8 text after selection is incorrect.")
    AssertEqual("‸", presentation.preedit.cursor.text, "The cursor text is incorrect.")
    AssertEqual("after_selection", presentation.preedit.cursor.segment, "The cursor segment is incorrect.")
    AssertEqual(0, presentation.preedit.cursor.offset, "The cursor offset is incorrect.")
}

TestCandidatePreviewPreeditPresentation() {
    local context := CreatePresentationContext()
    context.commit_text_preview := "输入法"
    local presentation := RabbitCandidatePresentation(context, "{}", "preview")

    AssertEqual("", presentation.preedit.before_selection, "Preview preedit retained a composition prefix.")
    AssertEqual("输入法", presentation.preedit.selected, "Preview preedit did not use the commit-text preview.")
    AssertEqual("", presentation.preedit.after_selection, "Preview preedit retained a composition suffix.")
    AssertEqual("after_selection", presentation.preedit.cursor.segment, "The preview cursor is in the wrong segment.")
    AssertEqual(0, presentation.preedit.cursor.offset, "The preview cursor is not at the end of the selection.")
}

TestEmptyCandidatePreviewFallback() {
    local context := CreatePresentationContext()
    context.composition.preedit := "shuru"
    context.composition.cursor_pos := 5
    local presentation := RabbitCandidatePresentation(context, "{}", "preview")

    AssertEqual("shuru", presentation.preedit.before_selection, "An empty preview did not fall back to composition.")
    AssertEqual("", presentation.preedit.selected, "The composition fallback created an unexpected selection.")
}

TestCandidateLabelFallbackPresentation() {
    local context := CreatePresentationContext()
    context.select_labels := Map(0, true, 1, "甲", 2, "")
    local presentation := RabbitCandidatePresentation(context, "[{}]")

    AssertEqual("[甲]", presentation.candidates[1].label, "The custom label is incorrect.")
    AssertEqual("[2]", presentation.candidates[2].label, "An empty custom label must fall back to its ordinal.")
    AssertEqual("候选一", presentation.candidates[1].text, "The candidate text is incorrect.")
    AssertEqual("注释", presentation.candidates[1].comment, "The candidate comment is incorrect.")
    AssertTrue(presentation.candidates[2].highlighted, "The highlighted candidate mapping is incorrect.")

    context.select_labels := Map(0, false, 1, "", 2, "")
    context.menu.select_keys := "ab"
    presentation := RabbitCandidatePresentation(context, "{}")
    AssertEqual("a", presentation.candidates[1].label, "The first select-key label is incorrect.")
    AssertEqual("b", presentation.candidates[2].label, "The second select-key label is incorrect.")
}

TestCandidateLabelsReusePageMetadata() {
    local context := CreatePresentationContext()
    local menu := context.menu
    local labels := Map(0, true, 1, "甲", 2, "")
    local menu_reads := 0, select_key_reads := 0, label_checks := 0
    menu.candidates.Push({text: "候选三", comment: ""}, {text: "候选四", comment: ""})
    menu.num_candidates := menu.candidates.Length
    menu.page_size := 2
    context.DefineProp("menu", {Get: ReadMenu})
    menu.DefineProp("select_keys", {Get: ReadSelectKeys})
    context.DefineProp("select_labels", {Get: ReadLabel})

    local presentation := RabbitCandidatePresentation(context, "[{}]")

    AssertEqual("[甲]", presentation.candidates[1].label, "The custom label is incorrect.")
    AssertEqual("[2]", presentation.candidates[2].label, "An empty custom label must fall back to its ordinal.")
    AssertEqual("[c]", presentation.candidates[3].label, "A label beyond the page size must use the select key.")
    AssertEqual("[4]", presentation.candidates[4].label, "A missing select key must fall back to its ordinal.")
    AssertEqual(1, menu_reads, "The candidate menu must be read once per presentation.")
    AssertEqual(1, select_key_reads, "Select keys must be read once per candidate page.")
    AssertEqual(1, label_checks, "Custom label availability must be checked once per candidate page.")

    ReadMenu(*) {
        menu_reads++
        return menu
    }

    ReadSelectKeys(*) {
        select_key_reads++
        return "abc"
    }

    ReadLabel(_, index) {
        if index == 0 {
            label_checks++
        }
        return labels[index]
    }
}

TestEmptyCandidatePresentation() {
    local context := CreatePresentationContext()
    context.composition.preedit := ""
    context.menu.candidates := []
    context.menu.num_candidates := 0
    context.menu.DeleteProp("select_keys")
    context.DeleteProp("select_labels")
    local presentation := RabbitCandidatePresentation(context, "{}")

    AssertEqual("", presentation.preedit.before_selection, "Empty preedit text is incorrect.")
    AssertEqual("", presentation.preedit.selected, "Empty selected text is incorrect.")
    AssertEqual("", presentation.preedit.after_selection, "Empty post-selection text is incorrect.")
    AssertEqual(0, presentation.preedit.cursor, "Empty preedit text must not create a cursor segment.")
    AssertEqual(0, presentation.candidates.Length, "An empty menu must produce no candidate rows.")
}

TestCandidatePresentationContentComparison() {
    local context := CreatePresentationContext()
    context.composition := {length: 9, preedit: "abcDefghi", cursor_pos: 5, sel_start: 3, sel_end: 6}
    context.menu.select_keys := "ab"
    context.menu.candidates[1] := {text: "Alpha", comment: "Note"}
    local presentation := RabbitCandidatePresentation(context, "{}")
    local other := RabbitCandidatePresentation(context, "{}")

    AssertTrue(presentation.HasSameContent(other), "Equal presentation data compared differently.")
    AssertTrue(!presentation.HasSameContent(0), "A missing previous presentation compared equal.")
    local first := other.candidates[1]
    local changes := [
        [other.preedit, "before_selection", "Abc"],
        [other.preedit, "selected", "def"],
        [other.preedit, "after_selection", "Ghi"],
        [other.preedit.cursor, "text", "|"],
        [other.preedit.cursor, "segment", "after_selection"],
        [other.preedit.cursor, "offset", 1],
        [other.preedit, "cursor", 0],
        [other, "highlighted_index", 1],
        [first, "label", "A"],
        [first, "text", "alpha"],
        [first, "comment", "note"],
        [first, "highlighted", true]
    ]
    local change
    for change in changes {
        local target := change[1]
        local property := change[2]
        local previous := target.%property%
        target.%property% := change[3]
        AssertTrue(!presentation.HasSameContent(other), "The comparison ignored a change in " . property . ".")
        target.%property% := previous
    }

    presentation.preedit.cursor := 0
    other.preedit.cursor := 0
    first.preview := false
    AssertTrue(presentation.HasSameContent(other), "A default preview flag or absent cursor compared differently.")
    first.preview := true
    AssertTrue(!presentation.HasSameContent(other), "The comparison ignored a preview row.")
    first.preview := false

    other.flow_page_size := 0
    AssertTrue(!presentation.HasSameContent(other), "An explicit flow page size compared equal to a missing one.")
    presentation.flow_page_size := 2
    other.flow_page_size := 2
    AssertTrue(presentation.HasSameContent(other), "Matching flow page sizes compared differently.")
    other.flow_page_size := 3
    AssertTrue(!presentation.HasSameContent(other), "The comparison ignored a flow page size change.")
    other.flow_page_size := 2

    other.candidates := [other.candidates[2], first]
    AssertTrue(!presentation.HasSameContent(other), "The comparison ignored a candidate order change.")
    other.candidates := [first]
    AssertTrue(!presentation.HasSameContent(other), "The comparison ignored a candidate count change.")
}

CreatePresentationContext() {
    return {
        composition: {
            length: 0,
            preedit: "",
            cursor_pos: 0,
            sel_start: 0,
            sel_end: 0
        },
        commit_text_preview: "",
        menu: {
            candidates: [
                { text: "候选一", comment: "注释" },
                { text: "候选二", comment: "" }
            ],
            highlighted_candidate_index: 1,
            num_candidates: 2,
            page_size: 5,
            select_keys: "12"
        },
        select_labels: Map(0, false, 1, "", 2, "")
    }
}
