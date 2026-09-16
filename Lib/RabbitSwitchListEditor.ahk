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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#Include RabbitSwitchList.ahk
#Include RabbitWindowTheme.ahk
#Include RabbitI18n.ahk
#Include RabbitConfigToolTip.ahk

; An in-page editor hosted by RabbitSchemaSettingsDialog's scrollable content panel.
; It deliberately keeps entry selection and entry editing in one surface so a switch
; no longer needs its own list dialog followed by a second entry dialog.
class RabbitSwitchListEditor {
    static ESTIMATED_HEIGHT := 410
    static STATE_LIST_ROWS := 4

    __New(owner, field, value, y) {
        local bottom_offset, button_height, button_width, dark_mode := owner.window_theme.dark_mode
        local entry_bottom, entry_height, entry_y, left_bottom_y, list_height, right_bottom
        local rows, state_list_height
        local action_y, left_bottom, notice_width, reset_width, state_button_y, state_editor_y, target_list_height
        if !(value is Array) {
            value := []
        }
        value := RabbitSwitchList.Validate(value)
        this.owner := owner
        this.field := field
        this.x := 12
        this.width := owner.content_width - 24
        this.list_width := Min(190, Max(170, Floor(this.width * 0.38)))
        this.editor_x := this.x + this.list_width + 10
        this.editor_width := this.width - this.list_width - 10
        this.list_column_width := Max(1, this.list_width - 20)
        this.state_list_client_width := Max(1, this.editor_width - 20)
        this.state_option_column_width := Min(86, Max(72, Floor(this.state_list_client_width * 0.29)))
        this.state_abbrev_column_width := Min(92, Max(72, Floor(this.state_list_client_width * 0.30)))
        this.state_state_column_width := this.state_list_client_width - this.state_option_column_width
            - this.state_abbrev_column_width
        this.entries := []
        this.entry_index := 0
        this.entry_original := Map()
        this.kind := RabbitSwitchList.TOGGLE
        this.name_value := ""
        this.options := []
        this.states := []
        this.abbrev := []
        this.reset_value := -1
        this.entry_loading := false
        this.state_editor_row := 0
        this.state_editor_dirty := false
        this.state_editor_loading := false
        this.updating_kind := false
        for entry in value {
            this.entries.Push(RabbitConfigValue.Clone(entry))
        }

        this.label := this.AddText(
            "x" . this.x . " y" . y . " w" . this.list_width . " h22 +0x200",
            field.label
        )
        this.list_y := y + 24
        rows := owner.GetListRows(field)
        this.list := owner.content_gui.AddListView(
            "x" . this.x . " y" . this.list_y . " w" . this.list_width . " r" . rows . " -Hdr -Multi NoSort",
            [""]
        )
        owner.TrackScrollableContentControl(this.list)
        this.list.OnEvent(
            "ItemSelect",
            (ctrl, row, selected) => selected ? this.OnEntrySelected(row) : 0
        )
        this.list.GetPos(, , , &list_height)
        this.toolbar_y := this.list_y + list_height + 6
        button_width := Floor((this.list_width - 6) / 2)
        this.add_button := this.AddButton(
            "x" . this.x . " y" . this.toolbar_y . " w" . button_width . " h28 +0x2000",
            RabbitI18n.Text("controls.add"),
            (*) => this.AddEntry()
        )
        this.delete_button := this.AddButton(
            "x" . (this.x + button_width + 6) . " y" . this.toolbar_y . " w" . button_width . " h28 +0x2000",
            RabbitI18n.Text("controls.delete"),
            (*) => this.DeleteEntry()
        )
        this.up_button := this.AddButton(
            "x" . this.x . " y" . (this.toolbar_y + 34) . " w" . button_width . " h28 +0x2000",
            RabbitI18n.Text("controls.move_up"),
            (*) => this.MoveEntry(-1)
        )
        this.down_button := this.AddButton(
            "x" . (this.x + button_width + 6) . " y" . (this.toolbar_y + 34) . " w" . button_width . " h28 +0x2000",
            RabbitI18n.Text("controls.move_down"),
            (*) => this.MoveEntry(1)
        )
        this.entry_y := y
        this.kind_label := this.AddText(
            "x" . this.editor_x . " y" . (this.entry_y + 4) . " w36 h22",
            RabbitI18n.Text("switch_list.kind")
        )
        this.kind_choice := this.AddControl(owner.content_gui.AddDropDownList(
            "x" . (this.editor_x + 40) . " y" . this.entry_y . " w94",
            [RabbitI18n.Text("switch_list.toggle"), RabbitI18n.Text("switch_list.radio")]
        ))
        this.kind_choice.OnEvent("Change", (*) => this.OnKindChanged())
        this.name_label := this.AddText(
            "x" . (this.editor_x + 140) . " y" . (this.entry_y + 4) . " w38 h22",
            RabbitI18n.Text("switch_list.name")
        )
        this.name_edit := this.AddControl(owner.content_gui.AddEdit(
            "x" . (this.editor_x + 182) . " y" . this.entry_y . " w" . (this.editor_width - 182) . " r1 -Multi"
        ))
        this.state_list_label := this.AddText(
            "x" . this.editor_x . " y" . (this.entry_y + 36) . " w" . this.editor_width . " h22",
            RabbitI18n.Text("switch_list.state_list")
        )
        this.state_list_y := this.entry_y + 60
        if dark_mode {
            this.AddStateListHeaders(this.state_list_y)
            this.state_list_y += 24
        }
        this.state_list := owner.content_gui.AddListView(
            "x" . this.editor_x . " y" . this.state_list_y . " w" . this.editor_width
                . " r" . RabbitSwitchListEditor.STATE_LIST_ROWS . (dark_mode ? " -Hdr" : "") . " -Multi NoSort",
            [
                RabbitI18n.Text("switch_list.option"),
                RabbitI18n.Text("switch_list.state"),
                RabbitI18n.Text("switch_list.abbrev"),
            ]
        )
        owner.TrackScrollableContentControl(this.state_list)
        this.state_list.OnEvent(
            "ItemSelect",
            (ctrl, row, selected) => selected ? this.OnStateSelected(row) : 0
        )
        this.state_list.GetPos(, , , &state_list_height)
        state_button_y := this.state_list_y + state_list_height + 2
        this.add_state_button := this.AddButton(
            "x" . this.editor_x . " y" . state_button_y . " w60 h28 +0x2000",
            RabbitI18n.Text("controls.add"),
            (*) => this.AddState()
        )
        this.delete_state_button := this.AddButton(
            "x" . (this.editor_x + 66) . " y" . state_button_y . " w60 h28 +0x2000",
            RabbitI18n.Text("controls.delete"),
            (*) => this.DeleteState()
        )
        this.up_state_button := this.AddButton(
            "x" . (this.editor_x + 132) . " y" . state_button_y . " w60 h28 +0x2000",
            RabbitI18n.Text("controls.move_up"),
            (*) => this.MoveState(-1)
        )
        this.down_state_button := this.AddButton(
            "x" . (this.editor_x + 198) . " y" . state_button_y . " w60 h28 +0x2000",
            RabbitI18n.Text("controls.move_down"),
            (*) => this.MoveState(1)
        )
        state_editor_y := state_button_y + 30
        this.current_state_label := this.AddText(
            "x" . this.editor_x . " y" . state_editor_y . " w" . this.editor_width . " h22",
            RabbitI18n.Text("switch_list.current_state")
        )
        this.state_option_label := this.AddText(
            "x" . this.editor_x . " y" . (state_editor_y + 28) . " w36 h22",
            RabbitI18n.Text("switch_list.option")
        )
        this.state_option_edit := this.AddControl(owner.content_gui.AddEdit(
            "x" . (this.editor_x + 40) . " y" . (state_editor_y + 24) . " w74 r1 -Multi"
        ))
        this.state_option_edit.OnEvent("Change", (*) => this.MarkStateEditorDirty())
        this.reset_enabled := this.AddControl(owner.content_gui.AddCheckbox(
            "x" . (this.editor_x + 122) . " y" . (state_editor_y + 25) . " w54 h22",
            RabbitI18n.Text("switch_list.reset")
        ))
        this.reset_enabled.OnEvent("Click", (*) => this.OnResetEnabledChanged())
        this.reset_choice := this.AddControl(owner.content_gui.AddDropDownList(
            "x" . (this.editor_x + 180) . " y" . (state_editor_y + 24) . " w" . (this.editor_width - 180),
            []
        ))
        this.reset_choice.OnEvent("Change", (*) => this.CaptureResetChoice())
        this.state_value_label := this.AddText(
            "x" . this.editor_x . " y" . (state_editor_y + 62) . " w36 h22",
            RabbitI18n.Text("switch_list.state")
        )
        this.state_value_edit := this.AddControl(owner.content_gui.AddEdit(
            "x" . (this.editor_x + 40) . " y" . (state_editor_y + 58) . " w74"
                . " r1 -Multi"
        ))
        this.state_value_edit.OnEvent("Change", (*) => this.MarkStateEditorDirty())
        this.state_abbrev_label := this.AddText(
            "x" . (this.editor_x + 122) . " y" . (state_editor_y + 62) . " w36 h22",
            RabbitI18n.Text("switch_list.abbrev")
        )
        this.state_abbrev_edit := this.AddControl(owner.content_gui.AddEdit(
            "x" . (this.editor_x + 162) . " y" . (state_editor_y + 58) . " w" . (this.editor_width - 162)
                . " r1 -Multi"
        ))
        this.state_abbrev_edit.OnEvent("Change", (*) => this.MarkStateEditorDirty())
        this.state_abbrev_edit.GetPos(, &entry_y, , &entry_height)
        entry_bottom := entry_y + entry_height
        right_bottom := entry_bottom
        target_list_height := Max(70, entry_bottom - this.list_y - 68)
        this.list.Move(, , , target_list_height)
        this.list.GetPos(, , , &list_height)
        this.toolbar_y := this.list_y + list_height + 6
        this.add_button.Move(, this.toolbar_y)
        this.delete_button.Move(, this.toolbar_y)
        this.up_button.Move(, this.toolbar_y + 34)
        this.down_button.Move(, this.toolbar_y + 34)
        this.down_button.GetPos(, &left_bottom_y, , &button_height)
        left_bottom := left_bottom_y + button_height
        if (bottom_offset := entry_bottom - left_bottom) {
            this.list.Move(, , , list_height + bottom_offset)
            this.toolbar_y += bottom_offset
            this.add_button.Move(, this.toolbar_y)
            this.delete_button.Move(, this.toolbar_y)
            this.up_button.Move(, this.toolbar_y + 34)
            this.down_button.Move(, this.toolbar_y + 34)
            left_bottom := entry_bottom
        }
        action_y := Max(left_bottom, right_bottom) + 10
        reset_width := Min(176, Max(150, Floor(this.width * 0.38)))
        notice_width := this.width - reset_width - 10
        this.status := this.AddControl(owner.content_gui.AddText(
            "x" . this.x . " y" . (action_y + 4) . " w" . notice_width . " h22 cRed",
            ""
        ))
        this.reset_button := this.AddButton(
            "x" . (this.x + this.width - reset_width) . " y" . action_y . " w" . reset_width . " h28 +0x2000",
            RabbitI18n.Text("controls.restore_schema_default"),
            (*) => this.RestoreDefault()
        )
        this.reset_hint := this.AddMutedText(
            "x" . this.x . " y" . (action_y + 4) . " w" . notice_width . " h22",
            ""
        )
        this.bottom := action_y + 34
        this.entry_form_controls := [
            this.kind_label, this.kind_choice, this.name_label, this.name_edit,
            this.state_list_label, this.state_list, this.add_state_button, this.delete_state_button,
            this.up_state_button, this.down_state_button, this.current_state_label,
            this.state_option_label, this.state_option_edit, this.state_value_label, this.state_value_edit,
            this.state_abbrev_label, this.state_abbrev_edit, this.reset_enabled, this.reset_choice, this.status
        ]
        if dark_mode {
            this.entry_form_controls.Push(this.state_option_header, this.state_state_header, this.state_abbrev_header)
        }
        RabbitConfigToolTip.Apply(
            owner.ConfigId(),
            field.path,
            this.label,
            this.list,
            this.add_button,
            this.delete_button,
            this.up_button,
            this.down_button,
            this.reset_button,
            this.reset_hint
        )
        this.RefreshResetState()
        this.RefreshEntryList(this.entries.Length ? 1 : 0)
    }

