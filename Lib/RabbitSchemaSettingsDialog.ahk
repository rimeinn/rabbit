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

#Include RabbitDialogPlacement.ahk
#Include RabbitKeyBindingDialog.ahk
#Include RabbitSchemaSettingsModel.ahk
#Include RabbitStringListItemDialog.ahk
#Include RabbitWindowTheme.ahk

#Include RabbitI18n.ahk

class RabbitSchemaSettingsDialog extends Gui {
    static CONTENT_SCROLL_LINE := 32
    static CONTENT_BOTTOM_PADDING := 14
    static MAX_DIALOG_HEIGHT := 720
    static MIN_DIALOG_HEIGHT := 360
    static WM_VSCROLL := 0x0115
    static WM_MOUSEWHEEL := 0x020A
    static SB_VERT := 1
    static SB_LINEUP := 0
    static SB_LINEDOWN := 1
    static SB_PAGEUP := 2
    static SB_PAGEDOWN := 3
    static SB_THUMBPOSITION := 4
    static SB_THUMBTRACK := 5
    static SB_TOP := 6
    static SB_BOTTOM := 7
    static SB_ENDSCROLL := 8
    static SIF_RANGE := 0x0001
    static SIF_PAGE := 0x0002
    static SIF_POS := 0x0004
    static SIF_TRACKPOS := 0x0010
    static SW_SCROLLCHILDREN := 0x0001
    static SW_INVALIDATE := 0x0002
    static SW_ERASE := 0x0004

