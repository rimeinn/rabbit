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

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\..\Lib\RabbitSettingsWindow.ahk
#Include ..\support\TestCommon.ahk

RunTest("settings window reaches first show before loading config", TestSettingsStartupFirstShow.Bind())
ExitApp()

TestSettingsStartupFirstShow() {
    static FIRST_SHOW_GOLDEN_MS := 750
    static INITIAL_CONTROL_GOLDEN := 40
    local calls := []
    local control_count := 0
    local elapsed, start
    local window := 0
    RabbitSettingsStartupPreview.render_count := 0
    start := A_TickCount
    window := RabbitSettingsWindow(
        RabbitSettingsStartupWorkflow(calls),
        false,
        RabbitSettingsStartupPreview,
        0,
        "",
        false,
        RabbitWindowThemeController,
        true
    )
    try {
        for hwnd, control in window {
            control_count += 1
        }
        window.Show("Center")
        elapsed := A_TickCount - start
        AssertTrue(
            elapsed <= FIRST_SHOW_GOLDEN_MS,
            Format("First show took {} ms; golden is {} ms.", elapsed, FIRST_SHOW_GOLDEN_MS)
        )
        AssertTrue(
            control_count <= INITIAL_CONTROL_GOLDEN,
            Format("First show created {} controls; golden is {}.", control_count, INITIAL_CONTROL_GOLDEN)
        )
        AssertEqual(0, calls.Length, "The settings window loaded config before its first show returned.")
        WaitForSettingsStartup(calls)
        AssertEqual("load_start,load_end,read_labels", JoinSettingsStartupCalls(calls),
            "The deferred settings load ran in the wrong order.")
        AssertEqual(1, RabbitSettingsStartupPreview.render_count,
            "The deferred startup rendered the preview more than once.")
        ExerciseLazySettingsPages(window)
        FileAppend Format("METRIC: first_show_ms={} initial_controls={}`n", elapsed, control_count), "*"
    } finally {
        if window {
            window.Dispose()
        }
    }
}

ExerciseLazySettingsPages(window) {
    for index in [2, 3, 4, 5, 6, 7, 1] {
        AssertTrue(window.SelectPage(index), "The GUI smoke test could not open page " . index . ".")
        Sleep(20)
    }
    window.appearance_tabs.Choose(2)
    window.OnAppearanceTabChanged()
    AssertTrue(window.appearance_font_group.Visible,
        "The GUI smoke test did not show the lazy typesetting controls.")
    Sleep(20)
}

WaitForSettingsStartup(calls) {
    local deadline := A_TickCount + 2000
    while calls.Length < 3 && A_TickCount < deadline {
        Sleep(20)
    }
    AssertEqual(3, calls.Length, "The deferred settings load did not finish before its timeout.")
}

JoinSettingsStartupCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitSettingsStartupWorkflow {
    __New(calls) {
        this.calls := calls
    }

    CreateUIStyleSettings() {
        this.calls.Push("load_start")
        Sleep(250)
        this.calls.Push("load_end")
        return RabbitSettingsStartupStyleSettings()
    }

    ReadCandidateLabels() {
        this.calls.Push("read_labels")
        return ["1", "2", "3", "4", "5"]
    }
}

class RabbitSettingsStartupStyleSettings {
    GetActiveColorScheme() {
        return "startup"
    }

    GetActiveColorSchemeDark() {
        return ""
    }

    GetCurrentStyle() {
        return RabbitUIStyleSnapshot()
    }

    GetPresetColorSchemes() {
        return [RabbitColorScheme.CreateDefault("startup", "Startup")]
    }

    Dispose() {
    }
}

class RabbitSettingsStartupPreview {
    static render_count := 0

    __New(owner) {
    }

    Render(style, select_labels := 0) {
        RabbitSettingsStartupPreview.render_count += 1
        return true
    }

    Hide() {
    }

    Dispose() {
    }
}
