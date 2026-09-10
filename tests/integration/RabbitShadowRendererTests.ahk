/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
#Requires AutoHotkey v2.0
#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitDirect2D.ahk
#Include ..\..\Lib\RabbitUIStyleSnapshot.ahk
#Include ..\..\Lib\RabbitCandidateBox.ahk
#Include ..\..\Lib\RabbitCandidatePreview.ahk

RunTest("native shadow blur preserves alpha and caches resources", TestNativeShadow)
RunTest("shadow windows preserve body geometry and click-through", TestShadowWindows)
RunTest("shadow bitmap preview uses production geometry", TestShadowBitmapPreview)
if A_Args.Length && A_Args[1] = "export" {
    RunTest("export shadow rendering examples", ExportShadowExamples)
}
ExitApp()

ExportShadowExamples() {
    local style := RabbitUIStyleSnapshot(0, Map("font_point", 22, "label_font_point", 18,
        "comment_font_point", 16, "margin_x", 14, "margin_y", 14, "candidate_spacing", 10,
        "candidate_padding_x", 8, "candidate_padding_y", 6, "corner_radius", 12, "round_corner", 8,
        "border_width", 1, "back_color", 0xfffafafa, "candidate_back_color", 0xfffafafa))
    local box := CandidateBox(style), modes, name, overrides, width, height, d2d, shapes, bounds
    local bitmap := 0, pixels, image := 0, encoder := Direct2D.str2guid("{557CF406-1A04-11D3-9A73-0000F81EF32E}")
    local output_dir := A_ScriptDir . "\..\..\Docs\images"
    modes := Map("shadow-disabled", Map(),
        "shadow-window", Map("shadow_radius", 12, "shadow_offset_y", 5, "shadow_color", 0x60000000),
        "shadow-all", Map("shadow_radius", 8, "shadow_offset_x", 2, "shadow_offset_y", 3,
            "shadow_color", 0x50000000, "hilited_shadow_color", 0x60000000,
            "hilited_candidate_shadow_color", 0x70000000, "candidate_shadow_color", 0x50000000))
    try {
        for name, overrides in modes {
            box.UpdateStyle(style.With(overrides))
            box.Build(TestShadowContext(), &width, &height)
            box.RenderFrame(height, false)
            shapes := box.render_shadow_shapes.Clone()
            shapes.InsertAt(1, { rect: { x: 0, y: 0, w: width, h: height },
                corner: box.style.corner_radius, color: box.style.shadow_color })
            bounds := RabbitShadowSurface.Bounds(box.style, shapes, width, height)
            d2d := RabbitDirect2D()
            d2d.SetRenderTarget("wic", bounds.w, bounds.h)
            try {
                bitmap := d2d.ID2D1RenderTarget.CreateBitmapFromWicBitmap(
                    box.d2d.ID2D1RenderTarget.GetWICBitmap(), d2d.d2dBmpPrps)
                d2d.BeginDraw()
                try {
                    RabbitShadowSurface.DrawExterior(d2d, width, height, bounds, box.style, shapes)
                    d2d.ID2D1RenderTarget.DrawBitmap(bitmap,
                        RabbitShadowRenderer.Rect(bounds.left, bounds.top, width, height))
                } finally {
                    d2d.EndDraw()
                }
                pixels := Buffer(bounds.w * bounds.h * 4)
                ComCall(7, d2d.ID2D1RenderTarget.GetWICBitmap(), "ptr", 0, "uint", bounds.w * 4,
                    "uint", pixels.Size, "ptr", pixels)
                RabbitShadowRenderer.Check(DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", bounds.w,
                    "int", bounds.h, "int", bounds.w * 4, "int", 0xE200B, "ptr", pixels, "ptr*", &image),
                    "Create example image")
                RabbitShadowRenderer.Check(DllCall("gdiplus\GdipSaveImageToFile", "ptr", image,
                    "wstr", output_dir . "\" . name . ".png", "ptr", encoder, "ptr", 0), "Save example")
            } finally {
                if image {
                    DllCall("gdiplus\GdipDisposeImage", "ptr", image)
                    image := 0
                }
                if bitmap {
                    ObjRelease(bitmap)
                    bitmap := 0
                }
                d2d := 0
            }
        }
    } finally {
        box.Dispose()
    }
}

TestShadowContext() {
    return {
        composition: { length: 5, preedit: "shuru", cursor_pos: 5, sel_start: 1, sel_end: 4 },
        menu: { candidates: [{ text: "输入法", comment: "测试" }, { text: "输入", comment: "" }],
            num_candidates: 2, highlighted_candidate_index: 0, page_size: 5, select_keys: "12345" },
        select_labels: Map(0, "")
    }
}

TestShadowWindows() {
    local style := RabbitUIStyleSnapshot(0, Map("shadow_radius", 10, "shadow_offset_x", -3,
        "shadow_offset_y", 4, "shadow_color", 0x80000000, "hilited_shadow_color", 0x600000ff,
        "hilited_candidate_shadow_color", 0x6000ff00, "candidate_shadow_color", 0x60ff0000))
    local box := CandidateBox(style), width, height, rect := Buffer(16), pixels, bounds
    local mode, body_size, surface, key, opacity, start, builds, elapsed
    try {
        for mode in ["stacked", "flow", "vertical_text"] {
            box.UpdateStyle(style.With(Map("layout_type", mode)))
            box.Build(TestShadowContext(), &width, &height)
            box.Show(200, 200)
            AssertTrue(box.shadow_surface && box.shadow_surface.visible, "The exterior shadow is missing.")
            surface := box.shadow_surface
            AssertTrue(surface.d2d.shadow_renderer && !surface.d2d.shadow_renderer.failed, "Exterior blur failed.")
            AssertTrue(!box.d2d.shadow_renderer.failed, "Internal blur failed.")
            DllCall("GetWindowRect", "ptr", box.gui.Hwnd, "ptr", rect)
            AssertEqual(200, NumGet(rect, 0, "int"), "Shadows moved the body anchor.")
            AssertEqual(width, NumGet(rect, 8, "int") - NumGet(rect, 0, "int"), "Shadows changed body width.")
            AssertTrue(WinGetExStyle("ahk_id " . surface.gui.Hwnd) & 0x20,
                "The shadow-only window must pass mouse events through.")
            bounds := RabbitShadowRenderer.Extents(style, true)
            pixels := Buffer(surface.width * surface.height * 4)
            ComCall(7, surface.d2d.ID2D1RenderTarget.GetWICBitmap(), "ptr", 0, "uint", surface.width * 4,
                "uint", pixels.Size, "ptr", pixels)
            AssertEqual(0, NumGet(pixels, ((bounds.top + 20) * surface.width + bounds.left + 20) * 4, "uint"),
                "The shadow surface painted over the body interior.")
            AssertTrue(NumGet(pixels, ((bounds.top + 20) * surface.width + bounds.left - 2) * 4 + 3, "uchar") > 0,
                "The exterior blur was clipped.")
            builds := surface.d2d.shadow_renderer.build_count
            start := A_TickCount
            Loop 30 {
                box.RenderFrame(height)
            }
            elapsed := A_TickCount - start
            AssertEqual(builds, surface.d2d.shadow_renderer.build_count, "Stable frames rebuilt exterior blur bitmaps.")
            TestWrite(Format("SHADOW {}: 30 stable frames {} ms, cached bitmaps {} bytes`n",
                mode, elapsed, surface.d2d.shadow_renderer.bytes))
            box.flow_animation_anchor_bottom := true
            box.flow_animation_anchor_y := 200 + height
            box.RenderPreviousFrame(Max(1, height // 2))
            AssertEqual(200 + height - Max(1, height // 2), box.display_render_y,
                "Bottom-anchored collapse moved the body incorrectly.")
            box.Hide()
            AssertTrue(!surface.visible, "Hiding the body left an orphan shadow.")
        }
        box.UpdateStyle(style.With(Map("floating_preedit", true, "floating_preedit_opacity", 0.5)))
        box.BuildFloatingPresentation(RabbitCandidatePresentation(TestShadowContext(), style.label_format),
            200, 200, 2, 24, &width, &height)
        box.Show(200, 240)
        AssertTrue(box.floating_preedit.shadow_surface.visible, "Floating preedit lost its shadow.")
        box.UpdateStyle(style.With(Map("shadow_radius", 0)))
        box.Build(TestShadowContext(), &width, &height)
        box.Show(200, 200)
        AssertTrue(!box.shadow_surface, "Disabling shadows retained exterior resources.")
    } finally {
        box.Dispose()
    }
}

TestShadowBitmapPreview() {
    local owner := Gui(), preview := 0, width, height
    try {
        preview := CandidatePreview(owner.AddPicture("w300 h300"))
        preview.Build(RabbitUIStyleSnapshot(0, Map("shadow_radius", 8, "shadow_color", 0x80000000)), &width, &height)
        preview.Render(["输入法", "输入", "数", "书", "输"], 1)
        AssertTrue(width > preview.candidate_box.boxWidth, "Bitmap preview omitted exterior padding.")
        AssertTrue(preview.hBitmap, "Bitmap preview failed to produce an image.")
        AssertTrue(!preview.candidate_box.visible, "Bitmap preview displayed an extra popup.")
        preview.SetBounds(100, 80)
        preview.Build(RabbitUIStyleSnapshot(0, Map("layout_type", "flow", "shadow_radius", 8,
            "shadow_color", 0x80000000)), &width, &height)
        preview.Render(["输入法", "输入", "数", "书", "输"], 1)
        AssertTrue(width <= 100 && height <= 80, "Flow preview overflowed its host control.")
    } finally {
        if preview {
            preview.Dispose()
        }
        owner.Destroy()
    }
}

TestNativeShadow() {
    local d2d := RabbitDirect2D(), style := RabbitUIStyleSnapshot(0, Map("shadow_radius", 8))
    local pixels := Buffer(80 * 60 * 4, 0), rect := { x: 15, y: 15, w: 40, h: 25 }
    d2d.SetRenderTarget("wic", 80, 60)
    d2d.BeginDraw()
    d2d.DrawShadow(rect, 6, style, 0x80000000)
    d2d.EndDraw()
    AssertTrue(!d2d.shadow_renderer.failed, "The native blur failed.")
    AssertEqual(1, d2d.shadow_renderer.build_count, "Expected one cached bitmap.")
    ComCall(7, d2d.ID2D1RenderTarget.GetWICBitmap(), "ptr", 0, "uint", 80 * 4,
        "uint", pixels.Size, "ptr", pixels)
    AssertEqual(0, NumGet(pixels, 0, "uint"), "The far corner must remain transparent.")
    AssertTrue(NumGet(pixels, (25 * 80 + 30) * 4 + 3, "uchar") > 80, "The shadow center is missing.")
    AssertTrue(NumGet(pixels, (25 * 80 + 13) * 4 + 3, "uchar") > 0, "The blur must extend outside the shape.")
    d2d.BeginDraw()
    d2d.DrawShadow(rect, 6, style, 0x80000000)
    d2d.EndDraw()
    AssertEqual(1, d2d.shadow_renderer.build_count, "Repeated frames must reuse the blur.")
    d2d.BeginDraw()
    d2d.DrawShadow(rect, 6, style, 0x80ff0000)
    d2d.EndDraw()
    ComCall(7, d2d.ID2D1RenderTarget.GetWICBitmap(), "ptr", 0, "uint", 80 * 4,
        "uint", pixels.Size, "ptr", pixels)
    local alpha := NumGet(pixels, (25 * 80 + 13) * 4 + 3, "uchar")
    local red := NumGet(pixels, (25 * 80 + 13) * 4 + 2, "uchar")
    AssertTrue(red > 0 && red <= alpha, "Colored blur pixels must use premultiplied alpha.")
    Loop 40 {
        d2d.BeginDraw()
        d2d.DrawShadow({ x: 15, y: 15, w: 20 + A_Index, h: 25 }, 6, style, 0x80000000)
        d2d.EndDraw()
        AssertTrue(d2d.shadow_renderer.cache.Count <= RabbitShadowRenderer.MAX_CACHE_ENTRIES,
            "Resizing allowed unbounded shadow cache growth.")
        AssertTrue(d2d.shadow_renderer.bytes <= RabbitShadowRenderer.MAX_CACHE_BYTES,
            "Resizing exceeded the shadow cache memory limit.")
    }
}
