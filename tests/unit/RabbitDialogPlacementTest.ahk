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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitDialogPlacement.ahk

RunTest("dialog placement centers on the owner monitor", TestDialogPlacementCenters.Bind())
RunTest("dialog placement stays in the owner work area", TestDialogPlacementClamps.Bind())

TestDialogPlacementCenters() {
    local owner := Rect(1600, 200, 2200, 800)
    local work := Rect(1280, 0, 2560, 1040)
    local position := RabbitDialogPlacement.Calculate(owner, work, 640, 542)
    AssertEqual(1580, position.x, "The dialog was not centered horizontally over its owner.")
    AssertEqual(229, position.y, "The dialog was not centered vertically over its owner.")
}

TestDialogPlacementClamps() {
    local owner := Rect(2380, 850, 2550, 1020)
    local work := Rect(1280, 0, 2560, 1040)
    local position := RabbitDialogPlacement.Calculate(owner, work, 640, 542)
    AssertEqual(1920, position.x, "The dialog extended past the owner monitor's right edge.")
    AssertEqual(498, position.y, "The dialog extended past the owner monitor's bottom edge.")

    position := RabbitDialogPlacement.Calculate(owner, work, 1400, 1200)
    AssertEqual(1280, position.x, "An oversized dialog did not start at the work area's left edge.")
    AssertEqual(0, position.y, "An oversized dialog did not start at the work area's top edge.")
}
