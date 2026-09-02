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

#Include RabbitCommon.ahk
#Include RabbitWindowTheme.ahk

class RabbitAboutPage {
    static PAGE_HEIGHT := 456
    static OPEN_SOURCE_PROJECTS := [
        {
            name: "AutoHotkey v2",
            license: "GPL-2.0",
            project_url: "https://github.com/AutoHotkey/AutoHotkey",
            license_url: "https://github.com/AutoHotkey/AutoHotkey/blob/master/license.txt"
        },
        {
            name: "librime",
            license: "BSD 3-Clause",
            project_url: "https://github.com/rime/librime",
            license_url: "https://github.com/rime/librime/blob/master/LICENSE"
        },
        {
            name: "librime-ahk",
            license: "GPL-3.0",
            project_url: "https://github.com/rimeinn/librime-ahk",
            license_url: "https://github.com/rimeinn/librime-ahk/blob/master/LICENSE"
        },
        {
            name: "AHK-Direct2D",
            license: "MIT",
            project_url: "https://github.com/rawbx/AHK-Direct2D",
            license_url: "https://github.com/rimeinn/rabbit/blob/master/Lib/Direct2D/LICENSE"
        },
        {
            name: "OpenCC",
            license: "Apache-2.0",
            project_url: "https://github.com/BYVoid/OpenCC",
            license_url: "https://github.com/BYVoid/OpenCC/blob/master/LICENSE"
        },
        {
            name: "GetCaretPos",
            license: "MIT",
            project_url: "https://github.com/Descolada/AHK-v2-libraries",
            license_url: "https://github.com/Descolada/AHK-v2-libraries/blob/main/LICENSE"
        },
        {
            name: "GetCaretPosEx",
            license: "MIT",
            project_url: "https://github.com/Tebayaki/AutoHotkeyScripts/tree/main/lib/GetCaretPosEx",
            license_url: "https://github.com/rimeinn/rabbit/blob/master/Lib/GetCaretPosEx/LICENSE.txt"
        },
        {
            name: "东风破（plum）",
            license: "LGPL-3.0",
            project_url: "https://github.com/rime/plum",
            license_url: "https://github.com/rime/plum/blob/master/LICENSE"
        },
        {
            name: "小狼毫（weasel）",
            license: "GPL-3.0",
            project_url: "https://github.com/rime/weasel",
            license_url: "https://github.com/rime/weasel/blob/master/LICENSE.txt"
        }
    ]

    __New(owner, x, y, width, show_message_callback := 0) {
        this.owner := owner
        this.x := x
        this.y := y
        this.width := width
        this.show_message_callback := show_message_callback
        this.CreateControls()
    }

    CreateControls() {
        local index, inner_x, license_x, project, project_link, license_link, row_y
        inner_x := this.x + 24
        license_x := this.x + this.width - 288

        this.about_group := this.owner.AddGroupBox(
            Format("x{} y{} w{} h166 Hidden", this.x, this.y, this.width),
            "关于玉兔毫"
        )
        this.owner.SetFont("s14 w600")
        this.about_name := this.owner.AddText(
            Format("x{} y{} w{} h28 Hidden", inner_x, this.y + 24, this.width - 48),
            "玉兔毫"
        )
        this.owner.SetFont("s10 w400")
        this.about_version := this.owner.AddText(
            Format("x{} y{} w{} h22 Hidden", inner_x, this.y + 56, this.width - 48),
            "版本：" . RABBIT_VERSION . (A_IsCompiled ? "（已编译）" : "（源代码运行）")
        )
        this.about_description := this.owner.AddText(
            Format("x{} y{} w{} h24 Hidden", inner_x, this.y + 88, this.width - 48),
            "由 AutoHotkey 实现的 Rime 输入法引擎 Windows 前端。"
        )
        this.about_project_link := this.AddLink(
            inner_x,
            this.y + 122,
            160,
            '<a href="https://github.com/rimeinn/rabbit">访问项目主页</a>'
        )
        this.about_license_link := this.AddLink(
            inner_x + 176,
            this.y + 122,
            160,
            '<a href="https://www.gnu.org/licenses/gpl-3.0.html">GPL-3.0 许可证</a>'
        )
        this.about_copyright := this.owner.AddText(
            Format("x{} y{} w{} h18 Hidden cGray", inner_x, this.y + 146, this.width - 48),
            "Copyright © 2023 - 2026 Xuesong Peng"
        )

        this.about_open_source_group := this.owner.AddGroupBox(
            Format("x{} y{} w{} h278 Hidden", this.x, this.y + 178, this.width),
            "使用的开源项目"
        )
        this.about_open_source_description := this.owner.AddText(
            Format("x{} y{} w{} h22 Hidden cGray", inner_x, this.y + 202, this.width - 48),
            "点击项目名或许可证查看详情。东风破安装的词库和方案可能有独立许可证。"
        )
        this.about_open_source_project_links := []
        this.about_open_source_license_links := []
        for index, project in RabbitAboutPage.OPEN_SOURCE_PROJECTS {
            row_y := this.y + 228 + (index - 1) * 24
            project_link := this.AddLink(
                inner_x,
                row_y,
                240,
                Format('<a href="{}">{}</a>', project.project_url, project.name)
            )
            license_link := this.AddLink(
                license_x,
                row_y,
                240,
                Format('<a href="{}">{}</a>', project.license_url, project.license)
            )
            this.about_open_source_project_links.Push(project_link)
            this.about_open_source_license_links.Push(license_link)
        }
    }