    AddControl(control) {
        this.owner.TrackContentControl(control)
        return control
    }

    AddText(options, value) {
        return this.owner.AddContentText(options, value)
    }

    AddMutedText(options, value) {
        return this.owner.AddContentMutedText(options, value)
    }

    AddButton(options, value, callback) {
        return this.owner.AddListButton(options, value, callback)
    }

    AddStateListHeaders(y) {
        local state_x := this.editor_x + this.state_option_column_width
        local abbrev_x := state_x + this.state_state_column_width
        this.state_option_header := this.owner.AddContentSurfaceText(
            "x" . this.editor_x . " y" . y . " w" . this.state_option_column_width . " h24 +0x200 c"
                . RabbitWindowThemeController.DARK_TEXT
                . " Background" . RabbitWindowThemeController.DARK_SURFACE,
            "  " . RabbitI18n.Text("switch_list.option")
        )
        this.state_state_header := this.owner.AddContentSurfaceText(
            "x" . state_x . " y" . y . " w" . this.state_state_column_width . " h24 +0x200 c"
                . RabbitWindowThemeController.DARK_TEXT . " Background" . RabbitWindowThemeController.DARK_SURFACE,
            "  " . RabbitI18n.Text("switch_list.state")
        )
        this.state_abbrev_header := this.owner.AddContentSurfaceText(
            "x" . abbrev_x . " y" . y . " w" . this.state_abbrev_column_width . " h24 +0x200 c"
                . RabbitWindowThemeController.DARK_TEXT
                . " Background" . RabbitWindowThemeController.DARK_SURFACE,
            "  " . RabbitI18n.Text("switch_list.abbrev")
        )
    }

