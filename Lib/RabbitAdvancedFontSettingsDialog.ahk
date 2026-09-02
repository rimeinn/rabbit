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

#Include RabbitAdvancedFontSettingsModel.ahk
#Include RabbitDialogPlacement.ahk
#Include RabbitWindowTheme.ahk

class RabbitAdvancedFontSettingsDialog extends Gui {
    static FONT_WEIGHTS := [
        { label: "细体", value: 100 },
        { label: "特细", value: 200 },
        { label: "轻体", value: 300 },
        { label: "半轻", value: 350 },
        { label: "常规", value: 400 },
        { label: "中等", value: 500 },
        { label: "半粗", value: 600 },
        { label: "粗体", value: 700 },
        { label: "特粗", value: 800 },
        { label: "黑体", value: 900 },
        { label: "特黑", value: 950 }
    ]
    static FONT_STYLES := [
        { label: "正常", value: 0 },
        { label: "倾斜", value: 1 },
        { label: "斜体", value: 2 }
    ]
    static RANGE_PRESETS := [
        { label: "全部字符", start: 0, end: RabbitFontSpec.MAX_CODE_POINT },
        { label: "基本拉丁（0020–007E）", start: 0x20, end: 0x7e },
        { label: "CJK 部首补充（2E80–2EFF）", start: 0x2e80, end: 0x2eff },
        { label: "康熙部首（2F00–2FDF）", start: 0x2f00, end: 0x2fdf },
        { label: "CJK 符号和标点（3000–303F）", start: 0x3000, end: 0x303f },
        { label: "CJK 笔画（31C0–31EF）", start: 0x31c0, end: 0x31ef },
        { label: "CJK Ext A（3400–4DBF）", start: 0x3400, end: 0x4dbf },
        { label: "中日韩统一表意文字（4E00–9FFF）", start: 0x4e00, end: 0x9fff },
        { label: "CJK Ext B（20000–2A6DF）", start: 0x20000, end: 0x2a6df },
        { label: "CJK Ext C（2A700–2B73F）", start: 0x2a700, end: 0x2b73f },
        { label: "CJK Ext D（2B740–2B81F）", start: 0x2b740, end: 0x2b81f },
        { label: "CJK Ext E（2B820–2CEAF）", start: 0x2b820, end: 0x2ceaf },
        { label: "CJK Ext F（2CEB0–2EBEF）", start: 0x2ceb0, end: 0x2ebef },
        { label: "CJK Ext G（30000–3134F）", start: 0x30000, end: 0x3134f },
        { label: "CJK Ext H（31350–323AF）", start: 0x31350, end: 0x323af },
        { label: "CJK Ext I（2EBF0–2EE5F）", start: 0x2ebf0, end: 0x2ee5f },
        { label: "CJK Ext J（323B0–3347F）", start: 0x323b0, end: 0x3347f },
        { label: "Emoji 补充区（1F300–1FAFF）", start: 0x1f300, end: 0x1faff },
        { label: "自定义范围", custom: true }
    ]

    __New(
        owner,
        values,
        installed_fonts := 0,
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local factory, initial_dark_mode := false, list_options, surface_options
        local role_labels := []
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        super.__New(
            "+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox",
            "高级字体设置",
            this
        )
        this.owner_window := owner
        this.model := RabbitAdvancedFontSettingsModel(values)
        this.installed_fonts := installed_fonts is Array ? installed_fonts.Clone() : []
        this.result := 0
        this.disposed := false
        this.loading := true
        this.current_role_index := 1
        this.initial_dark_mode := initial_dark_mode
        this.MarginX := 20
        this.MarginY := 18
        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )

        for role in RabbitAdvancedFontSettingsModel.ROLES {
            role_labels.Push(role.label)
        }
        this.role_tabs := this.AddTab3(
            "x20 y18 w720 h38" . (initial_dark_mode ? " cF0F0F0 Background202020" : ""),
            role_labels
        )
        this.role_tabs.OnEvent("Change", (*) => this.OnRoleChanged())
        this.role_tabs.UseTab()

