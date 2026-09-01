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

#Include RabbitColorScheme.ahk
#Include RabbitDialogPlacement.ahk
#Include RabbitWindowTheme.ahk

class RabbitColorSchemeDialog extends Gui {
    __New(
        owner,
        color_scheme,
        mode := "edit",
        preview := 0,
        select_labels := 0,
        id_validator := 0,
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local factory, field, index, initial_dark_mode := false, x, y
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        super.__New(
            "+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox",
            mode = "new" ? "新建配色方案" : mode = "copy" ? "复制配色方案" :
                mode = "view" ? "查看配色方案" : "编辑配色方案",
            this
        )
        this.owner_window := owner
        this.color_scheme := color_scheme
        this.mode := mode
        this.preview := preview
        this.select_labels := select_labels is Array ? select_labels.Clone() : []
        this.id_validator := id_validator
        this.colors := color_scheme.GetEditableColors()
        this.color_controls := Map()
        this.result := 0
        this.disposed := false
        this.preview_attached := false
        this.MarginX := 18
        this.MarginY := 18
        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )

        this.AddText("x20 y24 w72 h22", "方案名称：")
        this.name_edit := this.AddEdit("x94 y20 w208 r1 -Multi", color_scheme.name)
        this.AddText("x326 y24 w72 h22", "方案标识：")
        this.id_edit := this.AddEdit("x400 y20 w220 r1 -Multi", color_scheme.color_scheme_id)
        this.id_edit.Enabled := mode = "new" || mode = "copy"
        this.AddText("x20 y62 w72 h22", "作者：")
        this.author_edit := this.AddEdit("x94 y58 w526 r1 -Multi", color_scheme.author)

        this.window_group := this.AddGroupBox("x16 y98 w296 h276", "窗口与编码")
        this.candidate_group := this.AddGroupBox("x320 y98 w304 h352", "候选项")
        for index, field in RabbitColorScheme.EDITABLE_COLOR_FIELDS {
            if index <= 6 {
                x := 28
                y := 126 + (index - 1) * 38
            } else {
                x := 332
                y := 126 + (index - 7) * 38
            }
            this.AddColorControl(field, x, y)
        }

