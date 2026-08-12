/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 * Copyright (c) 2005 Tim <zerxmega@foxmail.com>
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

#Include RabbitUIStyleSnapshot.ahk
#Include RabbitCandidateBoxCommon.ahk
#Include RabbitCandidatePresentation.ahk
#Include RabbitFloatingPreedit.ahk
#Include RabbitLayeredWindow.ahk
#Include Direct2D/Direct2D.ahk

class CandidateBox {
    gui := 0
    static FLOW_ANIMATION_DURATION := 160
    static FLOW_ANIMATION_INTERVAL := 15

    __New(style, d2d_constructor := Direct2D) {
        this.gui := 0
        this.d2d := 0
        this.d2d_constructor := d2d_constructor
        this.layered_window := 0
        this.render_width := 0
        this.render_height := 0
        this.built := false
        this.visible := false
        this.disposed := false
        this.flow_expanded := false
        this.flow_animation_pending := false
        this.flow_animation_active := false
        this.flow_animation_anchor_bottom := false
        this.flow_animation_start_height := 0
        this.flow_animation_target_height := 0
        this.flow_animation_started_at := 0
        this.flow_animation_uses_previous_frame := false
        this.flow_animation_collapse_to_zero := false
        this.flow_animation_finish_pending := false
        this.floating_preedit := 0
        this.floating_preedit_active := false
        this.floating_preedit_failed := false
        this.floating_preedit_error := ""
        this.flow_animation_anchor_y := 0
        this.display_height := 0
        this.display_x := 0
        this.display_y := 0
        this.display_render_y := 0
        this.display_anchor_bottom := false
        this.target_x := 0
        this.target_y := 0
        this.target_anchor_bottom := false
        this.rendering := false
        this.render_pending := false
        this.flow_animation_callback := this.RenderFlowAnimationFrame.Bind(this)
        this.flow_animation_finish_callback := this.FinishFlowAnimation.Bind(this)
        this.render_pending_callback := this.RenderPendingFrame.Bind(this)

        try {
            ; +E0x8080088: WS_EX_NOACTIVATE | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST
            this.gui := Gui("-Caption -DPIScale +E0x8080088")
            this.d2d := this.CreateRenderTarget(1, 1)
            this.layered_window := RabbitLayeredWindow(this.gui.Hwnd)
            this.dpiScale := this.d2d.GetDesktopDpiScale()
            this.UpdateStyle(style)
        } catch as error {
            this.Dispose()
            throw error
        }
    }

    __Delete() {
        this.Dispose()
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.Hide()
        this.floating_preedit := 0
        this.layered_window := 0
        this.d2d := 0
        if this.gui {
            this.gui.Destroy()
            this.gui := 0
        }
        this.built := false
        this.disposed := true
    }

    UpdateStyle(style) {
        this.AssertNotDisposed()
        this.style := style
        this.borderWidth := style.border_width
        this.borderColor := style.border_color
        this.boxCornerR := style.corner_radius
        this.hlCornerR := style.round_corner
        this.lineSpacing := style.margin_y
        this.padding := style.margin_x
        this.layoutType := style.layout_type = "flow"
            ? "flow"
            : style.layout_type = "vertical_text" ? "vertical_text" : "stacked"
        this.verticalTextLeftToRight := style.vertical_text_left_to_right
        this.candidateSpacing := style.candidate_spacing
        this.alignType := style.align_type

        this.mainFont := this.CreateFontObj(style.font_face, style.font_point)
        this.labFont := this.CreateFontObj(style.label_font_face, style.label_font_point)
        this.commentFont := this.CreateFontObj(style.comment_font_face, style.comment_font_point)

        ; Preedit style
        this.textColor := style.text_color
        this.backgroundColor := style.back_color
        this.hlTxtColor := style.hilited_text_color
        this.hlBgColor := style.hilited_back_color
        ; Candidate style
        this.hlCandTxtColor := style.hilited_candidate_text_color
        this.hlCandBgColor := style.hilited_candidate_back_color
        this.candTxtColor := style.candidate_text_color
        this.candBgColor := style.candidate_back_color

        ; Some color schemes do not define these colors.
        this.labelColor := style.label_color
        this.hlLabelColor := style.hilited_label_color
        this.commentTxtColor := style.comment_text_color
        this.hlCommentTxtColor := style.hilited_comment_text_color
        if this.floating_preedit {
            this.floating_preedit.UpdateStyle(style)
            if !style.floating_preedit {
                this.floating_preedit.Hide()
                this.floating_preedit_active := false
            }
        }
    }

    SetFlowAnimationAnchor(anchor_bottom) {
        this.flow_animation_anchor_bottom := !!anchor_bottom
    }

