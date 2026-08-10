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

class RabbitLegacyCandidateLayout {
    static Calculate(presentation, metrics, margin_x, margin_y, min_width) {
        local x := margin_x
        local y := margin_y
        local preedit_height := 0
        local max_width := 0
        local layout := {pre: 0, sel: 0, post: 0, rows: []}

        if HasProp(metrics, "preedit") {
            local preedit_groups := RabbitGetPreeditGroups(presentation.preedit)
            local x := margin_x
            layout.preedit_segments := []
            loop preedit_groups.Length {
                local group := preedit_groups[A_Index]
                local group_metrics := metrics.preedit[A_Index]
                if A_Index == 2 {
                    x += margin_x
                }
                loop group.segments.Length {
                    local segment := group.segments[A_Index]
                    local segment_metrics := group_metrics[A_Index]
                    layout.preedit_segments.Push({
                        x: x,
                        y: y,
                        w: segment_metrics.w,
                        h: segment_metrics.h,
                        text: segment.text,
                        highlighted: group.highlighted,
                        cursor: segment.cursor
                    })
                    preedit_height := max(preedit_height, segment_metrics.h)
                    x += segment_metrics.w
                }
            }
            if layout.preedit_segments.Length {
                max_width := x - margin_x
            }
        } else if HasProp(metrics, "pre") && metrics.pre {
            layout.pre := {x: x, y: y, w: metrics.pre.w, h: metrics.pre.h}
            x += metrics.pre.w + margin_x
            preedit_height := max(preedit_height, metrics.pre.h)
            max_width += metrics.pre.w + margin_x
        }
        if HasProp(metrics, "sel") && metrics.sel {
            layout.sel := {x: x, y: y, w: metrics.sel.w, h: metrics.sel.h}
            x += metrics.sel.w + margin_x
            preedit_height := max(preedit_height, metrics.sel.h)
            max_width += metrics.sel.w + margin_x
        }
        if HasProp(metrics, "post") && metrics.post {
            layout.post := {x: x, y: y, w: metrics.post.w, h: metrics.post.h}
            preedit_height := max(preedit_height, metrics.post.h)
            max_width += metrics.post.w
        }

        local max_label_width := 0
        local max_candidate_width := 0
        local max_comment_width := 0
        local has_comment := false
        loop metrics.rows.Length {
            local row_metrics := metrics.rows[A_Index]
            local row_presentation := presentation.candidates[A_Index]
            max_label_width := max(max_label_width, row_metrics.label.w + margin_x)
            max_candidate_width := max(max_candidate_width, row_metrics.candidate.w + margin_x)
            max_comment_width := max(max_comment_width, row_metrics.comment.w)
            if row_presentation.comment {
                has_comment := true
            }
        }

        local list_width := max_label_width + max_candidate_width
            + has_comment * max_comment_width
        local box_width := max(min_width, list_width)
        if box_width > max_width && layout.post {
            layout.post.w += box_width - max_width
        }
        max_width := max(box_width, max_width)
        if max_width > list_width {
            max_candidate_width += max_width - list_width
        }

        y := 2 * margin_y + preedit_height
        loop metrics.rows.Length {
            local row_metrics := metrics.rows[A_Index]
            x := margin_x
            local row_height := max(
                row_metrics.label.h, row_metrics.candidate.h, row_metrics.comment.h)
            layout.rows.Push({
                label: {
                    x: x, y: y, w: max_label_width, h: row_height
                },
                candidate: {
                    x: x + max_label_width, y: y,
                    w: max_candidate_width, h: row_height
                },
                comment: {
                    x: x + max_label_width + max_candidate_width, y: y,
                    w: max_comment_width, h: row_height
                }
            })
            y += row_height + margin_y
        }

        layout.has_comment := has_comment
        layout.width := max_width + 2 * margin_x
        layout.height := y
        return layout
    }
}
