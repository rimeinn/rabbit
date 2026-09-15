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

#Include RabbitDialogPlacement.ahk
#Include RabbitPunctuatorMap.ahk
#Include RabbitStringListItemDialog.ahk
#Include RabbitWindowTheme.ahk

#Include RabbitI18n.ahk

class RabbitPunctuatorMapDialog extends Gui {
    static WINDOW_WIDTH := 640
    static WINDOW_HEIGHT := 470

    __New(
        owner,
        path,
        value := 0,
        rime_api := 0,
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local definition, entry, factory, initial_dark_mode := false
        if !RabbitPunctuatorMap.IsEditablePath(path) {
            throw ValueError(RabbitI18n.Text("punctuator.map_invalid"))
        }
        if !(value is Map) {
            value := Map()
        }
        value := RabbitPunctuatorMap.Validate(value, path)
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        super.__New(
            "+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox",
            RabbitI18n.Text("punctuator.editor_title", Map("map", RabbitPunctuatorMap.PathLabel(path))),
            this
        )
        this.owner_window := owner
        this.path := path
        this.rime_api := rime_api
        this.entries := []
        for definition, entry in value {
            this.entries.Push({key: definition, value: RabbitConfigValue.Clone(entry)})
        }
        this.result := 0
        this.disposed := false
        this.MarginX := 20
        this.MarginY := 18
        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )

