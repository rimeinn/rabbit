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
    "legacy measurement window cleanup",
    TestLegacyMeasurementWindowCleanup.Bind(candidate_style, candidate_context)
)
RunTest(
    "modern candidate lifecycle",
    TestBackendLifecycle.Bind("modern", CandidateBox(candidate_style), candidate_context, candidate_style)
)
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

RunTest(name, test) {
    test.Call()
    FileAppend("PASS: " . name . "`n", "*")
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

TestLegacyMeasurementWindowCleanup(style, context) {
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

        Loop 3 {
            candidate_box.Build(context, &width, &height)
        }
        AssertEqual(
            3,
            destroy_calls.value,
            "Legacy updates did not explicitly destroy their measurement windows."
        )
        AssertEqual(
            built_count,
            CountProcessGuiWindows(),
            "Legacy measurement windows remained after repeated updates."
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

        local updated_style := style.With(Map("min_width", style.min_width + 40))
        candidate_box.UpdateStyle(updated_style)
        candidate_box.UpdateStyle(updated_style)
        candidate_box.Build(context, &updated_width, &updated_height)
        AssertTrue(
            updated_width >= updated_style.min_width,
            name . " width must honor an updated style snapshot."
        )

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

AssertTrue(condition, message) {
    if !condition {
        throw Error(message)
    }
}

AssertEqual(expected, actual, message) {
    if expected != actual {
        throw Error(Format("{} Expected: {}. Actual: {}.", message, expected, actual))
    }
}

AssertThrows(callback, message) {
    try {
        callback.Call()
    } catch {
        return
    }
    throw Error(message)
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
