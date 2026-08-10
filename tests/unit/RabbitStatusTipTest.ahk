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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitConfigSnapshot.ahk
#Include ..\..\Lib\RabbitStatusTip.ahk

RunTest("themed status tip renders icons and text", TestStatusTipRendersContent.Bind())

TestStatusTipRendersContent() {
    local d2d := RabbitStatusTipDirect2DProbe(0)
    local layered_window := RabbitStatusTipLayeredWindowProbe(0)
    local tip := RabbitStatusTipProbe(
        RabbitUIStyleSnapshot(),
        RabbitConfigSnapshot(Map("show_tips_time", 1000)),
        (*) => d2d,
        (*) => layered_window
    )
    try {
        tip.Show("西", A_ScriptDir . "\..\..\Lib\rabbit-ascii.ico")
        AssertEqual("西", tip.text, "The status tip did not retain its label.")
        AssertEqual(1, d2d.scaled_image_calls, "The status tip did not render its icon.")
        AssertEqual(tip.icon_size, d2d.scaled_image_width, "The status tip did not scale its icon width.")
        AssertEqual(tip.icon_size, d2d.scaled_image_height, "The status tip did not scale its icon height.")
        AssertEqual(0, d2d.source_rect, "The status tip cropped its icon instead of scaling the full image.")
        AssertEqual(1, d2d.text_calls, "The status tip did not render its label.")
        AssertTrue(tip.box_width > 0 && tip.box_height > 0, "The status tip did not build a valid layout.")
        AssertEqual(1, layered_window.update_calls, "The status tip did not submit its layered surface.")
    } finally {
        tip.Dispose()
    }
}

class RabbitStatusTipProbe extends RabbitStatusTip {
    GetAnchor() {
        return {
            mode: "caret",
            x: 10,
            y: 20,
            w: 2,
            h: 16,
            monitor_info: { work: { left: 0, top: 0, right: 800, bottom: 600 } }
        }
    }
}

class RabbitStatusTipDirect2DProbe {
    __New(hwnd) {
        this.image_calls := 0
        this.scaled_image_calls := 0
        this.text_calls := 0
        this.bmpDstRect := Buffer(16, 0)
        this.ID2D1RenderTarget := RabbitStatusTipRenderTargetProbe(this)
    }

    GetDesktopDpiScale() {
        return 1
    }

    SetRenderTarget(target, width, height) {
    }

    GetMetrics(text, font_name, font_size) {
        return { w: StrLen(text) * 10, h: 20 }
    }

    SetPosition(x, y, width, height) {
    }

    BeginDraw() {
    }

    EndDraw() {
    }

    Clear() {
    }

    FillRoundedRectangle(x, y, width, height, radius_x, radius_y, color) {
    }

    DrawImage(path, x, y, width, height) {
        this.image_calls++
    }

    GetSavedOrCreateImgBitmap(path) {
        return 1
    }

    DrawText(text, x, y, font_size, color, font_name) {
        this.text_calls++
    }
}

class RabbitStatusTipRenderTargetProbe {
    __New(owner) {
        this.owner := owner
    }

    GetWICBitmap() {
        return 1
    }

    DrawBitmap(bitmap, destination, opacity := 1, interpolation := 1, source := 0) {
        this.owner.scaled_image_calls++
        this.owner.scaled_image_width := NumGet(destination, 8, "Float") - NumGet(destination, 0, "Float")
        this.owner.scaled_image_height := NumGet(destination, 12, "Float") - NumGet(destination, 4, "Float")
        this.owner.source_rect := source
    }
}

class RabbitStatusTipLayeredWindowProbe {
    __New(hwnd) {
        this.update_calls := 0
    }

    Update(wic_bitmap, width, height, x, y) {
        this.update_calls++
    }

    Dispose() {
    }
}
