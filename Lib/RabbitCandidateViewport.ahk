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

#Include RabbitCandidatePresentation.ahk

class RabbitCandidateViewport {
    __New() {
        this.expanded := false
        this.last_page_no := -1
    }

    Reset() {
        this.expanded := false
        this.last_page_no := -1
    }

    Build(context, label_format, layout_type, flow_rows, rime_api := 0, session_id := 0) {
        local presentation := RabbitCandidatePresentation(context, label_format)
        local page_no := context.menu.page_no
        local page_size := context.menu.page_size

        if layout_type != "flow" || page_size <= 0 {
            this.last_page_no := page_no
            return presentation
        }
        presentation.flow_page_size := page_size
        if this.last_page_no >= 0 {
            if this.last_page_no == 1 && page_no == 0 {
                this.expanded := false
            } else if page_no != this.last_page_no {
                this.expanded := true
            }
        }
        this.last_page_no := page_no
        if !this.expanded || !rime_api || !session_id || !this.CanPreload(rime_api) {
            return presentation
        }
        return this.BuildExpanded(
            context,
            label_format,
            Min(9, Max(1, flow_rows)),
            page_size,
            rime_api,
            session_id,
            presentation
        )
    }

    CanPreload(rime_api) {
        return HasMethod(rime_api, "api_available")
            && rime_api.api_available("candidate_list_begin")
            && rime_api.api_available("candidate_list_next")
            && rime_api.api_available("candidate_list_end")
            && rime_api.api_available("candidate_list_from_index")
    }

    BuildExpanded(context, label_format, flow_rows, page_size, rime_api, session_id, fallback) {
        local menu := context.menu
        local target_row := Ceil(flow_rows / 2)
        local start_page := Max(0, menu.page_no - target_row + 1)
        local candidates := this.LoadPages(rime_api, session_id, start_page, page_size, flow_rows)
        local available_pages := Ceil(candidates.Length / page_size)
        if available_pages < flow_rows && start_page > 0 {
            start_page := Max(0, start_page - (flow_rows - available_pages))
            candidates := this.LoadPages(rime_api, session_id, start_page, page_size, flow_rows)
        }
        if !candidates.Length {
            return fallback
        }

        fallback.candidates := []
        local current_start := menu.page_no * page_size
        local highlighted := current_start + menu.highlighted_candidate_index
        for candidate in candidates {
            local local_index := candidate.index - current_start + 1
            local is_current_page := 1 <= local_index && local_index <= page_size
            fallback.candidates.Push({
                label: is_current_page
                    ? Format(label_format, RabbitCandidatePresentation.GetLabel(context, local_index))
                    : "",
                text: candidate.text,
                comment: candidate.comment,
                highlighted: is_current_page && candidate.index == highlighted,
                preview: !is_current_page
            })
        }
        fallback.highlighted_index := menu.highlighted_candidate_index + 1
        return fallback
    }

    LoadPages(rime_api, session_id, start_page, page_size, flow_rows) {
        local result := []
        local iterator := rime_api.candidate_list_begin(session_id)
        if !iterator {
            return result
        }
        try {
            if !rime_api.candidate_list_from_index(session_id, iterator, start_page * page_size) {
                return result
            }
            Loop page_size * flow_rows {
                if !rime_api.candidate_list_next(iterator) {
                    break
                }
                result.Push({
                    index: iterator.index,
                    text: iterator.candidate.text,
                    comment: iterator.candidate.comment
                })
            }
        } finally {
            rime_api.candidate_list_end(iterator)
        }
        return result
    }
}
