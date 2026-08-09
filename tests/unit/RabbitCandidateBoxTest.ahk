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
#Include ..\..\Lib\RabbitCandidateBoxFactory.ahk

candidate_context := CreateCandidateContext()
candidate_style := RabbitUIStyleSnapshot()

if A_Args.Length {
    switch A_Args[1] {
        case "factory-old-windows":
            RunTest("old Windows factory selection", TestOldWindowsFactorySelection.Bind(candidate_style))
        case "factory-configured-legacy":
            RunTest(
                "configured legacy factory selection",
                TestConfiguredLegacyFactorySelection.Bind(candidate_style)
            )
        case "factory-modern":
            RunTest("modern factory selection", TestModernFactorySelection.Bind(candidate_style))
        case "legacy-build-no-direct2d":
            RunTest("legacy build without Direct2D", TestLegacyBuildWithoutDirect2D.Bind(candidate_style))
        case "visual-modern":
            ShowVisualCandidate(CandidateBox(candidate_style), candidate_context)
        case "visual-legacy":
            ShowVisualCandidate(LegacyCandidateBox(candidate_style), candidate_context)
        default:
            throw Error("Unknown test mode: " . A_Args[1])
    }
    ExitApp()
}

RunTest("old Windows factory selection", TestOldWindowsFactorySelection.Bind(candidate_style))
RunTest("configured legacy factory selection", TestConfiguredLegacyFactorySelection.Bind(candidate_style))
RunTest("modern factory selection", TestModernFactorySelection.Bind(candidate_style))
RunTest(
    "legacy update without measurement windows",
    TestLegacyUpdateWithoutMeasurementWindow.Bind(candidate_style, candidate_context)
)
RunTest("legacy dynamic calculated layout", TestLegacyDynamicCalculatedLayout.Bind(candidate_style))
RunTest("legacy GDI text measurement parity", TestLegacyGdiTextMeasurementParity.Bind(candidate_style))
RunTest("legacy fake GUI uniform row backgrounds", TestLegacyFakeGuiUniformRowBackgrounds)
RunTest("legacy pure layout calculation", TestLegacyPureLayoutCalculation.Bind())
RunTest(
    "modern candidate lifecycle",
    TestBackendLifecycle.Bind("modern", CandidateBox(candidate_style), candidate_context, candidate_style)
)
RunTest("modern flow candidate layout", TestModernFlowCandidateLayout.Bind(candidate_style))
RunTest(
    "legacy candidate lifecycle",
    TestBackendLifecycle.Bind("legacy", LegacyCandidateBox(candidate_style), candidate_context, candidate_style)
)
RunTest("partial construction cleanup", TestPartialConstructionCleanup.Bind(candidate_style))

ShowVisualCandidate(candidate_box, context) {
    local width, height
    try {
        candidate_box.Build(context, &width, &height)
        candidate_box.Show(100, 100)
        Sleep(5000)
    } finally {
        candidate_box.Dispose()
    }
}

CreateCandidateContext() {
    return {
        composition: {
            length: 5,
            preedit: "shuru",
            cursor_pos: 5,
            sel_start: 0,
            sel_end: 0
        },
        menu: {
            candidates: [
                { text: "输入法", comment: "测试" },
                { text: "输入", comment: "" }
            ],
            highlighted_candidate_index: 0,
            num_candidates: 2,
            page_size: 5,
            select_keys: "12345"
        },
        select_labels: Map(0, "", 1, "", 2, "")
    }
}

TestOldWindowsFactorySelection(style) {
    TestCandidateFactorySelection(true, "Old Windows", style)
}

TestConfiguredLegacyFactorySelection(style) {
    TestCandidateFactorySelection(true, "The legacy setting", style)
}

TestModernFactorySelection(style) {
    TestCandidateFactorySelection(false, "The modern path", style)
}