    __New(
        owner,
        model,
        schema_name := "",
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local groups, labels := [], initial_dark_mode := false, maximum_dialog_height
        local content_x, content_width, content_y := 18, header_height := 0
        local status_y, buttons_y, max_content_height, title := model.manifest.title
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        if schema_name {
            title .= " - " . schema_name
        }
        groups := model.manifest.groups
        if !(groups is Array) || !groups.Length {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map(
                "file", model.manifest.file_path
            )))
        }
        super.__New("+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox -Resize", title, this)
        this.owner_window := owner
        this.model := model
        this.groups := groups
        this.theme_factory := theme_factory
        this.dark_mode_reader := dark_mode_reader
        this.result := 0
        this.disposed := false
        this.visible := false
        this.current_group_index := 1
        this.group_list := 0
        this.content_anchor := 0
        this.field_controls := Map()
        this.content_control_hwnds := Map()
        this.content_list_hwnds := Map()
        this.draft_values := Map()
        this.reset_fields := Map()
        this.outer_muted_controls := []
        this.content_muted_controls := []
        this.content_surface_controls := []
        this.content_gui := 0
        this.content_window_theme := 0
        this.content_scroll_y := 0
        this.content_scroll_max := 0
        this.content_virtual_height := 0
        this.content_viewport_height := 0
        this.content_scroll_callback := this.OnContentVScroll.Bind(this)
        this.content_wheel_callback := this.OnContentMouseWheel.Bind(this)
        for field_id, value in model.values {
            this.draft_values[field_id] := RabbitConfigValue.Clone(value)
        }
        this.group_navigation_visible := groups.Length > 1
        this.dialog_width := this.group_navigation_visible ? 700 : 560
        content_x := this.group_navigation_visible ? 204 : 20
        content_width := this.dialog_width - content_x - 20
        this.content_x := content_x
        this.content_width := content_width
        this.MarginX := 20
        this.MarginY := 18
        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )
        if model.manifest.description {
            header_height := this.MeasureWrappedTextHeight(model.manifest.description, this.dialog_width - 40)
            this.AddOuterMutedText("x20 y" . content_y . " w" . (this.dialog_width - 40) . " h" . header_height,
                model.manifest.description)
            header_height += 12
        }
        this.content_y := content_y + header_height
        maximum_dialog_height := this.CalculateMaximumDialogHeight()
        max_content_height := maximum_dialog_height - this.content_y - 92
        this.content_height := this.CalculateContentHeight(Max(180, max_content_height))
        status_y := this.content_y + this.content_height + 8
        buttons_y := status_y + 30
        this.dialog_height := buttons_y + 50
        if this.group_navigation_visible {
            for group in groups {
                labels.Push(group.label)
            }
            this.group_list := this.AddListBox(
                "x20 y" . this.content_y . " w164 h" . this.content_height,
                labels
            )
            this.group_list.Choose(1)
            this.group_list.OnEvent("Change", (*) => this.OnGroupChanged())
        }
        this.content_anchor := this.AddText(
            "x" . this.content_x . " y" . this.content_y . " w1 h1 Hidden",
            ""
        )
        this.status := this.AddText("x20 y" . status_y . " w" . (this.dialog_width - 40) . " h24 cRed", "")
        this.save_button := this.AddButton(
            "x" . (this.dialog_width - 188) . " y" . buttons_y . " w80 h32 Default +0x2000",
            RabbitI18n.Text("common.ok")
        )
        this.save_button.OnEvent("Click", (*) => this.SaveSettings())
        this.cancel_button := this.AddButton(
            "x" . (this.dialog_width - 100) . " y" . buttons_y . " w80 h32 +0x2000",
            RabbitI18n.Text("common.cancel")
        )
        this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        this.window_theme := theme_factory(this, dark_mode_reader)
        this.window_theme.RegisterError(this.status)
        if this.group_list {
            this.window_theme.RegisterSurface(this.group_list)
        }
        if this.outer_muted_controls.Length {
            this.window_theme.RegisterMuted(this.outer_muted_controls*)
        }
        this.window_theme.Register()
        this.CreateContentPanel()
    }

    CalculateMaximumDialogHeight() {
        local monitor, monitor_info, work_height := RabbitSchemaSettingsDialog.MAX_DIALOG_HEIGHT
        monitor := MonitorManage.MonitorFromWindow(this.owner_window.Hwnd, MONITOR_DEFAULTTONEAREST)
        if monitor && (monitor_info := MonitorManage.GetMonitorInfo(monitor)) {
            work_height := Floor(monitor_info.work.height() * 0.8)
        }
        return Max(
            RabbitSchemaSettingsDialog.MIN_DIALOG_HEIGHT,
            Min(RabbitSchemaSettingsDialog.MAX_DIALOG_HEIGHT, work_height)
        )
    }

    CalculateContentHeight(maximum_height) {
        local field, group, group_height, height := 0
        for group in this.groups {
            group_height := 12
            if group.description {
                group_height += this.MeasureWrappedTextHeight(group.description, this.content_width - 24) + 10
            }
            for field in this.model.manifest.fields {
                if field.group != group.id {
                    continue
                }
                group_height += this.GetFieldContentHeight(field)
                if field.description {
                    group_height += this.MeasureWrappedTextHeight(field.description, this.content_width - 24) + 4
                }
                group_height += 6
            }
            height := Max(height, group_height + 8)
        }
        return Min(maximum_height, Max(180, height))
    }

    MeasureWrappedTextHeight(value, width) {
        local control, text_height
        if !value || width < 1 {
            return 0
        }
        control := this.AddText("x0 y0 w" . width . " Hidden", value)
        control.GetPos(, , , &text_height)
        return text_height
    }

    GetFieldContentHeight(field) {
        if field.type = "boolean" {
            return 28
        }
        if field.type = "list" || field.type = "key_binding_list" {
            return this.MeasureListFieldHeight(field)
        }
        return 30
    }

    MeasureListFieldHeight(field) {
        local control, dark_mode := !!this.dark_mode_reader.Call(), list_height, rows := this.GetListRows(field)
        if field.type = "list" {
            control := this.AddListBox("x0 y0 w100 r" . rows . " Hidden", [])
        } else {
            control := this.AddListView(
                "x0 y0 w100 r" . rows . " Hidden" . (dark_mode ? " -Hdr" : ""),
                [RabbitI18n.Text("controls.accept"), RabbitI18n.Text("controls.when"), RabbitI18n.Text("controls.action")]
            )
        }
        control.GetPos(, , , &list_height)
        if field.type = "key_binding_list" && dark_mode {
            list_height += 24
        }
        return list_height + 86
    }

    GetListRows(field) {
        local rows := HasProp(field, "rows") ? field.rows : RabbitSchemaSettingsManifest.DEFAULT_LIST_ROWS
        if Type(rows) != "Integer" || rows < RabbitSchemaSettingsManifest.MIN_LIST_ROWS
            || rows > RabbitSchemaSettingsManifest.MAX_LIST_ROWS {
            return RabbitSchemaSettingsManifest.DEFAULT_LIST_ROWS
        }
        return rows
    }

    AddOuterMutedText(options, value) {
        local control := this.AddText(options, value)
        this.outer_muted_controls.Push(control)
        return control
    }

    OnGroupChanged() {
        return this.SelectGroup(this.group_list.Value)
    }

    SelectGroup(index) {
        if index < 1 || index > this.groups.Length {
            return false
        }
        this.CaptureCurrentGroupValues()
        this.current_group_index := index
        if this.group_list && this.group_list.Value != index {
            this.group_list.Choose(index)
        }
        this.CreateContentPanel()
        return true
    }

    CreateContentPanel() {
        local factory, group := this.groups[this.current_group_index]
        local initial_dark_mode := this.window_theme.dark_mode, y := 12
        this.DestroyContentPanel()
        this.field_controls := Map()
        this.content_control_hwnds := Map()
        this.content_controls := []
        this.content_list_hwnds := Map()
        this.content_muted_controls := []
        this.content_surface_controls := []
        this.content_gui := Gui("+Parent" . this.Hwnd . " -Caption +0x200000", "")
        this.content_gui.MarginX := 12
        this.content_gui.MarginY := 12
        if initial_dark_mode {
            this.content_gui.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.content_gui.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )
        if group.description {
            y += this.AddContentDescription(y, group.description) + 10
        }
        for field in this.model.manifest.fields {
            if field.group = group.id {
                y := this.AddField(field, y)
            }
        }
        factory := this.theme_factory
        this.content_window_theme := factory(this.content_gui, this.dark_mode_reader)
        if this.content_muted_controls.Length {
            this.content_window_theme.RegisterMuted(this.content_muted_controls*)
        }
        if this.content_surface_controls.Length {
            this.content_window_theme.RegisterSurface(this.content_surface_controls*)
        }
        this.content_window_theme.Register()
        this.content_gui.Show(this.ContentPanelOptions() . " Hide")
        this.ConfigureContentScroll()
        if this.visible {
            this.ShowContentPanel()
        }
    }

    DestroyContentPanel() {
        if this.content_gui {
            OnMessage(RabbitSchemaSettingsDialog.WM_VSCROLL, this.content_scroll_callback, 0)
            OnMessage(RabbitSchemaSettingsDialog.WM_MOUSEWHEEL, this.content_wheel_callback, 0)
        }
        try {
            if this.content_window_theme {
                this.content_window_theme.Dispose()
            }
        } finally {
            this.content_window_theme := 0
            if this.content_gui {
                this.content_gui.Destroy()
                this.content_gui := 0
            }
        }
    }

    AddField(field, y) {
        local control, control_width := this.content_width - 196
        if field.type = "boolean" {
            control := this.content_gui.AddCheckbox("x12 y" . y . " w" . (this.content_width - 24) . " h24", field.label)
            control.Value := this.draft_values[field.id]
            this.TrackContentControl(control)
            this.field_controls[field.id] := control
            y += 28
        } else if field.type = "list" || field.type = "key_binding_list" {
            y := this.AddListField(field, y)
        } else {
            control := this.content_gui.AddText("x12 y" . y . " w170 h24 +0x200", field.label)
            this.TrackContentControl(control)
            if field.type = "enum" {
                control := this.content_gui.AddDropDownList("x184 y" . y . " w" . control_width, field.options)
                control.Text := this.draft_values[field.id]
            } else {
                control := this.content_gui.AddEdit(
                    "x184 y" . y . " w" . control_width . " r1 -Multi",
                    this.draft_values[field.id]
                )
            }
            this.TrackContentControl(control)
            this.field_controls[field.id] := control
            y += 30
        }
        if field.description {
            y += this.AddContentDescription(y, field.description) + 4
        }
        return y + 6
    }

    AddListField(field, y) {
        local controls := { type: field.type }
        local button_y, list_height, reset_y
        local rows := this.GetListRows(field)
        local list_y := y + 24
        this.AddContentText("x12 y" . y . " w" . (this.content_width - 24) . " h22 +0x200", field.label)
        if field.type = "list" {
            controls.list := this.content_gui.AddListBox(
                "x12 y" . list_y . " w" . (this.content_width - 24) . " r" . rows,
                []
            )
            controls.list.OnEvent("DoubleClick", (*) => this.EditListItem(field))
        } else {
            if this.window_theme.dark_mode {
                ; Native ListView headers remain light in dark mode, so use themeable Text controls instead.
                this.AddKeyBindingListHeaders(controls, list_y)
                list_y += 24
            }
            controls.list := this.content_gui.AddListView(
                "x12 y" . list_y . " w" . (this.content_width - 24) . " r" . rows
                    . (this.window_theme.dark_mode ? " -Hdr" : "") . " -Multi NoSort",
                [
                    RabbitI18n.Text("controls.accept"),
                    RabbitI18n.Text("controls.when"),
                    RabbitI18n.Text("controls.action"),
                ]
            )
            controls.list.OnEvent("DoubleClick", (ctrl, row) => this.EditListItem(field, row))
        }
        this.TrackScrollableContentControl(controls.list)
        controls.list.GetPos(, , , &list_height)
        reset_y := list_y + list_height + 4
        button_y := reset_y + 22
        controls.reset_hint := this.AddContentMutedText(
            "x12 y" . reset_y . " w" . (this.content_width - 24) . " h18",
            ""
        )
        controls.add_button := this.AddListButton(
            "x12 y" . button_y . " w58 h28 +0x2000",
            RabbitI18n.Text("controls.add"),
            (*) => this.AddListItem(field)
        )
        controls.edit_button := this.AddListButton(
            "x76 y" . button_y . " w58 h28 +0x2000",
            RabbitI18n.Text("controls.edit"),
            (*) => this.EditListItem(field)
        )
        controls.delete_button := this.AddListButton(
            "x140 y" . button_y . " w58 h28 +0x2000",
            RabbitI18n.Text("controls.delete"),
            (*) => this.DeleteListItem(field)
        )
        controls.up_button := this.AddListButton(
            "x204 y" . button_y . " w58 h28 +0x2000",
            RabbitI18n.Text("controls.move_up"),
            (*) => this.MoveListItem(field, -1)
        )
        controls.down_button := this.AddListButton(
            "x268 y" . button_y . " w58 h28 +0x2000",
            RabbitI18n.Text("controls.move_down"),
            (*) => this.MoveListItem(field, 1)
        )
        controls.reset_button := this.AddListButton(
            "x332 y" . button_y . " w" . (this.content_width - 344) . " h28 +0x2000",
            RabbitI18n.Text("controls.restore_schema_default"),
            (*) => this.RestoreListDefault(field)
        )
        this.field_controls[field.id] := controls
        this.RefreshListField(field)
        return button_y + 36
    }

    AddKeyBindingListHeaders(controls, y) {
        local surface_options := " c" . RabbitWindowThemeController.DARK_TEXT
            . " Background" . RabbitWindowThemeController.DARK_SURFACE
        controls.accept_header := this.AddContentSurfaceText(
            "x12 y" . y . " w136 h24 +0x200" . surface_options,
            "  " . RabbitI18n.Text("controls.accept")
        )
        controls.when_header := this.AddContentSurfaceText(
            "x148 y" . y . " w96 h24 +0x200" . surface_options,
            "  " . RabbitI18n.Text("controls.when")
        )
        controls.action_header := this.AddContentSurfaceText(
            "x244 y" . y . " w" . (this.content_width - 280) . " h24 +0x200" . surface_options,
            "  " . RabbitI18n.Text("controls.action")
        )
    }

    AddContentText(options, value) {
        local control := this.content_gui.AddText(options, value)
        this.TrackContentControl(control)
        return control
    }

    AddContentSurfaceText(options, value) {
        local control := this.content_gui.AddText(options, value)
        this.TrackContentControl(control)
        this.content_surface_controls.Push(control)
        return control
    }

    AddListButton(options, label, callback) {
        local control := this.content_gui.AddButton(options, label)
        this.TrackContentControl(control)
        control.OnEvent("Click", callback)
        return control
    }

    RefreshListField(field, selected_row := 0) {
        local action_key, action_value, binding, controls := this.field_controls[field.id]
        local item, row
        controls.list.Delete()
        if field.type = "list" {
            for item in this.draft_values[field.id] {
                controls.list.Add([item])
            }
            if selected_row && selected_row <= this.draft_values[field.id].Length {
                controls.list.Choose(selected_row)
            }
        } else {
            for binding in this.draft_values[field.id] {
                action_key := RabbitKeyBindingDialog.FindAction(binding, &action_value)
                row := controls.list.Add(
                    "",
                    binding.Has("accept") ? this.ListValueText(binding["accept"]) : "",
                    binding.Has("when") ? this.ListValueText(binding["when"]) : "",
                    action_key ? action_key . ": " . this.ListValueText(action_value) : ""
                )
            }
            controls.list.ModifyCol(1, 136)
            controls.list.ModifyCol(2, 96)
            controls.list.ModifyCol(3, this.content_width - 280)
            if selected_row && selected_row <= this.draft_values[field.id].Length {
                controls.list.Modify(selected_row, "Select Focus Vis")
            }
        }
        this.UpdateListResetState(field)
    }

    ListValueText(value) {
        return value is Map || value is Array ? "…" : String(value)
    }

    SelectedListRow(field) {
        local controls := this.field_controls[field.id]
        return field.type = "key_binding_list" ? controls.list.GetNext(0) : controls.list.Value
    }

    AddListItem(field) {
        local item
        if field.type = "list" {
            item := RabbitStringListItemDialog(this, "", false, this.dark_mode_reader).ShowModal()
        } else {
            item := RabbitKeyBindingDialog(this, 0, this.dark_mode_reader).ShowModal()
        }
        if !item {
            return false
        }
        this.CancelListReset(field)
        this.draft_values[field.id].Push(field.type = "list" ? item["value"] : item)
        this.RefreshListField(field, this.draft_values[field.id].Length)
        return true
    }

    EditListItem(field, row := 0) {
        local item
        if !row {
            row := this.SelectedListRow(field)
        }
        if row < 1 || row > this.draft_values[field.id].Length {
            return false
        }
        if field.type = "list" {
            item := RabbitStringListItemDialog(
                this,
                this.draft_values[field.id][row],
                true,
                this.dark_mode_reader
            ).ShowModal()
        } else {
            item := RabbitKeyBindingDialog(this, this.draft_values[field.id][row], this.dark_mode_reader).ShowModal()
        }
        if !item {
            return false
        }
        this.CancelListReset(field)
        this.draft_values[field.id][row] := field.type = "list" ? item["value"] : item
        this.RefreshListField(field, row)
        return true
    }

    DeleteListItem(field) {
        local row := this.SelectedListRow(field)
        if row < 1 || row > this.draft_values[field.id].Length {
            return false
        }
        this.CancelListReset(field)
        this.draft_values[field.id].RemoveAt(row)
        this.RefreshListField(field, Min(row, this.draft_values[field.id].Length))
        return true
    }

    MoveListItem(field, offset) {
        local item, row := this.SelectedListRow(field)
        local target := row + offset
        if row < 1 || target < 1 || target > this.draft_values[field.id].Length {
            return false
        }
        this.CancelListReset(field)
        item := this.draft_values[field.id].RemoveAt(row)
        this.draft_values[field.id].InsertAt(target, item)
        this.RefreshListField(field, target)
        return true
    }

    RestoreListDefault(field) {
        this.reset_fields[field.id] := true
        this.UpdateListResetState(field)
        return true
    }

    CancelListReset(field) {
        if this.reset_fields.Has(field.id) {
            this.reset_fields.Delete(field.id)
        }
    }

    UpdateListResetState(field) {
        local controls := this.field_controls[field.id]
        controls.reset_hint.Value := this.reset_fields.Has(field.id)
            ? RabbitI18n.Text("controls.restore_schema_default_pending") : ""
    }

    AddContentMutedText(options, value) {
        local control := this.content_gui.AddText(options, value)
        this.TrackContentControl(control)
        this.content_muted_controls.Push(control)
        return control
    }

    AddContentDescription(y, value) {
        local height := this.MeasureWrappedTextHeight(value, this.content_width - 24)
        this.AddContentMutedText("x12 y" . y . " w" . (this.content_width - 24) . " h" . height, value)
        return height
    }

    TrackContentControl(control) {
        this.content_control_hwnds[control.Hwnd] := true
        this.content_controls.Push(control)
        return control
    }

    TrackScrollableContentControl(control) {
        this.TrackContentControl(control)
        this.content_list_hwnds[control.Hwnd] := true
        return control
    }

    CaptureCurrentGroupValues() {
        local control, field
        if !this.field_controls.Count {
            return
        }
        for field in this.model.manifest.fields {
            if field.group != this.groups[this.current_group_index].id {
                continue
            }
            if field.type = "list" || field.type = "key_binding_list" {
                continue
            }
            control := this.field_controls[field.id]
            this.draft_values[field.id] := field.type = "boolean" ? !!control.Value
                : field.type = "enum" ? control.Text : control.Value
        }
    }

    ContentPanelOptions() {
        local bounds, origin
        if this.content_anchor && (bounds := RabbitDialogPlacement.GetWindowBounds(this.content_anchor.Hwnd)) {
            origin := Point()
            if DllCall("User32\ClientToScreen", "Ptr", this.Hwnd, "Ptr", origin, "Int") {
                return "x" . (bounds.left - origin.x) . " y" . (bounds.top - origin.y)
                    . " w" . this.content_width . " h" . this.content_height
            }
        }
        return "x" . this.content_x . " y" . this.content_y
            . " w" . this.content_width . " h" . this.content_height
    }

    GetContentViewportHeight() {
        local bounds := Buffer(16, 0)
        if this.content_gui && DllCall("User32\GetClientRect", "Ptr", this.content_gui.Hwnd, "Ptr", bounds, "Int") {
            return NumGet(bounds, 12, "Int") - NumGet(bounds, 4, "Int")
        }
        return this.content_height
    }

    MeasureContentVirtualHeight() {
        local bottom := 0, bounds, control, origin := Buffer(8, 0), origin_y
        local bottom_padding := Round(
            RabbitSchemaSettingsDialog.CONTENT_BOTTOM_PADDING * this.GetContentDpiScale()
        )
        if !DllCall("User32\ClientToScreen", "Ptr", this.content_gui.Hwnd, "Ptr", origin, "Int") {
            return this.content_height
        }
        origin_y := NumGet(origin, 4, "Int")
        for control in this.content_controls {
            bounds := Buffer(16, 0)
            if DllCall("User32\GetWindowRect", "Ptr", control.Hwnd, "Ptr", bounds, "Int") {
                bottom := Max(bottom, NumGet(bounds, 12, "Int") - origin_y)
            }
        }
        ; Preserve the minimum trailing space already included by the layout cursor.
        return bottom + bottom_padding
    }

    GetContentDpiScale() {
        local dpi := DllCall("User32\GetDpiForWindow", "Ptr", this.content_gui.Hwnd, "UInt")
        return dpi ? dpi / 96 : 1
    }

    GetContentControlBottom(control) {
        local bounds := Buffer(16, 0), origin := Buffer(8, 0)
        if !this.content_gui
            || !DllCall("User32\ClientToScreen", "Ptr", this.content_gui.Hwnd, "Ptr", origin, "Int")
            || !DllCall("User32\GetWindowRect", "Ptr", control.Hwnd, "Ptr", bounds, "Int") {
            return 0
        }
        return NumGet(bounds, 12, "Int") - NumGet(origin, 4, "Int")
    }

    ShowContentPanel() {
        if this.content_gui {
            ; Recalculate after the child panel receives its final DPI.
            this.content_gui.Show(this.ContentPanelOptions() . " NA")
            this.ConfigureContentScroll()
        }
    }

    ConfigureContentScroll() {
        ; ScrollWindowEx and scroll bars use physical client coordinates after DPI layout.
        this.content_viewport_height := this.GetContentViewportHeight()
        this.content_virtual_height := this.MeasureContentVirtualHeight()
        this.content_scroll_y := 0
        this.content_scroll_max := Max(0, this.content_virtual_height - this.content_viewport_height)
        this.SetContentScrollInfo()
    }

    SetContentScrollInfo() {
        local info
        if !this.content_gui {
            return
        }
        info := Buffer(28, 0)
        NumPut("UInt", info.Size, info, 0)
        NumPut(
            "UInt",
            RabbitSchemaSettingsDialog.SIF_RANGE | RabbitSchemaSettingsDialog.SIF_PAGE
                | RabbitSchemaSettingsDialog.SIF_POS,
            info,
            4
        )
        NumPut("Int", 0, info, 8)
        NumPut("Int", Max(0, this.content_virtual_height - 1), info, 12)
        NumPut("UInt", this.content_viewport_height, info, 16)
        NumPut("Int", this.content_scroll_y, info, 20)
        DllCall("User32\SetScrollInfo", "Ptr", this.content_gui.Hwnd, "Int", RabbitSchemaSettingsDialog.SB_VERT,
            "Ptr", info, "Int", true)
        DllCall(
            "User32\ShowScrollBar",
            "Ptr",
            this.content_gui.Hwnd,
            "Int",
            RabbitSchemaSettingsDialog.SB_VERT,
            "Int",
            this.content_scroll_max > 0
        )
        OnMessage(RabbitSchemaSettingsDialog.WM_VSCROLL, this.content_scroll_callback)
        OnMessage(RabbitSchemaSettingsDialog.WM_MOUSEWHEEL, this.content_wheel_callback)
    }

    OnContentVScroll(w_param, l_param, msg, hwnd) {
        local request, target := this.content_scroll_y
        if !this.content_gui || hwnd != this.content_gui.Hwnd {
            return
        }
        request := w_param & 0xFFFF
        switch request {
            case RabbitSchemaSettingsDialog.SB_LINEUP:
                target -= RabbitSchemaSettingsDialog.CONTENT_SCROLL_LINE
            case RabbitSchemaSettingsDialog.SB_LINEDOWN:
                target += RabbitSchemaSettingsDialog.CONTENT_SCROLL_LINE
            case RabbitSchemaSettingsDialog.SB_PAGEUP:
                target -= this.content_viewport_height
            case RabbitSchemaSettingsDialog.SB_PAGEDOWN:
                target += this.content_viewport_height
            case RabbitSchemaSettingsDialog.SB_THUMBPOSITION, RabbitSchemaSettingsDialog.SB_THUMBTRACK:
                target := this.GetContentTrackPosition()
            case RabbitSchemaSettingsDialog.SB_TOP:
                target := 0
            case RabbitSchemaSettingsDialog.SB_BOTTOM:
                target := this.content_scroll_max
            case RabbitSchemaSettingsDialog.SB_ENDSCROLL:
                return 0
            default:
                return
        }
        this.ScrollContentTo(target)
        return 0
    }

    GetContentTrackPosition() {
        local info := Buffer(28, 0)
        NumPut("UInt", info.Size, info, 0)
        NumPut("UInt", RabbitSchemaSettingsDialog.SIF_TRACKPOS, info, 4)
        if !DllCall(
            "User32\GetScrollInfo",
            "Ptr",
            this.content_gui.Hwnd,
            "Int",
            RabbitSchemaSettingsDialog.SB_VERT,
            "Ptr",
            info,
            "Int"
        ) {
            return this.content_scroll_y
        }
        return NumGet(info, 24, "Int")
    }

    OnContentMouseWheel(w_param, l_param, msg, hwnd) {
        local delta, list_hwnd
        if !this.content_gui {
            return
        }
        ; WM_MOUSEWHEEL is routed to the focused control, not necessarily the one under the pointer.
        if (list_hwnd := this.GetListControlAtWheelPoint(l_param)) {
            if hwnd != list_hwnd {
                DllCall(
                    "User32\SendMessageW",
                    "Ptr",
                    list_hwnd,
                    "UInt",
                    RabbitSchemaSettingsDialog.WM_MOUSEWHEEL,
                    "Ptr",
                    w_param,
                    "Ptr",
                    l_param,
                    "Ptr"
                )
                return 0
            }
            return
        }
        if hwnd != this.content_gui.Hwnd && !this.content_control_hwnds.Has(hwnd) {
            return
        }
        if !this.content_scroll_max {
            return
        }
        delta := (w_param >> 16) & 0xFFFF
        if delta & 0x8000 {
            delta -= 0x10000
        }
        if !delta {
            return 0
        }
        this.ScrollContentTo(
            this.content_scroll_y - Round(delta * RabbitSchemaSettingsDialog.CONTENT_SCROLL_LINE / 120)
        )
        return 0
    }

    GetListControlAtWheelPoint(l_param) {
        local point := Buffer(8, 0), hwnd
        NumPut("Int", this.GetMouseWheelCoordinate(l_param), point, 0)
        NumPut("Int", this.GetMouseWheelCoordinate(l_param, 16), point, 4)
        hwnd := DllCall("User32\WindowFromPoint", "Int64", NumGet(point, 0, "Int64"), "Ptr")
        while hwnd {
            if this.content_list_hwnds.Has(hwnd) {
                return hwnd
            }
            if hwnd = this.content_gui.Hwnd {
                return 0
            }
            hwnd := DllCall("User32\GetParent", "Ptr", hwnd, "Ptr")
        }
        return 0
    }

    GetMouseWheelCoordinate(l_param, shift := 0) {
        local coordinate := (l_param >> shift) & 0xFFFF
        return coordinate & 0x8000 ? coordinate - 0x10000 : coordinate
    }

    ScrollContentTo(position) {
        local target := Min(Max(position, 0), this.content_scroll_max)
        if target = this.content_scroll_y {
            return
        }
        DllCall(
            "User32\ScrollWindowEx",
            "Ptr",
            this.content_gui.Hwnd,
            "Int",
            0,
            "Int",
            this.content_scroll_y - target,
            "Ptr",
            0,
            "Ptr",
            0,
            "Ptr",
            0,
            "Ptr",
            0,
            "UInt",
            RabbitSchemaSettingsDialog.SW_SCROLLCHILDREN | RabbitSchemaSettingsDialog.SW_INVALIDATE
                | RabbitSchemaSettingsDialog.SW_ERASE
        )
        this.content_scroll_y := target
        this.SetContentScrollInfo()
    }

    ShowModal() {
        local hwnd := this.Hwnd
        RabbitDialogPlacement.ShowOnOwnerMonitor(this, this.owner_window.Hwnd, "w" . this.dialog_width
            . " h" . this.dialog_height)
        this.visible := true
        this.ShowContentPanel()
        WinWaitClose("ahk_id " . hwnd)
        return this.result
    }

    SaveSettings() {
        local normalized
        try {
            this.CaptureCurrentGroupValues()
            normalized := this.model.NormalizeValues(this.draft_values)
            this.result := this.model.HasNormalizedChanges(normalized, this.reset_fields)
                ? { values: normalized, reset_fields: this.reset_fields.Clone() } : 0
            this.Dispose()
            return true
        } catch as err {
            this.status.Value := err.Message
            return false
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        this.visible := false
        try {
            this.DestroyContentPanel()
            if this.window_theme {
                this.window_theme.Dispose()
                this.window_theme := 0
            }
        } finally {
            try this.Destroy()
        }
    }
}
