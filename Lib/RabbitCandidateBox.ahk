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

#Include <RabbitUIStyleSnapshot>
#Include <RabbitCandidateBoxCommon>
#Include <RabbitCandidatePresentation>
#Include <Direct2D/Direct2D>

class CandidateBox {
    gui := 0

    __New(style, d2d_constructor := Direct2D) {
        this.gui := 0
        this.d2d := 0
        this.built := false
        this.visible := false
        this.disposed := false

        try {
            ; +E0x8080088: WS_EX_NOACTIVATE | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST
            this.gui := Gui("-Caption -DPIScale +E0x8080088")
            this.d2d := d2d_constructor.Call(this.gui.Hwnd)
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
    }

    CreateFontObj(name, size) {
        local em_to_pt := 96.0 / 72.0
        local px := size * em_to_pt * this.dpiScale
        return { name: name, size: px }
    }

    Build(context, &win_w, &win_h) { ; build text layout
        local base_x, base_y, preedit_0, preedit_1, preedit_2, preedit_1_x
        local preedit_2_x, max_row_width
        local total_rows_height, label_box, candidate_box
        local comment_text, comment_box, row_rect, increment, label_width, candidate_width, comment, comment_gap
        this.AssertNotDisposed()
        local presentation := RabbitCandidatePresentation(context, this.style.label_format)
        this.num_candidates := presentation.candidates.Length
        this.hilited_index := presentation.highlighted_index

        ; Build preedit layout
        base_x := this.borderWidth + this.padding
        base_y := this.borderWidth + this.lineSpacing
        preedit_0 := this.GetTextMetrics(presentation.preedit.before_selection, this.mainFont)
        preedit_1 := this.GetTextMetrics(presentation.preedit.selected, this.mainFont)
        preedit_2 := this.GetTextMetrics(presentation.preedit.after_selection, this.mainFont)
        preedit_1_x := base_x + preedit_0.w + this.padding
        preedit_2_x := preedit_1_x + preedit_1.w
        this.preeditLayout := {
            selBox: {
                x: base_x, y: base_y, w: preedit_0.w, h: preedit_0.h,
                text: presentation.preedit.before_selection
            },
            hlSelBox: {
                x: preedit_1_x, y: base_y, w: preedit_1.w, h: preedit_1.h,
                text: presentation.preedit.selected
            },
            hlUnSelBox: {
                x: preedit_2_x, y: base_y, w: preedit_2.w, h: preedit_2.h,
                text: presentation.preedit.after_selection
            },
            left: base_x,
            top: base_y,
            width: preedit_0.w + this.padding + preedit_1.w + preedit_2.w,
            height: Max(preedit_0.h, preedit_1.h, preedit_2.h)
        }
        max_row_width := this.preeditLayout.width

        ; Build candidates layout
        total_rows_height := this.preeditLayout.height + this.lineSpacing
        base_y := base_y + total_rows_height
        this.candidatesLayout := { labels: [], cands: [], comments: [], rows: [] }

        Loop this.num_candidates {
            local candidate := presentation.candidates[A_Index]
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
        total_rows_height -= this.lineSpacing ; remove extra line spacing

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

    Show(x, y) {
        local background_x, background_y, background_width, background_height, background_radius, highlight_width
        local row_rect, label_color, candidate_color, comment_color, label, cand, comment
        this.AssertNotDisposed()
        if !this.built {
            throw Error("Candidate box must be built before it is shown.")
        }
        if !this.visible {
            this.gui.Show("NA")
            this.visible := true
        }

        this.d2d.SetPosition(x, y, this.boxWidth, this.boxHeight)
        this.d2d.BeginDraw()

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
        if this.preeditLayout.hlSelBox.text {
            ; highlight background for preedit selection
            this.d2d.FillRoundedRectangle(
                this.preeditLayout.hlSelBox.x, this.preeditLayout.hlSelBox.y,
                this.preeditLayout.hlSelBox.w, this.preeditLayout.hlSelBox.h,
                this.hlCornerR, this.hlCornerR, this.hlBgColor)
        }
        this.d2d.DrawText(this.preeditLayout.selBox.text, this.preeditLayout.selBox.x, this.preeditLayout.selBox.y, this.mainFont.size, this.textColor, this.mainFont.name)
        this.d2d.DrawText(this.preeditLayout.hlSelBox.text, this.preeditLayout.hlSelBox.x, this.preeditLayout.hlSelBox.y, this.mainFont.size, this.hlTxtColor, this.mainFont.name)
        this.d2d.DrawText(this.preeditLayout.hlUnSelBox.text, this.preeditLayout.hlUnSelBox.x, this.preeditLayout.hlUnSelBox.y, this.mainFont.size, this.textColor, this.mainFont.name)

        highlight_width := this.boxWidth - this.borderWidth * 2 - this.padding * 2
        ; Draw candidates
        Loop this.num_candidates {
            row_rect := this.candidatesLayout.rows[A_Index]
            label_color := this.labelColor
            candidate_color := this.candTxtColor
            comment_color := this.commentTxtColor
            if A_Index == this.hilited_index { ; Draw highlight if selected
                label_color := this.hlLabelColor
                candidate_color := this.hlCandTxtColor
                comment_color := this.hlCommentTxtColor
                this.d2d.FillRoundedRectangle(row_rect.x, row_rect.y, highlight_width, row_rect.h, this.hlCornerR, this.hlCornerR, this.hlCandBgColor)
            }

            label := this.candidatesLayout.labels[A_Index]
            this.d2d.DrawText(label.text, label.x, label.y, this.labFont.size, label_color, this.labFont.name)

            cand := this.candidatesLayout.cands[A_Index]
            this.d2d.DrawText(cand.text, cand.x, cand.y, this.mainFont.size, candidate_color, this.mainFont.name)

            comment := this.candidatesLayout.comments[A_Index]
            if comment.w > 0 {
                this.d2d.DrawText(comment.text, comment.x, comment.y, this.commentFont.size, comment_color, this.commentFont.name)
            }
        }

        this.d2d.EndDraw()
    }

    Hide() {
        if this.disposed {
            return
        }
        if this.visible {
            this.d2d.EndDraw()
            this.d2d.Clear()
            this.gui.Hide()
            this.visible := false
        }
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
}