TestCandidateFactorySelection(use_legacy_candidate_box, description, style) {
    local modern_count := { value: 0 }
    local legacy_count := { value: 0 }
    local direct2d_count := { value: 0 }
    local modern_constructor := CreateModernCandidate.Bind(modern_count, direct2d_count)
    local legacy_constructor := CreateLegacyCandidate.Bind(legacy_count)
    local factory := RabbitCandidateBoxFactory(style, modern_constructor, legacy_constructor)
    local candidate_box := factory.Create(use_legacy_candidate_box)

    local expected_modern := use_legacy_candidate_box ? 0 : 1
    local expected_legacy := expected_modern ? 0 : 1
    AssertEqual(expected_modern, modern_count.value, description . " selected the wrong modern backend count.")
    AssertEqual(expected_legacy, legacy_count.value, description . " selected the wrong legacy backend count.")
    AssertEqual(expected_modern, direct2d_count.value, description . " selected the wrong Direct2D count.")
    candidate_box.Dispose()
}

TestLegacyBuildWithoutDirect2D(style) {
    local direct2d_count := { value: 0 }
    local original_constructor := Direct2D.Prototype.GetOwnPropDesc("__New")
    local original_destructor := Direct2D.Prototype.GetOwnPropDesc("__Delete")
    Direct2D.Prototype.DefineProp(
        "__New", { Call: CountDirect2DConstruction.Bind(direct2d_count) })
    Direct2D.Prototype.DefineProp("__Delete", { Call: IgnoreDirect2DDestruction })
    local candidate_box := 0
    local width, height
    try {
        local construction_probe := Direct2D(0)
        AssertEqual(1, direct2d_count.value, "The Direct2D construction probe must count its calibration call.")
        construction_probe := 0
        direct2d_count.value := 0

        candidate_box := RabbitCandidateBoxFactory(style).Create(true)
        candidate_box.Build(candidate_context, &width, &height)
        AssertTrue(width > 0 && height > 0, "The legacy backend must build valid dimensions.")
    } finally {
        try {
            if candidate_box {
                candidate_box.Dispose()
            }
        } finally {
            try {
                Direct2D.Prototype.DefineProp("__New", original_constructor)
            } finally {
                Direct2D.Prototype.DefineProp("__Delete", original_destructor)
            }
        }
    }
    AssertEqual(0, direct2d_count.value, "Building the legacy backend must not construct Direct2D.")
}

CountDirect2DConstruction(direct2d_count, instance, parameters*) {
    direct2d_count.value++
}

IgnoreDirect2DDestruction(instance, parameters*) {
}

CreateModernCandidate(modern_count, direct2d_count, style) {
    modern_count.value++
    return CandidateBox(style, CreateFakeDirect2D.Bind(direct2d_count))
}

CreateLegacyCandidate(legacy_count, style) {
    legacy_count.value++
    return LegacyCandidateBox(style)
}

CreateFakeDirect2D(direct2d_count, hwnd) {
    direct2d_count.value++
    return RabbitFakeDirect2D()
}

TestLegacyUpdateWithoutMeasurementWindow(style, context) {
    local baseline := CountProcessGuiWindows()
    local candidate_box := 0
    local destroy_calls := { value: 0 }
    local box_gui_prototype := LegacyCandidateBox.BoxGui.Prototype
    local had_own_destroy := box_gui_prototype.HasOwnProp("Destroy")
    local own_destroy := had_own_destroy ? box_gui_prototype.GetOwnPropDesc("Destroy") : 0
    local original_destroy := box_gui_prototype.Destroy
    local width, height
    box_gui_prototype.DefineProp(
        "Destroy",
        { Call: CountLegacyGuiDestruction.Bind(destroy_calls, original_destroy) }
    )
    try {
        candidate_box := LegacyCandidateBox(style)
        candidate_box.Build(context, &width, &height)
        local built_count := CountProcessGuiWindows()
        AssertEqual(
            baseline + 1,
            built_count,
            "The initial legacy build must create only its owned candidate window."
        )

        candidate_box.Build(context, &width, &height)
        local baseline_gdi_objects := CountProcessGuiResources(0)
        local baseline_user_objects := CountProcessGuiResources(1)
        local update_started_at := A_TickCount
        Loop 20 {
            candidate_box.Build(context, &width, &height)
        }
        local update_duration := A_TickCount - update_started_at
        FileAppend(
            Format("CHARACTERIZATION: legacy 20 calculated updates {}ms`n", update_duration),
            "*"
        )
        AssertEqual(
            0,
            destroy_calls.value,
            "Legacy updates created and destroyed temporary measurement windows."
        )
        AssertEqual(
            built_count,
            CountProcessGuiWindows(),
            "The process GUI window count changed after repeated legacy updates."
        )
        AssertEqual(
            baseline_gdi_objects,
            CountProcessGuiResources(0),
            "Repeated legacy updates leaked GDI objects."
        )
        AssertEqual(
            baseline_user_objects,
            CountProcessGuiResources(1),
            "Repeated legacy updates leaked USER objects."
        )
    } finally {
        try {
            if candidate_box {
                candidate_box.Dispose()
            }
        } finally {
            if had_own_destroy {
                box_gui_prototype.DefineProp("Destroy", own_destroy)
            } else {
                box_gui_prototype.DeleteProp("Destroy")
            }
        }
    }
    AssertEqual(
        baseline,
        CountProcessGuiWindows(),
        "Legacy candidate disposal left native GUI windows behind."
    )
    AssertEqual(1, destroy_calls.value, "Legacy disposal did not destroy exactly one owned window.")
}

