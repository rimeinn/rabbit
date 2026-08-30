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

#Include RabbitAppearancePreview.ahk
#Include RabbitUIStyleSnapshot.ahk

class RabbitAppearanceSettingsPage {
    __New(owner, workflow, old_windows, preview_factory) {
        this.owner := owner
        this.workflow := workflow
        this.old_windows := old_windows
        this.preview_factory := preview_factory
        this.settings := 0
        this.presets := []
        this.preview := 0
        this.loading := false
        this.dirty := false
        this.style := RabbitUIStyleSnapshot()
        this.light_scheme := ""
        this.dark_scheme := ""
        this.disposed := false
    }

    SetVisible(visible) {
        local owner := this.owner
        owner.appearance_tabs.Visible := visible
        this.SetTabControlsVisible(visible)
        owner.appearance_status.Visible := visible
        if !visible && this.preview && HasMethod(this.preview, "Hide") {
            this.preview.Hide()
        }
    }

    SetTabControlsVisible(visible) {
        local owner := this.owner
        local color_visible := visible && owner.appearance_tabs.Value = 1
        local typesetting_visible := visible && owner.appearance_tabs.Value = 2
        for ctrl in owner.appearance_color_controls {
            ctrl.Visible := color_visible
        }
        for ctrl in owner.appearance_typesetting_controls {
            ctrl.Visible := typesetting_visible
        }
    }

    OnTabChanged() {
        this.SetTabControlsVisible(this.owner.selected_page = 1)
    }

    EnsureSettings() {
        local owner := this.owner
        if this.settings {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateUIStyleSettings") {
            owner.appearance_status.Value := "当前环境无法读取外观设置。"
            return false
        }
        try {
            this.settings := this.workflow.CreateUIStyleSettings()
            this.PopulateSettings()
            if this.old_windows {
                owner.appearance_status.Value := "旧版 Windows 暂不支持预览。"
            } else try {
                this.CreatePreview()
                this.RenderPreview()
            } catch as err {
                owner.appearance_status.Value := "无法显示预览：" . err.Message
            }
            return true
        } catch as err {
            owner.appearance_status.Value := err.Message
            return false
        }
    }

    CreatePreview() {
        local factory
        if this.old_windows || this.preview {
            return
        }
        factory := this.preview_factory
        this.preview := factory(this.owner)
    }

    PopulateSettings() {
        local owner := this.owner
        local style
        this.loading := true
        try {
            this.light_scheme := this.settings.GetActiveColorScheme()
            this.dark_scheme := HasMethod(this.settings, "GetActiveColorSchemeDark")
                ? this.settings.GetActiveColorSchemeDark()
                : ""
            style := HasMethod(this.settings, "GetCurrentStyle")
                ? this.settings.GetCurrentStyle()
                : RabbitUIStyleSnapshot()
            this.style := style
            this.presets := this.settings.GetPresetColorSchemes()
            this.PopulateColorList()
            this.PopulateStyle(style)
            this.dirty := false
            owner.appearance_status.Value := this.presets.Length
                ? ""
                : "没有找到可用的配色。"
        } finally {
            this.loading := false
        }
        this.UpdateConditionalControls()
        this.RenderPreview()
    }

    PopulateColorList() {
        local owner := this.owner
        local active_index := 0
        local names := []
        local selected_id := owner.appearance_target.Value = 2
            ? this.dark_scheme
            : this.light_scheme
        for i, info in this.presets {
            names.Push(info.name)
            if info.color_scheme_id = selected_id {
                active_index := i
            }
        }
        owner.appearance_list.Delete()
        owner.appearance_list.Add(names)
        if active_index > 0 {
            owner.appearance_list.Choose(active_index)
            this.ShowDetails(active_index)
        } else {
            owner.appearance_list.Choose(0)
            owner.appearance_details.Value := owner.appearance_target.Value = 2
                ? "深色模式当前跟随浅色配色。"
                : ""
        }
    }

    PopulateStyle(style) {
        local owner := this.owner
        this.SetFontValue(owner.appearance_font, style.font_face)
        this.SetFontValue(owner.appearance_preedit_font, style.preedit_font_face)
        this.SetFontValue(owner.appearance_label_font, style.label_font_face)
        this.SetFontValue(owner.appearance_comment_font, style.comment_font_face)
        owner.appearance_font_point.Value := style.font_point
        owner.appearance_label_font_point.Value := style.label_font_point
        owner.appearance_comment_font_point.Value := style.comment_font_point
        owner.appearance_label_format.Value := style.label_format
        owner.appearance_layout_type.Choose(
            style.layout_type = "flow" ? 2 : style.layout_type = "vertical_text" ? 3 : 1)
        owner.appearance_align_type.Choose(
            style.align_type = "center" ? 2 : style.align_type = "bottom" ? 3 : 1)
        owner.appearance_margin_x.Value := style.margin_x
        owner.appearance_margin_y.Value := style.margin_y
        owner.appearance_border_width.Value := style.border_width
        owner.appearance_corner_radius.Value := style.corner_radius
        owner.appearance_round_corner.Value := style.round_corner
        owner.appearance_min_width.Value := style.min_width
        owner.appearance_min_height.Value := style.min_height
        owner.appearance_flow_rows.Value := style.flow_rows
        owner.appearance_vertical_direction.Value := style.vertical_text_left_to_right
        owner.appearance_floating_preedit.Value := style.floating_preedit
        owner.appearance_floating_opacity.Value := Round(style.floating_preedit_opacity * 100)
        owner.appearance_floating_height.Value := style.floating_preedit_min_height
    }

