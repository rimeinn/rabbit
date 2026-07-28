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
#Include <RabbitInput>

RunTest("input hotkey ownership", TestInputHotkeyOwnership.Bind())

TestInputHotkeyOwnership() {
    local input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(),
        {},
        {}
    )
    input.RegisterHotKeys()
    AssertTrue(input.registered_hotkeys.Length > 0, "The input owner did not record its hotkeys.")
    input.Dispose()
    input.Dispose()
    Persistent(false)
    AssertEqual(0, input.registered_hotkeys.Length, "The input owner did not release its hotkeys.")
}
