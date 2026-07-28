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

RunTest("UTF-8 candidate presentation", TestUtf8CandidatePresentation.Bind())
RunTest("candidate label fallback presentation", TestCandidateLabelFallbackPresentation.Bind())
RunTest("empty candidate presentation", TestEmptyCandidatePresentation.Bind())

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
    AssertEqual("‸法", presentation.preedit.after_selection, "UTF-8 text after selection is incorrect.")
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

TestEmptyCandidatePresentation() {
    local context := CreatePresentationContext()
    context.composition.preedit := ""
    context.menu.candidates := []
    context.menu.num_candidates := 0
    local presentation := RabbitCandidatePresentation(context, "{}")

    AssertEqual("", presentation.preedit.before_selection, "Empty preedit text is incorrect.")
    AssertEqual("", presentation.preedit.selected, "Empty selected text is incorrect.")
    AssertEqual("", presentation.preedit.after_selection, "Empty post-selection text is incorrect.")
    AssertEqual(0, presentation.candidates.Length, "An empty menu must produce no candidate rows.")
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