    RefreshEntryList(selected_row := 0) {
        local entry
        this.entry_loading := true
        this.list.Delete()
        try {
            for entry in this.entries {
                this.list.Add(
                    "",
                    this.EntrySummary(entry)
                )
            }
            this.list.ModifyCol(1, this.list_column_width)
            selected_row := Min(Max(selected_row, 0), this.entries.Length)
            if selected_row {
                this.list.Modify(selected_row, "Select Focus Vis")
            }
        } finally {
            this.entry_loading := false
        }
        if selected_row {
            this.LoadEntry(selected_row)
        } else {
            this.ClearEntry()
        }
    }

    UpdateEntryListRow(row) {
        local entry
        if row < 1 || row > this.entries.Length || row > this.list.GetCount() {
            return
        }
        entry := this.entries[row]
        this.list.Modify(
            row,
            "",
            this.EntrySummary(entry)
        )
    }

    EntrySummary(entry) {
        return RabbitSwitchList.TypeLabel(entry) . " · " . RabbitSwitchList.OptionSummary(entry)
    }

    OnEntrySelected(row) {
        if this.entry_loading || row < 1 || row > this.entries.Length || row = this.entry_index {
            return
        }
        if !this.CommitEntry() {
            this.RestoreEntrySelection()
            return
        }
        this.LoadEntry(row)
    }

