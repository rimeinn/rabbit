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

#Include <RabbitCandidateBoxCommon>
#Include <RabbitCandidatePresentation>
#Include <RabbitUIStyleSnapshot>

class LegacyCandidateBox {
    static dbg := false

    __New(style) {
        this.gui := 0
        this.built := false
        this.visible := false
        this.disposed := false
        this.border := LegacyCandidateBox.dbg ? "+border" : 0

        try {
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
        ; Alpha is not supported.
        del_opaque(color) {
            return color & 0xffffff
        }
        this.text_color := del_opaque(style.text_color)
        this.back_color := del_opaque(style.back_color)
        this.candidate_text_color := del_opaque(style.candidate_text_color)
        this.candidate_back_color := del_opaque(style.candidate_back_color)
        this.label_color := del_opaque(style.label_color)
        this.comment_text_color := del_opaque(style.comment_text_color)
        this.hilited_text_color := del_opaque(style.hilited_text_color)
        this.hilited_back_color := del_opaque(style.hilited_back_color)
        this.hilited_candidate_text_color := del_opaque(style.hilited_candidate_text_color)
        this.hilited_candidate_back_color := del_opaque(style.hilited_candidate_back_color)
        this.hilited_label_color := del_opaque(style.hilited_label_color)
        this.hilited_comment_text_color := del_opaque(style.hilited_comment_text_color)

        this.base_opt := Format("c{:x} Background{:x} {}", this.text_color, this.back_color, this.border)
        this.candidate_opt := Format(
            "c{:x} Background{:x} {}", this.candidate_text_color, this.candidate_back_color, this.border)
        this.label_opt := Format(
            "c{:x} Background{:x} {}", this.label_color, this.candidate_back_color, this.border)
        this.comment_opt := Format(
            "c{:x} Background{:x} {}", this.comment_text_color, this.candidate_back_color, this.border)
        this.hilited_opt := Format(
            "c{:x} Background{:x} {}", this.hilited_text_color, this.hilited_back_color, this.border)
        this.hilited_candidate_opt := Format(
            "c{:x} Background{:x} {}",
            this.hilited_candidate_text_color, this.hilited_candidate_back_color, this.border)
        this.hilited_label_opt := Format(
            "c{:x} Background{:x} {}", this.hilited_label_color, this.hilited_candidate_back_color, this.border)
        this.hilited_comment_opt := Format(
            "c{:x} Background{:x} {}",
            this.hilited_comment_text_color, this.hilited_candidate_back_color, this.border)

        this.base_font_opt := Format("s{} q5", style.font_point)
        this.label_font_opt := Format("s{} q5", style.label_font_point)
        this.comment_font_opt := Format("s{} q5", style.comment_font_point)

        if this.gui {
            this.gui.BackColor := this.back_color
            this.gui.MarginX := style.margin_x
            this.gui.MarginY := style.margin_y

            if HasProp(this.gui, "pre") && this.gui.pre {
                this.gui.pre.Opt(this.base_opt)
            }
            if HasProp(this.gui, "sel") && this.gui.sel {
                this.gui.sel.Opt(this.hilited_opt)
            }
            if HasProp(this.gui, "post") && this.gui.post {
                this.gui.post.Opt(this.base_opt)
            }
        }
    }

    Build(context, &width, &height) {
        this.AssertNotDisposed()
        local presentation := RabbitCandidatePresentation(context, this.style.label_format)
        if !this.gui || !this.gui.built {
            this.gui := LegacyCandidateBox.BoxGui(this, presentation)
        } else {
            this.gui.Update(presentation)
        }
        width := this.gui.max_width
        height := this.gui.max_height
        this.built := true
    }

    Show(x, y) {
        this.AssertNotDisposed()
        if !this.built {
            throw Error("Candidate box must be built before it is shown.")
        }
        this.gui.Show(Format("AutoSize NA x{} y{}", x, y))
        this.visible := true
    }

    Hide() {
        if this.disposed {
            return
        }
        if this.visible && this.gui && HasMethod(this.gui, "Show") {
            this.gui.Show("Hide")
            this.visible := false
        }
    }

    AssertNotDisposed() {
        if this.disposed {
            throw Error("Candidate box has been disposed.")
        }
    }

    class BoxGui extends Gui {
        built := false
        __New(owner, presentation, &pre?, &sel?, &post?) {
            local w, h, h1, h2, h3
            super.__New(, , this)
            this.owner := owner

            local num_candidates := presentation.candidates.Length
            local hilited_index := presentation.highlighted_index
            pre := presentation.preedit.before_selection
            sel := presentation.preedit.selected
            post := presentation.preedit.after_selection

            this.Opt(Format("-DPIScale -Caption +Owner +AlwaysOnTop {} {} {}", WS_EX_NOACTIVATE, WS_EX_COMPOSITED, WS_EX_LAYERED))
            this.BackColor := this.owner.back_color
            this.SetFont(this.owner.base_font_opt, this.owner.style.font_face)
            this.MarginX := this.owner.style.margin_x
            this.MarginY := this.owner.style.margin_y
            this.num_candidates := num_candidates
            this.has_comment := false

            ; build preedit
            this.max_width := 0
            this.preedit_height := 0
            local head_position := Format(
                "x{} y{} section {}", this.MarginX, this.MarginY, this.owner.border)
            local position := head_position
            if pre {
                this.pre := this.AddText(position, pre)
                this.pre.Opt(this.owner.base_opt)
                position := Format("x+{} ys {}", this.MarginX, this.owner.border)
                this.pre.GetPos(, , &w, &h)
                this.preedit_height := max(this.preedit_height, h)
                this.pre_width := w
                this.max_width += (w + this.MarginX)
            }
            if sel {
                this.sel := this.AddText(position, sel)
                this.sel.Opt(this.owner.hilited_opt)
                position := Format("x+{} ys {}", this.MarginX, this.owner.border)
                this.sel.GetPos(, , &w, &h)
                this.preedit_height := max(this.preedit_height, h)
                this.sel_width := w
                this.max_width += (w + this.MarginX)
            }
            if post {
                this.post := this.AddText(position, post)
                this.post.Opt(this.owner.base_opt)
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
            loop num_candidates {
                position := Format("xs y+{} section {}", this.MarginY, this.owner.border)
                local candidate_presentation := presentation.candidates[A_Index]
                this.SetFont(this.owner.label_font_opt, this.owner.style.label_font_face)
                local label := this.AddText(
                    Format("Right {} vL{}", position, A_Index), candidate_presentation.label)
                label.GetPos(, , &w, &h1)
                this.max_label_width := max(this.max_label_width, w + this.MarginX)

                position := Format("x+{} ys {}", this.MarginX, this.owner.border)
                this.SetFont(this.owner.base_font_opt, this.owner.style.font_face)
                local candidate := this.AddText(
                    Format("{} vC{}", position, A_Index), candidate_presentation.text)
                candidate.GetPos(, , &w, &h2)
                this.max_candidate_width := max(this.max_candidate_width, w + this.MarginX)

                if (comment_text := candidate_presentation.comment) {
                    this.has_comment := true
                }
                this.SetFont(this.owner.comment_font_opt, this.owner.style.comment_font_face)
                local comment := this.AddText(Format("{} vM{}", position, A_Index), comment_text)
                comment.GetPos(, , &w, &h3)
                comment.Opt(Format("c{:x}", this.owner.comment_text_color))
                comment.Visible := this.has_comment
                this.max_comment_width := max(this.max_comment_width, w)
                this.candidate_height := max(this.candidate_height, h1, h2, h3)

                if A_Index == hilited_index {
                    label.Opt(this.owner.hilited_label_opt)
                    candidate.Opt(this.owner.hilited_candidate_opt)
                    comment.Opt(this.owner.hilited_comment_opt)
                } else {
                    label.Opt(this.owner.label_opt)
                    candidate.Opt(this.owner.candidate_opt)
                    comment.Opt(this.owner.comment_opt)
                }
            }

            ; adjust width height
            local list_width := this.max_label_width + this.max_candidate_width + this.has_comment * this.max_comment_width
            local box_width := max(this.owner.style.min_width, list_width)
            if box_width > this.max_width && HasProp(this, "post") && this.post {
                this.post.Move(, , this.post_width + box_width - this.max_width)
            }
            this.max_width := max(box_width, this.max_width)
            if this.max_width > list_width {
                this.max_candidate_width += this.max_width - list_width
                loop num_candidates {
                    this["C" . A_Index].Move(, , this.max_candidate_width)
                }
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

        Update(presentation) {
            local x, y, w, h, width, height
            local fake_gui := LegacyCandidateBox.BoxGui(this.owner, presentation, &pre, &sel, &post)
            local num_candidates := presentation.candidates.Length
            local hilited_index := presentation.highlighted_index
            this.SetFont(this.owner.base_font_opt, this.owner.style.font_face)
            this.num_candidates := max(this.num_candidates, num_candidates)
            this.max_width := fake_gui.max_width
            this.max_height := fake_gui.max_height

            ; reset preedit
            if pre {
                if !HasProp(this, "pre") || !this.pre {
                    this.pre := this.AddText(, pre)
                }
                this.pre.Value := fake_gui.pre.Value
                fake_gui.pre.GetPos(&x, &y, &w, &h)
                this.pre.Move(x, y, w, h)
            }
            if HasProp(this, "pre") && this.pre {
                this.pre.Visible := !!pre
            }
            if sel {
                if !HasProp(this, "sel") || !this.sel {
                    this.sel := this.AddText(, sel)
                }
                this.sel.Value := fake_gui.sel.Value
                fake_gui.sel.GetPos(&x, &y, &w, &h)
                this.sel.Move(x, y, w, h)
            }
            if HasProp(this, "sel") && this.sel {
                this.sel.Visible := !!sel
            }
            if post {
                if !HasProp(this, "post") || !this.post {
                    this.post := this.AddText(, post)
                }
                this.post.Value := fake_gui.post.Value
                fake_gui.post.GetPos(&x, &y, &w, &h)
                this.post.Move(x, y, w, h)
            }
            if HasProp(this, "post") && this.post {
                this.post.Visible := !!post

            ; reset candidates
            }
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
                this.SetFont(this.owner.label_font_opt, this.owner.style.label_font_face)
                try {
                    local label := this["L" . A_Index]
                } catch {
                    local label := this.AddText(Format("vL{}", A_Index), fake_label.Value)
                }
                this.SetFont(this.owner.base_font_opt, this.owner.style.font_face)
                try {
                    local candidate := this["C" . A_Index]
                } catch {
                    local candidate := this.AddText(Format("vC{}", A_Index), fake_candidate.Value)
                }
                this.SetFont(this.owner.comment_font_opt, this.owner.style.comment_font_face)
                try {
                    local comment := this["M" . A_Index]
                } catch {
                    local comment := this.AddText(Format("vM{}", A_Index), fake_comment.Value)
                }
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
                    label.Opt(this.owner.hilited_label_opt)
                    candidate.Opt(this.owner.hilited_candidate_opt)
                    comment.Opt(this.owner.hilited_comment_opt)
                } else {
                    label.Opt(this.owner.label_opt)
                    candidate.Opt(this.owner.candidate_opt)
                    comment.Opt(this.owner.comment_opt)
                }
                local visible := (A_Index <= num_candidates)
                label.Visible := visible
                candidate.Visible := visible
                comment.Visible := (fake_gui.has_comment && visible)
            }

            fake_gui.GetPos(, , &width, &height)
            this.Move(, , width, height)
            fake_gui.Destroy()
        }
    }
}