        this.AddText(
            "x20 y18 w590 h38",
            RabbitI18n.Text("punctuator.editor_hint", Map("map", RabbitPunctuatorMap.PathLabel(path)))
        )
        this.list := this.AddListView(
            "x20 y64 w600 h280 -Multi NoSort" . (initial_dark_mode ? " -Hdr" : ""),
            [
                RabbitI18n.Text("punctuator.trigger"),
                RabbitI18n.Text("punctuator.definition_type"),
                RabbitI18n.Text("punctuator.output"),
            ]
        )
        this.list.OnEvent("DoubleClick", (ctrl, row) => this.EditEntry(row))
        if initial_dark_mode {
            this.trigger_header := this.AddText(
                "x20 y64 w132 h24 +0x200 c" . RabbitWindowThemeController.DARK_TEXT
                    . " Background" . RabbitWindowThemeController.DARK_SURFACE,
                "  " . RabbitI18n.Text("punctuator.trigger")
            )
            this.type_header := this.AddText(
                "x152 y64 w126 h24 +0x200 c" . RabbitWindowThemeController.DARK_TEXT
                    . " Background" . RabbitWindowThemeController.DARK_SURFACE,
                "  " . RabbitI18n.Text("punctuator.definition_type")
            )
            this.output_header := this.AddText(
                "x278 y64 w342 h24 +0x200 c" . RabbitWindowThemeController.DARK_TEXT
                    . " Background" . RabbitWindowThemeController.DARK_SURFACE,
                "  " . RabbitI18n.Text("punctuator.output")
            )
        }
        this.add_button := this.AddButton("x20 y354 w78 h32 +0x2000", RabbitI18n.Text("controls.add"))
        this.add_button.OnEvent("Click", (*) => this.AddEntry())
        this.edit_button := this.AddButton("x106 y354 w78 h32 +0x2000", RabbitI18n.Text("controls.edit"))
        this.edit_button.OnEvent("Click", (*) => this.EditEntry())
        this.delete_button := this.AddButton("x192 y354 w78 h32 +0x2000", RabbitI18n.Text("controls.delete"))
        this.delete_button.OnEvent("Click", (*) => this.DeleteEntry())
        this.status := this.AddText("x20 y398 w600 h24 cRed", "")
        this.save_button := this.AddButton("x452 y430 w80 h32 Default +0x2000", RabbitI18n.Text("common.ok"))
        this.save_button.OnEvent("Click", (*) => this.SaveMap())
        this.cancel_button := this.AddButton("x540 y430 w80 h32 +0x2000", RabbitI18n.Text("common.cancel"))
        this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        factory := theme_factory
        this.window_theme := factory(this, dark_mode_reader)
        this.window_theme.RegisterError(this.status)
        if initial_dark_mode {
            this.window_theme.RegisterSurface(this.list)
            this.window_theme.RegisterSurface(this.trigger_header, this.type_header, this.output_header)
        }
        this.window_theme.Register()
        this.RefreshList()
    }

    ShowModal() {
        RabbitDialogPlacement.ShowOnOwnerMonitor(
            this,
            this.owner_window.Hwnd,
            "w" . RabbitPunctuatorMapDialog.WINDOW_WIDTH . " h" . RabbitPunctuatorMapDialog.WINDOW_HEIGHT
        )
        WinWaitClose("ahk_id " . this.Hwnd)
        return this.result
    }

    RefreshList(selected_row := 0) {
        local entry, row
        this.list.Delete()
        for entry in this.entries {
            row := this.list.Add(
                "",
                entry.key,
                RabbitPunctuatorMap.DefinitionTypeLabel(entry.value),
                RabbitPunctuatorMap.DefinitionSummary(entry.value)
            )
        }
        this.list.ModifyCol(1, 132)
        this.list.ModifyCol(2, 126)
        this.list.ModifyCol(3, 330)
        if selected_row && selected_row <= this.entries.Length {
            this.list.Modify(selected_row, "Select Focus Vis")
        }
    }

    AddEntry() {
        local entry := RabbitPunctuatorEntryDialog(
            this,
            this.path,
            "",
            0,
            this.rime_api,
            this.window_theme.dark_mode_reader
        ).ShowModal()
        if !entry {
            return false
        }
        if this.HasEntryKey(entry.key) {
            this.status.Value := RabbitI18n.Text("punctuator.key_duplicate")
            return false
        }
        this.entries.Push(entry)
        this.status.Value := ""
        this.RefreshList(this.entries.Length)
        return true
    }

    EditEntry(row := 0) {
        local entry, edited
        if !row {
            row := this.list.GetNext(0)
        }
        if row < 1 || row > this.entries.Length {
            this.status.Value := RabbitI18n.Text("punctuator.select_entry")
            return false
        }
        entry := this.entries[row]
        edited := RabbitPunctuatorEntryDialog(
            this,
            this.path,
            entry.key,
            entry.value,
            this.rime_api,
            this.window_theme.dark_mode_reader
        ).ShowModal()
        if !edited {
            return false
        }
        if this.HasEntryKey(edited.key, row) {
            this.status.Value := RabbitI18n.Text("punctuator.key_duplicate")
            return false
        }
        this.entries[row] := edited
        this.status.Value := ""
        this.RefreshList(row)
        return true
    }

    DeleteEntry() {
        local row := this.list.GetNext(0)
        if row < 1 || row > this.entries.Length {
            this.status.Value := RabbitI18n.Text("punctuator.select_entry")
            return false
        }
        this.entries.RemoveAt(row)
        this.status.Value := ""
        this.RefreshList(Min(row, this.entries.Length))
        return true
    }

    HasEntryKey(key, except_row := 0) {
        local index, entry
        for index, entry in this.entries {
            if index != except_row && entry.key = key {
                return true
            }
        }
        return false
    }

    SaveMap() {
        local entry, value := Map()
        for entry in this.entries {
            value[entry.key] := RabbitConfigValue.Clone(entry.value)
        }
        try {
            this.result := RabbitPunctuatorMap.Validate(value, this.path)
        } catch as err {
            this.status.Value := err.Message
            return false
        }
        this.Dispose()
        return true
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
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

class RabbitPunctuatorEntryDialog extends Gui {
    __New(
        owner,
        path,
        key := "",
        definition := 0,
        rime_api := 0,
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local factory, initial_dark_mode := false, type
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        super.__New(
            "+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox",
            definition ? RabbitI18n.Text("punctuator.edit_entry") : RabbitI18n.Text("punctuator.add_entry"),
            this
        )
        this.owner_window := owner
        this.path := path
        this.rime_api := rime_api
        this.original_definition := definition ? RabbitConfigValue.Clone(definition) : 0
        this.result := 0
        this.disposed := false
        this.MarginX := 20
        this.MarginY := 18
        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )

        this.AddText("x20 y22 w110 h22", RabbitI18n.Text("punctuator.trigger"))
        this.key_edit := this.AddEdit("x140 y18 w400 r1", key)
        this.AddText("x20 y60 w110 h22", RabbitI18n.Text("punctuator.definition_type"))
        this.type_values := RabbitPunctuatorMap.TYPE_VALUES
        this.type_labels := [
            RabbitI18n.Text("punctuator.type_direct"),
            RabbitI18n.Text("punctuator.type_list"),
            RabbitI18n.Text("punctuator.type_pair"),
            RabbitI18n.Text("punctuator.type_commit"),
            RabbitI18n.Text("punctuator.type_custom"),
        ]
        this.type_choice := this.AddComboBox("x140 y56 w400", this.type_labels)
        type := definition ? RabbitPunctuatorMap.DefinitionKind(definition) : "direct"
        this.type_choice.Choose(this.TypeIndex(type))
        this.type_choice.OnEvent("Change", (*) => this.UpdateTypeControls())

        this.direct_label := this.AddText("x20 y98 w110 h22", RabbitI18n.Text("punctuator.output"))
        this.direct_edit := this.AddEdit("x140 y94 w400 r1", "")
        this.commit_label := this.AddText("x20 y98 w110 h22", RabbitI18n.Text("punctuator.commit_output"))
        this.commit_edit := this.AddEdit("x140 y94 w400 r1", "")
        this.pair_label := this.AddText("x20 y98 w110 h22", RabbitI18n.Text("punctuator.pair_left"))
        this.pair_left := this.AddEdit("x140 y94 w400 r1", "")
        this.pair_right_label := this.AddText("x20 y136 w110 h22", RabbitI18n.Text("punctuator.pair_right"))
        this.pair_right := this.AddEdit("x140 y132 w400 r1", "")

        this.list_label := this.AddText("x20 y98 w110 h22", RabbitI18n.Text("punctuator.candidates"))
        this.candidate_list := this.AddListBox("x140 y94 w300 r4", [])
        this.candidate_add := this.AddButton("x448 y94 w92 h26", RabbitI18n.Text("controls.add"))
        this.candidate_add.OnEvent("Click", (*) => this.AddCandidate())
        this.candidate_edit := this.AddButton("x448 y126 w92 h26", RabbitI18n.Text("controls.edit"))
        this.candidate_edit.OnEvent("Click", (*) => this.EditCandidate())
        this.candidate_delete := this.AddButton("x448 y158 w92 h26", RabbitI18n.Text("controls.delete"))
        this.candidate_delete.OnEvent("Click", (*) => this.DeleteCandidate())
        this.candidate_up := this.AddButton("x140 y184 w72 h26", RabbitI18n.Text("controls.move_up"))
        this.candidate_up.OnEvent("Click", (*) => this.MoveCandidate(-1))
        this.candidate_down := this.AddButton("x220 y184 w72 h26", RabbitI18n.Text("controls.move_down"))
        this.candidate_down.OnEvent("Click", (*) => this.MoveCandidate(1))

        this.custom_label := this.AddText("x20 y98 w110 h22", RabbitI18n.Text("punctuator.custom_value"))
        this.custom_edit := this.AddEdit("x140 y94 w400 r5", "")
        this.custom_hint := this.AddText("x140 y198 w400 h38 cGray", RabbitI18n.Text("punctuator.custom_hint"))

        this.status := this.AddText("x20 y244 w520 h42 cRed", "")
        this.save_button := this.AddButton("x364 y300 w82 h32 Default +0x2000", RabbitI18n.Text("common.ok"))
        this.save_button.OnEvent("Click", (*) => this.SaveEntry())
        this.cancel_button := this.AddButton("x456 y300 w84 h32 +0x2000", RabbitI18n.Text("common.cancel"))
        this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        this.direct_controls := [this.direct_label, this.direct_edit]
        this.commit_controls := [this.commit_label, this.commit_edit]
        this.pair_controls := [this.pair_label, this.pair_left, this.pair_right_label, this.pair_right]
        this.list_controls := [
            this.list_label,
            this.candidate_list,
            this.candidate_add,
            this.candidate_edit,
            this.candidate_delete,
            this.candidate_up,
            this.candidate_down,
        ]
        this.custom_controls := [this.custom_label, this.custom_edit, this.custom_hint]

        if definition {
            this.LoadDefinition(definition)
        }
        factory := theme_factory
        this.window_theme := factory(this, dark_mode_reader)
        this.window_theme.RegisterError(this.status)
        this.window_theme.RegisterMuted(this.custom_hint)
        this.window_theme.Register()
        this.UpdateTypeControls()
    }

    ShowModal() {
        RabbitDialogPlacement.ShowOnOwnerMonitor(this, this.owner_window.Hwnd, "w560 h350")
        WinWaitClose("ahk_id " . this.Hwnd)
        return this.result
    }

    TypeIndex(type) {
        local value
        for value in this.type_values {
            if value = type {
                return A_Index
            }
        }
        return this.type_values.Length
    }

    CurrentType() {
        return this.type_values[this.type_choice.Value]
    }

    UpdateTypeControls() {
        local control, controls, type := this.CurrentType()
        for controls in [this.direct_controls, this.commit_controls, this.pair_controls, this.list_controls, this.custom_controls] {
            for control in controls {
                control.Visible := false
            }
        }
        switch type {
            case "direct": controls := this.direct_controls
            case "commit": controls := this.commit_controls
            case "pair": controls := this.pair_controls
            case "list": controls := this.list_controls
            default: controls := this.custom_controls
        }
        for control in controls {
            control.Visible := true
        }
    }

    LoadDefinition(definition) {
        local item
        switch RabbitPunctuatorMap.DefinitionKind(definition) {
            case "direct": this.direct_edit.Value := definition
            case "commit": this.commit_edit.Value := definition["commit"]
            case "pair":
                this.pair_left.Value := definition["pair"][1]
                this.pair_right.Value := definition["pair"][2]
            case "list":
                for item in definition {
                    this.candidate_list.Add([item])
                }
            default: this.custom_edit.Value := RabbitConfigValue.ToYaml(definition)
        }
    }

    AddCandidate() {
        local item := RabbitStringListItemDialog(this, "", false, this.window_theme.dark_mode_reader).ShowModal()
        if !item {
            return false
        }
        this.candidate_list.Add([item["value"]])
        return true
    }

    EditCandidate(row := 0) {
        local candidates, item
        if !row {
            row := this.candidate_list.Value
        }
        if row < 1 || row > this.candidate_list.GetCount() {
            this.status.Value := RabbitI18n.Text("punctuator.select_candidate")
            return false
        }
        item := RabbitStringListItemDialog(
            this,
            this.candidate_list.GetText(row),
            true,
            this.window_theme.dark_mode_reader
        ).ShowModal()
        if !item {
            return false
        }
        candidates := this.GetCandidates()
        candidates[row] := item["value"]
        this.RefreshCandidates(candidates, row)
        return true
    }

    DeleteCandidate() {
        local candidates, row := this.candidate_list.Value
        if row < 1 || row > this.candidate_list.GetCount() {
            this.status.Value := RabbitI18n.Text("punctuator.select_candidate")
            return false
        }
        candidates := this.GetCandidates()
        candidates.RemoveAt(row)
        this.RefreshCandidates(candidates, Min(row, candidates.Length))
        return true
    }

    MoveCandidate(offset) {
        local candidates, row := this.candidate_list.Value, target := row + offset, value
        if row < 1 || target < 1 || target > this.candidate_list.GetCount() {
            return false
        }
        candidates := this.GetCandidates()
        value := candidates.RemoveAt(row)
        candidates.InsertAt(target, value)
        this.RefreshCandidates(candidates, target)
        return true
    }

    GetCandidates() {
        local candidates := []
        Loop this.candidate_list.GetCount() {
            candidates.Push(this.candidate_list.GetText(A_Index))
        }
        return candidates
    }

    RefreshCandidates(candidates, selected_row := 0) {
        local value
        this.candidate_list.Delete()
        for value in candidates {
            this.candidate_list.Add([value])
        }
        if selected_row && selected_row <= candidates.Length {
            this.candidate_list.Choose(selected_row)
        }
    }

    SaveEntry() {
        local definition, key := this.key_edit.Value, type := this.CurrentType(), raw, config := 0
        try {
            RabbitPunctuatorMap.ValidateKey(key, this.path)
            switch type {
                case "direct":
                    if this.direct_edit.Value = "" {
                        throw ValueError(RabbitI18n.Text("punctuator.output_required"))
                    }
                    definition := this.direct_edit.Value
                case "commit":
                    if this.commit_edit.Value = "" {
                        throw ValueError(RabbitI18n.Text("punctuator.output_required"))
                    }
                    definition := Map("commit", this.commit_edit.Value)
                case "pair":
                    if this.pair_left.Value = "" || this.pair_right.Value = "" {
                        throw ValueError(RabbitI18n.Text("punctuator.pair_required"))
                    }
                    definition := Map("pair", [this.pair_left.Value, this.pair_right.Value])
                case "list":
                    if !this.candidate_list.GetCount() {
                        throw ValueError(RabbitI18n.Text("punctuator.candidates_required"))
                    }
                    definition := this.GetCandidates()
                default:
                    raw := this.custom_edit.Value
                    if this.original_definition && raw = RabbitConfigValue.ToYaml(this.original_definition) {
                        definition := RabbitConfigValue.Clone(this.original_definition)
                    } else {
                        if !this.rime_api {
                            throw ValueError(RabbitI18n.Text("punctuator.custom_unavailable"))
                        }
                        if !(config := this.rime_api.config_load_string("value: " . raw)) {
                            throw ValueError(RabbitI18n.Text("punctuator.custom_invalid"))
                        }
                        if !RabbitConfigValue.Read(this.rime_api, config, "value", &definition) {
                            throw ValueError(RabbitI18n.Text("punctuator.custom_invalid"))
                        }
                    }
            }
            if config {
                this.rime_api.config_close(config)
                config := 0
            }
            RabbitPunctuatorMap.ValidateDefinition(definition)
            this.result := {key: key, value: RabbitConfigValue.Clone(definition)}
            this.Dispose()
            return true
        } catch as err {
            if config {
                this.rime_api.config_close(config)
            }
            this.status.Value := err.Message
            return false
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
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
