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
 */

#Include RabbitMonitors.ahk

class RabbitDialogPlacement {
    static ShowOnOwnerMonitor(dialog, owner_hwnd, options := "") {
        local dialog_bounds, monitor, monitor_info, owner_bounds, position
        dialog.Show(Trim(options . " Hide"))
        dialog_bounds := this.GetWindowBounds(dialog.Hwnd)
        owner_bounds := this.GetWindowBounds(owner_hwnd)
        monitor := MonitorManage.MonitorFromWindow(owner_hwnd, MONITOR_DEFAULTTONEAREST)
        monitor_info := monitor ? MonitorManage.GetMonitorInfo(monitor) : 0
        if !dialog_bounds || !owner_bounds || !monitor_info {
            dialog.Show()
            return false
        }
        position := this.Calculate(
            owner_bounds,
            monitor_info.work,
            dialog_bounds.width(),
            dialog_bounds.height()
        )
        ; Move the hidden dialog first so that per-monitor DPI changes are applied before final centering.
        dialog.Show(Format("Hide x{} y{}", position.x, position.y))
        dialog_bounds := this.GetWindowBounds(dialog.Hwnd)
        if dialog_bounds {
            position := this.Calculate(
                owner_bounds,
                monitor_info.work,
                dialog_bounds.width(),
                dialog_bounds.height()
            )
        }
        dialog.Show(Format("x{} y{}", position.x, position.y))
        return true
    }

    static Calculate(owner_bounds, work_area, dialog_width, dialog_height) {
        local max_x := Max(work_area.left, work_area.right - dialog_width)
        local max_y := Max(work_area.top, work_area.bottom - dialog_height)
        local x := Round((owner_bounds.left + owner_bounds.right - dialog_width) / 2)
        local y := Round((owner_bounds.top + owner_bounds.bottom - dialog_height) / 2)
        return {
            x: Min(Max(x, work_area.left), max_x),
            y: Min(Max(y, work_area.top), max_y)
        }
    }

    static GetWindowBounds(hwnd) {
        local bounds := Rect()
        return DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", bounds, "Int") ? bounds : 0
    }
}
