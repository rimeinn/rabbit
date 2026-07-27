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
        if this.gui
            this.gui.Destroy()
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

        ; preedite style
        this.textColor := UIStyle.text_color
        this.backgroundColor := UIStyle.back_color
        this.hlTxtColor := UIStyle.hilited_text_color
        this.hlBgColor := UIStyle.hilited_back_color
        ; candidate style
        this.hlCandTxtColor := UIStyle.hilited_candidate_text_color
        this.hlCandBgColor := UIStyle.hilited_candidate_back_color
        this.candTxtColor := UIStyle.candidate_text_color
        this.candBgColor := UIStyle.candidate_back_color

        ; some color schemes have no these colors
        this.labelColor := UIStyle.label_color
        this.hlLabelColor := UIStyle.hilited_label_color
        this.commentTxtColor := UIStyle.comment_text_color
        this.hlCommentTxtColor := UIStyle.hilited_comment_text_color
    }

    CreateFontObj(name, size) {
        local em2pt := 96.0 / 72.0
        local px := size * em2pt * this.dpiScale
        return { name: name, size: px }
    }

    Build(context, &winW, &winH) { ; build text layout
        local menu := context.menu
        local cands := menu.candidates
        this.num_candidates := menu.num_candidates
        this.hilited_index := menu.highlighted_candidate_index + 1

        GetCompositionText(context.composition, &pre_selected, &selected, &post_selected)

        ; Build preedit layout
        baseX := this.borderWidth + this.padding
        baseY := this.borderWidth + this.lineSpacing
        prd0 := this.GetTextMetrics(pre_selected, this.mainFont)
        prd1 := this.GetTextMetrics(selected, this.mainFont)
        prd2 := this.GetTextMetrics(post_selected, this.mainFont)
        prd1X := baseX + prd0.w + this.padding
        prd2X := prd1X + prd1.w
        this.preeditLayout := {
            selBox: { x: baseX, y: baseY, w: prd0.w, h: prd0.h, text: pre_selected },
            hlSelBox: { x: prd1X, y: baseY, w: prd1.w, h: prd1.h, text: selected },
            hlUnSelBox: { x: prd2X, y: baseY, w: prd2.w, h: prd2.h, text: post_selected },
            left: baseX,
            top: baseY,
            width: prd0.w + this.padding + prd1.w + prd2.w,
            height: Max(prd0.h, prd1.h, prd2.h)
        }
        maxRowWidth := this.preeditLayout.width

        ; Build candidates layout
        totalRowsHeight := this.preeditLayout.height + this.lineSpacing
        baseY := baseY + totalRowsHeight
        this.candidatesLayout := { labels: [], cands: [], comments: [], rows: [] }

        has_label := !!context.select_labels[0]
        select_keys := menu.select_keys
        num_select_keys := StrLen(select_keys)
        Loop this.num_candidates {
            labelText := String(A_Index)
            if A_Index <= menu.page_size && has_label
                labelText := context.select_labels[A_Index] || labelText
            else if A_Index <= num_select_keys
                labelText := SubStr(select_keys, A_Index, 1)
            labelText := Format(UIStyle.label_format, labelText)
            labelBox := this.GetTextMetrics(labelText, this.labFont)
            this.candidatesLayout.labels.Push({ x: baseX, y: baseY, w: labelBox.w, h: labelBox.h, text: labelText })

            candText := cands[A_Index].text
            candBox := this.GetTextMetrics(candText, this.mainFont)
            this.candidatesLayout.cands.Push({ x: baseX + labelBox.w + this.padding, y: baseY, w: candBox.w, h: candBox.h, text: candText })

            commentText := cands[A_Index].comment
            commentBox := this.GetTextMetrics(commentText, this.commentFont)
            this.candidatesLayout.comments.Push({ x: baseX + labelBox.w + candBox.w, y: baseY, w: commentBox.w, h: commentBox.h, text: commentText })

            rowRect := {
                x: baseX, y: baseY,
                w: labelBox.w + this.padding + candBox.w + (commentText ? this.padding * 2 + commentBox.w : 0),
                h: Max(labelBox.h, candBox.h, commentBox.h)
            }
            this.candidatesLayout.rows.Push(rowRect)
            if (rowRect.w > maxRowWidth) {
                maxRowWidth := rowRect.w
            }
            increment := rowRect.h + this.lineSpacing
            baseY += increment, totalRowsHeight += increment
        }
        totalRowsHeight -= this.lineSpacing ; remove extra line spacing

        this.commentOffset := 0
        this.boxWidth := Ceil(maxRowWidth) + (this.borderWidth + this.padding) * 2
        if this.boxWidth < UIStyle.min_width {
            this.commentOffset := UIStyle.min_width - this.boxWidth
            this.boxWidth := UIStyle.min_width
        }
        this.boxHeight := Ceil(totalRowsHeight) + (this.borderWidth + this.padding) * 2
        winW := this.boxWidth
        winH := this.boxHeight

        ; get better spacing to align comments
        loop this.num_candidates {
            labelW := this.candidatesLayout.labels[A_Index].w
            candW := this.candidatesLayout.cands[A_Index].w
            comment := this.candidatesLayout.comments[A_Index]

            if comment.w > 0 {
                alignCommentGap := maxRowWidth - labelW - candW - comment.w - this.padding
                comment.x += alignCommentGap + this.commentOffset
            }
        }
    }

    Show(x, y) {
        if (CandidateBox.isHidden) {
            this.gui.Show("NA")
            CandidateBox.isHidden := 0
        }

        this.d2d.SetPosition(x, y, this.boxWidth, this.boxHeight)
        this.d2d.BeginDraw()

        if (this.borderWidth > 0) {
            ; Draw outer border as filled rounded rectangle (border color)
            this.d2d.FillRoundedRectangle(0, 0, this.boxWidth, this.boxHeight, this.boxCornerR, this.boxCornerR, this.borderColor)
            ; Draw inner background next
            bgX := this.borderWidth, bgY := this.borderWidth
            bgW := this.boxWidth - this.borderWidth * 2
            bgH := this.boxHeight - this.borderWidth * 2
            bgR := this.boxCornerR > this.borderWidth ? this.boxCornerR - this.borderWidth : 0
            this.d2d.FillRoundedRectangle(bgX, bgY, bgW, bgH, bgR, bgR, this.backgroundColor)
        } else {
            this.d2d.FillRoundedRectangle(0, 0, this.boxWidth, this.boxHeight, this.boxCornerR, this.boxCornerR, this.backgroundColor)
        }

        ; Draw preedit
        if (this.preeditLayout.hlSelBox.text) {
            ; highlight background for preedit selection
            this.d2d.FillRoundedRectangle(
                this.preeditLayout.hlSelBox.x, this.preeditLayout.hlSelBox.y,
                this.preeditLayout.hlSelBox.w, this.preeditLayout.hlSelBox.h,
                this.hlCornerR, this.hlCornerR, this.hlBgColor)
        }
        this.d2d.DrawText(this.preeditLayout.selBox.text, this.preeditLayout.selBox.x, this.preeditLayout.selBox.y, this.mainFont.size, this.textColor, this.mainFont.name)
        this.d2d.DrawText(this.preeditLayout.hlSelBox.text, this.preeditLayout.hlSelBox.x, this.preeditLayout.hlSelBox.y, this.mainFont.size, this.hlTxtColor, this.mainFont.name)
        this.d2d.DrawText(this.preeditLayout.hlUnSelBox.text, this.preeditLayout.hlUnSelBox.x, this.preeditLayout.hlUnSelBox.y, this.mainFont.size, this.textColor, this.mainFont.name)

        hiliteW := this.boxWidth - this.borderWidth * 2 - this.padding * 2
        ; Draw candidates
        Loop this.num_candidates {
            rowRect := this.candidatesLayout.rows[A_Index]
            labelFg := this.labelColor
            candFg := this.candTxtColor
            commentFg := this.commentTxtColor
            if (A_Index == this.hilited_index) { ; Draw highlight if selected
                labelFg := this.hlLabelColor
                candFg := this.hlCandTxtColor
                commentFg := this.hlCommentTxtColor
                this.d2d.FillRoundedRectangle(rowRect.x, rowRect.y, hiliteW, rowRect.h, this.hlCornerR, this.hlCornerR, this.hlCandBgColor)
            }

            label := this.candidatesLayout.labels[A_Index]
            this.d2d.DrawText(label.text, label.x, label.y, this.labFont.size, labelFg, this.labFont.name)

            cand := this.candidatesLayout.cands[A_Index]
            this.d2d.DrawText(cand.text, cand.x, cand.y, this.mainFont.size, candFg, this.mainFont.name)

            comment := this.candidatesLayout.comments[A_Index]
            if comment.w > 0 {
                this.d2d.DrawText(comment.text, comment.x, comment.y, this.commentFont.size, commentFg, this.commentFont.name)
            }
        }

        this.d2d.EndDraw()
    }

    Hide() {
        if (!CandidateBox.isHidden) {
            this.d2d.EndDraw()
            this.d2d.Clear()
            this.gui.Hide()
            CandidateBox.isHidden := 1
        }
    }

    GetTextMetrics(text, fontObj) {
        if !text
            return { w: 0, h: 0 }

        return this.d2d.GetMetrics(text, fontObj.name, fontObj.size)
    }
}

