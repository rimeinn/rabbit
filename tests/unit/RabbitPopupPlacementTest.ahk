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
RunTest("popup placement clears lower floating content", TestPlacementClearsLowerFloatingContent.Bind())
RunTest("popup placement keeps the lower caret edge", TestPlacementKeepsLowerCaretEdge.Bind())
RunTest("popup placement flips above caret", TestPlacementFlipsAboveCaret.Bind())
RunTest("popup placement accounts for floating content when flipping", TestPlacementFloatingContentFlips.Bind())
RunTest("popup placement clamps horizontal edges", TestPlacementClampsHorizontalEdges.Bind())
RunTest("popup placement clamps mouse fallback", TestPlacementClampsMouseFallback.Bind())
RunTest("visible window bounds can be queried", TestVisibleWindowBounds.Bind())
RunTest("Start popup placement uses the nearest left edge", TestStartPlacementUsesNearestLeftEdge.Bind())
RunTest("Start popup placement uses the nearest right edge", TestStartPlacementUsesNearestRightEdge.Bind())
RunTest("Start popup placement uses the nearest top edge", TestStartPlacementUsesNearestTopEdge.Bind())
RunTest("Start popup placement uses the nearest bottom edge", TestStartPlacementUsesNearestBottomEdge.Bind())
RunTest("Start popup top distance includes caret height", TestStartTopDistanceIncludesCaretHeight.Bind())
RunTest("Start popup skips a nearest edge without space", TestStartPlacementSkipsUnavailableEdge.Bind())
RunTest("Start popup side placement grows upward near the bottom", TestStartSidePlacementGrowsUpward.Bind())
RunTest("Start popup ignores a caret outside the menu", TestStartPlacementIgnoresOutsideCaret.Bind())
RunTest("Start popup rejects a full-work-area host", TestStartPlacementRejectsFullWorkAreaHost.Bind())

TestPlacementBelowCaret() {
    local position := RabbitPopupPlacement.PlaceBelowCaret(120, 200, 3, 20, 140, 50, TestWorkArea())
    AssertEqual(123, position.x, "The popup did not align with the caret edge.")
    AssertEqual(224, position.y, "The popup did not appear below the caret.")
    AssertTrue(!position.above, "A below-caret popup incorrectly requested a bottom animation anchor.")
}

TestPlacementClearsLowerFloatingContent() {
    local position := RabbitPopupPlacement.PlaceBelowCaret(120, 200, 3, 13, 140, 50, TestWorkArea(), 220)
    AssertEqual(224, position.y, "The popup overlapped floating content below a short caret.")
    AssertTrue(!position.above, "A popup with enough lower space incorrectly flipped above the caret.")
}

TestPlacementKeepsLowerCaretEdge() {
    local position := RabbitPopupPlacement.PlaceBelowCaret(120, 200, 3, 20, 140, 50, TestWorkArea(), 213)
    AssertEqual(224, position.y, "Floating content moved the popup above the lower caret edge.")
    AssertTrue(!position.above, "A popup with enough lower space incorrectly flipped above the caret.")
}

TestPlacementFlipsAboveCaret() {
    local position := RabbitPopupPlacement.PlaceBelowCaret(120, 560, 3, 20, 140, 50, TestWorkArea())
    AssertEqual(506, position.y, "The popup did not move above a bottom-edge caret.")
    AssertTrue(position.above, "An above-caret popup did not request a bottom animation anchor.")
}

