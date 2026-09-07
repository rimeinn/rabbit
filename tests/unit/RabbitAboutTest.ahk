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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitAbout.ahk
#Include ..\..\Lib\RabbitI18n.ahk

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

RunTest("localized about page grows for wrapped text", TestLocalizedAboutLayout.Bind())

TestLocalizedAboutLayout() {
    local directory := A_LineFile . "\..\..\..\locales", dialog := 0
    local description_y, description_height, first_row_y, normal_height
    try {
        RabbitI18n.Initialize(directory, "en-US")
        dialog := RabbitAboutDialog()
        AssertEqual("About Rabbit", dialog.Title, "About title did not use the active language.")
        normal_height := dialog.about_page.height
        dialog.Dispose()
        RabbitI18n.messages["about.credits_description"] :=
            RabbitI18n.Text("about.credits_description") . "`nExtra translated line.`nAnother translated line."
        dialog := RabbitAboutDialog()
        AssertTrue(dialog.about_page.height > normal_height, "Wrapped text did not grow the page.")
        dialog.about_page.about_open_source_description.GetPos(, &description_y, , &description_height)
        dialog.about_page.about_open_source_project_links[1].GetPos(, &first_row_y)
        AssertTrue(first_row_y >= description_y + description_height, "Project links overlap translated text.")
    } finally {
        if dialog {
            dialog.Dispose()
        }
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}
