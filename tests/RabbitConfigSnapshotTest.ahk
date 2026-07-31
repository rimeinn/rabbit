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

#Include <RabbitConfigSnapshot>

RunTest("config snapshot collection boundaries", TestConfigSnapshotCollections.Bind())
RunTest("caret hook defaults to disabled", TestCaretHookDefaults.Bind())

TestConfigSnapshotCollections() {
    local process_modes := Map("code.exe", true)
    local schema_icons := Map("rabbit", "rabbit.ico")
    local values := Map(
        "suspend_hotkey", "Control+Alt+space",
        "preset_process_ascii", process_modes,
        "schema_icon", schema_icons
    )
    local config := RabbitConfigSnapshot(values)

    process_modes["code.exe"] := false
    schema_icons["rabbit"] := "mutated.ico"
    values["suspend_hotkey"] := "Shift"
    AssertEqual(
        "Control+Alt+space",
        config.suspend_hotkey,
        "The config snapshot retained its scalar source."
    )
    AssertTrue(
        config.TryGetPresetProcessAscii("code.exe", &ascii_mode) && ascii_mode,
        "The config snapshot retained its process-mode Map."
    )
    AssertTrue(
        config.TryGetSchemaIcon("rabbit", &icon_path) && icon_path = "rabbit.ico",
        "The config snapshot retained its schema-icon Map."
    )

    local returned_modes := config.GetPresetProcessAscii()
    returned_modes["code.exe"] := false
    AssertTrue(
        config.TryGetPresetProcessAscii("code.exe", &ascii_mode) && ascii_mode,
        "The config snapshot exposed its process-mode Map."
    )
}

TestCaretHookDefaults() {
    local default_config := RabbitConfigSnapshot()
    local enabled_config := RabbitConfigSnapshot(Map("use_caret_hook", true))

    AssertTrue(
        !default_config.use_caret_hook,
        "The caret hook was enabled without an explicit setting."
    )
    AssertTrue(
        enabled_config.use_caret_hook,
        "An explicit caret-hook opt-in was not preserved."
    )
}
