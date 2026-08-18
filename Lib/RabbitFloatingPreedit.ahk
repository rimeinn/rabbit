/*
 * Copyright (c) 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
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

#Include RabbitCommon.ahk
#Include RabbitCandidatePresentation.ahk
#Include RabbitLayeredWindow.ahk
#Include Direct2D/Direct2D.ahk

class RabbitFloatingPreedit {
    static FONT_HEIGHT_CALIBRATION_TEXT := "中M"
    static DEBUG_OUTPUT := true
    ; Track render target recreations: the preedit box resizes with the text,
    ; and each change rebuilds the whole Direct2D stack.
    static render_target_recreate_count := 0

    __New(style, d2d_constructor := Direct2D) {
        this.gui := 0
        this.d2d := 0
        this.d2d_constructor := d2d_constructor
        this.layered_window := 0
        this.render_width := 0
        this.render_height := 0
        this.segments := []
        this.box_width := 0
        this.box_height := 0
        this.x := 0
        this.y := 0
        this.visible := false
        this.built := false
        this.disposed := false
        try {
            ; WS_EX_NOACTIVATE | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST
            this.gui := Gui("-Caption -DPIScale +E0x8080088")
            this.d2d := this.CreateRenderTarget(1, 1)
            this.layered_window := RabbitLayeredWindow(this.gui.Hwnd)
            this.dpi_scale := this.d2d.GetDesktopDpiScale()
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
        this.layered_window := 0
        this.d2d := 0
        if this.gui {
            this.gui.Destroy()
            this.gui := 0
        }
        this.disposed := true
    }

    UpdateStyle(style) {
        this.AssertNotDisposed()
        this.style := style
        this.font_face := style.preedit_font_face
        this.base_font_size := style.font_point * (96.0 / 72.0) * this.dpi_scale
        this.text_color := style.text_color
        this.highlighted_text_color := style.hilited_text_color
        this.background_color := style.preedit_back_color
        this.highlighted_background_color := style.floating_preedit_hilited_back_color
        this.border_width := style.border_width
        this.border_color := style.border_color
        this.corner_radius := style.corner_radius
        this.highlighted_corner_radius := style.round_corner
        this.opacity := Round(style.floating_preedit_opacity * 255)
        this.min_height := style.floating_preedit_min_height
    }

    Build(preedit, caret_x, caret_y, caret_w, caret_h) {
        local groups, group, segment, metrics, calibration_metrics
        local x, height := 0, text_y, selected_x := 0, selected_width := 0, selected_height := 0
        this.AssertNotDisposed()
        if caret_h <= 0 {
            throw ValueError("Floating preedit requires a positive caret height.")
        }
        groups := RabbitGetPreeditGroups(preedit)
        this.box_height := Max(caret_h, this.min_height)
        this.draw_border_width := Min(this.border_width, Floor(this.box_height / 4))
        this.draw_corner_radius := Min(this.corner_radius, this.box_height / 4)
        this.content_x := this.draw_border_width
        this.content_y := this.draw_border_width
        this.content_height := Max(1, this.box_height - this.draw_border_width * 2)
        calibration_metrics := this.d2d.GetMetrics(
            RabbitFloatingPreedit.FONT_HEIGHT_CALIBRATION_TEXT,
            this.font_face,
            this.base_font_size
        )
        if calibration_metrics.h <= 0 {
            throw Error("Floating preedit font calibration returned an invalid height.")
        }
        this.font_size := this.base_font_size * this.content_height / calibration_metrics.h
        x := this.content_x
        this.segments := []
        for group_index, group in groups {
            for segment in group.segments {
                metrics := this.d2d.GetMetrics(segment.text, this.font_face, this.font_size)
                this.segments.Push({
                    x: x,
                    y: 0,
                    w: metrics.w,
                    h: metrics.h,
                    text: segment.text,
                    highlighted: group.highlighted
                })
                if group.highlighted {
                    if !selected_width {
                        selected_x := x
                    }
                    selected_width += metrics.w
                    selected_height := Max(selected_height, metrics.h)
                }
                x += metrics.w
                height := Max(height, metrics.h)
            }
        }
        if !this.segments.Length {
            this.built := false
            this.Hide()
            return
        }
        text_y := this.content_y + Round((this.content_height - height) / 2)
        for segment in this.segments {
            segment.y := text_y
        }
        this.selected_box := selected_width ? {
            x: selected_x,
            y: text_y,
            w: selected_width,
            h: selected_height
        } : 0
        this.box_width := Max(1, Ceil(x) + this.draw_border_width)
        this.content_width := this.box_width - this.draw_border_width * 2
        this.draw_highlighted_corner_radius := Min(
            this.highlighted_corner_radius,
            selected_height ? selected_height / 4 : 0
        )
        this.x := caret_x + caret_w
        this.y := caret_y
        this.WriteDebugInfo(caret_x, caret_y, caret_w, caret_h)
        this.built := true
        if this.visible {
            this.Render()
        }
    }

    Show() {
        this.AssertNotDisposed()
        if !this.built {
            return
        }
        if !this.visible {
            this.gui.Show(Format("NA x{} y{} w{} h{}", this.x, this.y, this.box_width, this.box_height))
            this.visible := true
            this.Render()
        }
    }

    Hide() {
        if this.disposed || !this.visible {
            return
        }
        this.gui.Hide()
        this.visible := false
    }

    Render() {
        local segment, color, inner_x, inner_y, inner_width, inner_height, inner_radius
        this.EnsureRenderTarget()
        this.d2d.BeginDraw()
        try {
            if this.draw_border_width > 0 {
                this.d2d.FillRoundedRectangle(
                    0,
                    0,
                    this.box_width,
                    this.box_height,
                    this.draw_corner_radius,
                    this.draw_corner_radius,
                    this.border_color
                )
                inner_x := this.draw_border_width
                inner_y := this.draw_border_width
                inner_width := this.box_width - this.draw_border_width * 2
                inner_height := this.box_height - this.draw_border_width * 2
                inner_radius := this.draw_corner_radius > this.draw_border_width
                    ? Min(this.draw_corner_radius - this.draw_border_width, inner_height / 4)
                    : 0
                this.d2d.FillRoundedRectangle(
                    inner_x,
                    inner_y,
                    inner_width,
                    inner_height,
                    inner_radius,
                    inner_radius,
                    this.background_color
                )
            } else {
                this.d2d.FillRoundedRectangle(
                    0,
                    0,
                    this.box_width,
                    this.box_height,
                    this.draw_corner_radius,
                    this.draw_corner_radius,
                    this.background_color
                )
            }
            this.d2d.PushAxisAlignedClip(
                this.content_x,
                this.content_y,
                this.content_width,
                this.content_height
            )
            if this.selected_box {
                this.d2d.FillRoundedRectangle(
                    this.selected_box.x,
                    this.selected_box.y,
                    this.selected_box.w,
                    this.selected_box.h,
                    this.draw_highlighted_corner_radius,
                    this.draw_highlighted_corner_radius,
                    this.highlighted_background_color
                )
            }
            for segment in this.segments {
                color := segment.highlighted ? this.highlighted_text_color : this.text_color
                this.d2d.DrawText(
                    segment.text,
                    segment.x,
                    segment.y,
                    this.font_size,
                    color,
                    this.font_face
                )
            }
            this.d2d.PopAxisAlignedClip()
        } finally {
            this.d2d.EndDraw()
        }
        this.layered_window.Update(
            this.d2d.ID2D1RenderTarget.GetWICBitmap(),
            this.box_width,
            this.box_height,
            this.x,
            this.y,
            0,
            this.opacity
        )
    }

    EnsureRenderTarget() {
        if this.render_width = this.box_width && this.render_height = this.box_height {
            return
        }
        RabbitFloatingPreedit.render_target_recreate_count++
        if RabbitFloatingPreedit.render_target_recreate_count <= 3
            || Mod(RabbitFloatingPreedit.render_target_recreate_count, 100) == 0 {
            RabbitDebug(
                Format(
                    "floating preedit recreated Direct2D render target to {}x{} (total {})",
                    this.box_width,
                    this.box_height,
                    RabbitFloatingPreedit.render_target_recreate_count
                ),
                Format("RabbitFloatingPreedit.ahk:{}", A_LineNumber)
            )
        }
        this.d2d := 0
        this.d2d := this.CreateRenderTarget(this.box_width, this.box_height)
        this.render_width := this.box_width
        this.render_height := this.box_height
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
            throw Error("Floating preedit has been disposed.")
        }
    }

    WriteDebugInfo(caret_x, caret_y, caret_w, caret_h) {
        local hwnd, window_dpi := 0
        if !RabbitFloatingPreedit.DEBUG_OUTPUT {
            return
        }
        if hwnd := DllCall("GetForegroundWindow", "ptr") {
            window_dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
        }
        RabbitDebug(
            Format(
                "floating-preedit caret=({}, {}, {}, {}) target_dpi={} screen_dpi={} d2d_scale={} font_size={} box=({}, {}) content=({}, {}, {}, {})",
                caret_x,
                caret_y,
                caret_w,
                caret_h,
                window_dpi,
                A_ScreenDPI,
                this.dpi_scale,
                this.font_size,
                this.box_width,
                this.box_height,
                this.content_x,
                this.content_y,
                this.content_width,
                this.content_height
            ),
            Format("RabbitFloatingPreedit.ahk:{}", A_LineNumber)
        )
    }

    static HasText(preedit) {
        local group
        for group in RabbitGetPreeditGroups(preedit) {
            if group.segments.Length {
                return true
            }
        }
        return false
    }
}