GetCompositionText(composition, &pre_selected, &selected, &post_selected) {
    pre_selected := ""
    selected := ""
    post_selected := ""
    if not preedit := composition.preedit
        return false

    static cursor_text := "‸" ; or 𝙸
    static cursor_size := StrPut(cursor_text, "UTF-8") - 1 ; do not count tailing null

    local preedit_length := StrPut(preedit, "UTF-8")
    local selected_start := composition.sel_start
    local selected_end := composition.sel_end

    local preedit_buffer ; insert caret text into preedit text if applicable
    if 0 <= composition.cursor_pos and composition.cursor_pos <= preedit_length {
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
        if selected_start >= composition.cursor_pos
            selected_start := selected_start + cursor_size
        if selected_end > composition.cursor_pos
            selected_end := selected_end + cursor_size
    } else {
        preedit_buffer := Buffer(preedit_length, 0)
        StrPut(preedit, preedit_buffer, "UTF-8")
    }

    if 0 <= selected_start and selected_start < selected_end and selected_end <= preedit_length {
        pre_selected := StrGet(preedit_buffer, selected_start, "UTF-8")
        selected := StrGet(preedit_buffer.Ptr + selected_start, selected_end - selected_start, "UTF-8")
        post_selected := StrGet(preedit_buffer.Ptr + selected_end, "UTF-8")
        return true
    } else {
        pre_selected := StrGet(preedit_buffer, "UTF-8")
        return false
    }
}
