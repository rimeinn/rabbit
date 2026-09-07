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

#Include RabbitCandidateBox.ahk
#Include RabbitShadowSurface.ahk

; Bitmap adapter for the legacy settings dialog, using the production renderer.
class CandidatePreview {
    hBitmap := 0
    candidate_box := 0
    disposed := false
    max_width := 0
    max_height := 0

    SetBounds(width, height) {
        this.max_width := Max(1, width)
        this.max_height := Max(1, height)
    }

    __New(ctrl) {
        this.imgCtrl := ctrl
        this.candidate_box := CandidateBox(RabbitUIStyleSnapshot())
        this.dpiScale := this.candidate_box.dpiScale
    }

    __Delete() {
        this.Dispose()
    }

    Dispose() {
        local old_bitmap := 0
        if this.disposed {
            return
        }
        this.disposed := true
        if this.hBitmap {
            try old_bitmap := SendMessage(0x0172, 0, 0, this.imgCtrl.Hwnd)
            if old_bitmap && old_bitmap != this.hBitmap {
                DllCall("DeleteObject", "ptr", old_bitmap)
            }
            DllCall("DeleteObject", "ptr", this.hBitmap)
            this.hBitmap := 0
        }
        if this.candidate_box {
            this.candidate_box.Dispose()
            this.candidate_box := 0
        }
    }

    Build(style, &calc_width, &calc_height) {
        this.style := style
        this.Prepare(["输入法", "输入", "数", "书", "输"], 1)
        calc_width := this.previewWidth
        calc_height := this.previewHeight
    }

    Prepare(candidates, selected_index) {
        local items := [], index, text, width, height, shapes
        for index, text in candidates {
            items.Push({ text: text, comment: "" })
        }
        this.candidate_box.UpdateStyle(this.style)
        this.candidate_box.Build({
            composition: { length: 10, preedit: "RIMEshurufa", cursor_pos: 10, sel_start: 4, sel_end: 10 },
            menu: { candidates: items, num_candidates: items.Length,
                highlighted_candidate_index: selected_index - 1, page_size: items.Length, select_keys: "123456789" },
            select_labels: Map(0, "")
        }, &width, &height)
        shapes := this.candidate_box.GetShadowShapes(this.candidate_box.preeditLayout,
            this.candidate_box.candidatesLayout, this.candidate_box.candidateHighlights, this.style)
        shapes.InsertAt(1, { rect: { x: 0, y: 0, w: width, h: height },
            corner: this.style.corner_radius, color: this.style.shadow_color })
        this.shapes := shapes
        this.bounds := RabbitShadowSurface.Bounds(this.style, shapes, width, height)
        this.scale := Min(1, this.max_width ? this.max_width / this.bounds.w : 1,
            this.max_height ? this.max_height / this.bounds.h : 1)
        this.previewWidth := Max(1, Floor(this.bounds.w * this.scale))
        this.previewHeight := Max(1, Floor(this.bounds.h * this.scale))
    }

    Render(candidates, selected_index) {
        local d2d := RabbitDirect2D(), body_bitmap := 0, new_bitmap := 0, old_bitmap := 0
        local bounds, destination, transform := Buffer(24, 0)
        this.Prepare(candidates, selected_index)
        this.candidate_box.RenderFrame(this.candidate_box.boxHeight, false)
        bounds := this.bounds
        d2d.SetRenderTarget("wic", this.previewWidth, this.previewHeight)
        try {
            body_bitmap := d2d.ID2D1RenderTarget.CreateBitmapFromWicBitmap(
                this.candidate_box.d2d.ID2D1RenderTarget.GetWICBitmap(), d2d.d2dBmpPrps)
            if !body_bitmap {
                throw Error("Failed to create candidate preview bitmap.")
            }
            d2d.BeginDraw()
            try {
                NumPut("float", this.scale, transform, 0)
                NumPut("float", this.scale, transform, 12)
                d2d.ID2D1RenderTarget.SetTransform(transform)
                RabbitShadowSurface.DrawExterior(d2d, this.candidate_box.boxWidth,
                    this.candidate_box.boxHeight, bounds, this.style, this.shapes)
                destination := RabbitShadowRenderer.Rect(bounds.left, bounds.top,
                    this.candidate_box.boxWidth, this.candidate_box.boxHeight)
                d2d.ID2D1RenderTarget.DrawBitmap(body_bitmap, destination)
            } finally {
                d2d.EndDraw()
            }
            new_bitmap := d2d.ID2D1RenderTarget.GetHBitmapFromWICBitmap()
            if !new_bitmap {
                throw Error("Failed to create candidate preview image.")
            }
            old_bitmap := SendMessage(0x0172, 0, new_bitmap, this.imgCtrl.Hwnd)
            if old_bitmap && old_bitmap != this.hBitmap {
                DllCall("DeleteObject", "ptr", old_bitmap)
            }
            if this.hBitmap {
                DllCall("DeleteObject", "ptr", this.hBitmap)
            }
            this.hBitmap := new_bitmap
            new_bitmap := 0
        } finally {
            if body_bitmap {
                ObjRelease(body_bitmap)
            }
            if new_bitmap {
                DllCall("DeleteObject", "ptr", new_bitmap)
            }
        }
    }
}