    SetFontValue(ctrl, value) {
        local fonts := RabbitAppearanceSettingsPage.GetInstalledFontFaces()
        local selected := 0
        for index, font_face in fonts {
            if font_face = value {
                selected := index
                break
            }
        }
        if !selected {
            fonts.InsertAt(1, value)
            selected := 1
        }
        ctrl.Delete()
        ctrl.Add(fonts)
        ctrl.Choose(selected)
    }

    static GetInstalledFontFaces() {
        static cached := 0
        local names := Map()
        local result := []
        local text := ""
        if cached {
            return cached.Clone()
        }
        try {
            Loop Reg, "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts", "V" {
                local name := RegExReplace(A_LoopRegName, "\s+\([^)]*\)$")
                for face in StrSplit(name, " & ") {
                    face := Trim(face)
                    if face {
                        names[face] := true
                    }
                }
            }
        }
        for name in names {
            text .= name . "`n"
        }
        text := Sort(text, "D`n")
        for name in StrSplit(RTrim(text, "`n"), "`n") {
            if name {
                result.Push(name)
            }
        }
        if !result.Length {
            result.Push("Microsoft YaHei UI")
        }
        cached := result
        return cached.Clone()
    }

    OnTargetChange() {
        if this.loading {
            return
        }
        this.loading := true
        try {
            this.PopulateColorList()
        } finally {
            this.loading := false
        }
        this.RenderPreview()
    }

    OnSelectionChange() {
        local owner := this.owner
        local index := owner.appearance_list.Value
        if this.loading || index < 1 || index > this.presets.Length {
            return
        }
        local scheme_id := this.presets[index].color_scheme_id
        if owner.appearance_target.Value = 2 {
            if HasMethod(this.settings, "SelectDarkColorScheme") {
                this.settings.SelectDarkColorScheme(scheme_id)
            }
            this.dark_scheme := scheme_id
        } else {
            this.settings.SelectColorScheme(scheme_id)
            this.light_scheme := scheme_id
        }
        this.ShowDetails(index)
        this.MarkDirty()
        this.RenderPreview()
    }

    ShowDetails(index) {
        if index < 1 || index > this.presets.Length {
            return
        }
        local info := this.presets[index]
        this.owner.appearance_details.Value := info.author ? "作者：" . info.author : ""
    }

    OnControlsChanged() {
        local owner := this.owner
        if this.loading {
            return
        }
        this.UpdateConditionalControls()
        try {
            local values := this.GetValues()
            if this.settings && HasMethod(this.settings, "SetStyleValues") {
                this.settings.SetStyleValues(values)
            }
            owner.appearance_status.Value := ""
            this.MarkDirty()
            this.RenderPreview(values)
        } catch as err {
            owner.appearance_status.Value := err.Message
        }
    }

    UpdateConditionalControls() {
        local owner := this.owner
        local flow := owner.appearance_layout_type.Value = 2
        local vertical := owner.appearance_layout_type.Value = 3
        local stacked := !flow && !vertical
        local floating := !!owner.appearance_floating_preedit.Value
        owner.appearance_align_type.Enabled := flow
        owner.appearance_flow_rows.Enabled := flow
        owner.appearance_vertical_direction.Enabled := vertical
        owner.appearance_min_width_label.Enabled := stacked
        owner.appearance_min_width.Enabled := stacked
        owner.appearance_min_height_label.Enabled := vertical
        owner.appearance_min_height.Enabled := vertical
        owner.appearance_floating_opacity.Enabled := floating
        owner.appearance_floating_height.Enabled := floating
    }

    MarkDirty() {
        this.dirty := true
        this.owner.footer_status.Value := "外观设置尚未保存。"
        this.owner.UpdateApplyButton()
    }