    RestoreEntrySelection() {
        if !this.entry_index {
            return
        }
        this.entry_loading := true
        try this.list.Modify(this.entry_index, "Select Focus Vis")
        finally this.entry_loading := false
    }

    LoadEntry(row) {
        local entry
        if row < 1 || row > this.entries.Length {
            this.ClearEntry()
            return
        }
        entry := this.entries[row]
        this.entry_loading := true
        try {
            this.entry_index := row
            this.entry_original := RabbitConfigValue.Clone(entry)
            this.kind := RabbitSwitchList.Kind(entry)
            this.name_value := entry.Has("name") ? entry["name"] : ""
            this.options := entry.Has("options") ? RabbitConfigValue.Clone(entry["options"]) : []
            this.states := RabbitConfigValue.Clone(RabbitSwitchList.States(entry))
            this.abbrev := RabbitConfigValue.Clone(RabbitSwitchList.Abbreviations(entry))
            this.reset_value := RabbitSwitchList.Reset(entry)
            if this.kind = RabbitSwitchList.TOGGLE {
                while this.states.Length < 2 {
                    this.states.Push("")
                }
            }
            this.kind_choice.Choose(this.kind = RabbitSwitchList.TOGGLE ? 1 : 2)
            this.name_edit.Value := this.name_value
            this.state_editor_row := 0
            this.state_editor_dirty := false
            this.SetStatus()
        } finally {
            this.entry_loading := false
        }
        this.SetEntryFormVisible(true)
        this.UpdateKindControls()
        this.UpdateEntryToolTips()
    }

    ClearEntry() {
        this.entry_index := 0
        this.entry_original := Map()
        this.kind := RabbitSwitchList.TOGGLE
        this.options := []
        this.states := []
        this.abbrev := []
        this.reset_value := -1
        this.state_editor_row := 0
        this.state_editor_dirty := false
        this.state_editor_loading := true
        try {
            this.name_edit.Value := ""
            this.state_list.Delete()
            this.reset_choice.Delete()
            this.SetStatus()
        } finally {
            this.state_editor_loading := false
        }
        this.SetEntryFormVisible(false)
    }