        this.format_group := this.AddGroupBox("x20 y68 w720 h58", "全局字重与字形")
        this.AddText("x36 y92 w54 h22", "字重：")
        this.font_weight := this.AddDropDownList(
            "x92 y88 w150",
            this.ChoiceLabels(RabbitAdvancedFontSettingsDialog.FONT_WEIGHTS)
        )
        this.font_weight.OnEvent("Change", (*) => this.OnAttributesChanged())
        this.AddText("x264 y92 w54 h22", "字形：")
        this.font_style := this.AddDropDownList(
            "x320 y88 w150",
            this.ChoiceLabels(RabbitAdvancedFontSettingsDialog.FONT_STYLES)
        )
        this.font_style.OnEvent("Change", (*) => this.OnAttributesChanged())
        surface_options := initial_dark_mode ? " cF0F0F0 Background2B2B2B" : ""
        this.order_header := this.AddText(
            "x20 y140 w54 h24 Center +0x200" . surface_options,
            "顺序"
        )
        this.family_header := this.AddText(
            "x74 y140 w286 h24 +0x200" . surface_options,
            "  字体"
        )
        this.range_header := this.AddText(
            "x360 y140 w230 h24 +0x200" . surface_options,
            "  Unicode 范围"
        )
        list_options := initial_dark_mode
            ? "x20 y164 w570 h166 -Hdr"
            : "x20 y140 w570 h190"
        this.fallback_list := this.AddListView(
            list_options . " -Multi NoSort",
            ["顺序", "字体", "Unicode 范围"]
        )
        this.fallback_list.ModifyCol(1, 54)
        this.fallback_list.ModifyCol(2, 286)
        this.fallback_list.ModifyCol(3, 225)
        this.fallback_list.OnEvent(
            "ItemSelect",
            (ctrl, row, selected) => selected ? this.OnEntrySelected(row) : 0
        )
        this.add_button := this.AddButton("x608 y140 w114 h30", "添加字体")
        this.add_button.OnEvent("Click", (*) => this.AddEntry())
        this.delete_button := this.AddButton("x608 y178 w114 h30", "删除")
        this.delete_button.OnEvent("Click", (*) => this.DeleteEntry())
        this.move_up_button := this.AddButton("x608 y216 w114 h30", "上移")
        this.move_up_button.OnEvent("Click", (*) => this.MoveEntry(-1))
        this.move_down_button := this.AddButton("x608 y254 w114 h30", "下移")
        this.move_down_button.OnEvent("Click", (*) => this.MoveEntry(1))
        this.entry_group := this.AddGroupBox("x20 y344 w720 h126", "编辑所选字体")
        this.AddText("x36 y370 w54 h22", "字体：")
        this.family := this.AddComboBox("x92 y366 w286", this.installed_fonts)
        this.AddText("x396 y370 w54 h22", "范围：")
        this.range_preset := this.AddDropDownList(
            "x452 y366 w270",
            this.ChoiceLabels(RabbitAdvancedFontSettingsDialog.RANGE_PRESETS)
        )
        this.range_preset.OnEvent("Change", (*) => this.OnRangePresetChanged())
        this.AddText("x36 y410 w78 h22", "起始码位：")
        this.range_start := this.AddEdit("x116 y406 w118 r1 -Multi")
        this.AddText("x258 y410 w78 h22", "结束码位：")
        this.range_end := this.AddEdit("x338 y406 w118 r1 -Multi")
        this.update_button := this.AddButton("x608 y402 w114 h32", "更新所选项")
        this.update_button.OnEvent("Click", (*) => this.ApplyEntry())