    GetValues() {
        local owner := this.owner
        local font_face := Trim(owner.appearance_font.Text)
        local preedit_font_face := Trim(owner.appearance_preedit_font.Text)
        local label_font_face := Trim(owner.appearance_label_font.Text)
        local comment_font_face := Trim(owner.appearance_comment_font.Text)
        local label_format := owner.appearance_label_format.Value
        if !font_face || !preedit_font_face || !label_font_face || !comment_font_face {
            throw Error("字体名称不能为空。")
        }
        if !label_format {
            throw Error("候选序号格式不能为空。")
        }
        try {
            Format(label_format, "1")
        } catch {
            throw Error("候选序号格式无效。")
        }
        return Map(
            "font_face", font_face,
            "preedit_font_face", preedit_font_face,
            "label_font_face", label_font_face,
            "comment_font_face", comment_font_face,
            "font_point", this.ReadNumber(owner.appearance_font_point, "候选字号", 6, 72),
            "label_font_point", this.ReadNumber(
                owner.appearance_label_font_point, "候选序号字号", 6, 72),
            "comment_font_point", this.ReadNumber(
                owner.appearance_comment_font_point, "候选注释字号", 6, 72),
            "label_format", label_format,
            "layout_type", ["stacked", "flow", "vertical_text"][owner.appearance_layout_type.Value],
            "align_type", ["top", "center", "bottom"][owner.appearance_align_type.Value],
            "margin_x", this.ReadNumber(owner.appearance_margin_x, "水平边距", 0, 500),
            "margin_y", this.ReadNumber(owner.appearance_margin_y, "垂直边距", 0, 500),
            "border_width", this.ReadNumber(owner.appearance_border_width, "边框宽度", 0, 500),
            "corner_radius", this.ReadNumber(owner.appearance_corner_radius, "窗口圆角", 0, 500),
            "round_corner", this.ReadNumber(owner.appearance_round_corner, "候选及高亮圆角", 0, 500),
            "min_width", this.ReadNumber(owner.appearance_min_width, "堆叠最小宽度", 0, 2000),
            "min_height", this.ReadNumber(owner.appearance_min_height, "竖排最小高度", 0, 2000),
            "flow_rows", this.ReadNumber(owner.appearance_flow_rows, "展开页数", 1, 9),
            "vertical_text_left_to_right", !!owner.appearance_vertical_direction.Value,
            "floating_preedit", !!owner.appearance_floating_preedit.Value,
            "floating_preedit_opacity", this.ReadNumber(
                owner.appearance_floating_opacity, "浮动预编辑不透明度", 0, 100) / 100,
            "floating_preedit_min_height", this.ReadNumber(
                owner.appearance_floating_height, "浮动预编辑最小高度", 0, 500)
        )
    }

    ReadNumber(ctrl, name, minimum, maximum) {
        local text := Trim(ctrl.Value)
        if !text || !IsNumber(text) {
            throw Error(name . "必须是数字。")
        }
        local value := Number(text)
        if value != Integer(value) {
            throw Error(name . "必须是整数。")
        }
        if value < minimum || value > maximum {
            throw Error(Format("{}必须在 {} 到 {} 之间。", name, minimum, maximum))
        }
        return Integer(value)
    }

    FindPreset(color_scheme_id) {
        for index, info in this.presets {
            if info.color_scheme_id = color_scheme_id {
                return index
            }
        }
        return 0
    }

    RenderPreview(values := 0) {
        local owner := this.owner
        local index, info, selected_id, style
        if !this.preview || !this.presets.Length {
            return false
        }
        try {
            selected_id := owner.appearance_target.Value = 2 && this.dark_scheme
                ? this.dark_scheme
                : this.light_scheme
            index := this.FindPreset(selected_id)
            if !index {
                index := 1
            }
            info := this.presets[index]
            if !values {
                try values := this.GetValues()
            }
            style := values ? info.style.With(values) : info.style
            this.preview.Render(style, owner.GetAppearancePreviewLabels())
            if InStr(owner.appearance_status.Value, "无法显示预览：") = 1 {
                owner.appearance_status.Value := ""
            }
            return true
        } catch as err {
            owner.appearance_status.Value := "无法显示预览：" . err.Message
            return false
        }
    }

    ApplySettings() {
        local owner := this.owner
        local deploy_result, values
        if !this.settings || !this.dirty {
            return false
        }
        try {
            values := this.GetValues()
            if HasMethod(this.settings, "SetStyleValues") {
                this.settings.SetStyleValues(values)
            }
        } catch as err {
            owner.appearance_status.Value := err.Message
            return false
        }
        owner.Opt("+Disabled")
        owner.appearance_status.Value := "正在保存…"
        try {
            if !this.settings.Save() {
                owner.appearance_status.Value := "未能保存外观设置。"
                return false
            }
            deploy_result := this.workflow.UpdateWorkspace(true)
            if deploy_result != 0 {
                owner.appearance_status.Value := "设置已保存，但重新部署失败。"
                return false
            }
            this.dirty := false
            owner.appearance_status.Value := "外观设置已保存。"
            owner.footer_status.Value := "设置内容将在确认后统一保存和部署。"
            owner.UpdateApplyButton()
            return true
        } catch as err {
            owner.appearance_status.Value := "保存失败：" . err.Message
            return false
        } finally {
            owner.Opt("-Disabled")
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try {
            if this.preview {
                this.preview.Dispose()
                this.preview := 0
            }
        } finally {
            if this.settings {
                this.settings.Dispose()
                this.settings := 0
            }
        }
        this.owner := 0
    }
}