    SetEntryFormVisible(visible) {
        local control
        for control in this.entry_form_controls {
            control.Visible := visible
        }
        if visible {
            this.name_label.Visible := this.kind = RabbitSwitchList.TOGGLE
            this.name_edit.Visible := this.kind = RabbitSwitchList.TOGGLE
            this.add_state_button.Visible := this.kind = RabbitSwitchList.RADIO
            this.delete_state_button.Visible := this.kind = RabbitSwitchList.RADIO
            this.up_state_button.Visible := this.kind = RabbitSwitchList.RADIO
            this.down_state_button.Visible := this.kind = RabbitSwitchList.RADIO
        }
    }

    AddEntry() {
        if !this.CommitEntry() {
            return false
        }
        this.entries.Push(Map("name", "", "states", ["", ""]))
        this.NotifyEntriesChanged()
        this.RefreshEntryList(this.entries.Length)
        return true
    }

    DeleteEntry() {
        local row := this.entry_index
        if row < 1 || row > this.entries.Length {
            this.SetStatus(RabbitI18n.Text("switch_list.select_entry"))
            return false
        }
        this.entries.RemoveAt(row)
        this.NotifyEntriesChanged()
        this.RefreshEntryList(Min(row, this.entries.Length))
        return true
    }

    MoveEntry(offset) {
        local entry, row := this.entry_index, target := row + offset
        if row < 1 || target < 1 || target > this.entries.Length {
            return false
        }
        if !this.CommitEntry() {
            return false
        }
        entry := this.entries.RemoveAt(row)
        this.entries.InsertAt(target, entry)
        this.NotifyEntriesChanged()
        this.RefreshEntryList(target)
        return true
    }

    CommitEntry(show_error := true) {
        local item
        if !this.entry_index {
            return true
        }
        if !this.CommitStateEditor(show_error) {
            return false
        }
        try {
            item := RabbitSwitchList.Validate([this.BuildValue()])[1]
        } catch as err {
            if show_error {
                this.SetStatus(err.Message)
            }
            return false
        }
        this.entries[this.entry_index] := item
        this.NotifyEntriesChanged()
        this.UpdateEntryListRow(this.entry_index)
        this.SetStatus()
        return true
    }

    NotifyEntriesChanged() {
        this.owner.CancelSwitchListReset(this.field)
        this.owner.draft_values[this.field.id] := RabbitConfigValue.Clone(this.entries)
        this.RefreshResetState()
    }

    RestoreDefault() {
        this.owner.reset_fields[this.field.id] := true
        this.SetStatus()
        this.RefreshResetState()
        return true
    }

    RefreshResetState() {
        this.reset_hint.Value := this.owner.reset_fields.Has(this.field.id)
            ? RabbitI18n.Text("controls.restore_schema_default_pending") : ""
        this.reset_hint.Visible := !this.status.Value
    }

    SetStatus(value := "") {
        this.status.Value := value
        this.status.Visible := !!value
        this.reset_hint.Visible := !value
    }

    OnKindChanged() {
        local kind := this.kind_choice.Value = 1 ? RabbitSwitchList.TOGGLE : RabbitSwitchList.RADIO
        if this.entry_loading || this.updating_kind || kind = this.kind {
            return
        }
        if !this.CommitStateEditor() {
            this.updating_kind := true
            try this.kind_choice.Choose(this.kind = RabbitSwitchList.TOGGLE ? 1 : 2)
            finally this.updating_kind := false
            return
        }
        if this.kind = RabbitSwitchList.TOGGLE {
            this.name_value := this.name_edit.Value
        }
        this.CaptureResetChoice()
        if kind = RabbitSwitchList.RADIO {
            this.options := this.name_value ? [this.name_value] : [""]
            this.states := this.TakeFirstStates(1)
            this.abbrev := this.TakeFirstAbbreviations(1)
            if this.reset_value > 0 {
                this.reset_value := -1
            }
        } else {
            this.name_value := this.options.Length ? this.options[1] : ""
            this.states := this.TakeFirstStates(2)
            while this.states.Length < 2 {
                this.states.Push("")
            }
            this.abbrev := this.TakeFirstAbbreviations(2)
            while this.abbrev.Length < 2 {
                this.abbrev.Push("")
            }
            if this.reset_value > 1 {
                this.reset_value := -1
            }
        }
        this.kind := kind
        this.UpdateKindControls()
    }

    TakeFirstStates(count) {
        local result := [], index, value
        for index, value in this.states {
            if index > count {
                break
            }
            result.Push(value)
        }
        return result
    }

    TakeFirstAbbreviations(count) {
        local result := [], index, value
        for index, value in this.abbrev {
            if index > count {
                break
            }
            result.Push(value)
        }
        return result
    }

