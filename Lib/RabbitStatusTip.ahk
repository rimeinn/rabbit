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

#Include RabbitCommon.ahk
#Include RabbitCaret.ahk
#Include RabbitPopupPlacement.ahk
#Include RabbitUIStyleSnapshot.ahk
#Include RabbitLayeredWindow.ahk
#Include RabbitIcon.ahk
#Include Direct2D/Direct2D.ahk

class RabbitStatusTip {
    ; Track render target recreations: the tip box size changes with the shown
    ; text, and each change rebuilds the whole Direct2D stack.
    static render_target_recreate_count := 0

    __New(
        style,
        config,
        d2d_constructor := Direct2D,
        layered_window_constructor := RabbitLayeredWindow,
        gui_constructor := Gui
    ) {
        this.gui := 0
        this.d2d := 0
        this.d2d_constructor := d2d_constructor
        this.layered_window := 0
        this.render_width := 0
        this.render_height := 0
        this.visible := false
        this.disposed := false
        this.config := config
        this.hide_callback := this.Hide.Bind(this)
        try {
            ; WS_EX_NOACTIVATE | WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST
            this.gui := gui_constructor.Call("-Caption -DPIScale +E0x80800A8")
            this.d2d := this.CreateRenderTarget(1, 1)
            this.layered_window := layered_window_constructor.Call(this.gui.Hwnd)
            this.dpi_scale := this.d2d.GetDesktopDpiScale()
            this.UpdateStyle(style)
        } catch as err {
            this.Dispose()
            throw err
        }
    }

    __Delete() {
        this.Dispose()
    }

    Dispose() {
        if this.disposed {
            return
        }
        SetTimer(this.hide_callback, 0)
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
        this.border_width := style.border_width
        this.border_color := style.border_color
        this.corner_radius := style.corner_radius
        this.padding_x := style.margin_x
        this.padding_y := style.margin_y
        this.vertical_text := style.layout_type = "vertical_text"
        this.font := {
            name: style.font_face,
            size: style.font_point * 96.0 / 72.0 * this.dpi_scale
        }
        this.text_color := style.candidate_text_color
        this.back_color := style.candidate_back_color
    }

    Show(text, icon_path := "") {
        local placement, monitor_info, position
        this.AssertNotDisposed()
        placement := this.GetAnchor()
        monitor_info := placement.monitor_info
        this.Build(
            text,
            icon_path,
            monitor_info ? monitor_info.work.right - monitor_info.work.left : 0
        )
        switch placement.mode {
            case "caret":
                position := RabbitPopupPlacement.PlaceBelowCaret(
                    placement.x,
                    placement.y,
                    placement.w,
                    placement.h,
                    this.box_width,
                    this.box_height,
                    monitor_info
                )
            case "start_menu":
                position := RabbitPopupPlacement.PlaceOutsideRect(
                    placement.anchor_rect,
                    this.box_width,
                    this.box_height,
                    monitor_info,
                    placement.caret
                )
            default:
                position := RabbitPopupPlacement.PlaceAtPoint(
                    placement.x,
                    placement.y,
                    this.box_width,
                    this.box_height,
                    monitor_info
                )
        }
        this.EnsureRenderTarget()
        this.d2d.BeginDraw()
        this.Draw()
        this.d2d.EndDraw()
        if !this.visible {
            this.gui.Show(Format("NA x{} y{} w{} h{}", position.x, position.y, this.box_width, this.box_height))
            this.visible := true
        }
        this.layered_window.Update(
            this.d2d.ID2D1RenderTarget.GetWICBitmap(),
            this.box_width,
            this.box_height,
            position.x,
            position.y
        )
        SetTimer(this.hide_callback, 0)
        SetTimer(this.hide_callback, -this.config.show_tips_time)
    }

    Hide() {
        if this.disposed || !this.visible {
            return
        }
        this.gui.Hide()
        this.visible := false
    }

