/*
 * Copyright (c) 2023 - 2025 Xuesong Peng <pengxuesong.cn@gmail.com>
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
                comment.x += alignCommentGap
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

class LegacyCandidateBox {
    static dbg := false
    static gui := 0
    static border := LegacyCandidateBox.dbg ? "+border" : 0

    __New() {
        this.UpdateUIStyle()
    }

    UpdateUIStyle() {
        ; alpha not supported
        del_opaque(color) {
            return color & 0xffffff
        }
        LegacyCandidateBox.text_color := del_opaque(UIStyle.text_color)
        LegacyCandidateBox.back_color := del_opaque(UIStyle.back_color)
        LegacyCandidateBox.candidate_text_color := del_opaque(UIStyle.candidate_text_color)
        LegacyCandidateBox.candidate_back_color := del_opaque(UIStyle.candidate_back_color)
        LegacyCandidateBox.label_color := del_opaque(UIStyle.label_color)
        LegacyCandidateBox.comment_text_color := del_opaque(UIStyle.comment_text_color)
        LegacyCandidateBox.hilited_text_color := del_opaque(UIStyle.hilited_text_color)
        LegacyCandidateBox.hilited_back_color := del_opaque(UIStyle.hilited_back_color)
        LegacyCandidateBox.hilited_candidate_text_color := del_opaque(UIStyle.hilited_candidate_text_color)
        LegacyCandidateBox.hilited_candidate_back_color := del_opaque(UIStyle.hilited_candidate_back_color)
        LegacyCandidateBox.hilited_label_color := del_opaque(UIStyle.hilited_label_color)
        LegacyCandidateBox.hilited_comment_text_color := del_opaque(UIStyle.hilited_comment_text_color)

        LegacyCandidateBox.base_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.text_color, LegacyCandidateBox.back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.candidate_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.candidate_text_color, LegacyCandidateBox.candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.label_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.label_color, LegacyCandidateBox.candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.comment_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.comment_text_color, LegacyCandidateBox.candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.hilited_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.hilited_text_color, LegacyCandidateBox.hilited_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.hilited_candidate_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.hilited_candidate_text_color, LegacyCandidateBox.hilited_candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.hilited_label_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.hilited_label_color, LegacyCandidateBox.hilited_candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.hilited_comment_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.hilited_comment_text_color, LegacyCandidateBox.hilited_candidate_back_color, LegacyCandidateBox.border)

        LegacyCandidateBox.base_font_opt := Format("s{} q5", UIStyle.font_point)
        LegacyCandidateBox.label_font_opt := Format("s{} q5", UIStyle.label_font_point)
        LegacyCandidateBox.comment_font_opt := Format("s{} q5", UIStyle.comment_font_point)

        if LegacyCandidateBox.gui {
            LegacyCandidateBox.gui.BackColor := LegacyCandidateBox.back_color
            LegacyCandidateBox.gui.MarginX := UIStyle.margin_x
            LegacyCandidateBox.gui.MarginY := UIStyle.margin_y

            if HasProp(LegacyCandidateBox.gui, "pre") && LegacyCandidateBox.gui.pre
                LegacyCandidateBox.gui.pre.Opt(LegacyCandidateBox.base_opt)
            if HasProp(LegacyCandidateBox.gui, "sel") && LegacyCandidateBox.gui.sel
                LegacyCandidateBox.gui.sel.Opt(LegacyCandidateBox.hilited_opt)
            if HasProp(LegacyCandidateBox.gui, "post") && LegacyCandidateBox.gui.post
                LegacyCandidateBox.gui.post.Opt(LegacyCandidateBox.base_opt)
        }
    }

    Build(context, &width, &height) {
        if !LegacyCandidateBox.gui || !LegacyCandidateBox.gui.built
            LegacyCandidateBox.gui := LegacyCandidateBox.BoxGui(context)
        else
            LegacyCandidateBox.gui.Update(context)
        width := LegacyCandidateBox.gui.max_width
        height := LegacyCandidateBox.gui.max_height
    }

    Show(x, y) {
        LegacyCandidateBox.gui.Show(Format("AutoSize NA x{} y{}", x, y))
    }

    Hide() {
        if LegacyCandidateBox.gui && HasMethod(LegacyCandidateBox.gui, "Show")
            LegacyCandidateBox.gui.Show("Hide")
    }

    class BoxGui extends Gui {
        built := false
        __New(context, &pre?, &sel?, &post?, &menu?) {
            super.__New(, , this)

            menu := context.menu
            local cands := menu.candidates
            local num_candidates := menu.num_candidates
            local hilited_index := menu.highlighted_candidate_index + 1
            local composition := context.composition
            GetCompositionText(composition, &pre, &sel, &post)

            this.Opt(Format("-DPIScale -Caption +Owner +AlwaysOnTop {} {} {}", WS_EX_NOACTIVATE, WS_EX_COMPOSITED, WS_EX_LAYERED))
            this.BackColor := LegacyCandidateBox.back_color
            this.SetFont(LegacyCandidateBox.base_font_opt, UIStyle.font_face)
            this.MarginX := UIStyle.margin_x
            this.MarginY := UIStyle.margin_y
            this.num_candidates := num_candidates
            this.has_comment := false

            ; build preedit
            this.max_width := 0
            this.preedit_height := 0
            local head_position := Format("x{} y{} section {}", this.MarginX, this.MarginY, LegacyCandidateBox.border)
            local position := head_position
            if pre {
                this.pre := this.AddText(position, pre)
                this.pre.Opt(LegacyCandidateBox.base_opt)
                position := Format("x+{} ys {}", this.MarginX, LegacyCandidateBox.border)
                this.pre.GetPos(, , &w, &h)
                this.preedit_height := max(this.preedit_height, h)
                this.pre_width := w
                this.max_width += (w + this.MarginX)
            }
            if sel {
                this.sel := this.AddText(position, sel)
                this.sel.Opt(LegacyCandidateBox.hilited_opt)
                position := Format("x+{} ys {}", this.MarginX, LegacyCandidateBox.border)
                this.sel.GetPos(, , &w, &h)
                this.preedit_height := max(this.preedit_height, h)
                this.sel_width := w
                this.max_width += (w + this.MarginX)
            }
            if post {
                this.post := this.AddText(position, post)
                this.post.Opt(LegacyCandidateBox.base_opt)
                this.post.GetPos(, , &w, &h)
                this.preedit_height := max(this.preedit_height, h)
                this.post_width := w
                this.max_width += w
            }

            ; build candidates
            this.max_label_width := 0
            this.max_candidate_width := 0
            this.max_comment_width := 0
            this.candidate_height := 0
            local has_label := !!context.select_labels[0]
            local select_keys := menu.select_keys
            local num_select_keys := StrLen(select_keys)
            loop num_candidates {
                position := Format("xs y+{} section {}", this.MarginY, LegacyCandidateBox.border)
                local label_text := String(A_Index)
                if A_Index <= menu.page_size && has_label
                    label_text := context.select_labels[A_Index]
                else if A_Index <= num_select_keys
                    label_text := SubStr(select_keys, A_Index, 1)
                label_text := Format(UIStyle.label_format, label_text)
                this.SetFont(LegacyCandidateBox.label_font_opt, UIStyle.label_font_face)
                local label := this.AddText(Format("Right {} vL{}", position, A_Index), label_text)
                label.GetPos(, , &w, &h1)
                this.max_label_width := max(this.max_label_width, w + this.MarginX)

                position := Format("x+{} ys {}", this.MarginX, LegacyCandidateBox.border)
                this.SetFont(LegacyCandidateBox.base_font_opt, UIStyle.font_face)
                local candidate := this.AddText(Format("{} vC{}", position, A_Index), cands[A_Index].text)
                candidate.GetPos(, , &w, &h2)
                this.max_candidate_width := max(this.max_candidate_width, w + this.MarginX)

                if comment_text := cands[A_Index].comment
                    this.has_comment := true
                this.SetFont(LegacyCandidateBox.comment_font_opt, UIStyle.comment_font_face)
                local comment := this.AddText(Format("{} vM{}", position, A_Index), comment_text)
                comment.GetPos(, , &w, &h3)
                comment.Opt(Format("c{:x}", LegacyCandidateBox.comment_text_color))
                comment.Visible := this.has_comment
                this.max_comment_width := max(this.max_comment_width, w)
                this.candidate_height := max(this.candidate_height, h1, h2, h3)

                if A_Index == hilited_index {
                    label.Opt(LegacyCandidateBox.hilited_label_opt)
                    candidate.Opt(LegacyCandidateBox.hilited_candidate_opt)
                    comment.Opt(LegacyCandidateBox.hilited_comment_opt)
                } else {
                    label.Opt(LegacyCandidateBox.label_opt)
                    candidate.Opt(LegacyCandidateBox.candidate_opt)
                    comment.Opt(LegacyCandidateBox.comment_opt)
                }
            }

            ; adjust width height
            local list_width := this.max_label_width + this.max_candidate_width + this.has_comment * this.max_comment_width
            local box_width := max(UIStyle.min_width, list_width)
            if box_width > this.max_width && HasProp(this, "post") && this.post
                this.post.Move(, , this.post_width + box_width - this.max_width)
            this.max_width := max(box_width, this.max_width)
            if this.max_width > list_width {
                this.max_candidate_width += this.max_width - list_width
                loop num_candidates
                    this["C" . A_Index].Move(, , this.max_candidate_width)
            }
            local y := 2 * this.MarginY + this.preedit_height
            loop num_candidates {
                local x := this.MarginX
                this["L" . A_Index].Move(x, y, this.max_label_width)
                this["L" . A_Index].GetPos(, , , &h)
                local max_h := h
                x += this.max_label_width
                this["C" . A_Index].Move(x, y, this.max_candidate_width)
                this["C" . A_Index].GetPos(, , , &h)
                max_h := max(max_h, h)
                x += this.max_candidate_width
                this["M" . A_Index].Move(x, y, this.max_comment_width)
                this["M" . A_Index].GetPos(, , , &h)
                max_h := max(max_h, h)
                y += (max_h + this.MarginY)
            }
            this.max_height := y
            this.max_width += (2 * this.MarginX)

            this.built := true
        }

        Update(context) {
            local fake_gui := LegacyCandidateBox.BoxGui(context, &pre, &sel, &post, &menu)
            local num_candidates := menu.num_candidates
            local hilited_index := menu.highlighted_candidate_index + 1
            this.SetFont(LegacyCandidateBox.base_font_opt, UIStyle.font_face)
            this.num_candidates := max(this.num_candidates, num_candidates)
            this.max_width := fake_gui.max_width
            this.max_height := fake_gui.max_height

            ; reset preedit
            if pre {
                if !HasProp(this, "pre") || !this.pre
                    this.pre := this.AddText(, pre)
                this.pre.Value := fake_gui.pre.Value
                fake_gui.pre.GetPos(&x, &y, &w, &h)
                this.pre.Move(x, y, w, h)
            }
            if HasProp(this, "pre") && this.pre
                this.pre.Visible := !!pre
            if sel {
                if !HasProp(this, "sel") || !this.sel
                    this.sel := this.AddText(, sel)
                this.sel.Value := fake_gui.sel.Value
                fake_gui.sel.GetPos(&x, &y, &w, &h)
                this.sel.Move(x, y, w, h)
            }
            if HasProp(this, "sel") && this.sel
                this.sel.Visible := !!sel
            if post {
                if !HasProp(this, "post") || !this.post
                    this.post := this.AddText(, post)
                this.post.Value := fake_gui.post.Value
                fake_gui.post.GetPos(&x, &y, &w, &h)
                this.post.Move(x, y, w, h)
            }
            if HasProp(this, "post") && this.post
                this.post.Visible := !!post

            ; reset candidates
            loop this.num_candidates {
                if A_Index > num_candidates {
                    this["L" . A_Index].Visible := false
                    this["C" . A_Index].Visible := false
                    this["M" . A_Index].Visible := false
                    continue
                }
                local fake_label := fake_gui["L" . A_Index]
                local fake_candidate := fake_gui["C" . A_Index]
                local fake_comment := fake_gui["M" . A_Index]
                this.SetFont(LegacyCandidateBox.label_font_opt, UIStyle.label_font_face)
                try
                    local label := this["L" . A_Index]
                catch
                    local label := this.AddText(Format("vL{}", A_Index), fake_label.Value)
                this.SetFont(LegacyCandidateBox.base_font_opt, UIStyle.font_face)
                try
                    local candidate := this["C" . A_Index]
                catch
                    local candidate := this.AddText(Format("vC{}", A_Index), fake_candidate.Value)
                this.SetFont(LegacyCandidateBox.comment_font_opt, UIStyle.comment_font_face)
                try
                    local comment := this["M" . A_Index]
                catch
                    local comment := this.AddText(Format("vM{}", A_Index), fake_comment.Value)
                label.Value := fake_label.Value
                fake_label.GetPos(&x, &y, &w, &h)
                label.Move(x, y, w, h)
                candidate.Value := fake_candidate.Value
                fake_candidate.GetPos(&x, &y, &w, &h)
                candidate.Move(x, y, w, h)
                comment.Value := fake_comment.Value
                fake_comment.GetPos(&x, &y, &w, &h)
                comment.Move(x, y, w, h)

                if A_Index == hilited_index {
                    label.Opt(LegacyCandidateBox.hilited_label_opt)
                    candidate.Opt(LegacyCandidateBox.hilited_candidate_opt)
                    comment.Opt(LegacyCandidateBox.hilited_comment_opt)
                } else {
                    label.Opt(LegacyCandidateBox.label_opt)
                    candidate.Opt(LegacyCandidateBox.candidate_opt)
                    comment.Opt(LegacyCandidateBox.comment_opt)
                }
                local visible := (A_Index <= num_candidates)
                label.Visible := visible
                candidate.Visible := visible
                comment.Visible := (fake_gui.has_comment && visible)
            }

            fake_gui.GetPos(, , &width, &height)
            this.Move(, , width, height)
        }
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