    CreateFontObj(name, size) {
        local em_to_pt := 96.0 / 72.0
        local px := size * em_to_pt * this.dpiScale
        return { name: name, size: px }
    }

    Build(context, &win_w, &win_h) {
        local presentation := RabbitCandidatePresentation(context, this.style.label_format)
        this.BuildPresentation(presentation, &win_w, &win_h)
    }

    BuildPresentation(presentation, &win_w, &win_h, max_width := 0) {
        this.floating_preedit_active := false
        if this.floating_preedit {
            this.floating_preedit.Hide()
        }
        this.BuildPresentationLayout(presentation, &win_w, &win_h, max_width, true)
    }

    BuildFloatingPresentation(presentation, caret_x, caret_y, caret_w, caret_h, &win_w, &win_h, max_width := 0) {
        this.AssertNotDisposed()
        this.floating_preedit_active := false
        if !this.style.floating_preedit || this.floating_preedit_failed {
            if this.floating_preedit {
                this.floating_preedit.Hide()
            }
            this.BuildPresentationLayout(presentation, &win_w, &win_h, max_width, true)
            return
        }
        if caret_h <= 0 {
            if this.floating_preedit {
                this.floating_preedit.Hide()
            }
            this.BuildPresentationLayout(presentation, &win_w, &win_h, max_width, true)
            return
        }
        if !RabbitFloatingPreedit.HasText(presentation.preedit) {
            if this.floating_preedit {
                this.floating_preedit.Hide()
            }
            this.BuildPresentationLayout(presentation, &win_w, &win_h, max_width, false)
            return
        }
        try {
            if !this.floating_preedit {
                this.floating_preedit := RabbitFloatingPreedit(this.style, this.d2d_constructor)
            }
            this.floating_preedit.Build(presentation.preedit, caret_x, caret_y, caret_w, caret_h)
        } catch as error {
            this.floating_preedit_failed := true
            this.floating_preedit_error := error.Message
            if this.floating_preedit {
                this.floating_preedit.Hide()
            }
            this.BuildPresentationLayout(presentation, &win_w, &win_h, max_width, true)
            return
        }
        this.floating_preedit_active := true
        this.BuildPresentationLayout(presentation, &win_w, &win_h, max_width, false)
    }

    BuildPresentationLayout(presentation, &win_w, &win_h, max_width, include_preedit) {
        local expanded
        this.AssertNotDisposed()
        this.flow_animation_anchor_bottom := false
        if this.layoutType = "flow" && HasProp(presentation, "flow_page_size") {
            expanded := presentation.candidates.Length > presentation.flow_page_size
            this.flow_animation_pending := this.visible
                && (this.flow_animation_active || expanded != this.flow_expanded)
            this.flow_expanded := expanded
            this.BuildFlow(presentation, &win_w, &win_h, max_width, include_preedit)
            return
        }
        this.flow_animation_pending := false
        this.flow_expanded := false
        if this.layoutType = "vertical_text" {
            this.BuildVerticalText(presentation, &win_w, &win_h, include_preedit)
            return
        }
        this.BuildStacked(presentation, &win_w, &win_h, include_preedit)
    }

