/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#Include RabbitDirect2D.ahk
#Include RabbitLayeredWindow.ahk

; Keep the input/placement HWND unchanged. A separate WS_EX_TRANSPARENT layered
; window carries only exterior pixels, so clicks pass through across processes.
class RabbitShadowSurface {
    __New(owner_hwnd) {
        this.owner_hwnd := owner_hwnd
        this.gui := 0
        this.layered_window := 0
        this.d2d := 0
        this.width := 0
        this.height := 0
        this.visible := false
        this.style_key := ""
    }

    __Delete() {
        this.Dispose()
    }

    Dispose() {
        this.layered_window := 0
        this.d2d := 0
        if this.gui {
            this.gui.Destroy()
            this.gui := 0
        }
        this.visible := false
    }

    Hide() {
        if this.gui && this.visible {
            this.gui.Hide()
            this.visible := false
        }
    }

    static VisibleShapes(shapes, width, height, source_y) {
        local result := [], shape, x, y, right, bottom
        for shape in shapes {
            x := Max(0, shape.rect.x)
            y := Max(0, shape.rect.y - source_y)
            right := Min(width, shape.rect.x + shape.rect.w)
            bottom := Min(height, shape.rect.y + shape.rect.h - source_y)
            if right > x && bottom > y {
                result.Push({ rect: { x: x, y: y, w: right - x, h: bottom - y },
                    corner: shape.corner, color: shape.color })
            }
        }
        return result
    }

    static Bounds(style, shapes, width, height) {
        local left := 0, top := 0, right := width, bottom := height, shape, rect
        local pad := style.shadow_radius + 1
        for shape in shapes {
            if !RabbitShadowRenderer.Enabled(style, shape.color) {
                continue
            }
            rect := shape.rect
            left := Min(left, Floor(rect.x + style.shadow_offset_x - pad))
            top := Min(top, Floor(rect.y + style.shadow_offset_y - pad))
            right := Max(right, Ceil(rect.x + rect.w + style.shadow_offset_x + pad))
            bottom := Max(bottom, Ceil(rect.y + rect.h + style.shadow_offset_y + pad))
        }
        return { left: -left, top: -top, right: right - width, bottom: bottom - height,
            w: right - left, h: bottom - top }
    }

    static DrawExterior(d2d, width, height, bounds, style, visible_shapes) {
        local clips, clip, shape, rect, index
        RabbitShadowSurface.DrawWindowShadow(d2d, width, height, bounds, style, visible_shapes[1])
        clips := [
            { x: 0, y: 0, w: bounds.w, h: bounds.top },
            { x: 0, y: bounds.top + height, w: bounds.w, h: bounds.bottom },
            { x: 0, y: bounds.top, w: bounds.left, h: height },
            { x: bounds.left + width, y: bounds.top, w: bounds.right, h: height }
        ]
        for clip in clips {
            if clip.w <= 0 || clip.h <= 0 {
                continue
            }
            d2d.PushAxisAlignedClip(clip.x, clip.y, clip.w, clip.h)
            try {
                for index, shape in visible_shapes {
                    if index = 1 {
                        continue
                    }
                    rect := shape.rect
                    d2d.DrawShadow({ x: rect.x + bounds.left, y: rect.y + bounds.top,
                        w: rect.w, h: rect.h }, shape.corner, style, shape.color)
                }
            } finally {
                d2d.PopAxisAlignedClip()
            }
        }
    }

