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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitAbout.ahk

RunTest("standalone about dialog uses the shared about page", TestStandaloneAboutDialogUsesSharedPage.Bind())

TestStandaloneAboutDialogUsesSharedPage() {
    local dialog := RabbitAboutDialog()
    try {
        AssertEqual(
            "RabbitAboutPage",
            Type(dialog.about_page),
            "The standalone about dialog did not use the shared about page."
        )
        AssertTrue(dialog.about_page.about_group.Visible,
            "The standalone about dialog did not show the shared about page.")
        AssertEqual(
            RabbitAboutPage.OPEN_SOURCE_PROJECTS.Length,
            dialog.about_page.about_open_source_project_links.Length,
            "The standalone about dialog did not show every open source project.")
    } finally {
        dialog.Dispose()
    }
}