    BuildStacked(presentation, &win_w, &win_h, include_preedit := true) { ; build text layout
        local base_x, base_y, max_row_width
        local total_rows_height, label_box, candidate_box
        local comment_text, comment_box, row_rect, increment, label_width, candidate_width, comment, comment_gap
        this.num_candidates := presentation.candidates.Length
        this.hilited_index := presentation.highlighted_index
        this.candidateHighlights := []

        ; Build preedit layout
        base_x := this.borderWidth + this.padding
        base_y := this.borderWidth + this.lineSpacing
        this.preeditLayout := include_preedit
            ? this.BuildPreeditLayout(presentation, base_x, base_y)
            : this.CreateEmptyPreeditLayout(base_x, base_y)
        max_row_width := this.preeditLayout.width

        ; Build candidates layout
        total_rows_height := include_preedit ? this.preeditLayout.height + this.lineSpacing : 0
        base_y := base_y + total_rows_height
        this.candidatesLayout := { labels: [], cands: [], comments: [], rows: [] }

        Loop this.num_candidates {
            local candidate := presentation.candidates[A_Index]
            this.candidateHighlights.Push(candidate.highlighted)
            label_box := this.GetTextMetrics(candidate.label, this.labFont)
            this.candidatesLayout.labels.Push(
                { x: base_x, y: base_y, w: label_box.w, h: label_box.h, text: candidate.label })

            candidate_box := this.GetTextMetrics(candidate.text, this.mainFont)
            this.candidatesLayout.cands.Push({
                x: base_x + label_box.w + this.padding,
                y: base_y,
                w: candidate_box.w,
                h: candidate_box.h,
                text: candidate.text
            })

            comment_text := candidate.comment
            comment_box := this.GetTextMetrics(comment_text, this.commentFont)
            this.candidatesLayout.comments.Push({ x: base_x + label_box.w + candidate_box.w, y: base_y, w: comment_box.w, h: comment_box.h, text: comment_text })

            row_rect := {
                x: base_x, y: base_y,
                w: label_box.w + this.padding + candidate_box.w + (comment_text ? this.padding * 2 + comment_box.w : 0),
                h: Max(label_box.h, candidate_box.h, comment_box.h)
            }
            this.candidatesLayout.rows.Push(row_rect)
            if row_rect.w > max_row_width {
                max_row_width := row_rect.w
            }
            increment := row_rect.h + this.lineSpacing
            base_y += increment, total_rows_height += increment
        }
        if this.num_candidates {
            total_rows_height -= this.lineSpacing ; remove extra line spacing
        }

        this.commentOffset := 0
        this.boxWidth := Ceil(max_row_width) + (this.borderWidth + this.padding) * 2
        if this.boxWidth < this.style.min_width {
            this.commentOffset := this.style.min_width - this.boxWidth
            this.boxWidth := this.style.min_width
        }
        this.boxHeight := Ceil(total_rows_height) + (this.borderWidth + this.padding) * 2
        win_w := this.boxWidth
        win_h := this.boxHeight
        this.built := true

        ; get better spacing to align comments
        loop this.num_candidates {
            label_width := this.candidatesLayout.labels[A_Index].w
            candidate_width := this.candidatesLayout.cands[A_Index].w
            comment := this.candidatesLayout.comments[A_Index]

            if comment.w > 0 {
                comment_gap := max_row_width - label_width - candidate_width - comment.w - this.padding
                comment.x += comment_gap + this.commentOffset
            }
        }
    }

    BuildPreeditLayout(presentation, base_x, base_y) {
        local groups := RabbitGetPreeditGroups(presentation.preedit)
        local x := base_x
        local height := 0
        local selected_x := 0
        local selected_width := 0
        local selected_height := 0
        local layout := {
            segments: [],
            selectedBox: 0,
            left: base_x,
            top: base_y,
            width: 0,
            height: 0
        }

        for group_index, group in groups {
            if group_index == 2 || group_index == 3 {
                x += this.padding
            }
            for segment in group.segments {
                local metrics := this.GetTextMetrics(segment.text, this.mainFont)
                layout.segments.Push({
                    x: x,
                    y: base_y,
                    w: metrics.w,
                    h: metrics.h,
                    text: segment.text,
                    highlighted: group.highlighted,
                    cursor: segment.cursor
                })
                if group.highlighted {
                    if !selected_width {
                        selected_x := x
                    }
                    selected_width += metrics.w
                    selected_height := Max(selected_height, metrics.h)
                }
                height := Max(height, metrics.h)
                x += metrics.w
            }
        }

        if selected_width {
            layout.selectedBox := {
                x: selected_x,
                y: base_y,
                w: selected_width,
                h: selected_height
            }
        }
        layout.width := x - base_x
        layout.height := height
        return layout
    }

    CreateEmptyPreeditLayout(base_x, base_y) {
        return {
            segments: [],
            selectedBox: 0,
            left: base_x,
            top: base_y,
            width: 0,
            height: 0
        }
    }