CountLegacyGuiDestruction(destroy_calls, original_destroy, gui, parameters*) {
    destroy_calls.value++
    original_destroy.Call(gui, parameters*)
}

CountProcessGuiWindows() {
    local previous_detect_hidden_windows := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        local process_id := DllCall("GetCurrentProcessId", "UInt")
        return WinGetList("ahk_class AutoHotkeyGUI ahk_pid " . process_id).Length
    } finally {
        DetectHiddenWindows(previous_detect_hidden_windows)
    }
}

CountProcessGuiResources(flag) {
    local process := DllCall("GetCurrentProcess", "Ptr")
    return DllCall("user32\GetGuiResources", "Ptr", process, "UInt", flag, "UInt")
}

TestLegacyDynamicCalculatedLayout(style) {
    local baseline := CountProcessGuiWindows()
    local candidate_box := LegacyCandidateBox(style)
    local context := CreateCandidateContext()
    local width, height, expanded_width, expanded_height
    local client_width, client_height
    try {
        context.composition := {
            length: 6,
            preedit: "abcdef",
            cursor_pos: 99,
            sel_start: 0,
            sel_end: 0
        }
        context.menu.candidates := []
        context.menu.num_candidates := 0
        candidate_box.Build(context, &width, &height)
        AssertEqual(0, candidate_box.gui.num_candidates, "The composition-only layout created candidate rows.")
        AssertTrue(HasProp(candidate_box.gui, "pre"), "The composition-only layout omitted preedit text.")

        context.composition.sel_start := 2
        context.composition.sel_end := 4
        context.menu.candidates := [
            { text: "候选一", comment: "注释" },
            { text: "候选二", comment: "" },
            { text: "候选三", comment: "更多注释" }
        ]
        context.menu.num_candidates := 3
        candidate_box.Build(context, &width, &height)
        AssertTrue(HasProp(candidate_box.gui, "sel"), "The selected preedit control was not added lazily.")
        AssertTrue(HasProp(candidate_box.gui, "post"), "The trailing preedit control was not added lazily.")
        AssertEqual(3, candidate_box.gui.num_candidates, "The calculated layout omitted new candidate rows.")
        AssertTrue(candidate_box.gui["L3"].Visible, "The last added candidate row is hidden.")
        candidate_box.gui.GetClientPos(, , &client_width, &client_height)
        AssertEqual(width, client_width, "The built client width differs from the calculated width.")
        AssertEqual(height, client_height, "The built client height differs from the calculated height.")
        candidate_box.Show(10, 10)
        candidate_box.gui.GetClientPos(, , &client_width, &client_height)
        AssertEqual(width, client_width, "The displayed client width differs from the calculated width.")
        AssertEqual(height, client_height, "The displayed client height differs from the calculated height.")
        candidate_box.Hide()
        AssertEqual(
            baseline + 1,
            CountProcessGuiWindows(),
            "A dynamic legacy update created an additional GUI window."
        )

        context.menu.candidates[1].text := "这是一个用于验证候选框宽度扩展的非常长的候选文本"
        candidate_box.Build(context, &expanded_width, &expanded_height)
        AssertTrue(expanded_width > width, "A longer candidate did not expand the calculated layout.")
        AssertEqual(height, expanded_height, "Changing candidate width unexpectedly changed the layout height.")

        context.menu.candidates := [context.menu.candidates[1]]
        context.menu.num_candidates := 1
        candidate_box.Build(context, &width, &height)
        AssertTrue(!candidate_box.gui["L2"].Visible, "A removed candidate label remained visible.")
        AssertTrue(!candidate_box.gui["C2"].Visible, "A removed candidate text remained visible.")
        AssertTrue(!candidate_box.gui["M2"].Visible, "A removed candidate comment remained visible.")
    } finally {
        candidate_box.Dispose()
    }
    AssertEqual(baseline, CountProcessGuiWindows(), "The dynamic layout test leaked its candidate window.")
}

