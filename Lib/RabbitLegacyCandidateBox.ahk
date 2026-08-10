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

#Include RabbitCandidateBoxCommon.ahk
#Include RabbitCandidatePresentation.ahk
#Include RabbitLegacyCandidateLayout.ahk
#Include RabbitUIStyleSnapshot.ahk

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
        local segment_index, group, segment
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

            segment_index := 0
            for group in this.gui.preedit_groups {
                for segment in group.segments {
                    segment_index += 1
                    this.gui["P" . segment_index].Opt(
                        group.highlighted ? this.hilited_opt : this.base_opt)
                }
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
        this.gui.Show(Format(
            "NA x{} y{} w{} h{}", x, y, this.gui.max_width, this.gui.max_height))
        this.gui.RedrawAfterResize()
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
        __New(owner, presentation) {
            super.__New(, , this)
            this.owner := owner

            this.Opt(Format(
                "-DPIScale -Caption +Owner +AlwaysOnTop {} {} {}",
                WS_EX_NOACTIVATE, WS_EX_COMPOSITED, WS_EX_LAYERED))
            this.BackColor := this.owner.back_color
            this.SetFont(this.owner.base_font_opt, this.owner.style.font_face)
            this.MarginX := this.owner.style.margin_x
            this.MarginY := this.owner.style.margin_y
            this.num_candidates := 0
            this.preedit_segment_count := 0
            this.preedit_visible_count := 0
            this.has_comment := false
            this.max_width := 0
            this.max_height := 0

            this.Update(presentation)
            this.built := true
        }

        Update(presentation) {
            local num_candidates := presentation.candidates.Length
            local hilited_index := presentation.highlighted_index
            local layout
            this.EnsureControls(presentation)
            this.ApplyControlFonts()
            layout := this.CalculateLayout(presentation)

            this.ApplyPreeditLayout(layout)

            loop this.num_candidates {
                if A_Index > num_candidates {
                    this["L" . A_Index].Visible := false
                    this["C" . A_Index].Visible := false
                    this["M" . A_Index].Visible := false
                    continue
                }
                local row_presentation := presentation.candidates[A_Index]
                local row_layout := layout.rows[A_Index]
                local label := this["L" . A_Index]
                local candidate := this["C" . A_Index]
                local comment := this["M" . A_Index]
                label.Value := row_presentation.label
                label.Move(
                    row_layout.label.x, row_layout.label.y,
                    row_layout.label.w, row_layout.label.h)
                candidate.Value := row_presentation.text
                candidate.Move(
                    row_layout.candidate.x, row_layout.candidate.y,
                    row_layout.candidate.w, row_layout.candidate.h)
                comment.Value := row_presentation.comment
                comment.Move(
                    row_layout.comment.x, row_layout.comment.y,
                    row_layout.comment.w, row_layout.comment.h)

                if A_Index == hilited_index {
                    label.Opt(this.owner.hilited_label_opt)
                    candidate.Opt(this.owner.hilited_candidate_opt)
                    comment.Opt(this.owner.hilited_comment_opt)
                } else {
                    label.Opt(this.owner.label_opt)
                    candidate.Opt(this.owner.candidate_opt)
                    comment.Opt(this.owner.comment_opt)
                }
                label.Visible := true
                candidate.Visible := true
                comment.Visible := layout.has_comment
            }

            this.has_comment := layout.has_comment
            this.max_width := layout.width
            this.max_height := layout.height
            this.Move(, , this.max_width, this.max_height)
        }

        EnsureControls(presentation) {
            local num_candidates := presentation.candidates.Length
            local groups := RabbitGetPreeditGroups(presentation.preedit)
            local segment_index := 0
            this.preedit_groups := groups
            this.preedit_visible_count := 0
            this.pre := 0
            this.sel := 0
            this.post := 0
            for group in groups {
                for segment in group.segments {
                    segment_index += 1
                    this.preedit_visible_count := segment_index
                    local name := "P" . segment_index
                    if !HasProp(this, name) || !this.%name% {
                        this.SetFont(this.owner.base_font_opt, this.owner.style.font_face)
                        this.%name% := this.AddText(
                            Format("x0 y0 {} v{}", this.owner.border, name), segment.text)
                    }
                    if group.name = "before_selection" && !this.pre {
                        this.pre := this.%name%
                    } else if group.name = "selected" && !this.sel {
                        this.sel := this.%name%
                    } else if group.name = "after_selection" && !this.post {
                        this.post := this.%name%
                    }
                }
            }
            loop this.preedit_segment_count {
                if A_Index > this.preedit_visible_count {
                    this["P" . A_Index].Visible := false
                }
            }
            this.preedit_segment_count := Max(this.preedit_segment_count, this.preedit_visible_count)

            if num_candidates <= this.num_candidates {
                return
            }
            loop num_candidates - this.num_candidates {
                local index := this.num_candidates + A_Index
                local row := presentation.candidates[index]
                this.SetFont(this.owner.label_font_opt, this.owner.style.label_font_face)
                this.AddText(
                    Format("x0 y0 Right {} vL{}", this.owner.border, index), row.label)
                this.SetFont(this.owner.base_font_opt, this.owner.style.font_face)
                this.AddText(Format("x0 y0 {} vC{}", this.owner.border, index), row.text)
                this.SetFont(this.owner.comment_font_opt, this.owner.style.comment_font_face)
                this.AddText(Format("x0 y0 {} vM{}", this.owner.border, index), row.comment)
            }
            this.num_candidates := num_candidates
        }

        ApplyControlFonts() {
            loop this.preedit_segment_count {
                this["P" . A_Index].SetFont(
                    this.owner.base_font_opt, this.owner.style.font_face)
            }
            loop this.num_candidates {
                this["L" . A_Index].SetFont(
                    this.owner.label_font_opt, this.owner.style.label_font_face)
                this["C" . A_Index].SetFont(
                    this.owner.base_font_opt, this.owner.style.font_face)
                this["M" . A_Index].SetFont(
                    this.owner.comment_font_opt, this.owner.style.comment_font_face)
            }
        }

        ApplyPreeditLayout(layout) {
            loop this.preedit_segment_count {
                this["P" . A_Index].Visible := false
            }
            loop layout.preedit_segments.Length {
                local segment := layout.preedit_segments[A_Index]
                local control := this["P" . A_Index]
                control.Value := segment.text
                control.Move(segment.x, segment.y, segment.w, segment.h)
                control.Opt(segment.highlighted ? this.owner.hilited_opt : this.owner.base_opt)
                control.Visible := true
            }
        }

        CalculateLayout(presentation) {
            local hdc := DllCall("user32\GetDC", "Ptr", this.Hwnd, "Ptr")
            if !hdc {
                throw OSError(A_LastError, "GetDC failed.")
            }
            try {
                return this.CalculateLayoutWithDC(presentation, hdc)
            } finally {
                DllCall("user32\ReleaseDC", "Ptr", this.Hwnd, "Ptr", hdc, "Int")
            }
        }

        CalculateLayoutWithDC(presentation, hdc) {
            local preedit_metrics := []
            local segment_index := 0
            local metrics := {preedit: preedit_metrics, rows: []}
            for group in this.preedit_groups {
                local group_metrics := []
                for segment in group.segments {
                    segment_index += 1
                    group_metrics.Push(this.MeasureText(
                        hdc, segment.text, this["P" . segment_index]))
                }
                preedit_metrics.Push(group_metrics)
            }

            loop presentation.candidates.Length {
                local row := presentation.candidates[A_Index]
                local label_metrics := this.MeasureText(hdc, row.label, this["L" . A_Index])
                local candidate_metrics := this.MeasureText(hdc, row.text, this["C" . A_Index])
                local comment_metrics := this.MeasureText(hdc, row.comment, this["M" . A_Index])
                metrics.rows.Push({
                    label: label_metrics,
                    candidate: candidate_metrics,
                    comment: comment_metrics
                })
            }

            return RabbitLegacyCandidateLayout.Calculate(
                presentation, metrics, this.MarginX, this.MarginY, this.owner.style.min_width)
        }

        MeasureText(hdc, text, control) {
            ; Match AutoHotkey's Text autosizing so the calculated rectangles fit the native controls.
            static WM_GETFONT := 0x31
            static DT_EXPANDTABS := 0x40
            static DT_CALCRECT := 0x400
            static GWL_STYLE := -16
            static WS_BORDER := 0x800000
            static SM_CXBORDER := 5
            static SM_CYBORDER := 6
            local hfont := DllCall(
                "user32\SendMessage", "Ptr", control.Hwnd,
                "UInt", WM_GETFONT, "Ptr", 0, "Ptr", 0, "Ptr")
            if !hfont {
                throw Error("The candidate control does not have a font.")
            }
            local previous_font := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hfont, "Ptr")
            try {
                local display_text := text ? text : "H"
                local rect := Buffer(16, 0)
                local height := DllCall(
                    "user32\DrawTextW", "Ptr", hdc, "Str", display_text, "Int", -1,
                    "Ptr", rect, "UInt", DT_CALCRECT | DT_EXPANDTABS, "Int")
                local width := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")

                if text {
                    local last_character := Ord(SubStr(text, -1))
                    local abc := Buffer(12, 0)
                    if DllCall(
                        "gdi32\GetCharABCWidthsW", "Ptr", hdc,
                        "UInt", last_character, "UInt", last_character, "Ptr", abc, "Int") {
                        local overhang := NumGet(abc, 8, "Int")
                        if overhang < 0 {
                            width -= overhang
                        }
                    }
                }

                local style := DllCall(
                    "user32\GetWindowLong", "Ptr", control.Hwnd, "Int", GWL_STYLE, "UInt")
                if style & WS_BORDER {
                    width += 2 * DllCall(
                        "user32\GetSystemMetrics", "Int", SM_CXBORDER, "Int")
                    height += 2 * DllCall(
                        "user32\GetSystemMetrics", "Int", SM_CYBORDER, "Int")
                }
                return {w: width, h: height}
            } finally {
                DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", previous_font, "Ptr")
            }
        }

        RedrawAfterResize() {
            ; A visible layered/composited GUI can retain black pixels after it grows. Erase the
            ; parent background and repaint every child once the final window size is in place.
            static RDW_INVALIDATE := 0x0001
            static RDW_ERASE := 0x0004
            static RDW_ALLCHILDREN := 0x0080
            static RDW_UPDATENOW := 0x0100
            local flags := RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW
            DllCall(
                "user32\RedrawWindow", "Ptr", this.Hwnd,
                "Ptr", 0, "Ptr", 0, "UInt", flags, "Int")
        }
    }
}