    static DrawWindowShadow(d2d, width, height, bounds, style, shape) {
        local outer := 0, inner := 0, mask := 0, geometries := Buffer(2 * A_PtrSize)
        local rounded := Buffer(24), whole := RabbitShadowRenderer.Rect(0, 0, bounds.w, bounds.h)
        local parameters := Buffer(A_PtrSize = 8 ? 72 : 60, 0), transform_offset := 20 + A_PtrSize
        local radius := Min(shape.corner, width / 2, height / 2)
        if !RabbitShadowRenderer.Enabled(style, shape.color) {
            return
        }
        try {
            NumPut("float", bounds.left, "float", bounds.top, "float", bounds.left + width,
                "float", bounds.top + height, "float", radius, "float", radius, rounded)
            ComCall(5, d2d.ID2D1Factory.pF, "ptr", whole, "ptr*", &outer)
            ComCall(6, d2d.ID2D1Factory.pF, "ptr", rounded, "ptr*", &inner)
            NumPut("ptr", outer, "ptr", inner, geometries)
            ; Alternate fill excludes the rounded body while retaining its transparent corners.
            ComCall(8, d2d.ID2D1Factory.pF, "uint", 0, "ptr", geometries, "uint", 2, "ptr*", &mask)
            DllCall("ntdll\RtlMoveMemory", "ptr", parameters, "ptr", whole, "uptr", 16)
            NumPut("ptr", mask, parameters, 16)
            NumPut("float", 1, parameters, transform_offset)
            NumPut("float", 1, parameters, transform_offset + 12)
            NumPut("float", 1, parameters, transform_offset + 24)
            DllCall(Direct2D.vTable(d2d.ID2D1RenderTarget.pRT, 40), "ptr", d2d.ID2D1RenderTarget.pRT,
                "ptr", parameters, "ptr", 0)
            try {
                d2d.DrawShadow({ x: bounds.left, y: bounds.top, w: width, h: height },
                    shape.corner, style, shape.color)
            } finally {
                DllCall(Direct2D.vTable(d2d.ID2D1RenderTarget.pRT, 41), "ptr", d2d.ID2D1RenderTarget.pRT)
            }
        } finally {
            if mask {
                ObjRelease(mask)
            }
            if inner {
                ObjRelease(inner)
            }
            if outer {
                ObjRelease(outer)
            }
        }
    }

    Update(width, height, x, y, source_y, style, corner, shapes, opacity := 255) {
        local visible_shapes, bounds, style_key
        if !style.shadow_radius {
            this.Hide()
            return
        }
        visible_shapes := RabbitShadowSurface.VisibleShapes(shapes, width, height, source_y)
        visible_shapes.InsertAt(1, { rect: { x: 0, y: 0, w: width, h: height },
            corner: corner, color: style.shadow_color })
        bounds := RabbitShadowSurface.Bounds(style, visible_shapes, width, height)
        if bounds.w = width && bounds.h = height {
            this.Hide()
            return
        }
        try {
            if bounds.w * bounds.h * 4 > RabbitShadowRenderer.MAX_CACHE_BYTES {
                throw Error("Shadow surface exceeds the 16 MiB limit.")
            }
            if !this.gui {
                this.gui := Gui("-Caption -DPIScale +E0x80800A8")
                this.layered_window := RabbitLayeredWindow(this.gui.Hwnd)
            }
            style_key := RabbitShadowRenderer.StyleKey(style)
            if !this.d2d || this.width != bounds.w || this.height < bounds.h || this.style_key != style_key {
                this.d2d := 0
                this.d2d := RabbitDirect2D()
                this.width := bounds.w
                ; Reuse the target while an animation grows within this capacity.
                this.height := Ceil(bounds.h / 64) * 64
                if this.width * this.height * 4 > RabbitShadowRenderer.MAX_CACHE_BYTES {
                    this.height := bounds.h
                }
                this.d2d.SetRenderTarget("wic", this.width, this.height)
                this.style_key := style_key
            }
            this.d2d.BeginDraw()
            try {
                RabbitShadowSurface.DrawExterior(this.d2d, width, height, bounds, style, visible_shapes)
            } finally {
                this.d2d.EndDraw()
            }
            this.layered_window.Update(this.d2d.ID2D1RenderTarget.GetWICBitmap(), bounds.w, bounds.h,
                x - bounds.left, y - bounds.top, 0, opacity)
            if !this.visible {
                this.gui.Show(Format("NA x{} y{} w{} h{}", x - bounds.left, y - bounds.top, bounds.w, bounds.h))
                this.visible := true
            }
            ; Position directly behind the body without activation or a new taskbar entry.
            DllCall("user32\SetWindowPos", "ptr", this.gui.Hwnd, "ptr", this.owner_hwnd,
                "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13)
        } catch as err {
            this.Hide()
            RabbitDebug("Shadow surface disabled: " . err.Message . "`n" . err.Stack, A_LineFile)
        }
    }
}