    UpdateKindControls() {
        local toggle := this.kind = RabbitSwitchList.TOGGLE
        this.name_label.Value := RabbitI18n.Text("switch_list.name")
        this.name_label.Visible := toggle
        this.name_edit.Visible := toggle
        this.add_state_button.Visible := !toggle
        this.delete_state_button.Visible := !toggle
        this.up_state_button.Visible := !toggle
        this.down_state_button.Visible := !toggle
        this.state_option_edit.Enabled := !toggle
        this.RefreshStateList()
    }

    RefreshStateList(selected_row := 0) {
        local abbrev, count, index, option, state
        this.state_editor_loading := true
        this.state_list.Delete()
        try {
            if this.kind = RabbitSwitchList.TOGGLE {
                Loop 2 {
                    index := A_Index
                    state := index <= this.states.Length ? this.states[index] : ""
                    abbrev := index <= this.abbrev.Length ? this.abbrev[index] : ""
                    this.state_list.Add("", String(index - 1), state, abbrev)
                }
            } else {
                for index, option in this.options {
                    state := index <= this.states.Length ? this.states[index] : ""
                    abbrev := index <= this.abbrev.Length ? this.abbrev[index] : ""
                    this.state_list.Add("", option, state, abbrev)
                }
            }
            this.state_list.ModifyCol(1, this.state_option_column_width)
            this.state_list.ModifyCol(2, this.state_state_column_width)
            this.state_list.ModifyCol(3, this.state_abbrev_column_width)
            count := this.state_list.GetCount()
            if !selected_row {
                selected_row := this.state_editor_row
            }
            selected_row := Min(Max(selected_row, count ? 1 : 0), count)
            this.state_editor_row := selected_row
            if selected_row {
                this.state_list.Modify(selected_row, "Select Focus Vis")
            }
        } finally {
            this.state_editor_loading := false
        }
        if this.state_editor_row {
            this.LoadStateEditor(this.state_editor_row)
        } else {
            this.ClearStateEditor()
        }
        this.RefreshResetChoice()
    }

    OnStateSelected(row) {
        if this.state_editor_loading || row < 1 || row > this.StateCount() || row = this.state_editor_row {
            return
        }
        if !this.CommitStateEditor() {
            this.state_editor_loading := true
            try this.state_list.Modify(this.state_editor_row, "Select Focus Vis")
            finally this.state_editor_loading := false
            return
        }
        this.LoadStateEditor(row)
    }

    LoadStateEditor(row) {
        local abbrev := "", option := "", state := ""
        if row < 1 || row > this.StateCount() {
            this.ClearStateEditor()
            return
        }
        option := this.kind = RabbitSwitchList.RADIO ? this.options[row] : String(row - 1)
        state := row <= this.states.Length ? this.states[row] : ""
        abbrev := row <= this.abbrev.Length ? this.abbrev[row] : ""
        this.state_editor_loading := true
        try {
            this.state_editor_row := row
            this.state_option_edit.Value := option
            this.state_option_edit.Enabled := this.kind = RabbitSwitchList.RADIO
            this.state_value_edit.Value := state
            this.state_abbrev_edit.Value := abbrev
            this.state_editor_dirty := false
        } finally {
            this.state_editor_loading := false
        }
        this.UpdateEntryToolTips()
    }

    ClearStateEditor() {
        this.state_editor_loading := true
        try {
            this.state_editor_row := 0
            this.state_option_edit.Value := ""
            this.state_option_edit.Enabled := false
            this.state_value_edit.Value := ""
            this.state_abbrev_edit.Value := ""
            this.state_editor_dirty := false
        } finally {
            this.state_editor_loading := false
        }
        this.UpdateEntryToolTips()
    }

    MarkStateEditorDirty() {
        if this.state_editor_loading {
            return
        }
        this.state_editor_dirty := true
        this.SyncStateEditor()
    }

    SyncStateEditor() {
        local row := this.state_editor_row
        if !row {
            return
        }
        this.CaptureResetChoice()
        while this.states.Length < row {
            this.states.Push("")
        }
        while this.abbrev.Length < row {
            this.abbrev.Push("")
        }
        this.states[row] := this.state_value_edit.Value
        this.abbrev[row] := this.state_abbrev_edit.Value
        if this.kind = RabbitSwitchList.RADIO {
            this.options[row] := this.state_option_edit.Value
        }
        this.UpdateStateListRow(row)
        this.RefreshResetChoice()
        this.UpdateEntryToolTips()
    }

