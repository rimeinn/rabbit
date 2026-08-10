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
        local before_selection, selected, after_selection, cursor
        local menu := context.menu
        local candidates := menu.candidates
        RabbitGetCompositionText(
            context.composition, &before_selection, &selected, &after_selection, &cursor)
        this.preedit := {
            before_selection: before_selection,
            selected: selected,
            after_selection: after_selection,
            cursor: cursor
        }
        this.highlighted_index := menu.highlighted_candidate_index + 1
        this.candidates := []

        loop menu.num_candidates {
            local label := RabbitCandidatePresentation.GetLabel(context, A_Index)
            this.candidates.Push({
                label: Format(label_format, label),
                text: candidates[A_Index].text,
                comment: candidates[A_Index].comment,
                highlighted: A_Index == this.highlighted_index
            })
        }
    }

    static GetLabel(context, index) {
        local menu := context.menu
        local has_custom_labels := !!context.select_labels[0]
        local select_keys := menu.select_keys
        local select_key_count := StrLen(select_keys)
        local label := String(index)
        if index <= menu.page_size && has_custom_labels {
            return context.select_labels[index] || label
        }
        if index <= select_key_count {
            return SubStr(select_keys, index, 1)
        }
        return label
    }
}

RabbitGetCompositionText(composition, &pre_selected, &selected, &post_selected, &cursor) {
    local preedit
    pre_selected := ""
    selected := ""
    post_selected := ""
    cursor := 0
    if !(preedit := composition.preedit) {
        return false
    }
    static cursor_text := "‸" ; Alternative cursor: 𝙸

    local preedit_length := StrPut(preedit, "UTF-8")
    local selected_start := composition.sel_start
    local selected_end := composition.sel_end

    local cursor_pos := composition.cursor_pos
    if 0 <= cursor_pos && cursor_pos <= preedit_length {
        cursor := {text: cursor_text}
        if 0 <= selected_start && selected_start < selected_end && selected_end <= preedit_length {
            if cursor_pos <= selected_start {
                cursor.segment := "before_selection"
                cursor.offset := cursor_pos
            } else if cursor_pos < selected_end {
                cursor.segment := "selected"
                cursor.offset := cursor_pos - selected_start
            } else {
                cursor.segment := "after_selection"
                cursor.offset := cursor_pos - selected_end
            }
        } else {
            cursor.segment := "before_selection"
            cursor.offset := cursor_pos
        }
    }

    local preedit_buffer
    {
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

RabbitGetPreeditGroups(preedit) {
    local groups := []
    local names := ["before_selection", "selected", "after_selection"]
    local index := 0
    local cursor := preedit.cursor

    for name in names {
        index += 1
        local text := preedit.%name%
        local group := {
            name: name,
            highlighted: index == 2,
            segments: []
        }
        if cursor && cursor.segment = name {
            local before_cursor, after_cursor
            RabbitSplitUtf8Text(text, cursor.offset, &before_cursor, &after_cursor)
            if before_cursor {
                group.segments.Push({text: before_cursor, cursor: false})
            }
            group.segments.Push({text: cursor.text, cursor: true})
            if after_cursor {
                group.segments.Push({text: after_cursor, cursor: false})
            }
        } else if text {
            group.segments.Push({text: text, cursor: false})
        }
        groups.Push(group)
    }
    return groups
}

RabbitSplitUtf8Text(text, byte_offset, &before, &after) {
    local buffer_length := StrPut(text, "UTF-8")
    local text_buffer := Buffer(buffer_length, 0)
    StrPut(text, text_buffer, "UTF-8")
    before := byte_offset > 0 ? StrGet(text_buffer, byte_offset, "UTF-8") : ""
    after := StrGet(text_buffer.Ptr + byte_offset, "UTF-8")
}