        this.status := this.AddText("x20 y458 w600 h24 cRed", "")
        if mode = "view" {
            this.close_button := this.AddButton("x532 y490 w88 h32 Default", "关闭")
            this.close_button.OnEvent("Click", (*) => this.Dispose())
            this.SetEditable(false)
        } else {
            this.save_button := this.AddButton("x436 y490 w88 h32 Default", "确定")
            this.save_button.OnEvent("Click", (*) => this.SaveScheme())
            this.cancel_button := this.AddButton("x532 y490 w88 h32", "取消")
            this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        }
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        factory := theme_factory
        this.window_theme := factory(this, dark_mode_reader)
        this.window_theme.RegisterError(this.status)
        this.window_theme.Register()
    }

    AddColorControl(field, x, y) {
        local argb := this.colors[field.key]
        local label := this.AddText(Format("x{} y{} w116 h24 +0x200", x, y), field.label . "：")
        local swatch := this.AddText(
            Format("x{} y{} w28 h24 +Border +0x100 Background{}", x + 118, y, this.RgbHex(argb)),
            ""
        )
        local edit := this.AddEdit(
            Format("x{} y{} w126 h24 r1 -Multi", x + 152, y),
            RabbitColorScheme.FormatArgbText(argb)
        )
        swatch.OnEvent("Click", (*) => this.PickColor(field.key))
        edit.OnEvent("Change", (*) => this.OnColorTextChanged(field.key))
        this.color_controls[field.key] := { label: label, swatch: swatch, edit: edit }
    }

    SetEditable(editable) {
        local controls, key
        this.name_edit.Enabled := editable
        this.author_edit.Enabled := editable
        for key, controls in this.color_controls {
            controls.swatch.Enabled := editable
            controls.edit.Enabled := editable
        }
    }

    ShowModal() {
        local hwnd := this.Hwnd
        RabbitDialogPlacement.ShowOnOwnerMonitor(this, this.owner_window.Hwnd, "w640 h542")
        if this.preview && HasMethod(this.preview, "SetOwner") {
            this.preview.SetOwner(this)
            this.preview_attached := true
            this.RenderPreview()
        }
        WinWaitClose("ahk_id " . hwnd)
        return this.result
    }

    PickColor(key) {
        local selected
        if this.mode = "view" || !this.ChooseColor(this.colors[key], &selected) {
            return
        }
        this.colors[key] := selected
        this.color_controls[key].edit.Value := RabbitColorScheme.FormatArgbText(selected)
        this.UpdateSwatch(key)
        this.RenderPreview()
    }

    OnColorTextChanged(key) {
        if this.mode = "view" {
            return
        }
        try {
            this.colors[key] := RabbitColorScheme.ParseArgbText(this.color_controls[key].edit.Value)
            this.status.Value := ""
            this.UpdateSwatch(key)
            this.RenderPreview()
        } catch as err {
            this.status.Value := err.Message
        }
    }

    UpdateSwatch(key) {
        this.color_controls[key].swatch.Opt("Background" . this.RgbHex(this.colors[key]))
        this.color_controls[key].swatch.Redraw()
    }

    RenderPreview() {
        if !this.preview {
            return false
        }
        try {
            this.preview.Render(this.color_scheme.BuildPreviewStyle(0, this.colors), this.select_labels)
            return true
        } catch as err {
            this.status.Value := "无法显示预览：" . err.Message
            return false
        }
    }

    SaveScheme() {
        local author := Trim(this.author_edit.Value)
        local color_scheme_id := Trim(this.id_edit.Value)
        local name := Trim(this.name_edit.Value)
        local colors := Map()
        if !name {
            this.status.Value := "方案名称不能为空。"
            return false
        }
        try {
            RabbitColorScheme.ValidateId(color_scheme_id)
        } catch as err {
            this.status.Value := err.Message
            return false
        }
        if this.id_validator && !this.id_validator.Call(color_scheme_id) {
            this.status.Value := "方案标识已存在。"
            return false
        }
        try {
            for field in RabbitColorScheme.EDITABLE_COLOR_FIELDS {
                colors[field.key] := RabbitColorScheme.ParseArgbText(
                    this.color_controls[field.key].edit.Value
                )
            }
            if this.mode = "new" || this.mode = "copy" {
                this.result := this.color_scheme.CopyAs(color_scheme_id, name, author).WithEdits(
                    name,
                    author,
                    colors
                )
            } else {
                this.result := this.color_scheme.WithEdits(name, author, colors)
            }
        } catch as err {
            this.status.Value := err.Message
            return false
        }
        this.Dispose()
        return true
    }

    ChooseColor(argb, &selected) {
        static custom_colors := Buffer(64, 0)
        static CC_RGBINIT := 0x1
        static CC_FULLOPEN := 0x2
        local choose_color := Buffer(A_PtrSize = 8 ? 72 : 36, 0)
        local pointer_offset := A_PtrSize = 8 ? 8 : 4
        local rgb := ((argb & 0xff) << 16) | (argb & 0xff00) | ((argb >> 16) & 0xff)
        NumPut("UInt", choose_color.Size, choose_color, 0)
        NumPut("Ptr", this.Hwnd, choose_color, pointer_offset)
        NumPut("UInt", rgb, choose_color, A_PtrSize = 8 ? 24 : 12)
        NumPut("Ptr", custom_colors.Ptr, choose_color, A_PtrSize = 8 ? 32 : 16)
        NumPut("UInt", CC_RGBINIT | CC_FULLOPEN, choose_color, A_PtrSize = 8 ? 40 : 20)
        if !DllCall("Comdlg32\ChooseColorW", "Ptr", choose_color, "Int") {
            return false
        }
        rgb := NumGet(choose_color, A_PtrSize = 8 ? 24 : 12, "UInt")
        selected := (argb & 0xff000000)
            | ((rgb & 0xff) << 16)
            | (rgb & 0xff00)
            | ((rgb >> 16) & 0xff)
        return true
    }

    RgbHex(argb) {
        return Format("{:06X}", argb & 0xffffff)
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try {
            if this.preview_attached && this.preview && HasMethod(this.preview, "SetOwner") {
                this.preview.SetOwner(this.owner_window)
                this.preview_attached := false
            }
        } finally {
            try {
                if this.window_theme {
                    this.window_theme.Dispose()
                    this.window_theme := 0
                }
            } finally {
                try this.Destroy()
            }
        }
    }
}
