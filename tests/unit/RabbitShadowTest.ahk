/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitShadowSurface.ahk
#Include ..\..\Lib\RabbitColorScheme.ahk

RunTest("shadow settings validate limits and preserve signed offsets", TestShadowSettings)
RunTest("shadow bounds include only visible enabled shapes", TestShadowBounds)
RunTest("shadow colors survive editing and copying in every format", TestShadowColors)

TestShadowSettings() {
    local style := RabbitUIStyleSnapshot(0, Map("shadow_radius", 8, "shadow_offset_x", -12, "shadow_offset_y", 128))
    AssertEqual(8, style.shadow_radius, "The blur radius changed.")
    AssertEqual(-12, style.With(Map()).shadow_offset_x, "Copying lost the negative offset.")
    AssertEqual(128, style.shadow_offset_y, "The maximum offset changed.")
    AssertEqual(0, style.With(Map("shadow_radius", -1)).shadow_radius, "Negative radius must be rejected.")
    AssertEqual(0, style.With(Map("shadow_radius", 65)).shadow_radius, "Oversized radius must be rejected.")
    AssertEqual(0, style.With(Map("shadow_offset_x", 129)).shadow_offset_x, "Oversized offset must be rejected.")
    AssertEqual(0, style.With(Map("shadow_radius", "invalid")).shadow_radius, "Invalid radius must be rejected.")
    AssertEqual(0, RabbitUIStyleSnapshot().shadow_color, "Missing shadow colors must stay transparent.")
}

TestShadowBounds() {
    local style := RabbitUIStyleSnapshot(0, Map("shadow_radius", 8, "shadow_offset_x", -12, "shadow_offset_y", 3))
    local shapes := [{ rect: { x: 0, y: 0, w: 100, h: 50 }, corner: 6, color: 0x80000000 }]
    local bounds := RabbitShadowSurface.Bounds(style, shapes, 100, 50)
    AssertEqual(21, bounds.left, "Leftward shadows need asymmetric space.")
    AssertEqual(0, bounds.right, "A distant leftward shadow must not add right padding.")
    AssertEqual(6, bounds.top, "Top blur support was clipped.")
    AssertEqual(12, bounds.bottom, "Bottom blur support was clipped.")
    bounds := RabbitShadowSurface.Bounds(style.With(Map("shadow_radius", 0)), shapes, 100, 50)
    AssertEqual(100, bounds.w, "Disabled shadows changed layout width.")
    AssertEqual(50, bounds.h, "Disabled shadows changed layout height.")
    shapes[1].color := 0x00123456
    bounds := RabbitShadowSurface.Bounds(style, shapes, 100, 50)
    AssertEqual(100, bounds.w, "Zero alpha allocated shadow padding.")
    shapes := [{ rect: { x: 10, y: 60, w: 20, h: 20 }, corner: 4, color: 0x80000000 }]
    AssertEqual(0, RabbitShadowSurface.VisibleShapes(shapes, 100, 50, 0).Length,
        "Collapsed rows must not cast exterior shadows.")
    shapes := RabbitShadowSurface.VisibleShapes(shapes, 100, 50, 70)
    AssertEqual(0, shapes[1].rect.y, "Bottom-anchored cropping lost its origin.")
    AssertEqual(10, shapes[1].rect.h, "Only the visible part of a row may cast a shadow.")
}

TestShadowColors() {
    local format, color, scheme, copy, colors, key
    for format, color in Map("argb", "0x80402010", "abgr", "0x80102040", "rgba", "0x40201080") {
        scheme := RabbitColorScheme("test", Map("color_format", format, "shadow_color", color,
            "candidate_shadow_color", "0x00000000"))
        colors := scheme.GetEditableColors()
        AssertEqual(0x80402010, colors["shadow_color"], "Shadow color format was ignored.")
        for key in ["candidate_shadow_color", "hilited_shadow_color", "hilited_candidate_shadow_color"] {
            AssertEqual(0, colors[key], "A missing or transparent color became opaque.")
        }
        copy := scheme.WithEdits("Edited", "", colors).CopyAs("copy", "Copy")
        AssertEqual(0, copy.colors["candidate_shadow_color"], "Copying made the shadow opaque.")
        AssertEqual(0x80402010, copy.colors["shadow_color"], "Editing changed shadow alpha.")
    }
}