    CommitStateEditor(show_error := true) {
        return !this.state_editor_dirty || this.ApplyStateEdit(show_error)
    }

    ApplyStateEdit(show_error := true) {
        local abbrev, option, row := this.state_editor_row, state
        if !row {
            return true
        }
        this.SyncStateEditor()
        option := this.state_option_edit.Value
        state := this.state_value_edit.Value
        abbrev := this.state_abbrev_edit.Value
        try {
            if this.kind = RabbitSwitchList.RADIO {
                option := RabbitSwitchList.ValidateText(option, "switch_list.option_invalid")
                if !Trim(option) {
                    throw ValueError(RabbitI18n.Text("switch_list.option_required"))
                }
                if this.HasOption(option, row) {
                    throw ValueError(RabbitI18n.Text("switch_list.option_duplicate"))
                }
            }
            state := RabbitSwitchList.ValidateText(state, "switch_list.state_invalid")
            if !Trim(state) {
                throw ValueError(RabbitI18n.Text("switch_list.state_required"))
            }
            abbrev := RabbitSwitchList.ValidateText(abbrev, "switch_list.abbrev_invalid")
        } catch as err {
            if show_error {
                this.SetStatus(err.Message)
            }
            return false
        }
        while this.states.Length < row {
            this.states.Push("")
        }
        while this.abbrev.Length < row {
            this.abbrev.Push("")
        }
        this.states[row] := state
        this.abbrev[row] := abbrev
        if this.kind = RabbitSwitchList.RADIO {
            this.options[row] := option
        }
        this.state_editor_dirty := false
        this.UpdateStateListRow(row)
        this.RefreshResetChoice()
        this.SetStatus()
        return true
    }

    UpdateStateListRow(row) {
        local abbrev, option, state
        if row < 1 || row > this.state_list.GetCount() {
            return
        }
        option := this.kind = RabbitSwitchList.RADIO ? this.options[row] : String(row - 1)
        state := row <= this.states.Length ? this.states[row] : ""
        abbrev := row <= this.abbrev.Length ? this.abbrev[row] : ""
        this.state_list.Modify(row, "", option, state, abbrev)
    }

    RefreshResetChoice() {
        local choices := [], index, selected, state, was_loading := this.state_editor_loading
        if !this.entry_index {
            return
        }
        this.state_editor_loading := true
        try {
            Loop this.StateCount() {
                index := A_Index
                state := index <= this.states.Length ? this.states[index] : ""
                choices.Push(state ? state : Format("{} {}", RabbitI18n.Text("switch_list.state"), index))
            }
            this.reset_choice.Delete()
            this.reset_choice.Add(choices)
            this.reset_enabled.Value := this.reset_value >= 0
            this.reset_choice.Enabled := this.reset_enabled.Value
            selected := this.reset_value >= 0 && this.reset_value < this.StateCount() ? this.reset_value + 1 : 1
            if choices.Length {
                this.reset_choice.Choose(selected)
            }
        } finally {
            this.state_editor_loading := was_loading
        }
    }

    OnResetEnabledChanged() {
        this.reset_choice.Enabled := !!this.reset_enabled.Value
        if !this.reset_enabled.Value {
            this.reset_value := -1
            return
        }
        if this.reset_choice.Value < 1 {
            this.reset_choice.Choose(1)
        }
        this.CaptureResetChoice()
    }

    StateCount() {
        return this.kind = RabbitSwitchList.TOGGLE ? 2 : this.options.Length
    }

    CaptureResetChoice() {
        if this.state_editor_loading {
            return
        }
        if !this.reset_enabled || !this.reset_enabled.Value {
            this.reset_value := -1
        } else if !this.reset_choice || this.reset_choice.Value < 1 {
            this.reset_value := -1
        } else {
            this.reset_value := this.reset_choice.Value - 1
        }
    }

