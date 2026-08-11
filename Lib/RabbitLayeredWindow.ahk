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

class RabbitLayeredWindow {
    __New(hwnd) {
        this.hwnd := hwnd
        this.hdc := 0
        this.bitmap := 0
        this.old_bitmap := 0
        this.bits := 0
        this.width := 0
        this.height := 0
        this.disposed := false
    }

    __Delete() {
        this.Dispose()
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.ReleaseBitmap()
        this.disposed := true
    }

    Update(wic_bitmap, width, height, x, y, source_y := 0) {
        local stride := width * 4
        local size := stride * height
        local destination := Buffer(8, 0)
        local window_size := Buffer(8, 0)
        local source := Buffer(8, 0)
        local source_rect := Buffer(16, 0)
        local blend := Buffer(4, 0)

        if this.disposed {
            throw Error("Layered window has been disposed.")
        }
        if !wic_bitmap {
            throw Error("Layered window update requires a WIC bitmap.")
        }
        if source_y < 0 {
            throw ValueError("Layered window source y must not be negative.")
        }

        this.EnsureBitmap(width, height)
        NumPut("int", source_y, source_rect, 4)
        NumPut("int", width, source_rect, 8)
        NumPut("int", height, source_rect, 12)
        if ComCall(
            CopyPixels := 7,
            wic_bitmap,
            "ptr", source_rect,
            "uint", stride,
            "uint", size,
            "ptr", this.bits
        ) != 0 {
            throw Error("WIC bitmap pixel copy failed.")
        }

        NumPut("int", x, destination, 0)
        NumPut("int", y, destination, 4)
        NumPut("int", width, window_size, 0)
        NumPut("int", height, window_size, 4)
        NumPut("uchar", 0, blend, 0) ; AC_SRC_OVER
        NumPut("uchar", 0, blend, 1)
        NumPut("uchar", 255, blend, 2) ; Use the per-pixel alpha channel.
        NumPut("uchar", 1, blend, 3) ; AC_SRC_ALPHA

        if !DllCall(
            "user32\UpdateLayeredWindow",
            "ptr", this.hwnd,
            "ptr", 0,
            "ptr", destination,
            "ptr", window_size,
            "ptr", this.hdc,
            "ptr", source,
            "uint", 0,
            "ptr", blend,
            "uint", 2 ; ULW_ALPHA
        ) {
            throw OSError(A_LastError, "UpdateLayeredWindow failed.")
        }
    }

    EnsureBitmap(width, height) {
        local bitmap_info, bitmap, bits := 0
        if this.width = width && this.height = height {
            return
        }

        this.ReleaseBitmap()
        this.hdc := DllCall("gdi32\CreateCompatibleDC", "ptr", 0, "ptr")
        if !this.hdc {
            throw OSError(A_LastError, "CreateCompatibleDC failed.")
        }

        bitmap_info := Buffer(40, 0)
        NumPut("uint", 40, bitmap_info, 0) ; BITMAPINFOHEADER.biSize
        NumPut("int", width, bitmap_info, 4) ; biWidth
        NumPut("int", -height, bitmap_info, 8) ; Top-down DIB: biHeight
        NumPut("ushort", 1, bitmap_info, 12) ; biPlanes
        NumPut("ushort", 32, bitmap_info, 14) ; biBitCount
        NumPut("uint", 0, bitmap_info, 16) ; BI_RGB

        bitmap := DllCall(
            "gdi32\CreateDIBSection",
            "ptr", 0,
            "ptr", bitmap_info,
            "uint", 0,
            "ptr*", &bits,
            "ptr", 0,
            "uint", 0,
            "ptr"
        )
        if !bitmap {
            this.ReleaseBitmap()
            throw OSError(A_LastError, "CreateDIBSection failed.")
        }

        this.bitmap := bitmap
        this.bits := bits
        this.old_bitmap := DllCall(
            "gdi32\SelectObject", "ptr", this.hdc, "ptr", this.bitmap, "ptr")
        if !this.old_bitmap {
            this.ReleaseBitmap()
            throw OSError(A_LastError, "SelectObject failed.")
        }
        this.width := width
        this.height := height
    }

    ReleaseBitmap() {
        if this.hdc {
            if this.old_bitmap {
                DllCall("gdi32\SelectObject", "ptr", this.hdc, "ptr", this.old_bitmap, "ptr")
                this.old_bitmap := 0
            }
            DllCall("gdi32\DeleteDC", "ptr", this.hdc)
            this.hdc := 0
        }
        if this.bitmap {
            DllCall("gdi32\DeleteObject", "ptr", this.bitmap)
            this.bitmap := 0
        }
        this.bits := 0
        this.width := 0
        this.height := 0
    }
}
