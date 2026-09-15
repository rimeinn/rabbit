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
 */

#Include RabbitI18n.ahk

class RabbitMenuSettings {
    static PAGE_SIZE_PATH := "menu/page_size"
    static ALTERNATIVE_SELECT_LABELS_PATH := "menu/alternative_select_labels"
    static ALTERNATIVE_SELECT_KEYS_PATH := "menu/alternative_select_keys"
    static PAGE_DOWN_CYCLE_PATH := "menu/page_down_cycle"
    static ALTERNATIVE_SELECT_KEYS_DEFAULT := ""
    static PAGE_DOWN_CYCLE_DEFAULT := false

    static ValidateAlternativeSelectKeys(value) {
        local char, code, seen := Map()
        value := String(value)
        Loop Parse value {
            char := A_LoopField
            code := Ord(char)
            if code < 0x20 || code > 0x7E {
                throw ValueError(RabbitI18n.Text("menu.alternative_select_keys_invalid"))
            }
            if seen.Has(char) {
                throw ValueError(RabbitI18n.Text("menu.alternative_select_keys_duplicate"))
            }
            seen[char] := true
        }
        return value
    }
}
