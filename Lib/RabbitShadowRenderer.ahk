/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#Include Direct2D/Direct2D.ahk
#Include RabbitCommon.ahk

; Bitmaps belong to one render target. No reference back to the owner is retained.
class RabbitShadowRenderer {
    static MAX_CACHE_BYTES := 16 * 1024 * 1024
    static MAX_CACHE_ENTRIES := 32

    __New() {
        this.cache := Map()
        this.bytes := 0
        this.target := 0
        this.failed := false
        this.build_count := 0
    }

    __Delete() {
        this.Clear()
    }

    Clear() {
        local key, item
        for key, item in this.cache {
            ObjRelease(item.bitmap)
        }
        this.cache.Clear()
        this.bytes := 0
    }

    static StyleKey(style) {
        return Format("{}:{}:{}:{}:{}:{}:{}", style.shadow_radius, style.shadow_offset_x,
            style.shadow_offset_y, style.shadow_color, style.hilited_shadow_color,
            style.hilited_candidate_shadow_color, style.candidate_shadow_color)
    }

    static Enabled(style, color) {
        return style.shadow_radius > 0 && ((color >> 24) & 0xff) > 0
    }

    static Extents(style, enabled) {
        local radius := enabled ? style.shadow_radius + 1 : 0
        return {
            left: enabled ? Max(0, radius - style.shadow_offset_x) : 0,
            top: enabled ? Max(0, radius - style.shadow_offset_y) : 0,
            right: enabled ? Max(0, radius + style.shadow_offset_x) : 0,
            bottom: enabled ? Max(0, radius + style.shadow_offset_y) : 0
        }
    }

    Draw(d2d, rect, corner, style, color) {
        local key, item, destination, radius := style.shadow_radius
        if !RabbitShadowRenderer.Enabled(style, color) || rect.w <= 0 || rect.h <= 0 {
            return
        }
        if this.target != d2d.ID2D1RenderTarget.pRT {
            this.Clear()
            this.target := d2d.ID2D1RenderTarget.pRT
            this.failed := false
        }
        if this.failed {
            return
        }
        try {
            key := Format("{}:{}:{}:{}:{}", rect.w, rect.h, corner, radius, color)
            if !this.cache.Has(key) {
                item := this.CreateBitmap(d2d, rect.w, rect.h, corner, radius, color)
                if this.bytes + item.bytes > RabbitShadowRenderer.MAX_CACHE_BYTES || this.cache.Count >= RabbitShadowRenderer.MAX_CACHE_ENTRIES {
                    this.Clear()
                }
                this.cache[key] := item
                this.bytes += item.bytes
                this.build_count++
            }
            item := this.cache[key]
            destination := RabbitShadowRenderer.Rect(rect.x + style.shadow_offset_x - radius - 1,
                rect.y + style.shadow_offset_y - radius - 1, item.w, item.h)
            d2d.ID2D1RenderTarget.DrawBitmap(item.bitmap, destination)
        } catch as err {
            this.failed := true
            this.Clear()
            RabbitDebug("Shadow disabled: " . err.Message . "`n" . err.Stack, A_LineFile)
        }
    }

    static Rect(x, y, width, height) {
        local result := Buffer(16)
        NumPut("float", x, "float", y, "float", x + width, "float", y + height, result)
        return result
    }

    static Check(status, operation) {
        if status {
            throw Error(operation . " failed (GDI+ status " . status . ").")
        }
    }

