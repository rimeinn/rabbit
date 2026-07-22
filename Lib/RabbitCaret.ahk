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

/*
 * original code can be found in https://github.com/Descolada/AHK-v2-libraries
 * with MIT License
 */

#Include <RabbitConfig>
#Include <GetCaretPosEx\GetCaretPosEx>

/**
 * Gets the position of the caret with UIA, Acc or CaretGetPos.
 * Credit: plankoe (https://www.reddit.com/r/AutoHotkey/comments/ysuawq/get_the_caret_location_in_any_program/)
 * @param X Value is set to the screen X-coordinate of the caret
 * @param Y Value is set to the screen Y-coordinate of the caret
 * @param W Value is set to the width of the caret
 * @param H Value is set to the height of the caret
 */
GetCaretPos(&caret_x?, &caret_y?, &caret_w?, &caret_h?) {
    caret_x := 0
    caret_y := 0
    caret_w := 0
    caret_h := 0

    if GetCaretPosEx(&left, &top, &right, &bottom, RabbitConfig.use_caret_hook) {
        if !IsSet(left) || !IsSet(top) || !IsSet(right) || !IsSet(bottom)
            return GetBuiltInCaretPos(&caret_x, &caret_y, &caret_w, &caret_h)

        local max_int := 2147483647
        local max_uint := 4294967295
        caret_x := left
        caret_y := top
        caret_w := right - left
        caret_h := bottom - top
        if caret_x > max_int
            caret_x := caret_x - max_uint - 1
        if caret_y > max_int
            caret_y := caret_y - max_uint - 1

        return true
    }

    return GetBuiltInCaretPos(&caret_x, &caret_y, &caret_w, &caret_h)
}

GetBuiltInCaretPos(&x, &y, &w, &h) {
    local saved_caret := A_CoordModeCaret
    CoordMode("Caret", "Screen")
    local found := CaretGetPos(&x, &y)
    CoordMode("Caret", saved_caret)
    if found {
        w := 4
        h := 20
    } else {
        x := 0
        y := 0
    }
    return found
}