TestLegacyGdiTextMeasurementParity(style) {
    local baseline := CountProcessGuiWindows()
    local candidate_box := LegacyCandidateBox(style)
    local native_gui := 0
    local width, height
    local cases := [
        {
            name: "Chinese text",
            font_opt: "s14 q5",
            font_face: "Microsoft YaHei UI",
            control_opt: "",
            text: "输入法"
        },
        {
            name: "empty text",
            font_opt: "s14 q5",
            font_face: "Microsoft YaHei UI",
            control_opt: "",
            text: ""
        },
        {
            name: "tab expansion",
            font_opt: "s14 q5",
            font_face: "Microsoft YaHei UI",
            control_opt: "",
            text: "A`tB"
        },
        {
            name: "accelerator prefix",
            font_opt: "s14 q5",
            font_face: "Segoe UI",
            control_opt: "Right",
            text: "A&B"
        },
        {
            name: "multiline text",
            font_opt: "s12 q5",
            font_face: "Segoe UI",
            control_opt: "",
            text: "line 1`nline 2"
        },
        {
            name: "italic overhang",
            font_opt: "italic s16 q5",
            font_face: "Times New Roman",
            control_opt: "",
            text: "f"
        },
        {
            name: "bordered text",
            font_opt: "s14 q5",
            font_face: "Microsoft YaHei UI",
            control_opt: "+Border",
            text: "边框"
        },
        {
            name: "font fallback",
            font_opt: "s14 q5",
            font_face: "Rabbit Missing Font",
            control_opt: "",
            text: "fallback 字体"
        },
        {
            name: "supplementary character",
            font_opt: "s14 q5",
            font_face: "Segoe UI Emoji",
            control_opt: "",
            text: "😀"
        }
    ]
    try {
        candidate_box.Build(CreateCandidateContext(), &width, &height)
        loop cases.Length {
            local test_case := cases[A_Index]
            native_gui := Gui("-DPIScale")
            try {
                native_gui.SetFont(test_case.font_opt, test_case.font_face)
                local native_control := native_gui.AddText(
                    "x0 y0 " . test_case.control_opt, test_case.text)
                local native_width, native_height
                native_control.GetPos(, , &native_width, &native_height)

                local hdc := DllCall("user32\GetDC", "Ptr", native_gui.Hwnd, "Ptr")
                if !hdc {
                    throw OSError(A_LastError, "GetDC failed for the native measurement oracle.")
                }
                try {
                    local measured := candidate_box.gui.MeasureText(
                        hdc, test_case.text, native_control)
                } finally {
                    DllCall("user32\ReleaseDC", "Ptr", native_gui.Hwnd, "Ptr", hdc, "Int")
                }
                AssertEqual(
                    native_width,
                    measured.w,
                    test_case.name . " width differs from AutoHotkey native autosizing."
                )
                AssertEqual(
                    native_height,
                    measured.h,
                    test_case.name . " height differs from AutoHotkey native autosizing."
                )
            } finally {
                native_gui.Destroy()
                native_gui := 0
            }
        }
    } finally {
        try {
            if native_gui {
                native_gui.Destroy()
            }
        } finally {
            candidate_box.Dispose()
        }
    }
    AssertEqual(baseline, CountProcessGuiWindows(), "The native measurement oracle leaked a GUI window.")
}