    UpdateEntryToolTips() {
        local entry_path, option_path, state_path
        if !this.entry_index {
            return
        }
        entry_path := this.field.path . "/@" . (this.entry_index - 1)
        RabbitConfigToolTip.Apply(this.owner.ConfigId(), entry_path, this.kind_label, this.kind_choice)
        RabbitConfigToolTip.Apply(this.owner.ConfigId(), entry_path . "/name", this.name_label, this.name_edit)
        RabbitConfigToolTip.Apply(
            this.owner.ConfigId(),
            entry_path . "/states",
            this.state_list_label,
            this.state_list,
            this.add_state_button,
            this.delete_state_button,
            this.up_state_button,
            this.down_state_button,
            this.current_state_label
        )
        if HasProp(this, "state_option_header") {
            RabbitConfigToolTip.Apply(
                this.owner.ConfigId(),
                entry_path . "/states",
                this.state_option_header,
                this.state_state_header,
                this.state_abbrev_header
            )
        }
        if this.state_editor_row {
            state_path := entry_path . "/states/@" . (this.state_editor_row - 1)
            option_path := this.kind = RabbitSwitchList.RADIO
                ? entry_path . "/options/@" . (this.state_editor_row - 1) : state_path
            RabbitConfigToolTip.Apply(
                this.owner.ConfigId(),
                option_path,
                this.state_option_label,
                this.state_option_edit
            )
            RabbitConfigToolTip.Apply(this.owner.ConfigId(), state_path, this.state_value_label, this.state_value_edit)
            RabbitConfigToolTip.Apply(
                this.owner.ConfigId(),
                entry_path . "/abbrev/@" . (this.state_editor_row - 1),
                this.state_abbrev_label,
                this.state_abbrev_edit
            )
        }
        RabbitConfigToolTip.Apply(
            this.owner.ConfigId(),
            entry_path . "/reset",
            this.reset_enabled,
            this.reset_choice
        )
    }

    AddState() {
        if this.kind != RabbitSwitchList.RADIO {
            return false
        }
        if !this.CommitStateEditor() {
            return false
        }
        this.options.Push("")
        this.states.Push("")
        this.abbrev.Push("")
        this.SetStatus()
        this.RefreshStateList(this.options.Length)
        return true
    }

    DeleteState() {
        local row := this.state_list.GetNext(0)
        if this.kind != RabbitSwitchList.RADIO {
            return false
        }
        if row < 1 || row > this.options.Length {
            this.SetStatus(RabbitI18n.Text("switch_list.select_state"))
            return false
        }
        this.state_editor_dirty := false
        this.options.RemoveAt(row)
        if row <= this.states.Length {
            this.states.RemoveAt(row)
        }
        if row <= this.abbrev.Length {
            this.abbrev.RemoveAt(row)
        }
        if this.reset_value = row - 1 {
            this.reset_value := -1
        } else if this.reset_value > row - 1 {
            this.reset_value -= 1
        }
        this.SetStatus()
        this.RefreshStateList(Min(row, this.options.Length))
        return true
    }

    MoveState(offset) {
        local row := this.state_list.GetNext(0), target := row + offset, value
        if this.kind != RabbitSwitchList.RADIO || row < 1 || target < 1 || target > this.options.Length {
            return false
        }
        if !this.CommitStateEditor() {
            return false
        }
        while this.states.Length < this.options.Length {
            this.states.Push("")
        }
        while this.abbrev.Length < this.options.Length {
            this.abbrev.Push("")
        }
        value := this.options.RemoveAt(row)
        this.options.InsertAt(target, value)
        this.MoveArrayItem(this.states, row, target)
        this.MoveArrayItem(this.abbrev, row, target)
        if this.reset_value = row - 1 {
            this.reset_value := target - 1
        } else if this.reset_value = target - 1 {
            this.reset_value := row - 1
        }
        this.RefreshStateList(target)
        return true
    }

    MoveArrayItem(values, row, target) {
        local value
        if row > values.Length || target > values.Length {
            return
        }
        value := values.RemoveAt(row)
        values.InsertAt(target, value)
    }

    HasOption(option, except_row := 0) {
        local index, value
        for index, value in this.options {
            if index != except_row && value = option {
                return true
            }
        }
        return this.kind = RabbitSwitchList.TOGGLE && this.name_value = option
    }

    BuildValue() {
        local item := RabbitConfigValue.Clone(this.entry_original)
        if this.kind = RabbitSwitchList.TOGGLE {
            item["name"] := this.name_edit.Value
            if item.Has("options") {
                item.Delete("options")
            }
        } else {
            item["options"] := RabbitConfigValue.Clone(this.options)
            if item.Has("name") {
                item.Delete("name")
            }
        }
        item["states"] := RabbitConfigValue.Clone(this.states)
        if this.HasAbbreviation() {
            item["abbrev"] := RabbitConfigValue.Clone(this.abbrev)
        } else if item.Has("abbrev") {
            item.Delete("abbrev")
        }
        if this.reset_value >= 0 {
            item["reset"] := this.reset_value
        } else if item.Has("reset") {
            item.Delete("reset")
        }
        return item
    }

    HasAbbreviation() {
        local value
        for value in this.abbrev {
            if value != "" {
                return true
            }
        }
        return false
    }
}
