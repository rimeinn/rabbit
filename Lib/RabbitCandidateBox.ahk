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

#Include <RabbitUIStyle>
#Include <Direct2D/Direct2D>

; https://learn.microsoft.com/windows/win32/winmsg/extended-window-styles
global WS_EX_NOACTIVATE := "+E0x8000000"
global WS_EX_COMPOSITED := "+E0x02000000"
global WS_EX_LAYERED    := "+E0x00080000"

class CandidateBox {
    gui := 0
    static isHidden := 1

    __New() {
        ; +E0x8080088: WS_EX_NOACTIVATE | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST
        this.gui := Gui("-Caption -DPIScale +E0x8080088")

        this.d2d := Direct2D(this.gui.Hwnd)
        this.dpiScale := this.d2d.GetDesktopDpiScale()

        this.UpdateUIStyle()
    }

    __Delete() {
        this.Hide()
        if this.gui {
            this.gui.Destroy()
        }
    }

    UpdateUIStyle() {
        this.borderWidth := UIStyle.border_width
        this.borderColor := UIStyle.border_color
        this.boxCornerR := UIStyle.corner_radius
        this.hlCornerR := UIStyle.round_corner
        this.lineSpacing := UIStyle.margin_y
        this.padding := UIStyle.margin_x

        this.mainFont := this.CreateFontObj(UIStyle.font_face, UIStyle.font_point)
        this.labFont := this.CreateFontObj(UIStyle.label_font_face, UIStyle.label_font_point)
        this.commentFont := this.CreateFontObj(UIStyle.comment_font_face, UIStyle.comment_font_point)

        ; Preedit style
        this.textColor := UIStyle.text_color
        this.backgroundColor := UIStyle.back_color
        this.hlTxtColor := UIStyle.hilited_text_color
        this.hlBgColor := UIStyle.hilited_back_color
        ; Candidate style
        this.hlCandTxtColor := UIStyle.hilited_candidate_text_color
        this.hlCandBgColor := UIStyle.hilited_candidate_back_color
        this.candTxtColor := UIStyle.candidate_text_color
        this.candBgColor := UIStyle.candidate_back_color

        ; Some color schemes do not define these colors.
        this.labelColor := UIStyle.label_color
        this.hlLabelColor := UIStyle.hilited_label_color
        this.commentTxtColor := UIStyle.comment_text_color
        this.hlCommentTxtColor := UIStyle.hilited_comment_text_color
    }

    CreateFontObj(name, size) {
        local em_to_pt := 96.0 / 72.0
        local px := size * em_to_pt * this.dpiScale
        return { name: name, size: px }
    }

    Build(context, &win_w, &win_h) { ; build text layout
        local pre_selected, selected, post_selected, base_x, base_y, preedit_0, preedit_1, preedit_2, preedit_1_x
        local preedit_2_x, max_row_width
        local total_rows_height, has_label, select_keys, num_select_keys, label_text, label_box, candidate_text
        local candidate_box
        local comment_text, comment_box, row_rect, increment, label_width, candidate_width, comment, comment_gap
        local menu := context.menu
        local cands := menu.candidates
        this.num_candidates := menu.num_candidates
        this.hilited_index := menu.highlighted_candidate_index + 1

        GetCompositionText(context.composition, &pre_selected, &selected, &post_selected)

        ; Build preedit layout
        base_x := this.borderWidth + this.padding
        base_y := this.borderWidth + this.lineSpacing
        preedit_0 := this.GetTextMetrics(pre_selected, this.mainFont)
        preedit_1 := this.GetTextMetrics(selected, this.mainFont)
        preedit_2 := this.GetTextMetrics(post_selected, this.mainFont)
        preedit_1_x := base_x + preedit_0.w + this.padding
        preedit_2_x := preedit_1_x + preedit_1.w
        this.preeditLayout := {
            selBox: { x: base_x, y: base_y, w: preedit_0.w, h: preedit_0.h, text: pre_selected },
            hlSelBox: { x: preedit_1_x, y: base_y, w: preedit_1.w, h: preedit_1.h, text: selected },
            hlUnSelBox: { x: preedit_2_x, y: base_y, w: preedit_2.w, h: preedit_2.h, text: post_selected },
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

        has_label := !!context.select_labels[0]
        select_keys := menu.select_keys
        num_select_keys := StrLen(select_keys)
        Loop this.num_candidates {
            label_text := String(A_Index)
            if A_Index <= menu.page_size && has_label {
                label_text := context.select_labels[A_Index] || label_text
            } else if A_Index <= num_select_keys {
                label_text := SubStr(select_keys, A_Index, 1)
            }
            label_text := Format(UIStyle.label_format, label_text)
            label_box := this.GetTextMetrics(label_text, this.labFont)
            this.candidatesLayout.labels.Push({ x: base_x, y: base_y, w: label_box.w, h: label_box.h, text: label_text })

            candidate_text := cands[A_Index].text
            candidate_box := this.GetTextMetrics(candidate_text, this.mainFont)
            this.candidatesLayout.cands.Push({ x: base_x + label_box.w + this.padding, y: base_y, w: candidate_box.w, h: candidate_box.h, text: candidate_text })

            comment_text := cands[A_Index].comment
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
        if this.boxWidth < UIStyle.min_width {
            this.commentOffset := UIStyle.min_width - this.boxWidth
            this.boxWidth := UIStyle.min_width
        }
        this.boxHeight := Ceil(total_rows_height) + (this.borderWidth + this.padding) * 2
        win_w := this.boxWidth
        win_h := this.boxHeight

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
        if CandidateBox.isHidden {
            this.gui.Show("NA")
            CandidateBox.isHidden := 0
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
        if !CandidateBox.isHidden {
            this.d2d.EndDraw()
            this.d2d.Clear()
            this.gui.Hide()
            CandidateBox.isHidden := 1
        }
    }

    GetTextMetrics(text, font_obj) {
        if !text {
            return { w: 0, h: 0 }
        }
        return this.d2d.GetMetrics(text, font_obj.name, font_obj.size)
    }
}

GetCompositionText(composition, &pre_selected, &selected, &post_selected) {
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
