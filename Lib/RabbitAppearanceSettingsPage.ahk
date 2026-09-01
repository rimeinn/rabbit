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
#Include RabbitColorSchemeDialog.ahk
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
        this.selection_dirty := false
        this.disposed := false
        this.dialog_factory := RabbitColorSchemeDialog
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
        owner.appearance_follow_light.Visible := color_visible && owner.appearance_target.Value = 2
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
            if owner.appearance_typesetting_created {
                this.PopulateStyle(style)
            }
            this.dirty := false
            this.selection_dirty := false
            owner.appearance_status.Value := this.presets.Length
                ? ""
                : "没有找到可用的配色。"
        } finally {
            this.loading := false
        }
        if owner.appearance_typesetting_created {
            this.UpdateConditionalControls()
        }
    }

    PopulateColorList(selected_id := "") {
        local owner := this.owner
        local active_index := 0
        local selected_index := 0
        local active_id := owner.appearance_target.Value = 2
            ? this.dark_scheme
            : this.light_scheme
        if !selected_id {
            selected_id := active_id
        }
        for i, info in this.presets {
            if info.color_scheme_id = active_id {
                active_index := i
            }
            if info.color_scheme_id = selected_id {
                selected_index := i
            }
        }
        owner.appearance_list.Delete()
        for i, info in this.presets {
            owner.appearance_list.Add(
                "",
                i = active_index ? "●" : "",
                info.name,
                info.color_scheme_id,
                this.IsCustomScheme(info) ? "自定义" : "内置"
            )
        }
        owner.appearance_list.ModifyCol(1, 54)
        owner.appearance_list.ModifyCol(2, 210)
        owner.appearance_list.ModifyCol(3, 156)
        owner.appearance_list.ModifyCol(4, 90)
        if !selected_index && this.presets.Length {
            selected_index := active_index ? active_index : 1
        }
        if selected_index {
            owner.appearance_list.Modify(selected_index, "Select Focus Vis")
            this.ShowDetails(selected_index)
        } else if owner.appearance_target.Value = 2 && !this.dark_scheme {
            owner.appearance_details.Value := "深色模式当前跟随浅色配色。"
        }
        owner.appearance_follow_light.Value := owner.appearance_target.Value = 2 && !this.dark_scheme
        this.UpdateColorButtons()
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
        owner.appearance_candidate_padding_x.Value := style.candidate_padding_x
        owner.appearance_candidate_padding_y.Value := style.candidate_padding_y
        owner.appearance_candidate_spacing.Value := style.candidate_spacing
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
        this.SetTabControlsVisible(this.owner.selected_page = 1)
        this.RenderPreview()
    }

    OnSelectionChange() {
        local owner := this.owner
        local index := this.SelectedSchemeIndex()
        if this.loading || index < 1 || index > this.presets.Length {
            return
        }
        this.ShowDetails(index)
        this.UpdateColorButtons()
        this.RenderPreview()
    }

    ShowDetails(index) {
        if index < 1 || index > this.presets.Length {
            return
        }
        local info := this.presets[index]
        this.owner.appearance_details.Value := "标识：" . info.color_scheme_id
            . (info.author ? "    作者：" . info.author : "")
            . (this.IsCustomScheme(info) ? "" : "`n内置方案只读；可以复制后修改。")
    }

    SelectedSchemeIndex() {
        local row := this.owner.appearance_list.GetNext(0)
        return row >= 1 && row <= this.presets.Length ? row : 0
    }

    SelectedScheme() {
        local index := this.SelectedSchemeIndex()
        return index ? this.presets[index] : 0
    }

    IsCustomScheme(color_scheme) {
        return HasMethod(color_scheme, "IsCustom") && color_scheme.IsCustom()
    }

    IsManageableCustomScheme(color_scheme) {
        if !this.IsCustomScheme(color_scheme) {
            return false
        }
        try {
            RabbitColorScheme.ValidateId(color_scheme.color_scheme_id)
            return true
        } catch {
            return false
        }
    }

    UpdateColorButtons() {
        local owner := this.owner
        local color_scheme := this.SelectedScheme()
        owner.appearance_copy.Enabled := !!color_scheme
        owner.appearance_edit.Enabled := !!color_scheme
        owner.appearance_delete.Enabled := color_scheme && this.IsManageableCustomScheme(color_scheme)
        owner.appearance_use.Enabled := color_scheme
            && !(
                owner.appearance_target.Value = 1 && color_scheme.color_scheme_id = this.light_scheme
                || owner.appearance_target.Value = 2 && color_scheme.color_scheme_id = this.dark_scheme
            )
    }

    UseSelectedColorScheme() {
        local owner := this.owner
        local color_scheme := this.SelectedScheme()
        if !color_scheme {
            return false
        }
        if owner.appearance_target.Value = 2 {
            this.dark_scheme := color_scheme.color_scheme_id
            owner.appearance_follow_light.Value := false
        } else {
            this.light_scheme := color_scheme.color_scheme_id
        }
        this.selection_dirty := true
        this.PopulateColorList(color_scheme.color_scheme_id)
        this.MarkDirty()
        this.RenderPreview()
        return true
    }

    OnFollowLightChange() {
        local owner := this.owner
        if this.loading || owner.appearance_target.Value != 2 {
            return
        }
        if owner.appearance_follow_light.Value {
            this.dark_scheme := ""
            this.selection_dirty := true
            this.PopulateColorList()
            this.MarkDirty()
            this.RenderPreview()
        } else if !this.UseSelectedColorScheme() {
            owner.appearance_follow_light.Value := true
        }
    }

    AddColorScheme() {
        local color_scheme_id := this.SuggestColorSchemeId("custom")
        local style_values := this.GetPreviewStyleValues()
        local base_style := style_values ? this.style.With(style_values) : this.style
        local draft := RabbitColorScheme.CreateDefault(color_scheme_id, "新配色", "", base_style)
        return this.ShowColorSchemeDialog(draft, "new")
    }

    CopyColorScheme() {
        local source := this.SelectedScheme()
        if !source {
            return false
        }
        local color_scheme_id := this.SuggestColorSchemeId(source.color_scheme_id . "_copy")
        local draft := source.CopyAs(color_scheme_id, source.name . " 副本", source.author)
        return this.ShowColorSchemeDialog(draft, "copy")
    }

    EditColorScheme(row := 0) {
        local color_scheme, index
        if row {
            this.owner.appearance_list.Modify(row, "Select Focus Vis")
        }
        index := this.SelectedSchemeIndex()
        if !index {
            return false
        }
        color_scheme := this.presets[index]
        return this.ShowColorSchemeDialog(
            color_scheme,
            this.IsManageableCustomScheme(color_scheme) ? "edit" : "view",
            index
        )
    }

    DeleteColorScheme() {
        local color_scheme := this.SelectedScheme()
        local index := this.SelectedSchemeIndex()
        if !color_scheme || !this.IsManageableCustomScheme(color_scheme) {
            return false
        }
        if color_scheme.color_scheme_id = this.light_scheme || color_scheme.color_scheme_id = this.dark_scheme {
            this.owner.appearance_status.Value := "请先将浅色和深色模式切换到其他配色。"
            return false
        }
        if this.owner.ShowMessage(
            "确定删除配色方案“" . color_scheme.name . "”吗？",
            "【玉兔毫】",
            "YesNo Icon!"
        ) != "Yes" {
            return false
        }
        this.settings.DeleteColorScheme(color_scheme.color_scheme_id)
        this.presets.RemoveAt(index)
        this.PopulateColorList()
        this.MarkDirty()
        this.RenderPreview()
        return true
    }

    ShowColorSchemeDialog(color_scheme, mode, replace_index := 0) {
        local dialog, factory, preview_style_overrides, result
        factory := this.dialog_factory
        preview_style_overrides := this.GetPreviewStyleValues()
        dialog := factory(
            this.owner,
            color_scheme,
            mode,
            this.preview,
            this.owner.GetAppearancePreviewLabels(),
            preview_style_overrides,
            mode = "new" || mode = "copy" ? this.IsColorSchemeIdAvailable.Bind(this) : 0,
            this.owner.window_theme.dark_mode_reader
        )
        try {
            result := dialog.ShowModal()
        } finally {
            dialog.Dispose()
        }
        if !result {
            this.RenderPreview()
            return false
        }
        if replace_index {
            this.presets[replace_index] := result
        } else {
            this.presets.Push(result)
        }
        this.settings.UpsertColorScheme(result)
        this.PopulateColorList(result.color_scheme_id)
        this.MarkDirty()
        this.RenderPreview()
        return true
    }

    IsColorSchemeIdAvailable(color_scheme_id) {
        for color_scheme in this.presets {
            if StrLower(color_scheme.color_scheme_id) = StrLower(color_scheme_id) {
                return false
            }
        }
        return true
    }

    SuggestColorSchemeId(prefix) {
        local candidate := StrLower(RegExReplace(prefix, "[^a-z0-9_-]", "_"))
        local index := 2
        if !candidate || !RegExMatch(candidate, "^[a-z0-9]") {
            candidate := "custom"
        }
        local result := candidate
        while !this.IsColorSchemeIdAvailable(result) {
            result := candidate . "_" . index
            index += 1
        }
        return result
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
        if !owner.appearance_typesetting_created {
            return
        }
        local flow := owner.appearance_layout_type.Value = 2
        local vertical := owner.appearance_layout_type.Value = 3
        local stacked := !flow && !vertical
        local floating := !!owner.appearance_floating_preedit.Value
        owner.appearance_align_type.Enabled := !vertical
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
        if !owner.appearance_typesetting_created {
            return this.style
        }
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
            "margin_x", this.ReadNumber(owner.appearance_margin_x, "窗口水平边距", 0, 500),
            "margin_y", this.ReadNumber(owner.appearance_margin_y, "窗口垂直边距", 0, 500),
            "candidate_padding_x", this.ReadNumber(
                owner.appearance_candidate_padding_x, "候选水平内边距", 0, 500),
            "candidate_padding_y", this.ReadNumber(
                owner.appearance_candidate_padding_y, "候选垂直内边距", 0, 500),
            "candidate_spacing", this.ReadNumber(owner.appearance_candidate_spacing, "候选间距", 0, 500),
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
        if text = "" || !IsNumber(text) {
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

    GetPreviewStyleValues(values := 0) {
        if !values && this.owner.appearance_typesetting_created {
            try values := this.GetValues()
        }
        return values
    }

    RenderPreview(values := 0) {
        local owner := this.owner
        local index, info, selected_id, style
        if !this.preview || !this.presets.Length {
            return false
        }
        try {
            index := this.SelectedSchemeIndex()
            if !index {
                selected_id := owner.appearance_target.Value = 2 && this.dark_scheme
                    ? this.dark_scheme
                    : this.light_scheme
                index := this.FindPreset(selected_id)
                if !index {
                    index := 1
                }
            }
            info := this.presets[index]
            ; Preset snapshots already contain the shared typography and layout values. Before the
            ; typesetting controls exist, GetValues() returns the full startup snapshot, whose colors
            ; must not override the scheme selected for preview.
            values := this.GetPreviewStyleValues(values)
            style := info.BuildPreviewStyle(values)
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
            this.PrepareSave(values)
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
            this.selection_dirty := false
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

    PrepareSave(values) {
        if HasMethod(this.settings, "SetStyleValues") {
            this.settings.SetStyleValues(values)
        }
        if this.selection_dirty {
            if HasMethod(this.settings, "StageColorSchemeSelection") {
                this.settings.StageColorSchemeSelection(this.light_scheme, this.dark_scheme)
            } else {
                this.settings.SelectColorScheme(this.light_scheme)
                if this.dark_scheme && HasMethod(this.settings, "SelectDarkColorScheme") {
                    this.settings.SelectDarkColorScheme(this.dark_scheme)
                } else if !this.dark_scheme && HasMethod(this.settings, "FollowLightColorScheme") {
                    this.settings.FollowLightColorScheme()
                }
            }
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