        this.AddText("x20 y490 w92 h22", "配置字符串：")
        this.raw_source := this.AddEdit("x114 y486 w500 r1 -Multi")
        this.parse_button := this.AddButton("x624 y484 w116 h30", "从字符串更新")
        this.parse_button.OnEvent("Click", (*) => this.ParseRawSource())
        this.status := this.AddText("x20 y526 w720 h24 cRed", "")
        this.save_button := this.AddButton("x552 y558 w88 h32 Default", "确定")
        this.save_button.OnEvent("Click", (*) => this.SaveSettings())
        this.cancel_button := this.AddButton("x652 y558 w88 h32", "取消")
        this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        this.order_header.Visible := initial_dark_mode
        this.family_header.Visible := initial_dark_mode
        this.range_header.Visible := initial_dark_mode
        factory := theme_factory
        this.window_theme := factory(this, dark_mode_reader)
        this.window_theme.RegisterError(this.status)
        this.window_theme.RegisterSurface(
            this.order_header,
            this.family_header,
            this.range_header
        )
        this.window_theme.Register()
        this.RefreshRole(1)
        this.loading := false
    }

    ShowModal() {
        local hwnd := this.Hwnd
        RabbitDialogPlacement.ShowOnOwnerMonitor(this, this.owner_window.Hwnd, "w760 h610")
        WinWaitClose("ahk_id " . hwnd)
        return this.result
    }

    OnRoleChanged() {
        if this.loading {
            return
        }
        local next_index := this.role_tabs.Value
        if !this.ApplyEntry() {
            this.loading := true
            try this.role_tabs.Choose(this.current_role_index)
            finally this.loading := false
            return
        }
        this.RefreshRole(next_index)
    }

    RefreshRole(role_index, selected_row := 1) {
        local entry, index, role, spec
        this.loading := true
        try {
            this.current_role_index := role_index
            role := RabbitAdvancedFontSettingsModel.ROLES[role_index]
            spec := this.model.GetSpec(role.key)
            this.font_weight.Choose(this.FindChoice(
                RabbitAdvancedFontSettingsDialog.FONT_WEIGHTS,
                spec.font_weight
            ))
            this.font_style.Choose(this.FindChoice(
                RabbitAdvancedFontSettingsDialog.FONT_STYLES,
                spec.font_style
            ))
            this.fallback_list.Delete()
            for index, entry in spec.entries {
                this.fallback_list.Add("", index, entry.family, this.RangeText(entry))
            }
            selected_row := Min(Max(selected_row, 1), spec.entries.Length)
            this.fallback_list.Modify(selected_row, "Select Focus Vis")
            this.raw_source.Value := spec.Serialize()
            this.LoadEntryEditor(selected_row)
            this.status.Value := ""
        } finally {
            this.loading := false
        }
    }

    OnEntrySelected(row) {
        if !this.loading {
            this.LoadEntryEditor(row)
        }
    }

    LoadEntryEditor(row) {
        local entry := this.CurrentSpec().entries[row]
        local preset := this.FindRangePreset(entry.start_code_point, entry.end_code_point)
        this.family.Text := entry.family
        this.range_preset.Choose(preset)
        this.range_start.Value := RabbitFontSpec.FormatCodePoint(entry.start_code_point)
        this.range_end.Value := RabbitFontSpec.FormatCodePoint(entry.end_code_point)
        this.UpdateRangeEditState()
        this.UpdateActionState(row)
    }

    OnAttributesChanged() {
        if this.loading {
            return
        }
        try {
            this.model.SetAttributes(
                this.CurrentRole().key,
                RabbitAdvancedFontSettingsDialog.FONT_WEIGHTS[this.font_weight.Value].value,
                RabbitAdvancedFontSettingsDialog.FONT_STYLES[this.font_style.Value].value
            )
            this.raw_source.Value := this.CurrentSpec().Serialize()
            this.status.Value := ""
        } catch as err {
            this.status.Value := err.Message
        }
    }

    OnRangePresetChanged() {
        if this.loading {
            return
        }
        local preset := RabbitAdvancedFontSettingsDialog.RANGE_PRESETS[this.range_preset.Value]
        if !HasProp(preset, "custom") {
            this.range_start.Value := RabbitFontSpec.FormatCodePoint(preset.start)
            this.range_end.Value := RabbitFontSpec.FormatCodePoint(preset.end)
        }
        this.UpdateRangeEditState()
    }

    UpdateRangeEditState() {
        local preset := RabbitAdvancedFontSettingsDialog.RANGE_PRESETS[this.range_preset.Value]
        local custom := HasProp(preset, "custom") && preset.custom
        this.range_start.Enabled := custom
        this.range_end.Enabled := custom
    }

    ApplyEntry(show_error := true) {
        local end_code_point, preset, start_code_point
        local row := this.fallback_list.GetNext(0)
        if !row {
            return true
        }
        try {
            preset := RabbitAdvancedFontSettingsDialog.RANGE_PRESETS[this.range_preset.Value]
            if HasProp(preset, "custom") && preset.custom {
                start_code_point := this.ParseCodePointInput(this.range_start.Value)
                end_code_point := this.ParseCodePointInput(this.range_end.Value)
            } else {
                start_code_point := preset.start
                end_code_point := preset.end
            }
            this.model.UpdateEntry(
                this.CurrentRole().key,
                row,
                this.family.Text,
                start_code_point,
                end_code_point
            )
            this.RefreshRole(this.current_role_index, row)
            return true
        } catch as err {
            if show_error {
                this.status.Value := err.Message
            }
            return false
        }
    }

    AddEntry() {
        if !this.ApplyEntry() {
            return false
        }
        local row := this.fallback_list.GetNext(0)
        local family := row ? this.CurrentSpec().entries[row].family : "Microsoft YaHei UI"
        local added := this.model.AddEntry(this.CurrentRole().key, family)
        this.RefreshRole(this.current_role_index, added)
        return true
    }

    DeleteEntry() {
        local row := this.fallback_list.GetNext(0)
        if !row {
            this.status.Value := "请先选择一个字体。"
            return false
        }
        try {
            row := this.model.DeleteEntry(this.CurrentRole().key, row)
            this.RefreshRole(this.current_role_index, row)
            return true
        } catch as err {
            this.status.Value := err.Message
            return false
        }
    }

    MoveEntry(offset) {
        local row := this.fallback_list.GetNext(0)
        if !row || !this.ApplyEntry() {
            return false
        }
        row := this.model.MoveEntry(this.CurrentRole().key, row, offset)
        this.RefreshRole(this.current_role_index, row)
        return true
    }

    ParseRawSource() {
        try {
            this.model.SetSource(this.CurrentRole().key, this.raw_source.Value)
            this.RefreshRole(this.current_role_index)
            return true
        } catch as err {
            this.status.Value := err.Message
            return false
        }
    }

    SaveSettings() {
        if !this.ApplyEntry() {
            return false
        }
        this.result := this.model.GetValues()
        this.Dispose()
        return true
    }

    UpdateActionState(row) {
        local length := this.CurrentSpec().entries.Length
        this.delete_button.Enabled := length > 1
        this.move_up_button.Enabled := row > 1
        this.move_down_button.Enabled := row < length
    }

    CurrentRole() {
        return RabbitAdvancedFontSettingsModel.ROLES[this.current_role_index]
    }

    CurrentSpec() {
        return this.model.GetSpec(this.CurrentRole().key)
    }

    RangeText(entry) {
        if entry.start_code_point = 0 && entry.end_code_point = RabbitFontSpec.MAX_CODE_POINT {
            return "全部字符"
        }
        return "U+" . Format("{:04X}", entry.start_code_point)
            . " – U+" . Format("{:04X}", entry.end_code_point)
    }

    FindRangePreset(start_code_point, end_code_point) {
        local index, preset
        for index, preset in RabbitAdvancedFontSettingsDialog.RANGE_PRESETS {
            if !HasProp(preset, "custom") && preset.start = start_code_point
                && preset.end = end_code_point {
                return index
            }
        }
        return RabbitAdvancedFontSettingsDialog.RANGE_PRESETS.Length
    }

    ParseCodePointInput(value) {
        value := Trim(value)
        if !value {
            throw ValueError("Unicode 起始和结束码位不能为空。")
        }
        try {
            return RabbitFontSpec.ParseCodePoint(value)
        } catch as err {
            throw ValueError("Unicode 码位无效：" . err.Message)
        }
    }

    FindChoice(choices, value) {
        for index, choice in choices {
            if choice.value = value {
                return index
            }
        }
        throw ValueError("Unsupported font setting value: " . value)
    }

    ChoiceLabels(choices) {
        local labels := []
        for choice in choices {
            labels.Push(choice.label)
        }
        return labels
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