    EnsureRenderTarget() {
        if this.render_width = this.box_width && this.render_height = this.box_height {
            return
        }
        RabbitStatusTip.render_target_recreate_count++
        if RabbitStatusTip.render_target_recreate_count <= 3
            || Mod(RabbitStatusTip.render_target_recreate_count, 100) == 0 {
            RabbitDebug(
                Format(
                    "status tip recreated Direct2D render target to {}x{} (total {})",
                    this.box_width,
                    this.box_height,
                    RabbitStatusTip.render_target_recreate_count
                ),
                Format("RabbitStatusTip.ahk:{}", A_LineNumber)
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

    GetAnchor() {
        local caret_x, caret_y, caret_w, caret_h, mouse_x, mouse_y
        local mouse_coord_mode, monitor_info, start_menu_info, start_menu_caret
        start_menu_info := RabbitPopupPlacement.GetActiveStartMenuInfo()
        if start_menu_info {
            monitor_info := start_menu_info.monitor_info
            if start_menu_info.usable {
                start_menu_caret := 0
                if RabbitGetCaretPos(
                    &caret_x,
                    &caret_y,
                    &caret_w,
                    &caret_h,
                    this.config.use_caret_hook
                ) {
                    start_menu_caret := { x: caret_x, y: caret_y, w: caret_w, h: caret_h }
                }
                return {
                    mode: "start_menu",
                    anchor_rect: start_menu_info.anchor_rect,
                    caret: start_menu_caret,
                    monitor_info: monitor_info
                }
            }
            return {
                mode: "top_left",
                x: monitor_info.work.left + RabbitPopupPlacement.GAP,
                y: monitor_info.work.top + RabbitPopupPlacement.GAP,
                monitor_info: monitor_info
            }
        }
        if RabbitGetCaretPos(
            &caret_x,
            &caret_y,
            &caret_w,
            &caret_h,
            this.config.use_caret_hook
        ) {
            monitor_info := RabbitPopupPlacement.GetWorkAreaAt(caret_x, caret_y)
            return {
                mode: "caret",
                x: caret_x,
                y: caret_y,
                w: caret_w,
                h: caret_h,
                monitor_info: monitor_info
            }
        }
        mouse_coord_mode := A_CoordModeMouse
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouse_x, &mouse_y)
        CoordMode("Mouse", mouse_coord_mode)
        monitor_info := RabbitPopupPlacement.GetWorkAreaAt(mouse_x, mouse_y)
        return { mode: "mouse", x: mouse_x, y: mouse_y, monitor_info: monitor_info }
    }

    Build(text, icon_path, max_width) {
        local icon_width := 0
        local content_width, max_text_width, text_metrics, icon_metrics
        this.icon_path := this.ResolveIconPath(icon_path)
        icon_metrics := this.d2d.GetMetrics("M", this.font.name, this.font.size)
        this.icon_size := this.icon_path ? Ceil(icon_metrics.h) : 0
        if this.icon_size {
            icon_width := this.icon_size + this.padding_x
        }
        if this.vertical_text {
            this.BuildVerticalText(text)
            return
        }
        max_text_width := max_width
            ? Max(1, max_width - (this.border_width + this.padding_x) * 2 - icon_width)
            : 0
        this.text := this.TruncateText(text, max_text_width)
        text_metrics := this.d2d.GetMetrics(this.text, this.font.name, this.font.size)
        content_width := icon_width + text_metrics.w
        this.text_x := this.border_width + this.padding_x + icon_width
        this.text_y := this.border_width + this.padding_y
        this.icon_x := this.border_width + this.padding_x
        this.icon_y := this.text_y + Max(0, (text_metrics.h - this.icon_size) / 2)
        this.box_width := Ceil(content_width) + (this.border_width + this.padding_x) * 2
        this.box_height := Ceil(Max(text_metrics.h, this.icon_size)) + (this.border_width + this.padding_y) * 2
        if max_width {
            this.box_width := Min(this.box_width, max_width)
        }
    }

    BuildVerticalText(text) {
        local content_width, content_height, base_x, base_y
        this.text := text
        this.text_metrics := this.GetVerticalTextMetrics(this.text)
        content_width := Max(this.icon_size, this.text_metrics.w)
        content_height := this.icon_size + this.text_metrics.h
        if this.icon_size {
            content_height += this.padding_y
        }
        base_x := this.border_width + this.padding_x
        base_y := this.border_width + this.padding_y
        this.icon_x := base_x + (content_width - this.icon_size) / 2
        this.icon_y := base_y
        this.text_x := base_x + (content_width - this.text_metrics.w) / 2
        this.text_y := base_y + this.icon_size + (this.icon_size ? this.padding_y : 0)
        this.box_width := Ceil(content_width) + (this.border_width + this.padding_x) * 2
        this.box_height := Ceil(content_height) + (this.border_width + this.padding_y) * 2
    }

    Draw() {
        local inner_x, inner_y, inner_w, inner_h, inner_radius
        if this.border_width > 0 {
            this.d2d.FillRoundedRectangle(
                0,
                0,
                this.box_width,
                this.box_height,
                this.corner_radius,
                this.corner_radius,
                this.border_color
            )
            inner_x := this.border_width
            inner_y := this.border_width
            inner_w := this.box_width - this.border_width * 2
            inner_h := this.box_height - this.border_width * 2
            inner_radius := this.corner_radius > this.border_width
                ? this.corner_radius - this.border_width
                : 0
            this.d2d.FillRoundedRectangle(
                inner_x,
                inner_y,
                inner_w,
                inner_h,
                inner_radius,
                inner_radius,
                this.back_color
            )
        } else {
            this.d2d.FillRoundedRectangle(
                0,
                0,
                this.box_width,
                this.box_height,
                this.corner_radius,
                this.corner_radius,
                this.back_color
            )
        }
        if this.icon_path {
            this.DrawIcon()
        }
        if this.vertical_text {
            this.DrawVerticalText()
        } else {
            this.d2d.DrawText(
                this.text,
                this.text_x,
                this.text_y,
                this.font.size,
                this.text_color,
                this.font.name
            )
        }
    }

    DrawIcon() {
        local icon_x := Round(this.icon_x)
        local icon_y := Round(this.icon_y)
        NumPut("float", icon_x, this.d2d.bmpDstRect, 0)
        NumPut("float", icon_y, this.d2d.bmpDstRect, 4)
        NumPut("float", icon_x + this.icon_size, this.d2d.bmpDstRect, 8)
        NumPut("float", icon_y + this.icon_size, this.d2d.bmpDstRect, 12)
        if (bitmap := this.GetSavedOrCreateIconBitmap(this.icon_path, this.icon_size)) {
            ; Leave the source rectangle empty so Direct2D scales the complete image into bmpDstRect.
            this.d2d.ID2D1RenderTarget.DrawBitmap(bitmap, this.d2d.bmpDstRect, 1, 1)
        }
    }

    GetSavedOrCreateIconBitmap(icon_path, icon_size) {
        return RabbitIcon.GetSavedOrCreateBitmap(this.d2d, icon_path, icon_size)
    }

    ResolveIconPath(icon_path) {
        local app_path
        if !icon_path {
            return ""
        }
        if FileExist(icon_path) {
            return icon_path
        }
        app_path := A_ScriptDir . "\" . icon_path
        return FileExist(app_path) ? app_path : ""
    }

    TruncateText(text, max_width) {
        local ellipsis := "…"
        local truncated := text
        if !max_width || this.d2d.GetMetrics(text, this.font.name, this.font.size).w <= max_width {
            return text
        }
        while truncated && this.d2d.GetMetrics(truncated . ellipsis, this.font.name, this.font.size).w > max_width {
            truncated := SubStr(truncated, 1, -1)
        }
        return truncated ? truncated . ellipsis : ellipsis
    }

    GetVerticalTextMetrics(text) {
        if !text {
            return { w: 0, h: 0 }
        }
        return this.d2d.GetMetrics(text, this.font.name, this.font.size, 400, 0, {
            reading_direction: Direct2D.DWRITE_READING_DIRECTION_TOP_TO_BOTTOM,
            flow_direction: Direct2D.DWRITE_FLOW_DIRECTION_RIGHT_TO_LEFT
        })
    }

    DrawVerticalText() {
        local text_box_height
        ; DirectWrite can wrap a Latin vertical glyph when its measured line height is exact.
        text_box_height := this.text_metrics.h + this.font.size
        this.d2d.DrawTextWithLayout(
            this.text,
            this.text_x,
            this.text_y,
            this.font.size,
            this.text_color,
            this.font.name,
            this.text_metrics.w,
            text_box_height,
            {
                readingDirection: Direct2D.DWRITE_READING_DIRECTION_TOP_TO_BOTTOM,
                flowDirection: Direct2D.DWRITE_FLOW_DIRECTION_RIGHT_TO_LEFT
            }
        )
    }

    AssertNotDisposed() {
        if this.disposed {
            throw Error("Status tip has been disposed.")
        }
    }
}
