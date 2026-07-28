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

if A_Args.Length {
    switch A_Args[1] {
        case "factory-old-windows":
            RunTest("old Windows factory selection", TestOldWindowsFactorySelection.Bind())
        case "factory-configured-legacy":
            RunTest("configured legacy factory selection", TestConfiguredLegacyFactorySelection.Bind())
        case "factory-modern":
            RunTest("modern factory selection", TestModernFactorySelection.Bind())
        case "visual-modern":
            ShowVisualCandidate(CandidateBox(), candidate_context)
        case "visual-legacy":
            ShowVisualCandidate(LegacyCandidateBox(), candidate_context)
        default:
            throw Error("Unknown test mode: " . A_Args[1])
    }
    ExitApp()
}

RunTest("old Windows factory selection", TestOldWindowsFactorySelection.Bind())
RunTest("configured legacy factory selection", TestConfiguredLegacyFactorySelection.Bind())
RunTest("modern factory selection", TestModernFactorySelection.Bind())
RunTest("modern candidate lifecycle", TestBackendLifecycle.Bind("modern", CandidateBox(), candidate_context))
RunTest("legacy candidate lifecycle", TestBackendLifecycle.Bind("legacy", LegacyCandidateBox(), candidate_context))
RunTest("partial construction cleanup", TestPartialConstructionCleanup.Bind())

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

TestOldWindowsFactorySelection() {
    TestCandidateFactorySelection(true, false, "Old Windows")
}

TestConfiguredLegacyFactorySelection() {
    TestCandidateFactorySelection(false, true, "The legacy setting")
}

TestModernFactorySelection() {
    TestCandidateFactorySelection(false, false, "The modern path")
}

TestCandidateFactorySelection(is_old_windows, use_legacy_candidate_box, description) {
    local modern_count := { value: 0 }
    local legacy_count := { value: 0 }
    local direct2d_count := { value: 0 }
    local modern_constructor := CreateModernCandidate.Bind(modern_count, direct2d_count)
    local legacy_constructor := CreateLegacyCandidate.Bind(legacy_count)
    local is_old_windows_probe := (*) => is_old_windows
    local factory := RabbitCandidateBoxFactory(
        UIStyle, is_old_windows_probe, modern_constructor, legacy_constructor)
    local candidate_box := factory.Create(use_legacy_candidate_box)

    local expected_modern := (is_old_windows || use_legacy_candidate_box) ? 0 : 1
    local expected_legacy := expected_modern ? 0 : 1
    AssertEqual(expected_modern, modern_count.value, description . " selected the wrong modern backend count.")
    AssertEqual(expected_legacy, legacy_count.value, description . " selected the wrong legacy backend count.")
    AssertEqual(expected_modern, direct2d_count.value, description . " selected the wrong Direct2D count.")
    candidate_box.Dispose()
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

TestBackendLifecycle(name, candidate_box, context) {
    local first_width, first_height, second_width, second_height
    try {
        candidate_box.Hide()
        candidate_box.Hide()
        candidate_box.Build(context, &first_width, &first_height)
        candidate_box.Build(context, &second_width, &second_height)

        AssertTrue(first_width > 0, name . " width must be positive.")
        AssertTrue(first_height > 0, name . " height must be positive.")
        AssertEqual(first_width, second_width, name . " width must be stable across repeated builds.")
        AssertEqual(first_height, second_height, name . " height must be stable across repeated builds.")
        AssertTrue(first_width >= UIStyle.min_width, name . " width must honor the configured minimum.")

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
        candidate_box.UpdateStyle.Bind(candidate_box, UIStyle),
        name . " UpdateStyle() must fail after disposal.")
}

BuildCandidate(candidate_box, context) {
    local width, height
    candidate_box.Build(context, &width, &height)
}

TestPartialConstructionCleanup() {
    RabbitFailingModernCandidateBox.dispose_calls := 0
    AssertThrows(
        (*) => RabbitFailingModernCandidateBox(UIStyle, ThrowDirect2D.Bind()),
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