    BuildVerticalText(presentation, &win_w, &win_h, include_preedit := true) {
        local base_x := this.borderWidth + this.padding
        local base_y := this.borderWidth + this.lineSpacing
        local preedit_layout := include_preedit
            ? this.BuildVerticalPreeditLayout(presentation, base_x, base_y)
            : this.CreateEmptyPreeditLayout(base_x, base_y)
        local cards := []
        local candidates_width := 0
        local content_height := preedit_layout.height
        local content_width, content_bottom, x, y, card, label, candidate, candidate_box, comment

        this.AssertNotDisposed()
        this.num_candidates := presentation.candidates.Length
        this.hilited_index := presentation.highlighted_index
        this.candidateHighlights := []
        this.preeditLayout := preedit_layout
        this.candidatesLayout := { labels: [], cands: [], comments: [], rows: [] }

        Loop this.num_candidates {
            candidate := presentation.candidates[A_Index]
            label := this.GetVerticalTextMetrics(candidate.label, this.labFont)
            candidate_box := this.GetVerticalTextMetrics(candidate.text, this.mainFont)
            comment := this.GetVerticalTextMetrics(candidate.comment, this.commentFont)
            card := {
                label: label,
                candidate: candidate_box,
                comment: comment,
                width: Max(label.w, candidate_box.w, comment.w),
                height: label.h + (label.h ? this.padding : 0) + candidate_box.h
                    + (comment.h ? this.padding + comment.h : 0)
            }
            cards.Push(card)
            candidates_width += card.width
            if A_Index > 1 {
                candidates_width += this.candidateSpacing
            }
            content_height := Max(content_height, card.height)
            this.candidateHighlights.Push(candidate.highlighted)
        }

        content_width := candidates_width
        if preedit_layout.width {
            if content_width {
                content_width += this.candidateSpacing
            }
            content_width += preedit_layout.width
        }
        this.boxWidth := Ceil(content_width) + (this.borderWidth + this.padding) * 2
        this.boxHeight := Max(this.style.min_height, Ceil(content_height) + (this.borderWidth + this.lineSpacing) * 2)
        content_bottom := this.boxHeight - this.borderWidth - this.lineSpacing
        x := this.verticalTextLeftToRight ? base_x : base_x + content_width
        if preedit_layout.width && !this.verticalTextLeftToRight {
            x -= preedit_layout.width
            this.OffsetLayoutX(preedit_layout, x - preedit_layout.left)
            x -= this.candidateSpacing
        } else if preedit_layout.width {
            x += preedit_layout.width
            if this.num_candidates {
                x += this.candidateSpacing
            }
        }

        Loop this.num_candidates {
            candidate := presentation.candidates[A_Index]
            card := cards[A_Index]
            if !this.verticalTextLeftToRight {
                x -= card.width
            }
            y := base_y
            this.candidatesLayout.labels.Push({
                x: x + (card.width - card.label.w) / 2,
                y: y,
                w: card.label.w,
                h: card.label.h,
                text: candidate.label
            })
            y += card.label.h + (card.label.h ? this.padding : 0)
            this.candidatesLayout.cands.Push({
                x: x + (card.width - card.candidate.w) / 2,
                y: y,
                w: card.candidate.w,
                h: card.candidate.h,
                text: candidate.text
            })
            this.candidatesLayout.comments.Push({
                x: x + (card.width - card.comment.w) / 2,
                y: content_bottom - card.comment.h,
                w: card.comment.w,
                h: card.comment.h,
                text: candidate.comment
            })
            this.candidatesLayout.rows.Push({ x: x, y: base_y, w: card.width, h: content_bottom - base_y })
            x += this.verticalTextLeftToRight ? card.width + this.candidateSpacing : -this.candidateSpacing
        }

        win_w := this.boxWidth
        win_h := this.boxHeight
        this.built := true
    }

    BuildVerticalPreeditLayout(presentation, base_x, base_y) {
        local groups := RabbitGetPreeditGroups(presentation.preedit)
        local y := base_y
        local width := 0
        local selected_y := 0
        local selected_height := 0
        local layout := {
            segments: [],
            selectedBox: 0,
            left: base_x,
            top: base_y,
            width: 0,
            height: 0
        }

        for group_index, group in groups {
            if group_index == 2 || group_index == 3 {
                y += this.padding
            }
            for segment in group.segments {
                local metrics := this.GetVerticalTextMetrics(segment.text, this.mainFont)
                layout.segments.Push({
                    x: base_x,
                    y: y,
                    w: metrics.w,
                    h: metrics.h,
                    text: segment.text,
                    highlighted: group.highlighted,
                    cursor: segment.cursor
                })
                if group.highlighted {
                    if !selected_height {
                        selected_y := y
                    }
                    selected_height += metrics.h
                    width := Max(width, metrics.w)
                }
                width := Max(width, metrics.w)
                y += metrics.h
            }
        }

        if selected_height {
            layout.selectedBox := { x: base_x, y: selected_y, w: width, h: selected_height }
        }
        layout.width := width
        layout.height := y - base_y
        return layout
    }

    OffsetLayoutX(layout, offset) {
        local segment
        if !offset {
            return
        }
        for segment in layout.segments {
            segment.x += offset
        }
        if layout.selectedBox {
            layout.selectedBox.x += offset
        }
        layout.left += offset
    }

    OffsetCandidateLayoutX(offset) {
        local layout_name, layout, row
        for layout_name in ["labels", "cands", "comments", "rows"] {
            layout := this.candidatesLayout.%layout_name%
            for row in layout {
                row.x += offset
            }
        }
    }