TestLegacyFakeGuiUniformRowBackgrounds() {
    local baseline := CountProcessGuiWindows()
    local fake_gui := Gui("-DPIScale")
    try {
        fake_gui.SetFont("s18 q5", "Microsoft YaHei UI")
        local label := fake_gui.AddText("x0 y0 Right", "1. ")
        fake_gui.SetFont("s10 q5", "Times New Roman")
        local candidate := fake_gui.AddText("x0 y0", "candidate")
        fake_gui.SetFont("s14 q5", "Microsoft YaHei UI")
        local comment := fake_gui.AddText("x0 y0", "comment")

        local label_width, label_text_height
        local candidate_width, candidate_text_height
        local comment_width, comment_text_height
        label.GetPos(, , &label_width, &label_text_height)
        candidate.GetPos(, , &candidate_width, &candidate_text_height)
        comment.GetPos(, , &comment_width, &comment_text_height)
        AssertTrue(
            label_text_height != candidate_text_height
                || candidate_text_height != comment_text_height,
            "The fake GUI must provide different natural text heights."
        )

        local presentation := {candidates: [{comment: "comment"}]}
        local metrics := {
            pre: 0,
            sel: 0,
            post: 0,
            rows: [{
                label: {w: label_width, h: label_text_height},
                candidate: {w: candidate_width, h: candidate_text_height},
                comment: {w: comment_width, h: comment_text_height}
            }]
        }
        local layout := RabbitLegacyCandidateLayout.Calculate(presentation, metrics, 6, 4, 0)
        local row := layout.rows[1]
        local expected_height := max(
            label_text_height, candidate_text_height, comment_text_height)
        AssertEqual(expected_height, row.label.h, "The fake label background did not fill the row.")
        AssertEqual(
            expected_height,
            row.candidate.h,
            "The fake candidate background did not fill the row."
        )
        AssertEqual(expected_height, row.comment.h, "The fake comment background did not fill the row.")

        label.Move(row.label.x, row.label.y, row.label.w, row.label.h)
        candidate.Move(row.candidate.x, row.candidate.y, row.candidate.w, row.candidate.h)
        comment.Move(row.comment.x, row.comment.y, row.comment.w, row.comment.h)
        local label_height, candidate_height, comment_height
        label.GetPos(, , , &label_height)
        candidate.GetPos(, , , &candidate_height)
        comment.GetPos(, , , &comment_height)
        AssertEqual(expected_height, label_height, "The fake label control retained a shorter background.")
        AssertEqual(
            expected_height,
            candidate_height,
            "The fake candidate control retained a shorter background."
        )
        AssertEqual(expected_height, comment_height, "The fake comment control retained a shorter background.")
    } finally {
        fake_gui.Destroy()
    }
    AssertEqual(baseline, CountProcessGuiWindows(), "The uniform fake GUI row test leaked a window.")
}

