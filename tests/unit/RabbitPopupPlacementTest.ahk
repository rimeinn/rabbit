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
#Include ..\..\Lib\RabbitPopupPlacement.ahk

RunTest("popup placement below caret", TestPlacementBelowCaret.Bind())
RunTest("popup placement flips above caret", TestPlacementFlipsAboveCaret.Bind())
RunTest("popup placement clamps horizontal edges", TestPlacementClampsHorizontalEdges.Bind())
RunTest("popup placement clamps mouse fallback", TestPlacementClampsMouseFallback.Bind())

TestPlacementBelowCaret() {
    local position := RabbitPopupPlacement.PlaceBelowCaret(120, 200, 3, 20, 140, 50, TestWorkArea())
    AssertEqual(123, position.x, "The popup did not align with the caret edge.")
    AssertEqual(224, position.y, "The popup did not appear below the caret.")
    AssertTrue(!position.above, "A below-caret popup incorrectly requested a bottom animation anchor.")
}

TestPlacementFlipsAboveCaret() {
    local position := RabbitPopupPlacement.PlaceBelowCaret(120, 560, 3, 20, 140, 50, TestWorkArea())
    AssertEqual(506, position.y, "The popup did not move above a bottom-edge caret.")
    AssertTrue(position.above, "An above-caret popup did not request a bottom animation anchor.")
}

TestPlacementClampsHorizontalEdges() {
    local left := RabbitPopupPlacement.PlaceBelowCaret(0, 200, 0, 20, 140, 50, TestWorkArea())
    local right := RabbitPopupPlacement.PlaceBelowCaret(980, 200, 20, 20, 140, 50, TestWorkArea())
    AssertEqual(0, left.x, "The popup escaped the left work-area edge.")
    AssertEqual(860, right.x, "The popup escaped the right work-area edge.")
}

TestPlacementClampsMouseFallback() {
    local position := RabbitPopupPlacement.PlaceAtPoint(990, 590, 140, 50, TestWorkArea())
    AssertEqual(860, position.x, "The mouse fallback escaped the right work-area edge.")
    AssertEqual(550, position.y, "The mouse fallback escaped the bottom work-area edge.")
}

TestWorkArea() {
    return { work: { left: 0, top: 0, right: 1000, bottom: 600 } }
}