    BuildFlow(presentation, &win_w, &win_h, max_width, include_preedit := true) {
        local base_x := this.borderWidth + this.padding
        local base_y := this.borderWidth + this.lineSpacing
        local preedit_layout := include_preedit
            ? this.BuildPreeditLayout(presentation, base_x, base_y)
            : this.CreateEmptyPreeditLayout(base_x, base_y)
        local preedit_width := preedit_layout.width
        local preedit_height := preedit_layout.height
        local page_size := presentation.flow_page_size
        local max_row_width := preedit_width
        local available_width := max_width ? Max(1, max_width - (this.borderWidth + this.padding) * 2) : 0
        local card_max_width := available_width
            ? Max(1, (available_width - (page_size - 1) * this.candidateSpacing) / page_size)
            : 0
        local column_count, row_count, column_widths := [], label_widths := [], row_heights := []
        local cards := [], column_x := [], row_y := []
        local content_width := 0

        this.AssertNotDisposed()
        this.num_candidates := presentation.candidates.Length
        this.hilited_index := 0
        this.candidateHighlights := []
        this.preeditLayout := preedit_layout
        this.candidatesLayout := { labels: [], cands: [], comments: [], rows: [] }
        if include_preedit {
            base_y += preedit_height + this.lineSpacing
        }

        Loop page_size {
            label_widths.Push(0)
        }
        Loop this.num_candidates {
            local candidate := presentation.candidates[A_Index]
            local column := Mod(A_Index - 1, page_size) + 1
            label_widths[column] := Max(label_widths[column], this.GetTextMetrics(candidate.label, this.labFont).w)
        }
        column_count := Min(page_size, this.num_candidates)
        row_count := Ceil(this.num_candidates / page_size)
        Loop column_count {
            column_widths.Push(0)
        }
        Loop row_count {
            row_heights.Push(0)
        }

        Loop this.num_candidates {
            local candidate := presentation.candidates[A_Index]
            local column := Mod(A_Index - 1, page_size) + 1
            local row := Ceil(A_Index / page_size)
            local label_box := this.GetTextMetrics(candidate.label, this.labFont)
            local label_width := label_widths[column]
            local candidate_box := this.GetTextMetrics(candidate.text, this.mainFont)
            local comment_box := this.GetTextMetrics(candidate.comment, this.commentFont)
            local card_width := label_width + (label_width ? this.padding : 0) + candidate_box.w
            if comment_box.w {
                card_width += this.padding + comment_box.w
            }
            if card_max_width && card_width > card_max_width {
                this.TruncateFlowCandidate(candidate, label_width, card_max_width)
                candidate_box := this.GetTextMetrics(candidate.text, this.mainFont)
                comment_box := this.GetTextMetrics(candidate.comment, this.commentFont)
                card_width := label_width + (label_width ? this.padding : 0) + candidate_box.w
                if comment_box.w {
                    card_width += this.padding + comment_box.w
                }
            }
            cards.Push({
                label_box: label_box,
                candidate_box: candidate_box,
                comment_box: comment_box,
                column: column,
                row: row,
                width: card_width,
                height: Max(label_box.h, candidate_box.h, comment_box.h)
            })
            column_widths[column] := Max(column_widths[column], card_width)
            row_heights[row] := Max(row_heights[row], cards[A_Index].height)
        }

        Loop column_count {
            column_x.Push(base_x + content_width)
            content_width += column_widths[A_Index]
            if A_Index < column_count {
                content_width += this.candidateSpacing
            }
        }
        max_row_width := Max(max_row_width, content_width)
        Loop row_count {
            row_y.Push(base_y)
            base_y += row_heights[A_Index]
            if A_Index < row_count {
                base_y += this.candidateSpacing
            }
        }

        Loop this.num_candidates {
            local candidate := presentation.candidates[A_Index]
            local card_info := cards[A_Index]
            local label_width := label_widths[card_info.column]
            local card_x := column_x[card_info.column]
            local card_y := row_y[card_info.row]
            local candidate_x := card_x + label_width + (label_width ? this.padding : 0)
            local comment_x := candidate_x + card_info.candidate_box.w
            if card_info.comment_box.w {
                comment_x += this.padding
            }
            this.candidatesLayout.labels.Push({
                x: card_x,
                y: this.AlignFlowText(card_y, row_heights[card_info.row], card_info.label_box.h),
                w: card_info.label_box.w,
                h: card_info.label_box.h,
                text: candidate.label
            })
            this.candidatesLayout.cands.Push({
                x: candidate_x,
                y: this.AlignFlowText(card_y, row_heights[card_info.row], card_info.candidate_box.h),
                w: card_info.candidate_box.w,
                h: card_info.candidate_box.h,
                text: candidate.text
            })
            this.candidatesLayout.comments.Push({
                x: comment_x,
                y: this.AlignFlowText(card_y, row_heights[card_info.row], card_info.comment_box.h),
                w: card_info.comment_box.w,
                h: card_info.comment_box.h,
                text: candidate.comment
            })
            this.candidatesLayout.rows.Push({
                x: card_x, y: card_y, w: column_widths[card_info.column], h: row_heights[card_info.row]
            })
            this.candidateHighlights.Push(candidate.highlighted)
        }

        this.boxWidth := Ceil(max_row_width) + (this.borderWidth + this.padding) * 2
        this.boxHeight := Ceil(base_y + this.borderWidth + this.lineSpacing)
        win_w := this.boxWidth
        win_h := this.boxHeight
        this.built := true
    }

