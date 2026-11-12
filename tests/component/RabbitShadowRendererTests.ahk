/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
#Requires AutoHotkey v2.0
#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitDirect2D.ahk
#Include ..\..\Lib\RabbitUIStyleSnapshot.ahk
#Include ..\..\Lib\RabbitCandidateBox.ahk
#Include ..\..\Lib\RabbitCandidatePreview.ahk

RunTest("native shadow blur preserves alpha and caches resources", TestNativeShadow)
RunTest("WIC resize preserves factories and redraws on the new target", TestWicRenderTargetResize)
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
            local context := TestShadowContext()
            box.UpdateStyle(style.With(Map("layout_type", mode)))
            box.Build(context, &width, &height)
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
            local body_target := box.d2d.ID2D1RenderTarget
            local shadow_target := surface.d2d.ID2D1RenderTarget
            builds := surface.d2d.shadow_renderer.build_count
            start := A_TickCount
            Loop 30 {
                box.RenderFrame(height)
            }
            elapsed := A_TickCount - start
            AssertEqual(builds, surface.d2d.shadow_renderer.build_count, "Stable frames rebuilt exterior blur bitmaps.")
            AssertTrue(box.d2d.ID2D1RenderTarget == body_target, "Stable frames replaced the candidate WIC target.")
            AssertTrue(surface.d2d.ID2D1RenderTarget == shadow_target, "Stable frames replaced the shadow WIC target.")
            TestWrite(Format("SHADOW {}: 30 stable frames {} ms, cached bitmaps {} bytes`n",
                mode, elapsed, surface.d2d.shadow_renderer.bytes))
            if mode = "stacked" {
                local old_width := width
                local old_shadow_width := surface.width
                local body_d2d := box.d2d
                context.menu.candidates[1].text := "A much longer candidate expands the window."
                box.Build(context, &width, &height)
                box.Show(200, 200)
                AssertTrue(width > old_width, "The long candidate did not widen the window.")
                AssertTrue(box.d2d == body_d2d, "Widening the candidate box recreated its Direct2D object.")
                AssertTrue(box.d2d.ID2D1RenderTarget != body_target, "The wider candidate kept the old WIC target.")
                AssertEqual(width, box.d2d.GetRenderTargetSize().width, "The candidate WIC width did not update.")
                AssertTrue(surface.visible && surface.width > old_shadow_width, "The wider candidate lost its shadow.")
                AssertEqual(surface.width, surface.d2d.GetRenderTargetSize().width, "The shadow WIC width did not update.")
                AssertTrue(surface.d2d.shadow_renderer && !surface.d2d.shadow_renderer.failed,
                    "The wider candidate's shadow failed to draw.")
            }
            box.flow_animation_anchor_bottom := true
            box.flow_animation_anchor_y := 200 + height
            box.RenderPreviousFrame(Max(1, height // 2))
            AssertEqual(200 + height - Max(1, height // 2), box.display_render_y,
                "Bottom-anchored collapse moved the body incorrectly.")
            box.Hide()
            AssertTrue(!surface.visible, "Hiding the body left an orphan shadow.")
        }
        box.UpdateStyle(style.With(Map("floating_preedit", true, "floating_preedit_opacity", 0.5)))
        local floating_context := TestShadowContext()
        box.BuildFloatingPresentation(RabbitCandidatePresentation(floating_context, style.label_format),
            200, 200, 2, 24, &width, &height)
        box.Show(200, 240)
        local floating := box.floating_preedit
        AssertTrue(floating.shadow_surface.visible, "Floating preedit lost its shadow.")
        local floating_width := floating.box_width
        local floating_d2d := floating.d2d
        local floating_target := floating.d2d.ID2D1RenderTarget
        local floating_shadow_width := floating.shadow_surface.width
        floating.Render()
        AssertTrue(floating.d2d.ID2D1RenderTarget == floating_target, "Stable floating preedit replaced its WIC target.")
        floating_context.composition.preedit := "A much longer floating preedit string."
        floating_context.composition.length := StrLen(floating_context.composition.preedit)
        floating_context.composition.cursor_pos := floating_context.composition.length
        box.BuildFloatingPresentation(RabbitCandidatePresentation(floating_context, style.label_format),
            200, 200, 2, 24, &width, &height)
        box.Show(200, 240)
        AssertTrue(floating.box_width > floating_width, "The longer floating preedit did not widen the window.")
        AssertTrue(floating.d2d == floating_d2d, "Widening floating preedit recreated its Direct2D object.")
        AssertTrue(floating.d2d.ID2D1RenderTarget != floating_target, "The wider floating preedit kept the old WIC target.")
        AssertEqual(floating.box_width, floating.d2d.GetRenderTargetSize().width, "The floating WIC width did not update.")
        local floating_shadow := floating.shadow_surface
        AssertTrue(floating_shadow.visible && floating_shadow.width > floating_shadow_width,
            "The wider floating preedit lost its shadow.")
        AssertEqual(floating_shadow.width, floating_shadow.d2d.GetRenderTargetSize().width,
            "The floating shadow WIC width did not update.")
        AssertTrue(floating_shadow.d2d.shadow_renderer && !floating_shadow.d2d.shadow_renderer.failed,
            "The wider floating preedit shadow failed to draw.")
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

TestWicRenderTargetResize() {
    local d2d := RabbitDirect2D()
    local style := RabbitUIStyleSnapshot(0, Map("shadow_radius", 8))
    local original_target := ObjPtr(d2d.SetRenderTarget("wic", 80, 60))
    local d2d_factory := ObjPtr(d2d.ID2D1Factory)
    local write_factory := ObjPtr(d2d.IDWriteFactory)
    local text_format := d2d.GetSavedOrCreateTextFormat("Segoe UI", 16)
    local stroke_style := d2d.GetSavedOrCreateStrokeStyle(0)
    local gradient_colors := Map(0, 0xff000000, 1, 0xffffffff)
    local gradient := d2d.GetSavedOrCreateGradientdStops(gradient_colors)
    AssertTrue(gradient, "The original target did not create gradient stops.")
    AssertWicResizeFrame(d2d, style, 80, 60)

    NumPut("uint", 87, "uint", 1, d2d.d2dBmpPrps)
    local bitmap := d2d.ID2D1RenderTarget.CreateBitmapFromWicBitmap(
        d2d.ID2D1RenderTarget.GetWICBitmap(), d2d.d2dBmpPrps)
    AssertTrue(bitmap, "The original target did not create a cached bitmap.")
    d2d.d2dBitmaps["resize-probe"] := bitmap
    local shadow := ObjPtr(d2d.shadow_renderer)

    AssertThrows(() => d2d.ResizeWicRenderTarget(0, 60), "A zero-width resize did not fail.")
    d2d.ID2D1Factory.DefineProp("CreateWicBitmapRenderTarget", { Call: FailWicTargetCreation })
    try {
        AssertThrows(() => d2d.ResizeWicRenderTarget(120, 90), "Target creation failure did not propagate.")
    } finally {
        d2d.ID2D1Factory.DeleteProp("CreateWicBitmapRenderTarget")
    }
    AssertEqual(original_target, ObjPtr(d2d.ID2D1RenderTarget), "A failed resize replaced the render target.")
    AssertEqual(80, d2d.GetRenderTargetSize().width, "A failed resize changed the target width.")
    AssertEqual(60, d2d.GetRenderTargetSize().height, "A failed resize changed the target height.")
    AssertEqual(1, d2d.solidBrushes.Count, "A failed resize cleared the brush cache.")
    AssertEqual(1, d2d.gradientStops.Count, "A failed resize cleared gradient stops.")
    AssertEqual(gradient, d2d.GetSavedOrCreateGradientdStops(gradient_colors), "A failed resize lost gradient stops.")
    AssertEqual(bitmap, d2d.d2dBitmaps["resize-probe"], "A failed resize lost the cached bitmap.")
    AssertEqual(shadow, ObjPtr(d2d.shadow_renderer), "A failed resize reset the shadow renderer.")
    AssertWicResizeFrame(d2d, style, 80, 60)

    local resized := d2d.ResizeWicRenderTarget(120, 90)
    AssertTrue(resized == d2d.ID2D1RenderTarget, "Resize did not return the active render target.")
    AssertTrue(ObjPtr(resized) != original_target, "Resize reused the previous WIC target.")
    AssertEqual(120, d2d.GetRenderTargetSize().width, "Resize did not update the target width.")
    AssertEqual(90, d2d.GetRenderTargetSize().height, "Resize did not update the target height.")
    AssertEqual(d2d_factory, ObjPtr(d2d.ID2D1Factory), "Resize replaced the Direct2D factory.")
    AssertEqual(write_factory, ObjPtr(d2d.IDWriteFactory), "Resize replaced the DirectWrite factory.")
    AssertEqual(1, d2d.textFormats.Count, "Resize cleared the text format cache.")
    AssertEqual(text_format, d2d.GetSavedOrCreateTextFormat("Segoe UI", 16), "Resize recreated a text format.")
    AssertEqual(1, d2d.strokeStyles.Count, "Resize cleared the stroke style cache.")
    AssertEqual(stroke_style, d2d.GetSavedOrCreateStrokeStyle(0), "Resize recreated a stroke style.")
    AssertEqual(0, d2d.solidBrushes.Count, "Resize kept brushes from the previous target.")
    AssertEqual(0, d2d.gradientStops.Count, "Resize kept gradient stops from the previous target.")
    AssertEqual(0, d2d.d2dBitmaps.Count, "Resize kept bitmaps from the previous target.")
    AssertTrue(!d2d.shadow_renderer, "Resize kept the previous target's shadow renderer.")
    AssertWicResizeFrame(d2d, style, 120, 90)
}

FailWicTargetCreation(factory, bitmap, properties) {
    throw Error("Injected WIC target creation failure.")
}

AssertWicResizeFrame(d2d, style, width, height) {
    local pixels := Buffer(width * height * 4)
    local result
    d2d.BeginDraw()
    try {
        d2d.DrawShadow({x: 15, y: 15, w: 40, h: 25}, 6, style, 0x80000000)
        d2d.FillRectangle(0, 0, 8, 8, 0xff2277cc)
    } finally {
        result := d2d.EndDraw()
    }
    AssertEqual(0, result, "The WIC target did not finish drawing.")
    ComCall(7, d2d.ID2D1RenderTarget.GetWICBitmap(), "ptr", 0, "uint", width * 4,
        "uint", pixels.Size, "ptr", pixels)
    AssertEqual(0xff2277cc, NumGet(pixels, (4 * width + 4) * 4, "uint"), "The brush did not paint the expected pixel.")
    AssertTrue(NumGet(pixels, (25 * width + 30) * 4 + 3, "uchar") > 80, "The shadow bitmap was missing.")
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