    AddLink(x, y, width, value) {
        local link := this.owner.AddLink(Format("x{} y{} w{} h20 Hidden", x, y, width), value)
        link.OnEvent("Click", this.OnLinkClick.Bind(this))
        return link
    }

    RegisterTheme(theme) {
        theme.RegisterMuted(this.about_copyright, this.about_open_source_description)
        theme.RegisterLink(this.about_project_link, this.about_license_link)
        for link in this.about_open_source_project_links {
            theme.RegisterLink(link)
        }
        for link in this.about_open_source_license_links {
            theme.RegisterLink(link)
        }
    }

    SetVisible(visible) {
        for control in [
            this.about_group,
            this.about_name,
            this.about_version,
            this.about_description,
            this.about_project_link,
            this.about_license_link,
            this.about_copyright,
            this.about_open_source_group,
            this.about_open_source_description,
        ] {
            control.Visible := visible
        }
        for link in this.about_open_source_project_links {
            link.Visible := visible
        }
        for link in this.about_open_source_license_links {
            link.Visible := visible
        }
    }

    OnLinkClick(ctrl, index, link) {
        return this.OpenLink(link)
    }

    OpenLink(link) {
        try {
            Run(link)
            return true
        } catch as err {
            if this.show_message_callback {
                this.show_message_callback.Call(
                    "无法打开链接：`n" . err.Message,
                    "【玉兔毫】",
                    "Ok Iconx"
                )
            } else {
                MsgBox("无法打开链接：`n" . err.Message, "【玉兔毫】", "Ok Iconx")
            }
            return false
        }
    }
}

class RabbitAboutDialog extends Gui {
    static WINDOW_WIDTH := 620
    static WINDOW_HEIGHT := RabbitAboutPage.PAGE_HEIGHT + 40

    __New() {
        local dark_mode := !!RabbitWindowThemeController.Prepare()
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】关于", this)
        this.disposed := false
        this.SetFont("s10" . (dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""), "Microsoft YaHei UI")
        if dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.MarginX := 20
        this.MarginY := 20
        this.about_page := RabbitAboutPage(this, 20, 20, RabbitAboutDialog.WINDOW_WIDTH - 40)
        this.about_page.SetVisible(true)
        this.window_theme := RabbitWindowThemeController(this)
        this.about_page.RegisterTheme(this.window_theme)
        this.OnEvent("Close", this.OnClose.Bind(this))
        this.OnEvent("Escape", this.OnClose.Bind(this))
        this.window_theme.Register()
    }

    Show(options := "") {
        super.Show(Trim(options . Format(
            " w{} h{}",
            RabbitAboutDialog.WINDOW_WIDTH,
            RabbitAboutDialog.WINDOW_HEIGHT
        )))
    }

    OnClose(*) {
        this.Dispose()
        return true
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        this.window_theme.Dispose()
        this.Destroy()
    }
}