    AlignFlowText(row_y, row_height, text_height) {
        if this.alignType = "center" {
            return row_y + (row_height - text_height) / 2
        }
        if this.alignType = "bottom" {
            return row_y + row_height - text_height
        }
        return row_y
    }

    TruncateFlowCandidate(candidate, label_width, available_width) {
        local gap_width := label_width ? this.padding : 0
        local content_width := Max(0, available_width - label_width - gap_width)
        local candidate_width := this.GetTextMetrics(candidate.text, this.mainFont).w
        if candidate_width > content_width {
            candidate.comment := ""
            candidate.text := this.TruncateText(candidate.text, content_width, this.mainFont)
            return
        }
        if candidate.comment {
            local comment_width := Max(0, content_width - candidate_width - this.padding)
            candidate.comment := this.TruncateText(candidate.comment, comment_width, this.commentFont)
        }
    }

    TruncateText(text, max_width, font) {
        local ellipsis := "…"
        local truncated := text
        if max_width <= 0 {
            return ""
        }
        if this.GetTextMetrics(text, font).w <= max_width {
            return text
        }
        if this.GetTextMetrics(ellipsis, font).w > max_width {
            return ""
        }
        while truncated && this.GetTextMetrics(truncated . ellipsis, font).w > max_width {
            truncated := SubStr(truncated, 1, -1)
        }
        return truncated ? truncated . ellipsis : ellipsis
    }

    Show(x, y) {
        local collapse
        this.AssertNotDisposed()
        if !this.built {
            throw Error("Candidate box must be built before it is shown.")
        }
        if this.floating_preedit_active {
            this.floating_preedit.Show()
        }
        this.CancelFlowAnimationFinish()
        this.StopFlowAnimation()
        if this.floating_preedit_active && !this.num_candidates {
            this.flow_animation_pending := false
            this.render_pending := false
            if this.visible {
                this.gui.Hide()
                this.visible := false
            }
            return
        }
        this.target_x := x
        this.target_y := y
        this.target_anchor_bottom := this.flow_animation_anchor_bottom
        if this.flow_animation_pending {
            collapse := this.display_height > this.boxHeight
            if !collapse {
                this.display_x := x
                this.display_y := y
                this.display_render_y := y
                this.display_anchor_bottom := this.target_anchor_bottom
            } else {
                this.flow_animation_anchor_bottom := this.display_anchor_bottom
            }
            this.flow_animation_collapse_to_zero := collapse
                && this.display_anchor_bottom != this.target_anchor_bottom
            this.StartFlowAnimation()
            return
        }
        this.flow_animation_collapse_to_zero := false
        this.display_x := x
        this.display_y := y
        this.display_render_y := y
        this.display_anchor_bottom := this.target_anchor_bottom
        this.RenderFrame(this.boxHeight)
    }

    StartFlowAnimation() {
        local start_height := this.display_height ? this.display_height : this.boxHeight
        this.flow_animation_pending := false
        this.flow_animation_active := true
        this.flow_animation_start_height := Max(1, start_height)
        this.flow_animation_target_height := this.flow_animation_collapse_to_zero ? 0 : this.boxHeight
        this.flow_animation_uses_previous_frame := this.flow_animation_start_height > this.flow_animation_target_height
            && this.render_height >= this.flow_animation_start_height
        this.flow_animation_anchor_y := this.flow_animation_anchor_bottom
            ? this.display_render_y + (this.flow_animation_uses_previous_frame ? this.display_height : this.boxHeight)
            : this.display_render_y
        this.flow_animation_started_at := A_TickCount
        this.RenderFlowAnimationFrame()
        if this.flow_animation_active {
            SetTimer(this.flow_animation_callback, CandidateBox.FLOW_ANIMATION_INTERVAL)
        }
    }

    RenderFlowAnimationFrame() {
        local elapsed := A_TickCount - this.flow_animation_started_at
        local progress := Min(1, Max(0, elapsed / CandidateBox.FLOW_ANIMATION_DURATION))
        local eased_progress := 1 - (1 - progress) ** 3
        local height := Round(
            this.flow_animation_start_height
                + (this.flow_animation_target_height - this.flow_animation_start_height) * eased_progress)

        if this.flow_animation_uses_previous_frame {
            this.RenderPreviousFrame(height)
        } else {
            this.RenderFrame(height)
        }
        if progress >= 1 {
            local used_previous_frame := this.flow_animation_uses_previous_frame
            local collapse_to_zero := this.flow_animation_collapse_to_zero
            this.StopFlowAnimation()
            if used_previous_frame {
                if collapse_to_zero {
                    this.flow_animation_finish_pending := true
                    SetTimer(this.flow_animation_finish_callback, -1)
                } else {
                    this.FinishFlowAnimation()
                }
            }
        }
    }

