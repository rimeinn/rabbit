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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitConfigSnapshot.ahk
#Include ..\..\Lib\RabbitStatusTip.ahk

RunTest("themed status tip renders icons and text", TestStatusTipRendersContent.Bind())
RunTest("vertical status tip keeps its icon upright", TestVerticalStatusTipRendersContent.Bind())

TestStatusTipRendersContent() {
    RabbitStatusTipLayeredWindowProbe.events := []
    local d2d := RabbitStatusTipDirect2DProbe(0)
    local layered_window := RabbitStatusTipLayeredWindowProbe(0)
    local tip := RabbitStatusTipProbe(
        RabbitUIStyleSnapshot(),
        RabbitConfigSnapshot(Map("show_tips_time", 1000)),
        (*) => d2d,
        (*) => layered_window,
        (*) => RabbitStatusTipGuiProbe()
    )
    try {
        tip.Show("西", A_ScriptDir . "\..\..\Lib\rabbit-ascii.ico")
        AssertEqual("西", tip.text, "The status tip did not retain its label.")
        AssertEqual(tip.icon_size, tip.loaded_icon_size, "The status tip used the wrong icon target size.")
        AssertEqual(1, d2d.scaled_image_calls, "The status tip did not render its icon.")
        AssertEqual(tip.icon_size, d2d.scaled_image_width, "The status tip did not scale its icon width.")
        AssertEqual(tip.icon_size, d2d.scaled_image_height, "The status tip did not scale its icon height.")
        AssertEqual(0, d2d.source_rect, "The status tip cropped its icon instead of scaling the full image.")
        AssertEqual(1, d2d.text_calls, "The status tip did not render its label.")
        AssertTrue(tip.box_width > 0 && tip.box_height > 0, "The status tip did not build a valid layout.")
        AssertTrue(
            InStr(tip.gui.show_options, "x") && InStr(tip.gui.show_options, "y"),
            "The first status tip display did not use its calculated position."
        )
        AssertEqual(
            "show",
            RabbitStatusTipLayeredWindowProbe.events[1],
            "The status tip submitted its layered surface before its first GUI show."
        )
        AssertEqual(1, layered_window.update_calls, "The status tip did not submit its layered surface.")
    } finally {
        tip.Dispose()
    }
}

TestVerticalStatusTipRendersContent() {
    RabbitStatusTipLayeredWindowProbe.events := []
    local d2d := RabbitStatusTipDirect2DProbe(0)
    local layered_window := RabbitStatusTipLayeredWindowProbe(0)
    local style := RabbitUIStyleSnapshot().With(Map(
        "layout_type", "vertical_text",
        "vertical_text_left_to_right", false
    ))
    local tip := RabbitStatusTipProbe(
        style,
        RabbitConfigSnapshot(Map("show_tips_time", 1000)),
        (*) => d2d,
        (*) => layered_window,
        (*) => RabbitStatusTipGuiProbe()
    )
    try {
        tip.Show("竖排文字", A_ScriptDir . "\..\..\Lib\rabbit-ascii.ico")
        AssertEqual("竖排文字", tip.text, "The vertical status tip did not retain its label.")
        AssertEqual(tip.icon_size, tip.loaded_icon_size, "The vertical status tip used the wrong icon target size.")
        AssertEqual(1, d2d.scaled_image_calls, "The vertical status tip did not render its icon.")
        AssertEqual(tip.icon_size, d2d.scaled_image_width, "The vertical status tip changed its icon width.")
        AssertEqual(tip.icon_size, d2d.scaled_image_height, "The vertical status tip changed its icon height.")
        AssertEqual(0, d2d.source_rect, "The vertical status tip cropped its icon.")
        AssertEqual(0, d2d.text_calls, "The vertical status tip used horizontal text rendering.")
        AssertEqual(1, d2d.text_layout_calls, "The vertical status tip did not use a text layout.")
        AssertEqual(
            Direct2D.DWRITE_READING_DIRECTION_TOP_TO_BOTTOM,
            d2d.text_layout_options.readingDirection,
            "The vertical status tip used the wrong reading direction."
        )
        AssertEqual(
            Direct2D.DWRITE_FLOW_DIRECTION_RIGHT_TO_LEFT,
            d2d.text_layout_options.flowDirection,
            "The vertical status tip used the wrong flow direction."
        )
        AssertTrue(tip.text_y > tip.icon_y, "The vertical status tip did not place text below its icon.")
        AssertEqual(
            tip.icon_x + tip.icon_size / 2,
            tip.text_x + tip.text_metrics.w / 2,
            "The vertical status tip did not center its icon and text in one column."
        )
        AssertTrue(tip.box_height > tip.box_width, "The vertical status tip did not build a vertical layout.")
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

    GetSavedOrCreateIconBitmap(icon_path, icon_size) {
        this.loaded_icon_size := icon_size
        return 1
    }
}

class RabbitStatusTipDirect2DProbe {
    __New(hwnd) {
        this.image_calls := 0
        this.scaled_image_calls := 0
        this.text_calls := 0
        this.text_layout_calls := 0
        this.bmpDstRect := Buffer(16, 0)
        this.ID2D1RenderTarget := RabbitStatusTipRenderTargetProbe(this)
    }

    GetDesktopDpiScale() {
        return 1
    }

    SetRenderTarget(target, width, height) {
    }

    GetMetrics(text, font_name, font_size, args*) {
        if args.Length {
            return { w: 20, h: StrLen(text) * 20 }
        }
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

    DrawTextWithLayout(text, x, y, font_size, color, font_name, width, height, options) {
        this.text_layout_calls++
        this.text_layout_options := options
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
    static events := []

    __New(hwnd) {
        this.update_calls := 0
    }

    Update(wic_bitmap, width, height, x, y) {
        RabbitStatusTipLayeredWindowProbe.events.Push("update")
        this.update_calls++
    }

    Dispose() {
    }
}

class RabbitStatusTipGuiProbe {
    __New() {
        this.Hwnd := 1
    }

    Show(options := "") {
        this.show_options := options
        RabbitStatusTipLayeredWindowProbe.events.Push("show")
    }

    Hide() {
    }

    Destroy() {
    }
}
