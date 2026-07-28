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

class RabbitCandidatePresentation {
    __New(context, label_format) {
        local before_selection, selected, after_selection
        local menu := context.menu
        local candidates := menu.candidates
        local has_custom_labels := !!context.select_labels[0]
        local select_keys := menu.select_keys
        local select_key_count := StrLen(select_keys)

        RabbitGetCompositionText(
            context.composition, &before_selection, &selected, &after_selection)
        this.preedit := {
            before_selection: before_selection,
            selected: selected,
            after_selection: after_selection
        }
        this.highlighted_index := menu.highlighted_candidate_index + 1
        this.candidates := []

        loop menu.num_candidates {
            local label := String(A_Index)
            if A_Index <= menu.page_size && has_custom_labels {
                label := context.select_labels[A_Index] || label
            } else if A_Index <= select_key_count {
                label := SubStr(select_keys, A_Index, 1)
            }
            this.candidates.Push({
                label: Format(label_format, label),
                text: candidates[A_Index].text,
                comment: candidates[A_Index].comment,
                highlighted: A_Index == this.highlighted_index
            })
        }
    }
}

RabbitGetCompositionText(composition, &pre_selected, &selected, &post_selected) {
    local preedit, byte
    pre_selected := ""
    selected := ""
    post_selected := ""
    if !(preedit := composition.preedit) {
        return false
    }
    static cursor_text := "‸" ; Alternative cursor: 𝙸
    static cursor_size := StrPut(cursor_text, "UTF-8") - 1 ; Do not count the trailing null terminator.

    local preedit_length := StrPut(preedit, "UTF-8")
    local selected_start := composition.sel_start
    local selected_end := composition.sel_end

    local preedit_buffer ; insert caret text into preedit text if applicable
    if 0 <= composition.cursor_pos && composition.cursor_pos <= preedit_length {
        preedit_buffer := Buffer(preedit_length + cursor_size, 0)
        local temp_preedit := Buffer(preedit_length, 0)
        StrPut(preedit, temp_preedit, "UTF-8")
        local src := temp_preedit.Ptr
        local tgt := preedit_buffer.Ptr
        Loop composition.cursor_pos {
            byte := NumGet(src, A_Index - 1, "Char")
            NumPut("Char", byte, tgt, A_Index - 1)
        }
        src := src + composition.cursor_pos
        tgt := tgt + composition.cursor_pos
        StrPut(cursor_text, tgt, "UTF-8")
        tgt := tgt + cursor_size
        Loop preedit_length - composition.cursor_pos {
            byte := NumGet(src, A_Index - 1, "Char")
            NumPut("Char", byte, tgt, A_Index - 1)
        }
        preedit_length := preedit_length + cursor_size
        if selected_start >= composition.cursor_pos {
            selected_start := selected_start + cursor_size
        }
        if selected_end > composition.cursor_pos {
            selected_end := selected_end + cursor_size
        }
    } else {
        preedit_buffer := Buffer(preedit_length, 0)
        StrPut(preedit, preedit_buffer, "UTF-8")
    }

    if 0 <= selected_start && selected_start < selected_end && selected_end <= preedit_length {
        pre_selected := StrGet(preedit_buffer, selected_start, "UTF-8")
        selected := StrGet(preedit_buffer.Ptr + selected_start, selected_end - selected_start, "UTF-8")
        post_selected := StrGet(preedit_buffer.Ptr + selected_end, "UTF-8")
        return true
    } else {
        pre_selected := StrGet(preedit_buffer, "UTF-8")
        return false
    }
}