    FinishFlowAnimation() {
        this.flow_animation_finish_pending := false
        if this.disposed || !this.visible {
            return
        }
        this.display_x := this.target_x
        this.display_y := this.target_y
        this.display_render_y := this.target_y
        this.flow_animation_anchor_bottom := this.target_anchor_bottom
        this.display_anchor_bottom := this.target_anchor_bottom
        this.RenderFrame(this.boxHeight)
    }

    RenderPreviousFrame(height) {
        local source_y, display_y
        if !this.BeginRender() {
            return
        }
        try {
            height := Min(this.render_height, Max(1, height))
            source_y := this.flow_animation_anchor_bottom ? this.render_height - height : 0
            display_y := this.flow_animation_anchor_bottom ? this.flow_animation_anchor_y - height : this.flow_animation_anchor_y
            this.layered_window.Update(
                this.d2d.ID2D1RenderTarget.GetWICBitmap(),
                this.render_width,
                height,
                this.display_x,
                display_y,
                source_y
            )
            this.display_height := height
            this.display_render_y := display_y
            this.display_anchor_bottom := this.flow_animation_anchor_bottom
        } finally {
            this.EndRender()
        }
    }

    RenderFrame(height) {
        local background_x, background_y, background_width, background_height, background_radius, highlight_width
        local row_rect, label_color, candidate_color, comment_color, label, cand, comment
        local segment, selected_box, source_y, display_y
        local num_candidates, preedit_layout, candidates_layout, candidate_highlights
        if !this.BeginRender() {
            return
        }
        try {
            ; A new input thread can build the next layout while this frame is drawing.
            ; Keep this frame internally consistent; the queued render will draw the newer layout.
            num_candidates := this.num_candidates
            preedit_layout := this.preeditLayout
            candidates_layout := this.candidatesLayout
            candidate_highlights := this.candidateHighlights
            height := Min(this.boxHeight, Max(1, height))
            source_y := this.flow_animation_anchor_bottom ? this.boxHeight - height : 0
            if this.flow_animation_active && this.flow_animation_anchor_bottom {
                display_y := this.flow_animation_anchor_y - height
            } else {
                display_y := this.display_y + (this.flow_animation_anchor_bottom ? source_y : 0)
            }
            this.EnsureRenderTarget()
            this.d2d.BeginDraw()
            this.d2d.PushAxisAlignedClip(0, source_y, this.boxWidth, height)

            if this.borderWidth > 0 {
                ; Draw outer border as filled rounded rectangle (border color)
                this.d2d.FillRoundedRectangle(0, 0, this.boxWidth, this.boxHeight, this.boxCornerR, this.boxCornerR, this.borderColor)
                ; Draw inner background next
                background_x := this.borderWidth, background_y := this.borderWidth
                background_width := this.boxWidth - this.borderWidth * 2
                background_height := this.boxHeight - this.borderWidth * 2
                background_radius := this.boxCornerR > this.borderWidth ? this.boxCornerR - this.borderWidth : 0
                this.d2d.FillRoundedRectangle(background_x, background_y, background_width, background_height, background_radius, background_radius, this.backgroundColor)
            } else {
                this.d2d.FillRoundedRectangle(0, 0, this.boxWidth, this.boxHeight, this.boxCornerR, this.boxCornerR, this.backgroundColor)
            }

            ; Draw preedit
            if (selected_box := preedit_layout.selectedBox) {
                ; Highlight background for preedit selection.
                this.d2d.FillRoundedRectangle(
                    selected_box.x, selected_box.y,
                    selected_box.w, selected_box.h,
                    this.hlCornerR, this.hlCornerR, this.hlBgColor)
            }
            for segment in preedit_layout.segments {
                this.DrawLayoutText(segment, this.mainFont, segment.highlighted ? this.hlTxtColor : this.textColor)
            }

            highlight_width := this.boxWidth - this.borderWidth * 2 - this.padding * 2
            ; Draw candidates
            Loop num_candidates {
                row_rect := candidates_layout.rows[A_Index]
                label_color := this.labelColor
                candidate_color := this.candTxtColor
                comment_color := this.commentTxtColor
                if candidate_highlights[A_Index] { ; Draw highlight if selected
                    label_color := this.hlLabelColor
                    candidate_color := this.hlCandTxtColor
                    comment_color := this.hlCommentTxtColor
                    this.d2d.FillRoundedRectangle(
                        row_rect.x,
                        row_rect.y,
                        this.layoutType != "stacked" ? row_rect.w : highlight_width,
                        row_rect.h,
                        this.hlCornerR,
                        this.hlCornerR,
                        this.hlCandBgColor
                    )
                }

                label := candidates_layout.labels[A_Index]
                this.DrawLayoutText(label, this.labFont, label_color)

                cand := candidates_layout.cands[A_Index]
                this.DrawLayoutText(cand, this.mainFont, candidate_color)

                comment := candidates_layout.comments[A_Index]
                if comment.w > 0 {
                    this.DrawLayoutText(comment, this.commentFont, comment_color)
                }
            }

            this.d2d.PopAxisAlignedClip()
            this.d2d.EndDraw()
            this.layered_window.Update(
                this.d2d.ID2D1RenderTarget.GetWICBitmap(),
                this.boxWidth,
                height,
                this.display_x,
                display_y,
                source_y
            )
            if !this.visible {
                this.gui.Show("NA")
                this.visible := true
            }
            this.display_height := height
            this.display_render_y := display_y
            this.display_anchor_bottom := this.flow_animation_anchor_bottom
        } finally {
            this.EndRender()
        }
    }