    CreateBitmap(d2d, width, height, corner, radius, color) {
        local pad := radius + 1, w := Ceil(width) + 2 * pad, h := Ceil(height) + 2 * pad
        local bitmap := 0, graphics := 0, path := 0, brush := 0, effect := 0, result := 0
        local data := Buffer(16 + 2 * A_PtrSize, 0), locked := false
        local guid := Direct2D.str2guid("{633C80A4-1843-482B-9EF2-BE2834C5FDD4}")
        local parameters := Buffer(8, 0), props := Buffer(16, 0), region := Buffer(16, 0)
        local diameter := Min(Max(0, corner * 2), width, height)
        if w * h * 4 > RabbitShadowRenderer.MAX_CACHE_BYTES {
            throw Error("Shadow bitmap exceeds the 16 MiB limit.")
        }
        try {
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h,
                "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &bitmap), "Create shadow bitmap")
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bitmap,
                "ptr*", &graphics), "Create shadow graphics")
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipSetSmoothingMode", "ptr", graphics, "int", 4), "Set smoothing")
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path), "Create shadow path")
            if diameter > 0 {
                RabbitShadowRenderer.AddArc(path, pad, pad, diameter, 180)
                RabbitShadowRenderer.AddArc(path, pad + width - diameter, pad, diameter, 270)
                RabbitShadowRenderer.AddArc(path, pad + width - diameter, pad + height - diameter, diameter, 0)
                RabbitShadowRenderer.AddArc(path, pad, pad + height - diameter, diameter, 90)
                RabbitShadowRenderer.Check(DllCall("gdiplus\GdipClosePathFigure", "ptr", path), "Close shadow path")
            } else {
                RabbitShadowRenderer.Check(DllCall("gdiplus\GdipAddPathRectangle", "ptr", path, "float", pad,
                    "float", pad, "float", width, "float", height), "Add shadow rectangle")
            }
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipCreateSolidFill", "uint", color, "ptr*", &brush), "Create shadow brush")
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipFillPath", "ptr", graphics, "ptr", brush, "ptr", path), "Fill shadow")
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", graphics)
            graphics := 0
            ; GdipCreateEffect takes a GUID by value, not REFGUID (different x86 ABI).
            if A_PtrSize = 8 {
                RabbitShadowRenderer.Check(DllCall("gdiplus\GdipCreateEffect", "ptr", guid, "ptr*", &effect), "Create blur")
            } else {
                RabbitShadowRenderer.Check(DllCall("gdiplus\GdipCreateEffect", "uint", NumGet(guid, 0, "uint"),
                    "uint", NumGet(guid, 4, "uint"), "uint", NumGet(guid, 8, "uint"),
                    "uint", NumGet(guid, 12, "uint"), "ptr*", &effect), "Create blur")
            }
            NumPut("float", radius, parameters)
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipSetEffectParameters", "ptr", effect,
                "ptr", parameters, "uint", parameters.Size), "Set blur radius")
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipBitmapApplyEffect", "ptr", bitmap, "ptr", effect,
                "ptr", 0, "int", 0, "ptr", 0, "ptr", 0), "Blur shadow")
            NumPut("int", w, "int", h, region, 8)
            RabbitShadowRenderer.Check(DllCall("gdiplus\GdipBitmapLockBits", "ptr", bitmap, "ptr", region,
                "uint", 1, "int", 0xE200B, "ptr", data), "Lock shadow pixels")
            locked := true
            NumPut("uint", 87, "uint", 1, "float", 96, "float", 96, props)
            ; D2D1_SIZE_U occupies eight bytes on both architectures.
            ComCall(4, d2d.ID2D1RenderTarget.pRT, "int64", w | (h << 32),
                "ptr", NumGet(data, 16, "ptr"), "uint", NumGet(data, 8, "int"),
                "ptr", props, "ptr*", &result)
            return { bitmap: result, w: w, h: h, bytes: w * h * 4 }
        } finally {
            if locked {
                DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", bitmap, "ptr", data)
            }
            if effect {
                DllCall("gdiplus\GdipDeleteEffect", "ptr", effect)
            }
            if brush {
                DllCall("gdiplus\GdipDeleteBrush", "ptr", brush)
            }
            if path {
                DllCall("gdiplus\GdipDeletePath", "ptr", path)
            }
            if graphics {
                DllCall("gdiplus\GdipDeleteGraphics", "ptr", graphics)
            }
            if bitmap {
                DllCall("gdiplus\GdipDisposeImage", "ptr", bitmap)
            }
        }
    }

    static AddArc(path, x, y, diameter, start) {
        RabbitShadowRenderer.Check(DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", x, "float", y,
            "float", diameter, "float", diameter, "float", start, "float", 90), "Add shadow corner")
    }
}