TestPlacementFloatingContentFlips() {
    local monitor_info := { work: { left: 0, top: 0, right: 1000, bottom: 290 } }
    local position := RabbitPopupPlacement.PlaceBelowCaret(120, 200, 3, 13, 140, 50, monitor_info, 240)
    AssertEqual(146, position.y, "The popup did not flip when floating content consumed the lower space.")
    AssertTrue(position.above, "A popup flipped by floating content did not request a bottom animation anchor.")
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

TestVisibleWindowBounds() {
    local test_window := Gui("-DPIScale")
    try {
        test_window.Show("NA x-32000 y-32000 w200 h100")
        local bounds := RabbitPopupPlacement.GetVisibleWindowBounds(test_window.Hwnd)
        AssertTrue(IsObject(bounds), "The visible-window query did not return a rectangle.")
        AssertTrue(bounds.right > bounds.left, "The visible-window rectangle had no width.")
        AssertTrue(bounds.bottom > bounds.top, "The visible-window rectangle had no height.")
    } finally {
        test_window.Destroy()
    }
}

TestStartPlacementUsesNearestLeftEdge() {
    local anchor := { left: 300, top: 200, right: 700, bottom: 600 }
    local caret := { x: 320, y: 400, w: 2, h: 20 }
    local position := RabbitPopupPlacement.PlaceOutsideRect(anchor, 140, 50, TallTestWorkArea(), caret)
    AssertEqual("left", position.side, "The popup did not use the nearest left edge of Start.")
    AssertEqual(156, position.x, "The left-side popup overlapped Start.")
    AssertEqual(400, position.y, "The left-side popup did not align with the caret.")
    AssertTrue(!position.above, "The left-side popup unexpectedly requested upward flow.")
}

TestStartPlacementUsesNearestRightEdge() {
    local anchor := { left: 300, top: 200, right: 700, bottom: 600 }
    local caret := { x: 680, y: 400, w: 2, h: 20 }
    local position := RabbitPopupPlacement.PlaceOutsideRect(anchor, 140, 50, TallTestWorkArea(), caret)
    AssertEqual("right", position.side, "The popup did not use the nearest right edge of Start.")
    AssertEqual(704, position.x, "The right-side popup overlapped Start.")
    AssertEqual(400, position.y, "The right-side popup did not align with the caret.")
}

TestStartPlacementUsesNearestTopEdge() {
    local anchor := { left: 300, top: 200, right: 700, bottom: 600 }
    local caret := { x: 500, y: 220, w: 2, h: 20 }
    local position := RabbitPopupPlacement.PlaceOutsideRect(anchor, 140, 50, TallTestWorkArea(), caret)
    AssertEqual("above", position.side, "The popup did not use the nearest top edge of Start.")
    AssertEqual(500, position.x, "The above-Start popup did not align with the caret.")
    AssertEqual(146, position.y, "The above-Start popup did not preserve its lower edge.")
    AssertTrue(position.above, "The above-Start popup did not request upward flow.")
}

TestStartPlacementUsesNearestBottomEdge() {
    local anchor := { left: 300, top: 200, right: 700, bottom: 600 }
    local caret := { x: 500, y: 570, w: 2, h: 20 }
    local position := RabbitPopupPlacement.PlaceOutsideRect(anchor, 140, 50, TallTestWorkArea(), caret)
    AssertEqual("below", position.side, "The popup did not use the nearest bottom edge of Start.")
    AssertEqual(500, position.x, "The below-Start popup did not align with the caret.")
    AssertEqual(604, position.y, "The below-Start popup overlapped Start.")
    AssertTrue(!position.above, "The below-Start popup unexpectedly requested upward flow.")
}

TestStartTopDistanceIncludesCaretHeight() {
    local anchor := { left: 200, top: 100, right: 800, bottom: 500 }
    local caret := { x: 500, y: 285, w: 2, h: 50 }
    local position := RabbitPopupPlacement.PlaceOutsideRect(anchor, 140, 50, TallTestWorkArea(), caret)
    AssertEqual("below", position.side, "The top-edge distance ignored the caret height.")
}

TestStartPlacementSkipsUnavailableEdge() {
    local anchor := { left: 200, top: 100, right: 600, bottom: 590 }
    local caret := { x: 550, y: 570, w: 2, h: 20 }
    local position := RabbitPopupPlacement.PlaceOutsideRect(anchor, 140, 50, TestWorkArea(), caret)
    AssertEqual("right", position.side, "The popup did not use the nearest edge with enough screen space.")
}

TestStartSidePlacementGrowsUpward() {
    local anchor := { left: 200, top: 300, right: 600, bottom: 590 }
    local caret := { x: 550, y: 550, w: 2, h: 20 }
    local position := RabbitPopupPlacement.PlaceOutsideRect(anchor, 140, 150, TestWorkArea(), caret)
    AssertEqual("right", position.side, "The bottom-edge popup left the nearest available side.")
    AssertEqual(400, position.y, "The bottom-edge popup did not align its lower edge with the caret.")
    AssertTrue(position.above, "The bottom-edge popup did not request upward flow.")
}

TestStartPlacementIgnoresOutsideCaret() {
    local anchor := { left: 200, top: 100, right: 600, bottom: 500 }
    local caret := { x: 50, y: 550, w: 2, h: 20 }
    local position := RabbitPopupPlacement.PlaceOutsideRect(anchor, 140, 50, TestWorkArea(), caret)
    AssertEqual(100, position.y, "A caret outside Start changed the popup alignment.")
}

TestStartPlacementRejectsFullWorkAreaHost() {
    local work_area := TestWorkArea()
    local anchor := { left: 0, top: 0, right: 1000, bottom: 600 }
    local visible_start := { left: 200, top: 100, right: 800, bottom: 590 }
    AssertTrue(
        RabbitPopupPlacement.IsUsableAnchorRect(visible_start, work_area),
        "A visible Start surface was rejected as an anchor."
    )
    AssertTrue(
        !RabbitPopupPlacement.IsUsableAnchorRect(anchor, work_area),
        "A full-work-area composition host was accepted as the visible Start surface."
    )
}

TestWorkArea() {
    return { work: { left: 0, top: 0, right: 1000, bottom: 600 } }
}

TallTestWorkArea() {
    return { work: { left: 0, top: 0, right: 1000, bottom: 800 } }
}