TestLegacyPureLayoutCalculation() {
    local presentation := {
        candidates: [
            { comment: "comment" },
            { comment: "" }
        ]
    }
    local metrics := {
        pre: {w: 10, h: 20},
        sel: {w: 20, h: 18},
        post: {w: 30, h: 16},
        rows: [
            {
                label: {w: 5, h: 10},
                candidate: {w: 50, h: 20},
                comment: {w: 10, h: 12}
            },
            {
                label: {w: 8, h: 11},
                candidate: {w: 40, h: 22},
                comment: {w: 8, h: 12}
            }
        ]
    }
    local layout := RabbitLegacyCandidateLayout.Calculate(presentation, metrics, 6, 4, 100)

    AssertEqual(112, layout.width, "The pure layout calculated the wrong overall width.")
    AssertEqual(78, layout.height, "The pure layout calculated the wrong overall height.")
    AssertEqual(6, layout.pre.x, "The preedit start position is incorrect.")
    AssertEqual(22, layout.sel.x, "The selected preedit position is incorrect.")
    AssertEqual(48, layout.post.x, "The trailing preedit position is incorrect.")
    AssertEqual(58, layout.post.w, "The trailing preedit did not absorb the minimum-width expansion.")
    AssertEqual(14, layout.rows[1].label.w, "The shared label column width is incorrect.")
    AssertEqual(76, layout.rows[1].candidate.w, "The shared candidate column width is incorrect.")
    AssertEqual(96, layout.rows[1].comment.x, "The comment column position is incorrect.")
    AssertEqual(20, layout.rows[1].label.h, "The first label did not fill the row height.")
    AssertEqual(20, layout.rows[1].candidate.h, "The first candidate did not fill the row height.")
    AssertEqual(20, layout.rows[1].comment.h, "The first comment did not fill the row height.")
    AssertEqual(28, layout.rows[1].label.y, "The first candidate row position is incorrect.")
    AssertEqual(22, layout.rows[2].label.h, "The second label did not fill the row height.")
    AssertEqual(22, layout.rows[2].candidate.h, "The second candidate did not fill the row height.")
    AssertEqual(22, layout.rows[2].comment.h, "The second comment did not fill the row height.")
    AssertEqual(52, layout.rows[2].label.y, "The second candidate row position is incorrect.")
    AssertTrue(layout.has_comment, "The pure layout did not retain its comment column.")

    presentation := {candidates: []}
    metrics := {pre: 0, sel: 0, post: 0, rows: []}
    layout := RabbitLegacyCandidateLayout.Calculate(presentation, metrics, 6, 4, 100)
    AssertEqual(112, layout.width, "The empty layout did not retain the configured minimum width.")
    AssertEqual(8, layout.height, "The empty layout did not retain its vertical margins.")
    AssertTrue(!layout.has_comment, "The empty layout retained a comment column.")

    presentation := {candidates: [{comment: ""}]}
    metrics := {
        pre: 0,
        sel: 0,
        post: 0,
        rows: [{
            label: {w: 5, h: 10},
            candidate: {w: 20, h: 15},
            comment: {w: 50, h: 12}
        }]
    }
    layout := RabbitLegacyCandidateLayout.Calculate(presentation, metrics, 6, 4, 0)
    AssertEqual(49, layout.width, "An empty comment incorrectly widened the candidate layout.")
    AssertEqual(27, layout.height, "The comment-free row height is incorrect.")
    AssertTrue(!layout.has_comment, "An empty comment created a visible comment column.")
}

TestModernFlowCandidateLayout(style) {
    local candidate_box := CandidateBox(style.With(Map(
        "layout_type", "flow",
        "candidate_spacing", 7,
        "align_type", "center"
    )))
    local presentation := RabbitCandidatePresentation(CreateCandidateContext(), "{}")
    local width, height
    presentation.flow_page_size := 2
    Loop 4 {
        presentation.candidates.Push({
            label: "",
            text: "预览候选" . A_Index,
            comment: A_Index = 1 ? "预览注释" : "",
            highlighted: false,
            preview: true
        })
    }
    try {
        candidate_box.BuildPresentation(presentation, &width, &height, 400)
        AssertTrue(width >= style.min_width, "The flow candidate layout ignored the minimum width.")
        AssertTrue(
            candidate_box.candidatesLayout.rows[3].y > candidate_box.candidatesLayout.rows[1].y,
            "A flow page did not advance to the next candidate row."
        )
        AssertEqual(
            candidate_box.candidatesLayout.rows[1].y,
            candidate_box.candidatesLayout.rows[2].y,
            "Candidates from the same flow page were split into separate rows."
        )
        AssertEqual(
            candidate_box.candidatesLayout.cands[1].x,
            candidate_box.candidatesLayout.cands[3].x,
            "The first candidate column was not aligned across flow pages."
        )
        AssertEqual(
            candidate_box.candidatesLayout.cands[2].x,
            candidate_box.candidatesLayout.cands[4].x,
            "The second candidate column was not aligned across flow pages."
        )
        AssertEqual(
            "",
            candidate_box.candidatesLayout.labels[3].text,
            "A preloaded flow candidate retained its selection label."
        )
        AssertTrue(
            candidate_box.candidateHighlights[1],
            "The selected current-page candidate lost its card highlight."
        )
        AssertTrue(
            !candidate_box.candidateHighlights[3],
            "A preloaded candidate received a highlight."
        )
    } finally {
        candidate_box.Dispose()
    }
}