    BeginRender() {
        if this.rendering {
            this.render_pending := true
            return false
        }
        this.rendering := true
        return true
    }

    EndRender() {
        this.rendering := false
        if this.render_pending && !this.disposed {
            this.render_pending := false
            SetTimer(this.render_pending_callback, -1)
        }
    }

    RenderPendingFrame() {
        if this.disposed || !this.visible {
            return
        }
        if this.flow_animation_active {
            this.RenderFlowAnimationFrame()
        } else {
            this.RenderFrame(this.boxHeight)
        }
    }

    Hide() {
        if this.disposed {
            return
        }
        this.StopFlowAnimation()
        this.CancelFlowAnimationFinish()
        this.flow_animation_pending := false
        this.render_pending := false
        if this.floating_preedit {
            this.floating_preedit.Hide()
        }
        if this.visible {
            this.gui.Hide()
            this.visible := false
        }
    }

    StopFlowAnimation() {
        if this.flow_animation_active {
            SetTimer(this.flow_animation_callback, 0)
            this.flow_animation_active := false
        }
        this.flow_animation_uses_previous_frame := false
    }

    CancelFlowAnimationFinish() {
        if this.flow_animation_finish_pending {
            SetTimer(this.flow_animation_finish_callback, 0)
            this.flow_animation_finish_pending := false
        }
    }

    EnsureRenderTarget() {
        if this.render_width = this.boxWidth && this.render_height = this.boxHeight {
            return
        }
        this.d2d := 0
        this.d2d := this.CreateRenderTarget(this.boxWidth, this.boxHeight)
        this.render_width := this.boxWidth
        this.render_height := this.boxHeight
    }

    CreateRenderTarget(width, height) {
        local d2d := this.d2d_constructor.Call()
        if HasMethod(d2d, "SetRenderTarget") {
            d2d.SetRenderTarget("wic", width, height)
        }
        return d2d
    }

    AssertNotDisposed() {
        if this.disposed {
            throw Error("Candidate box has been disposed.")
        }
    }

    GetTextMetrics(text, font_obj) {
        if !text {
            return { w: 0, h: 0 }
        }
        return this.d2d.GetMetrics(text, font_obj.name, font_obj.size)
    }

    GetVerticalTextMetrics(text, font_obj) {
        if !text {
            return { w: 0, h: 0 }
        }
        return this.d2d.GetMetrics(text, font_obj.name, font_obj.size, 400, 0, {
            reading_direction: Direct2D.DWRITE_READING_DIRECTION_TOP_TO_BOTTOM,
            flow_direction: Direct2D.DWRITE_FLOW_DIRECTION_RIGHT_TO_LEFT
        })
    }

    DrawLayoutText(layout, font_obj, color) {
        local text_box_height
        if this.layoutType = "vertical_text" {
            ; DirectWrite can wrap a Latin vertical glyph when its measured line height is exact.
            text_box_height := layout.h + font_obj.size
            this.d2d.DrawTextWithLayout(
                layout.text,
                layout.x,
                layout.y,
                font_obj.size,
                color,
                font_obj.name,
                layout.w,
                text_box_height,
                {
                    readingDirection: Direct2D.DWRITE_READING_DIRECTION_TOP_TO_BOTTOM,
                    flowDirection: Direct2D.DWRITE_FLOW_DIRECTION_RIGHT_TO_LEFT
                }
            )
            return
        }
        this.d2d.DrawText(layout.text, layout.x, layout.y, font_obj.size, color, font_obj.name)
    }
}
