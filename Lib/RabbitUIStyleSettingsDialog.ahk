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

#Include <RabbitCommon>
#Include <RabbitCandidatePreview>
#Include <RabbitUIStyleSettings>

class UIStyleSettingsDialog extends Gui {
    __New(settings, old_windows := RabbitIsOldWindows(), preview_factory := CandidatePreview) {
        local h, group_x, group_y, group_width, group_height
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】界面风格设定", this)
        this.settings := settings
        this.loaded := false
        this.accepted := false
        this.disposed := false

        this.preset := []

        ; Layout
        this.MarginX := 15
        this.MarginY := 15
        this.color_schemes_width := 220
        this.preview_width := 220
        this.preview_offset := 20
        this.AddText("x10 y10", "主题：").GetPos(, , , &h)
        this.title_height := h
        this.color_schemes := this.AddListBox(Format("Section r15 w{} -Multi", this.color_schemes_width))
        this.color_schemes.OnEvent("Change", (ctrl, info) => this.OnColorSchemeSelChange())
        this.color_schemes.GetPos(, , , &h)
        this.list_height := h
        this.preview_group := this.AddGroupBox(Format("x+{} yp-8 w{} h{}", this.preview_offset, this.preview_width, this.list_height + 8), "预览")
        ; 0xE(SS_BITMAP) or 0x4E (Bitmap and Resizable, but text is unclear)
        this.preview_img := this.AddPicture("xp+50 yp+50 w180 h180 0xE BackgroundWhite")
        if old_windows {
            this.preview_img.Visible := false
            this.preview_group.GetPos(&group_x, &group_y, &group_width, &group_height)
            this.AddText(Format("x{} y{} w{} h{} Center +0x200", group_x + 10, group_y + 20,
                group_width - 20, group_height - 30), "旧版 Windows 暂不支持预览")
            this.candidate_box := 0
        } else {
            this.candidate_box := preview_factory(this.preview_img)
        }

        this.set_font := this.AddButton(Format("xs ys+{} w120", this.list_height + this.MarginY), "设置字体")
        this.set_font.Opt("+Disabled") ; TODO: implement font setting
        this.ok := this.AddButton("x+180 w90", "中")
        this.ok.OnEvent("Click", (*) => this.OnOK())

        try {
            this.Populate()
        } catch {
            this.Dispose()
            throw
        }
    }

    Populate() {
        local i, info
        if !this.settings {
            return
        }
        local active := this.settings.GetActiveColorScheme()
        local active_index := 0
        this.preset := this.settings.GetPresetColorSchemes()
        local names := []
        for i, info in this.preset {
            names.Push(info.name)
            if info.color_scheme_id = active {
                active_index := i
            }
        }
        this.color_schemes.Opt("-Redraw")
        this.color_schemes.Add(names)
        this.color_schemes.Opt("+Redraw")
        if active_index > 0 {
            this.color_schemes.Choose(active_index)
            this.Preview(active_index)
        }
        this.loaded := true
    }

    OnColorSchemeSelChange() {
        local index := this.color_schemes.Value
        if index > 0 && index <= this.preset.Length {
            this.settings.SelectColorScheme(this.preset[index].color_scheme_id)
            this.Preview(index)
        }
        return 0
    }

    Preview(index) {
        local box_width, box_height
        if !this.candidate_box || index <= 0 || index > this.preset.Length {
            return
        }
        local info := this.preset[index]
        this.candidate_box.Build(info.style, &box_width, &box_height)
        box_width := box_width / this.candidate_box.dpiScale
        box_height := box_height / this.candidate_box.dpiScale
        local box_x := this.MarginX + this.color_schemes_width + this.preview_offset + Round((this.preview_width - box_width) / 2)
        local box_y := this.MarginY + this.title_height + 8 + Round((this.list_height - box_height) / 2)
        this.preview_img.Move(box_x, box_y, box_width, box_height)
        this.candidate_box.Render(["输入法", "输入", "数", "书", "输"], 1)
    }

    OnOK() {
        this.Exit(true)
    }

    Exit(yes) {
        this.accepted := yes
        this.Dispose()
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try {
            if this.candidate_box {
                this.candidate_box.Dispose()
                this.candidate_box := 0
            }
        } finally {
            try this.Destroy()
        }
    }
}
