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

#Include RabbitMonitors.ahk

class RabbitPopupPlacement {
    static GAP := 4
    static DWMWA_EXTENDED_FRAME_BOUNDS := 9

    static GetVisibleWindowBounds(hwnd) {
        local bounds := Rect()
        try {
            if DllCall(
                "dwmapi\DwmGetWindowAttribute",
                "Ptr",
                hwnd,
                "UInt",
                this.DWMWA_EXTENDED_FRAME_BOUNDS,
                "Ptr",
                bounds,
                "UInt",
                Rect.struct_size,
                "Int"
            ) = 0 {
                return bounds
            }
        }
        if DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", bounds, "Int") {
            return bounds
        }
        return 0
    }

    static IsUsableAnchorRect(anchor, monitor_info) {
        local work
        if !anchor || !monitor_info {
            return false
        }
        work := monitor_info.work
        if anchor.right <= anchor.left || anchor.bottom <= anchor.top {
            return false
        }
        if anchor.right <= work.left || anchor.left >= work.right
            || anchor.bottom <= work.top || anchor.top >= work.bottom {
            return false
        }
        ; A full-work-area CoreWindow is a composition host, not the visible
        ; Start surface that can safely anchor a non-overlapping popup.
        return anchor.left > work.left || anchor.top > work.top
            || anchor.right < work.right || anchor.bottom < work.bottom
    }

    static GetWorkAreaAt(x, y) {
        local hmon := MonitorManage.MonitorFromPoint(
            Point(x, y),
            MONITOR_DEFAULTTONEAREST
        )
        return hmon ? MonitorManage.GetMonitorInfo(hmon) : 0
    }

    static PlaceBelowCaret(caret_x, caret_y, caret_w, caret_h, box_w, box_h, monitor_info, content_bottom?) {
        local x := caret_x + caret_w
        local lower_edge := caret_y + caret_h
        if IsSet(content_bottom) {
            lower_edge := Max(lower_edge, content_bottom)
        }
        local y := lower_edge + this.GAP
        local above := false
        if monitor_info && y + box_h > monitor_info.work.bottom {
            y := caret_y - this.GAP - box_h
            above := true
        }
        local position := this.ClampToWorkArea(x, y, box_w, box_h, monitor_info)
        position.above := above
        return position
    }

    static PlaceAtPoint(x, y, box_w, box_h, monitor_info) {
        return this.ClampToWorkArea(x, y, box_w, box_h, monitor_info)
    }

    static PlaceOutsideRect(anchor, box_w, box_h, monitor_info, caret := 0) {
        local work := monitor_info.work
        local gap := this.GAP
        local position
        local align_x := anchor.left
        local align_y := anchor.top
        local align_bottom := anchor.bottom
        if this.IsCaretInsideRect(caret, anchor) {
            align_x := caret.x
            align_y := caret.y
            align_bottom := caret.y
        }
        if work.right - anchor.right >= box_w + gap {
            position := this.PlaceBesideRect(
                anchor.right + gap,
                align_y,
                align_bottom,
                box_w,
                box_h,
                monitor_info
            )
            position.side := "right"
            return position
        }
        if anchor.left - work.left >= box_w + gap {
            position := this.PlaceBesideRect(
                anchor.left - gap - box_w,
                align_y,
                align_bottom,
                box_w,
                box_h,
                monitor_info
            )
            position.side := "left"
            return position
        }
        if anchor.top - work.top >= box_h + gap {
            position := this.ClampToWorkArea(
                align_x,
                anchor.top - gap - box_h,
                box_w,
                box_h,
                monitor_info
            )
            position.side := "above"
            position.above := true
            return position
        }
        if work.bottom - anchor.bottom >= box_h + gap {
            position := this.ClampToWorkArea(
                align_x,
                anchor.bottom + gap,
                box_w,
                box_h,
                monitor_info
            )
            position.side := "below"
            position.above := false
            return position
        }
        position := this.PlaceAtPoint(work.left + gap, work.top + gap, box_w, box_h, monitor_info)
        position.side := "fallback"
        position.above := false
        return position
    }

    static IsCaretInsideRect(caret, anchor) {
        return caret
            && caret.x >= anchor.left && caret.x < anchor.right
            && caret.y >= anchor.top && caret.y < anchor.bottom
    }

    static PlaceBesideRect(x, align_y, align_bottom, box_w, box_h, monitor_info) {
        local work := monitor_info.work
        local y := align_y
        local above := false
        if y + box_h > work.bottom {
            ; Keep the lower edge at the caret y as a flow layout grows upward.
            y := Min(align_bottom, work.bottom) - box_h
            above := true
        }
        local position := this.ClampToWorkArea(x, y, box_w, box_h, monitor_info)
        position.above := above
        return position
    }

    static ClampToWorkArea(x, y, box_w, box_h, monitor_info) {
        local work
        if !monitor_info {
            return { x: x, y: y }
        }
        work := monitor_info.work
        x := Max(work.left, Min(x, work.right - box_w))
        y := Max(work.top, Min(y, work.bottom - box_h))
        return { x: x, y: y }
    }
}