TestBackendLifecycle(name, candidate_box, context, style) {
    local first_width, first_height, second_width, second_height
    local updated_width, updated_height, restored_width, restored_height
    try {
        candidate_box.Hide()
        candidate_box.Hide()
        candidate_box.Build(context, &first_width, &first_height)
        candidate_box.Build(context, &second_width, &second_height)

        AssertTrue(first_width > 0, name . " width must be positive.")
        AssertTrue(first_height > 0, name . " height must be positive.")
        AssertEqual(first_width, second_width, name . " width must be stable across repeated builds.")
        AssertEqual(first_height, second_height, name . " height must be stable across repeated builds.")
        AssertTrue(first_width >= style.min_width, name . " width must honor the configured minimum.")

        local updated_style := style.With(Map(
            "min_width", style.min_width + 40,
            "font_point", style.font_point + 2,
            "label_font_point", style.label_font_point + 2,
            "comment_font_point", style.comment_font_point + 2
        ))
        candidate_box.UpdateStyle(updated_style)
        candidate_box.UpdateStyle(updated_style)
        candidate_box.Build(context, &updated_width, &updated_height)
        AssertTrue(
            updated_width >= updated_style.min_width,
            name . " width must honor an updated style snapshot."
        )
        AssertTrue(updated_height > first_height, name . " height did not reflect the updated fonts.")

        candidate_box.UpdateStyle(style)
        candidate_box.Build(context, &restored_width, &restored_height)
        AssertEqual(first_width, restored_width, name . " width must restore with the original style snapshot.")
        AssertEqual(first_height, restored_height, name . " height must restore with the original style snapshot.")

        candidate_box.Show(10, 10)
        candidate_box.Show(10, 10)
        candidate_box.Hide()
        candidate_box.Hide()
        FileAppend(Format("CHARACTERIZATION: {} {}x{}`n", name, first_width, first_height), "*")
    } finally {
        candidate_box.Dispose()
    }

    candidate_box.Hide()
    candidate_box.Dispose()
    AssertThrows(
        BuildCandidate.Bind(candidate_box, context),
        name . " Build() must fail after disposal.")
    AssertThrows(
        candidate_box.Show.Bind(candidate_box, 10, 10),
        name . " Show() must fail after disposal.")
    AssertThrows(
        candidate_box.UpdateStyle.Bind(candidate_box, style),
        name . " UpdateStyle() must fail after disposal.")
}

BuildCandidate(candidate_box, context) {
    local width, height
    candidate_box.Build(context, &width, &height)
}

TestPartialConstructionCleanup(style) {
    RabbitFailingModernCandidateBox.dispose_calls := 0
    AssertThrows(
        (*) => RabbitFailingModernCandidateBox(style, ThrowDirect2D.Bind()),
        "Modern construction failure must be rethrown.")
    AssertEqual(1, RabbitFailingModernCandidateBox.dispose_calls,
        "Modern construction failure must dispose partial resources once.")

    RabbitFailingLegacyCandidateBox.dispose_calls := 0
    AssertThrows(
        (*) => RabbitFailingLegacyCandidateBox({}),
        "Legacy construction failure must be rethrown.")
    AssertEqual(1, RabbitFailingLegacyCandidateBox.dispose_calls,
        "Legacy construction failure must dispose partial resources once.")
}

ThrowDirect2D(hwnd) {
    throw Error("Injected Direct2D construction failure.")
}

class RabbitFakeDirect2D {
    GetDesktopDpiScale() {
        return 1
    }
}

class RabbitFailingModernCandidateBox extends CandidateBox {
    static dispose_calls := 0

    Dispose() {
        if !this.disposed {
            RabbitFailingModernCandidateBox.dispose_calls++
        }
        super.Dispose()
    }
}

class RabbitFailingLegacyCandidateBox extends LegacyCandidateBox {
    static dispose_calls := 0

    Dispose() {
        if !this.disposed {
            RabbitFailingLegacyCandidateBox.dispose_calls++
        }
        super.Dispose()
    }
}
