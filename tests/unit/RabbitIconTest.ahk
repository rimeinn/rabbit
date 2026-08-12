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
#Include ..\..\Lib\RabbitIcon.ahk

RunTest("status icon selects the closest ICO size without upscaling", TestIconPreferredSize.Bind())
RunTest("status icon creates a Direct2D bitmap from the selected ICO frame", TestIconBitmapCreation.Bind())

TestIconPreferredSize() {
    local icon_path := A_ScriptDir . "\..\..\Lib\rabbit.ico"
    local cases := Map(16, 16, 17, 24, 19, 24, 24, 24, 25, 32, 32, 32, 33, 48, 48, 48, 49, 256)
    local selected_size

    for target_size, expected_size in cases {
        selected_size := RabbitIcon.GetPreferredSize(icon_path, target_size)
        AssertTrue(!!selected_size, "The bundled icon did not provide a usable ICO frame.")
        AssertEqual(expected_size, selected_size.width, "The icon loader selected the wrong ICO frame.")
        AssertEqual(expected_size, selected_size.height, "The icon loader selected a non-square ICO frame.")
    }
}

TestIconBitmapCreation() {
    local icon_path := A_ScriptDir . "\..\..\Lib\rabbit.ico"
    local d2d := Direct2D()
    local bitmap := 0

    try {
        ; A WIC target is a memory bitmap; it does not create or show a GUI window.
        d2d.SetRenderTarget("wic", 24, 24)
        bitmap := RabbitIcon.GetSavedOrCreateBitmap(d2d, icon_path, 19)
        AssertTrue(!!bitmap, "The selected ICO frame did not become a Direct2D bitmap.")
    } finally {
        d2d := 0
    }
}
