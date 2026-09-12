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

#Include RabbitAppearancePreview.ahk
#Include RabbitAdvancedFontSettingsDialog.ahk
#Include RabbitColorSchemeDialog.ahk
#Include RabbitCommon.ahk
#Include RabbitDeploymentPlan.ahk
#Include Direct2D\Direct2D.ahk
#Include RabbitFontSpec.ahk
#Include RabbitUIStyleSnapshot.ahk

#Include RabbitI18n.ahk

class RabbitAppearanceSettingsPage {
    preview_error := ""

    static CBN_DROPDOWN := 7
    static CB_INITSTORAGE := 0x0161

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
        this.font_dialog_factory := RabbitAdvancedFontSettingsDialog
        this.loaded_font_controls := Map()
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
        local typesetting_visible := visible && owner.appearance_tabs.Value = 3
        for ctrl in owner.appearance_font_controls {
            ctrl.Visible := visible && owner.appearance_tabs.Value = 2
        }
        for ctrl in owner.appearance_color_controls {
            ctrl.Visible := color_visible
        }
        for ctrl in owner.appearance_typesetting_controls {
            ctrl.Visible := typesetting_visible
        }
        for ctrl in owner.appearance_preedit_controls {
            ctrl.Visible := visible && owner.appearance_tabs.Value = 4
        }
        owner.appearance_follow_light.Visible := color_visible && owner.appearance_target.Value = 2
        this.UpdateConditionalControls()
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
            owner.appearance_status.Value := RabbitI18n.Text("appearance.appearance_unavailable")
            return false
        }
        try {
            this.settings := this.workflow.CreateUIStyleSettings()
            this.PopulateSettings()
            if this.old_windows {
                owner.appearance_status.Value := RabbitI18n.Text("appearance.legacy_preview")
            } else try {
                this.CreatePreview()
            } catch as err {
                this.preview_error := RabbitI18n.Text("messages.preview_error", Map("reason", err.Message))
                owner.appearance_status.Value := this.preview_error
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
                : RabbitI18n.Text("appearance.no_colors")
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
                this.IsCustomScheme(info) ? RabbitI18n.Text("controls.custom") : RabbitI18n.Text("appearance.builtin")
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
            owner.appearance_details.Value := RabbitI18n.Text("appearance.following_light")
        }
        owner.appearance_follow_light.Value := owner.appearance_target.Value = 2 && !this.dark_scheme
        this.UpdateColorButtons()
    }

    PopulateStyle(style) {
        local font_controls_elapsed, font_controls_started_at := A_TickCount
        local other_controls_started_at
        local owner := this.owner
        this.SetFontValue(owner.appearance_font, style.font_face)
        this.SetFontValue(owner.appearance_preedit_font, style.preedit_font_face)
        this.SetFontValue(owner.appearance_label_font, style.label_font_face)
        this.SetFontValue(owner.appearance_comment_font, style.comment_font_face)
        font_controls_elapsed := A_TickCount - font_controls_started_at
        other_controls_started_at := A_TickCount
        owner.appearance_font_point.Value := style.font_point
        owner.appearance_label_font_point.Value := style.label_font_point
        owner.appearance_comment_font_point.Value := style.comment_font_point
        owner.appearance_label_format.Value := style.label_format
        owner.appearance_preedit_type.Choose(style.preedit_type = "preview" ? 2 : 1)
        owner.appearance_layout_type.Choose(
            style.layout_type = "flow" ? 2 : style.layout_type = "vertical_text" ? 3 : 1)
        owner.appearance_align_type.Choose(
            style.align_type = "center" ? 2 : style.align_type = "bottom" ? 3 : 1)
        owner.appearance_margin_x.Value := style.margin_x
        owner.appearance_margin_y.Value := style.margin_y
        owner.appearance_preedit_margin_x.Value := style.preedit_margin_x_explicit ? style.preedit_margin_x : ""
        owner.appearance_preedit_margin_y.Value := style.preedit_margin_y_explicit ? style.preedit_margin_y : ""
        owner.appearance_candidate_padding_x.Value := style.candidate_padding_x
        owner.appearance_candidate_padding_y.Value := style.candidate_padding_y
        owner.appearance_candidate_spacing.Value := style.candidate_spacing
        owner.appearance_shadow_radius.Value := style.shadow_radius
        owner.appearance_shadow_offset_x.Value := style.shadow_offset_x
        owner.appearance_shadow_offset_y.Value := style.shadow_offset_y
        owner.appearance_border_width.Value := style.border_width
        owner.appearance_corner_radius.Value := style.corner_radius
        owner.appearance_round_corner.Value := style.round_corner
        owner.appearance_preedit_border_width.Value := style.preedit_border_width_explicit
            ? style.preedit_border_width
            : ""
        owner.appearance_preedit_corner_radius.Value := style.preedit_corner_radius_explicit
            ? style.preedit_corner_radius
            : ""
        owner.appearance_preedit_round_corner.Value := style.preedit_round_corner_explicit
            ? style.preedit_round_corner
            : ""
        owner.appearance_min_width.Value := style.min_width
        owner.appearance_min_height.Value := style.min_height
        owner.appearance_flow_rows.Value := style.flow_rows
        owner.appearance_vertical_direction.Value := style.vertical_text_left_to_right
        owner.appearance_floating_preedit.Value := style.floating_preedit
        owner.appearance_floating_opacity.Value := Round(style.floating_preedit_opacity * 100)
        owner.appearance_floating_height.Value := style.floating_preedit_min_height
        RabbitDebug(
            Format(
                "typesetting style populated: total_ms={} font_controls_ms={} other_controls_ms={}",
                A_TickCount - font_controls_started_at,
                font_controls_elapsed,
                A_TickCount - other_controls_started_at
            ),
            Format("RabbitAppearanceSettingsPage.ahk:{}", A_LineNumber),
            1
        )
    }

    SetFontValue(ctrl, value) {
        if !this.loaded_font_controls.Has(ctrl.Hwnd) {
            ctrl.Text := value
            return
        }
        this.PopulateFontChoices(ctrl, value)
    }

    LoadFontChoices(ctrl) {
        if this.loaded_font_controls.Has(ctrl.Hwnd) {
            return false
        }
        this.PopulateFontChoices(ctrl, ctrl.Text)
        return true
    }

    PopulateFontChoices(ctrl, value) {
        local add_elapsed, add_started_at, catalog_elapsed, catalog_started_at
        local fonts, item, loading := this.loading
        local prepare_elapsed, prepare_started_at, reserve_bytes := 0
        local reserve_elapsed, reserve_result, reserve_started_at, selected := 0
        local total_started_at := A_TickCount
        catalog_started_at := A_TickCount
        fonts := RabbitAppearanceSettingsPage.GetInstalledFontFaces()
        catalog_elapsed := A_TickCount - catalog_started_at
        prepare_started_at := A_TickCount
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
        for item in fonts {
            reserve_bytes += (StrLen(item) + 1) * 2
        }
        prepare_elapsed := A_TickCount - prepare_started_at
        this.loading := true
        try {
            ctrl.Delete()
            reserve_started_at := A_TickCount
            ; Reserve the UTF-16 item storage before sending the bulk of CB_ADDSTRING messages.
            reserve_result := SendMessage(
                RabbitAppearanceSettingsPage.CB_INITSTORAGE,
                fonts.Length,
                reserve_bytes,
                ctrl.Hwnd
            )
            reserve_elapsed := A_TickCount - reserve_started_at
            add_started_at := A_TickCount
            ctrl.Add(fonts)
            ctrl.Choose(selected)
            add_elapsed := A_TickCount - add_started_at
            this.loaded_font_controls[ctrl.Hwnd] := true
        } finally {
            this.loading := loading
        }
        RabbitDebug(
            Format(
                "typesetting font combo populated: total_ms={} catalog_ms={} prepare_ms={} "
                    . "reserve_ms={} add_ms={} items={} reserve_bytes={} reserve_result={}",
                A_TickCount - total_started_at,
                catalog_elapsed,
                prepare_elapsed,
                reserve_elapsed,
                add_elapsed,
                fonts.Length,
                reserve_bytes,
                reserve_result
            ),
            Format("RabbitAppearanceSettingsPage.ahk:{}", A_LineNumber),
            1
        )
    }

    OpenAdvancedFontSettings() {
        local dialog, factory, result
        local owner := this.owner
        local values := Map(
            "font_face", Trim(owner.appearance_font.Text),
            "preedit_font_face", Trim(owner.appearance_preedit_font.Text),
            "label_font_face", Trim(owner.appearance_label_font.Text),
            "comment_font_face", Trim(owner.appearance_comment_font.Text)
        )
        factory := this.font_dialog_factory
        try {
            dialog := factory(
                owner,
                values,
                RabbitAppearanceSettingsPage.GetInstalledFontFaces(),
                owner.window_theme.dark_mode_reader
            )
        } catch as err {
            owner.appearance_status.Value := err.Message
            return false
        }
        try {
            result := dialog.ShowModal()
        } finally {
            dialog.Dispose()
        }
        if !result {
            return false
        }
        this.loading := true
        try {
            this.SetFontValue(owner.appearance_font, result["font_face"])
            this.SetFontValue(owner.appearance_preedit_font, result["preedit_font_face"])
            this.SetFontValue(owner.appearance_label_font, result["label_font_face"])
            this.SetFontValue(owner.appearance_comment_font, result["comment_font_face"])
        } finally {
            this.loading := false
        }
        this.OnControlsChanged()
        return true
    }

    static GetInstalledFontFaces() {
        static cached := 0
        local enumerate_elapsed, enumerate_started_at, sort_started_at
        local face, factory := 0
        local names := Map()
        local result := []
        local text := ""
        if cached {
            return cached.Clone()
        }
        enumerate_started_at := A_TickCount
        try {
            factory := Direct2D.IDWriteFactory()
            for face in factory.GetSystemFontFaces() {
                face := Trim(face)
                if face {
                    names[face] := true
                }
            }
        }
        enumerate_elapsed := A_TickCount - enumerate_started_at
        sort_started_at := A_TickCount
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
        RabbitDebug(
            Format(
                "typesetting font catalog initialized: total_ms={} enumerate_ms={} sort_ms={} families={}",
                A_TickCount - enumerate_started_at,
                enumerate_elapsed,
                A_TickCount - sort_started_at,
                result.Length
            ),
            Format("RabbitAppearanceSettingsPage.ahk:{}", A_LineNumber),
            1
        )
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
        this.owner.appearance_details.Value := RabbitI18n.Text("messages.color_id", Map("id", info.color_scheme_id))
            . (info.author ? RabbitI18n.Text("messages.color_author", Map("author", info.author)) : "")
            . (this.IsCustomScheme(info) ? "" : RabbitI18n.Text("messages.color_readonly"))
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
        local draft := RabbitColorScheme.CreateDefault(color_scheme_id, RabbitI18n.Text("appearance.new_color"), "", base_style)
        return this.ShowColorSchemeDialog(draft, "new")
    }

    CopyColorScheme() {
        local source := this.SelectedScheme()
        if !source {
            return false
        }
        local color_scheme_id := this.SuggestColorSchemeId(source.color_scheme_id . "_copy")
        local draft := source.CopyAs(color_scheme_id, RabbitI18n.Text("messages.color_copy", Map("name", source.name)), source.author)
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
            this.owner.appearance_status.Value := RabbitI18n.Text("appearance.color_in_use")
            return false
        }
        if this.owner.ShowMessage(
            RabbitI18n.Text("messages.color_delete", Map("name", color_scheme.name)),
            RabbitI18n.Text("about.message_title"),
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
        local name
        for name in ["floating_opacity", "floating_height", "preedit_margin_x", "preedit_margin_y",
            "preedit_border_width", "preedit_corner_radius", "preedit_round_corner"] {
            owner.%"appearance_" . name%.Enabled := floating
            owner.%"appearance_" . name . "_label"%.Enabled := floating
        }
        owner.appearance_preedit_hint.Enabled := floating
    }

    MarkDirty() {
        this.dirty := true
        this.owner.footer_status.Value := RabbitI18n.Text("appearance.appearance_dirty")
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
            throw Error(RabbitI18n.Text("appearance.font_required"))
        }
        this.ValidateFontSetting(font_face, RabbitI18n.Text("appearance.font_text"))
        this.ValidateFontSetting(preedit_font_face, RabbitI18n.Text("appearance.font_preedit"))
        this.ValidateFontSetting(label_font_face, RabbitI18n.Text("appearance.font_label"))
        this.ValidateFontSetting(comment_font_face, RabbitI18n.Text("appearance.font_comment"))
        if !label_format {
            throw Error(RabbitI18n.Text("appearance.label_format_required"))
        }
        try {
            Format(label_format, "1")
        } catch {
            throw Error(RabbitI18n.Text("appearance.label_format_invalid"))
        }
        return Map(
            "font_face", font_face,
            "preedit_font_face", preedit_font_face,
            "label_font_face", label_font_face,
            "comment_font_face", comment_font_face,
            "font_point", this.ReadNumber(owner.appearance_font_point, RabbitI18n.Text("appearance.text_size"), 6, 72),
            "label_font_point", this.ReadNumber(
                owner.appearance_label_font_point, RabbitI18n.Text("appearance.label_size"), 6, 72),
            "comment_font_point", this.ReadNumber(
                owner.appearance_comment_font_point, RabbitI18n.Text("appearance.comment_size"), 6, 72),
            "label_format", label_format,
            "preedit_type", ["composition", "preview"][owner.appearance_preedit_type.Value],
            "layout_type", ["stacked", "flow", "vertical_text"][owner.appearance_layout_type.Value],
            "align_type", ["top", "center", "bottom"][owner.appearance_align_type.Value],
            "margin_x", this.ReadNumber(owner.appearance_margin_x, RabbitI18n.Text("appearance.margin_x"), 0, 500),
            "margin_y", this.ReadNumber(owner.appearance_margin_y, RabbitI18n.Text("appearance.margin_y"), 0, 500),
            "preedit_margin_x", this.ReadOptionalNumber(
                owner.appearance_preedit_margin_x, RabbitI18n.Text("appearance.preedit_margin_x"), 0, 500),
            "preedit_margin_y", this.ReadOptionalNumber(
                owner.appearance_preedit_margin_y, RabbitI18n.Text("appearance.preedit_margin_y"), 0, 500),
            "candidate_padding_x", this.ReadNumber(
                owner.appearance_candidate_padding_x, RabbitI18n.Text("appearance.padding_x"), 0, 500),
            "candidate_padding_y", this.ReadNumber(
                owner.appearance_candidate_padding_y, RabbitI18n.Text("appearance.padding_y"), 0, 500),
            "candidate_spacing", this.ReadNumber(owner.appearance_candidate_spacing, RabbitI18n.Text("appearance.spacing"), 0, 500),
            "shadow_radius", this.ReadNumber(owner.appearance_shadow_radius, RabbitI18n.Text("appearance.shadow_radius"), 0, RabbitUIStyleSnapshot.MAX_SHADOW_RADIUS),
            "shadow_offset_x", this.ReadNumber(owner.appearance_shadow_offset_x, RabbitI18n.Text("appearance.shadow_x"), -RabbitUIStyleSnapshot.MAX_SHADOW_OFFSET, RabbitUIStyleSnapshot.MAX_SHADOW_OFFSET),
            "shadow_offset_y", this.ReadNumber(owner.appearance_shadow_offset_y, RabbitI18n.Text("appearance.shadow_y"), -RabbitUIStyleSnapshot.MAX_SHADOW_OFFSET, RabbitUIStyleSnapshot.MAX_SHADOW_OFFSET),
            "border_width", this.ReadNumber(owner.appearance_border_width, RabbitI18n.Text("appearance.border"), 0, 500),
            "corner_radius", this.ReadNumber(owner.appearance_corner_radius, RabbitI18n.Text("appearance.corner"), 0, 500),
            "round_corner", this.ReadNumber(owner.appearance_round_corner, RabbitI18n.Text("appearance.round_corner"), 0, 500),
            "preedit_border_width", this.ReadOptionalNumber(
                owner.appearance_preedit_border_width,
                RabbitI18n.Text("appearance.preedit_border_width"),
                0,
                500
            ),
            "preedit_corner_radius", this.ReadOptionalNumber(
                owner.appearance_preedit_corner_radius,
                RabbitI18n.Text("appearance.preedit_corner_radius"),
                0,
                500
            ),
            "preedit_round_corner", this.ReadOptionalNumber(
                owner.appearance_preedit_round_corner,
                RabbitI18n.Text("appearance.preedit_round_corner"),
                0,
                500
            ),
            "min_width", this.ReadNumber(owner.appearance_min_width, RabbitI18n.Text("appearance.min_width"), 0, 2000),
            "min_height", this.ReadNumber(owner.appearance_min_height, RabbitI18n.Text("appearance.min_height"), 0, 2000),
            "flow_rows", this.ReadNumber(owner.appearance_flow_rows, RabbitI18n.Text("appearance.pages"), 1, 9),
            "vertical_text_left_to_right", !!owner.appearance_vertical_direction.Value,
            "floating_preedit", !!owner.appearance_floating_preedit.Value,
            "floating_preedit_opacity", this.ReadNumber(
                owner.appearance_floating_opacity, RabbitI18n.Text("appearance.opacity"), 0, 100) / 100,
            "floating_preedit_min_height", this.ReadNumber(
                owner.appearance_floating_height, RabbitI18n.Text("appearance.floating_height"), 0, 500)
        )
    }

    ValidateFontSetting(value, label) {
        try {
            RabbitFontSpec.Parse(value)
        } catch as err {
            throw Error(RabbitI18n.Text("messages.font_invalid", Map("label", label, "reason", err.Message)))
        }
    }

    ReadNumber(ctrl, name, minimum, maximum) {
        local text := Trim(ctrl.Value)
        if text = "" || !IsNumber(text) {
            throw Error(RabbitI18n.Text("messages.number_required", Map("name", name)))
        }
        local value := Number(text)
        if value != Integer(value) {
            throw Error(RabbitI18n.Text("messages.integer_required", Map("name", name)))
        }
        if value < minimum || value > maximum {
            throw Error(RabbitI18n.Text("messages.number_range", Map("name", name, "minimum", minimum, "maximum", maximum)))
        }
        return Integer(value)
    }

    ReadOptionalNumber(ctrl, name, minimum, maximum) {
        return Trim(ctrl.Value) = "" ? "" : this.ReadNumber(ctrl, name, minimum, maximum)
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
            if this.preview_error && owner.appearance_status.Value == this.preview_error {
                owner.appearance_status.Value := ""
                this.preview_error := ""
            }
            return true
        } catch as err {
            this.preview_error := RabbitI18n.Text("messages.preview_error", Map("reason", err.Message))
            owner.appearance_status.Value := this.preview_error
            return false
        }
    }

    ApplySettings() {
        local owner := this.owner
        local deploy_result, values, uses_parent_lock := false
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
        if HasMethod(owner, "TryBeginParentOperation") {
            if !owner.TryBeginParentOperation() {
                return false
            }
            uses_parent_lock := true
        } else {
            owner.Opt("+Disabled")
        }
        owner.appearance_status.Value := RabbitI18n.Text("controls.saving")
        try {
            if !this.settings.Save() {
                owner.appearance_status.Value := RabbitI18n.Text("controls.appearance_save_error")
                return false
            }
            deploy_result := owner.Deploy(RabbitDeploymentPlan.RabbitConfig())
            if deploy_result != 0 {
                owner.appearance_status.Value := RabbitI18n.Text("controls.redeploy_error")
                return false
            }
            this.dirty := false
            this.selection_dirty := false
            owner.appearance_status.Value := RabbitI18n.Text("controls.appearance_saved")
            owner.footer_status.Value := RabbitI18n.Text("controls.save_hint")
            owner.UpdateApplyButton()
            return true
        } catch as err {
            owner.appearance_status.Value := RabbitI18n.Text("messages.save_error", Map("reason", err.Message))
            return false
        } finally {
            if uses_parent_lock {
                owner.EndParentOperation()
            } else {
                owner.Opt("-Disabled")
            }
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
