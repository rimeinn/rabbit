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
