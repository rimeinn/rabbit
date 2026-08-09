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
 *
 */

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitCandidateViewport.ahk

RunTest("flow viewport expands after page transition", TestFlowViewportExpansion.Bind())
RunTest("flow viewport centers the final page", TestFlowViewportFinalPage.Bind())
RunTest("flow viewport falls back without iterator APIs", TestFlowViewportFallback.Bind())

TestFlowViewportExpansion() {
    local rime := RabbitCandidateViewportRimeProbe(18)
    local viewport := RabbitCandidateViewport()
    local presentation := viewport.Build(CreateViewportContext(0), "{}", "flow", 5, rime, 1)

    AssertEqual(3, presentation.candidates.Length, "A collapsed flow viewport must show the current page only.")
    AssertTrue(HasProp(presentation, "flow_page_size"), "Flow presentation omitted its page size.")

    presentation := viewport.Build(CreateViewportContext(1), "{}", "flow", 5, rime, 1)
    AssertEqual(15, presentation.candidates.Length, "An expanded viewport did not preload five pages.")
    AssertEqual("候选 1", presentation.candidates[1].text, "The candidate iterator inserted an empty first item.")
    AssertEqual("", presentation.candidates[1].label, "A preview page retained a label.")
    AssertEqual("1", presentation.candidates[4].label, "The current page did not retain its labels.")
    AssertTrue(presentation.candidates[4].highlighted, "The current highlighted candidate was lost.")
    AssertTrue(!presentation.candidates[1].highlighted, "A preview candidate was highlighted.")
    AssertEqual(1, rime.end_calls, "The candidate iterator was not ended after preloading.")
}

TestFlowViewportFinalPage() {
    local rime := RabbitCandidateViewportRimeProbe(18)
    local viewport := RabbitCandidateViewport()
    viewport.Build(CreateViewportContext(0), "{}", "flow", 5, rime, 1)
    local presentation := viewport.Build(CreateViewportContext(5), "{}", "flow", 5, rime, 1)

    AssertEqual(15, presentation.candidates.Length, "The tail viewport did not backfill five pages.")
    AssertEqual("候选 4", presentation.candidates[1].text, "The tail viewport started on the wrong page.")
    AssertEqual("1", presentation.candidates[13].label, "The final current page was not positioned in the last row.")
}

TestFlowViewportFallback() {
    local viewport := RabbitCandidateViewport()
    local rime := { api_available: (*) => false }
    viewport.Build(CreateViewportContext(0), "{}", "flow", 5, rime, 1)
    local presentation := viewport.Build(CreateViewportContext(1), "{}", "flow", 5, rime, 1)

    AssertEqual(3, presentation.candidates.Length, "An unavailable iterator did not fall back to the current page.")
}

CreateViewportContext(page_no) {
    local candidates := []
    Loop 3 {
        local index := page_no * 3 + A_Index
        candidates.Push({ text: "候选 " . index, comment: "注释 " . index })
    }
    return {
        composition: {
            length: 1,
            preedit: "shuru",
            cursor_pos: 5,
            sel_start: 0,
            sel_end: 0
        },
        menu: {
            candidates: candidates,
            highlighted_candidate_index: 0,
            num_candidates: candidates.Length,
            page_no: page_no,
            page_size: 3,
            select_keys: "123"
        },
        select_labels: Map(0, "", 1, "", 2, "", 3, "")
    }
}

class RabbitCandidateViewportRimeProbe {
    __New(count) {
        this.candidates := []
        Loop count {
            this.candidates.Push({ text: "候选 " . A_Index, comment: "注释 " . A_Index })
        }
        this.end_calls := 0
    }

    api_available(func) {
        return func = "candidate_list_begin"
            || func = "candidate_list_next"
            || func = "candidate_list_end"
            || func = "candidate_list_from_index"
    }

    candidate_list_begin(session_id) {
        return { index: 0, candidate: 0 }
    }

    candidate_list_from_index(session_id, iterator, index) {
        if index < 0 || index >= this.candidates.Length {
            return false
        }
        iterator.index := index - 1
        iterator.candidate := 0
        return true
    }

    candidate_list_next(iterator) {
        local index := iterator.index + 1
        if index >= this.candidates.Length {
            return false
        }
        iterator.index := index
        iterator.candidate := this.candidates[index + 1]
        return true
    }

    candidate_list_end(iterator) {
        this.end_calls++
    }
}
