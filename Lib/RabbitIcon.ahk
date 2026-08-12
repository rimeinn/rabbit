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

#Include Direct2D\Direct2D.ahk

class RabbitIcon {
    static GetPreferredSize(icon_path, target_size) {
        local icon_data, entry_count, entry_offset, width, height, image_size, image_offset
        local best_larger := 0
        local best_smaller := 0

        try {
            icon_data := FileRead(icon_path, "RAW")
        } catch {
            return 0
        }
        if icon_data.Size < 6
            || NumGet(icon_data, 0, "UShort") != 0
            || NumGet(icon_data, 2, "UShort") != 1 {
            return 0
        }
        entry_count := NumGet(icon_data, 4, "UShort")
        if icon_data.Size < 6 + entry_count * 16 {
            return 0
        }

        target_size := Max(1, Ceil(target_size))
        Loop entry_count {
            entry_offset := 6 + (A_Index - 1) * 16
            width := NumGet(icon_data, entry_offset, "UChar")
            height := NumGet(icon_data, entry_offset + 1, "UChar")
            width := width ? width : 256
            height := height ? height : 256
            image_size := NumGet(icon_data, entry_offset + 8, "UInt")
            image_offset := NumGet(icon_data, entry_offset + 12, "UInt")
            if width != height
                || !image_size
                || image_offset > icon_data.Size
                || image_size > icon_data.Size - image_offset {
                continue
            }
            if width >= target_size {
                if !best_larger || width < best_larger.width {
                    best_larger := {
                        width: width,
                        height: height,
                        data: icon_data,
                        entry_offset: entry_offset,
                        image_size: image_size,
                        image_offset: image_offset
                    }
                }
            } else if !best_smaller || width > best_smaller.width {
                best_smaller := {
                    width: width,
                    height: height,
                    data: icon_data,
                    entry_offset: entry_offset,
                    image_size: image_size,
                    image_offset: image_offset
                }
            }
        }
        return best_larger ? best_larger : best_smaller
    }

    static GetSavedOrCreateBitmap(d2d, icon_path, target_size) {
        local selected_size, cache_key, single_icon_data, h_memory := 0, p_memory := 0, p_stream := 0
        local p_gdi_bitmap := 0, wic_bitmap := 0, p_wic_bitmap_source := 0, p_d2d_bitmap := 0

        if !(selected_size := RabbitIcon.GetPreferredSize(icon_path, target_size)) {
            return d2d.GetSavedOrCreateImgBitmap(icon_path)
        }
        cache_key := "RabbitIcon|" . icon_path . "|" . selected_size.width . "x" . selected_size.height
        if d2d.d2dBitmaps.Has(cache_key) {
            return d2d.d2dBitmaps[cache_key]
        }

        try {
            single_icon_data := Buffer(22 + selected_size.image_size, 0)
            NumPut("ushort", 1, single_icon_data, 2) ; ICO image type
            NumPut("ushort", 1, single_icon_data, 4) ; one image
            DllCall(
                "RtlMoveMemory",
                "ptr", single_icon_data.Ptr + 6,
                "ptr", selected_size.data.Ptr + selected_size.entry_offset,
                "uptr", 16
            )
            NumPut("uint", 22, single_icon_data, 18)
            DllCall(
                "RtlMoveMemory",
                "ptr", single_icon_data.Ptr + 22,
                "ptr", selected_size.data.Ptr + selected_size.image_offset,
                "uptr", selected_size.image_size
            )
            h_memory := DllCall("GlobalAlloc", "uint", 0x2, "uptr", single_icon_data.Size, "ptr")
            if !h_memory || !(p_memory := DllCall("GlobalLock", "ptr", h_memory, "ptr")) {
                return 0
            }
            DllCall("RtlMoveMemory", "ptr", p_memory, "ptr", single_icon_data.Ptr, "uptr", single_icon_data.Size)
            DllCall("GlobalUnlock", "ptr", h_memory)
            if DllCall(
                "ole32\CreateStreamOnHGlobal",
                "ptr", h_memory,
                "int", 1, ; The stream owns h_memory after this call.
                "ptr*", &p_stream := 0
            ) != 0 {
                return 0
            }
            h_memory := 0
            if DllCall("gdiplus\GdipCreateBitmapFromStream", "ptr", p_stream, "ptr*", &p_gdi_bitmap := 0) != 0
                || !p_gdi_bitmap {
                return 0
            }
            wic_bitmap := Direct2D.ID2D1WicBitmapRenderTarget(selected_size.width, selected_size.height)
            p_wic_bitmap_source := wic_bitmap.GdiBitmapToWICBitmapSource(
                p_gdi_bitmap,
                Format32bppPArgb := 0xE200B
            )
            if !p_wic_bitmap_source {
                return 0
            }
            NumPut("uint", 87, d2d.d2dBmpPrps, 0) ; DXGI_FORMAT_B8G8R8A8_UNORM
            NumPut("uint", 1, d2d.d2dBmpPrps, 4)  ; D2D1_ALPHA_MODE_PREMULTIPLIED
            p_d2d_bitmap := d2d.ID2D1RenderTarget.CreateBitmapFromWicBitmap(
                p_wic_bitmap_source,
                d2d.d2dBmpPrps
            )
            return d2d.d2dBitmaps[cache_key] := p_d2d_bitmap
        } finally {
            if p_wic_bitmap_source {
                Direct2D.release(p_wic_bitmap_source)
            }
            if wic_bitmap && wic_bitmap.pWICBitmap {
                Direct2D.release(wic_bitmap.pWICBitmap)
                wic_bitmap.pWICBitmap := 0
            }
            if p_gdi_bitmap {
                DllCall("gdiplus\GdipDisposeImage", "ptr", p_gdi_bitmap)
            }
            if p_stream {
                ObjRelease(p_stream)
            }
            if h_memory {
                DllCall("GlobalFree", "ptr", h_memory)
            }
        }
    }
}
