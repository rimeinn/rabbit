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

#Include RabbitCandidatePreview.ahk
#Include RabbitCommon.ahk

class RabbitSettingsWindow extends Gui {
    static pages := [
        { title: "外观", description: "选择玉兔毫候选窗使用的配色。" },
        { title: "输入方案", description: "选择输入方案并设置方案选单快捷键。" },
        { title: "输入与行为", description: "设置玉兔毫的输入、提示和候选行为。" },
        { title: "应用适配", description: "按应用程序设置默认输入状态。" },
        { title: "用户词典", description: "备份、恢复、导入和导出用户词典。" },
        { title: "维护与同步", description: "重新部署、同步用户资料并查看诊断信息。" },
        { title: "关于", description: "查看版本、许可证和项目链接。" },
    ]

    __New(workflow := 0, old_windows := RabbitIsOldWindows(), preview_factory := CandidatePreview) {
        local page_names := []
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】设置", this)
        this.workflow := workflow
        this.old_windows := old_windows
        this.preview_factory := preview_factory
        this.appearance_settings := 0
        this.appearance_presets := []
        this.appearance_preview := 0
        this.appearance_loading := false
        this.appearance_dirty := false
        this.behavior_model := 0
        this.behavior_loading := false
        this.behavior_dirty := false
        this.switcher_model := 0
        this.switcher_items := Map()
        this.switcher_loading := false
        this.switcher_dirty := false
        this.disposed := false
        this.selected_page := 0

        this.SetFont("s10", "Microsoft YaHei UI")
        this.MarginX := 20
        this.MarginY := 20

        this.SetFont("s16 w600")
        this.AddText("x20 y20 w170 h32 Center", "玉兔毫")
        this.SetFont("s9 w400")
        this.AddText("x20 y52 w170 h22 Center cGray", "Windows 设置")

        for page in RabbitSettingsWindow.pages {
            page_names.Push(page.title)
        }
        this.navigation := this.AddListBox("x20 y88 w170 h390 -Multi", page_names)
        this.navigation.OnEvent("Change", (*) => this.SelectPage(this.navigation.Value))

        this.AddText("x205 y20 w1 h458 +0x10")
        this.SetFont("s18 w600")
        this.page_title := this.AddText("x230 y28 w570 h38", "")
        this.SetFont("s10 w400")
        this.page_description := this.AddText("x230 y72 w570 h28 cGray", "")
        this.AddText("x230 y112 w570 h1 +0x10")

        this.appearance_group := this.AddGroupBox("x230 y136 w570 h290 Hidden", "候选窗配色")
        this.appearance_list := this.AddListBox("x254 y174 w250 h174 -Multi Hidden")
        this.appearance_list.OnEvent("Change", (*) => this.OnAppearanceSelectionChange())
        this.appearance_details := this.AddText("x254 y358 w250 h44 Hidden", "")
        this.appearance_preview_group := this.AddGroupBox("x526 y174 w248 h178 Hidden", "预览")
        this.appearance_preview_img := this.AddPicture("x560 y202 w180 h126 0xE BackgroundWhite Hidden")
        this.appearance_preview_unavailable := this.AddText(
            "x546 y210 w208 h108 Center +0x200 Hidden",
            "旧版 Windows 暂不支持预览"
        )
        this.appearance_status := this.AddText("x526 y370 w248 h32 Hidden", "")

        this.placeholder := this.AddGroupBox("x230 y136 w570 h290", "页面内容")
        this.placeholder_text := this.AddText(
            "x254 y174 w520 h80",
            "这里将逐步迁入现有部署器功能。当前页面骨架不会读取或修改配置。"
        )

        this.switcher_group := this.AddGroupBox("x230 y136 w570 h290 Hidden", "输入方案")
        this.switcher_list := this.AddListView(
            "x254 y174 w250 h178 Checked NoSort -Multi Hidden",
            ["方案名称"]
        )
        this.switcher_list.OnEvent("Click", (ctrl, row) => this.ShowSwitcherDetails(row))
        this.switcher_list.OnEvent("ItemCheck", (*) => this.MarkSwitcherDirty())
        this.switcher_details := this.AddText(
            "x526 y174 w248 h178 Hidden",
            "选择左侧方案以查看简介。"
        )
        this.switcher_hotkeys_label := this.AddText("x254 y374 w100 h24 Hidden", "方案选单快捷键：")
        this.switcher_hotkeys := this.AddEdit("x374 y370 w400 r1 -Multi Hidden")
        this.switcher_hotkeys.OnEvent("Change", (*) => this.MarkSwitcherDirty())
        this.switcher_status := this.AddText("x254 y402 w520 h20 Hidden", "")

        this.behavior_group := this.AddGroupBox("x230 y136 w570 h290 Hidden", "输入与行为")
        this.show_tips := this.AddCheckbox("x254 y174 w230 h24 Hidden", "显示输入状态提示")
        this.show_tips.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.show_tips_time_label := this.AddText("x526 y176 w92 h22 Hidden", "显示时长（毫秒）：")
        this.show_tips_time := this.AddEdit("x650 y172 w100 r1 Number -Multi Hidden")
        this.show_tips_time.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.global_ascii := this.AddCheckbox("x254 y214 w496 h24 Hidden", "在所有程序之间共享中西文状态")
        this.global_ascii.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.fix_candidate_box := this.AddCheckbox("x254 y254 w496 h24 Hidden", "组字时保持候选窗位置不变")
        this.fix_candidate_box.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.use_legacy_candidate_box := this.AddCheckbox("x254 y294 w496 h24 Hidden", "使用旧版候选窗")
        this.use_legacy_candidate_box.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.bypass_password_fields := this.AddCheckbox("x254 y334 w496 h24 Hidden", "在密码输入框中绕过 Rime")
        this.bypass_password_fields.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.behavior_status := this.AddText("x254 y382 w496 h28 Hidden", "")

        this.about_group := this.AddGroupBox("x230 y136 w570 h250 Hidden", "关于玉兔毫")
        this.SetFont("s14 w600")
        this.about_name := this.AddText("x254 y176 w496 h30 Hidden", "玉兔毫")
        this.SetFont("s10 w400")
        this.about_version := this.AddText(
            "x254 y216 w496 h24 Hidden",
            "版本：" . RABBIT_VERSION . (A_IsCompiled ? "（已编译）" : "（源代码运行）")
        )
        this.about_description := this.AddText(
            "x254 y252 w496 h48 Hidden",
            "由 AutoHotkey 实现的 Rime 输入法引擎 Windows 前端。"
        )
        this.about_project_link := this.AddLink(
            "x254 y316 w160 h24 Hidden",
            '<a href="https://github.com/rimeinn/rabbit">访问项目主页</a>'
        )
        this.about_project_link.OnEvent("Click", this.OnLinkClick.Bind(this))
        this.about_license_link := this.AddLink(
            "x430 y316 w160 h24 Hidden",
            '<a href="https://www.gnu.org/licenses/gpl-3.0.html">GPL-3.0 许可证</a>'
        )
        this.about_license_link.OnEvent("Click", this.OnLinkClick.Bind(this))
        this.about_copyright := this.AddText(
            "x254 y356 w496 h24 Hidden cGray",
            "Copyright © 2023 - 2026 Xuesong Peng"
        )

        this.dictionary_group := this.AddGroupBox("x230 y136 w570 h180 Hidden", "用户词典")
        this.dictionary_text := this.AddText(
            "x254 y174 w520 h52 Hidden",
            "管理用户词典快照，或以文本码表格式导入、导出词条。"
        )
        this.dictionary_button := this.AddButton("x254 y246 w160 h32 Hidden", "打开词典管理")
        this.dictionary_button.OnEvent("Click", (*) => this.RunDictionaryManagement())

        this.maintenance_group := this.AddGroupBox("x230 y136 w570 h220 Hidden", "维护与同步")
        this.maintenance_text := this.AddText(
            "x254 y174 w520 h52 Hidden",
            "重新部署使配置改动生效；同步用户资料会合并本机与同步目录中的数据。"
        )
        this.deploy_button := this.AddButton("x254 y246 w130 h32 Hidden", "重新部署")
        this.deploy_button.OnEvent("Click", (*) => this.RunDeploy())
        this.sync_button := this.AddButton("x398 y246 w130 h32 Hidden", "同步用户资料")
        this.sync_button.OnEvent("Click", (*) => this.RunSync())
        this.operation_status := this.AddText("x254 y302 w520 h28 Hidden", "")

        this.footer_status := this.AddText(
            "x230 y452 w340 h22 cGray",
            "设置内容将在确认后统一保存和部署。"
        )
        this.apply_button := this.AddButton("x580 y444 w110 h32 Hidden Disabled", "保存并部署")
        this.apply_button.OnEvent("Click", (*) => this.ApplyCurrentPage())
        this.close_button := this.AddButton("x700 y444 w100 h32", "关闭")
        this.close_button.OnEvent("Click", this.OnClose.Bind(this))
        this.OnEvent("Close", this.OnClose.Bind(this))
        this.OnEvent("Escape", this.OnClose.Bind(this))

        this.SelectPage(1)
    }

    SelectPage(index) {
        local page
        if index < 1 || index > RabbitSettingsWindow.pages.Length {
            return false
        }
        this.selected_page := index
        if this.navigation.Value != index {
            this.navigation.Choose(index)
        }
        page := RabbitSettingsWindow.pages[index]
        this.page_title.Value := page.title
        this.page_description.Value := page.description
        this.SetPlaceholderVisible(
            index != 1 && index != 2 && index != 3 && index != 5 && index != 6 && index != 7
        )
        this.SetAppearanceVisible(index = 1)
        this.SetSwitcherVisible(index = 2)
        this.SetBehaviorVisible(index = 3)
        this.SetDictionaryVisible(index = 5)
        this.SetMaintenanceVisible(index = 6)
        this.SetAboutVisible(index = 7)
        if index = 1 {
            this.EnsureAppearanceSettings()
        } else if index = 2 {
            this.EnsureSwitcherSettings()
        } else if index = 3 {
            this.EnsureBehaviorSettings()
        }
        this.UpdateApplyButton()
        return true
    }

    SetPlaceholderVisible(visible) {
        this.placeholder.Visible := visible
        this.placeholder_text.Visible := visible
    }

    SetAppearanceVisible(visible) {
        this.appearance_group.Visible := visible
        this.appearance_list.Visible := visible
        this.appearance_details.Visible := visible
        this.appearance_preview_group.Visible := visible
        this.appearance_preview_img.Visible := visible && !this.old_windows
        this.appearance_preview_unavailable.Visible := visible && this.old_windows
        this.appearance_status.Visible := visible
        if visible {
            this.apply_button.Visible := true
        }
    }

    SetSwitcherVisible(visible) {
        this.switcher_group.Visible := visible
        this.switcher_list.Visible := visible
        this.switcher_details.Visible := visible
        this.switcher_hotkeys_label.Visible := visible
        this.switcher_hotkeys.Visible := visible
        this.switcher_status.Visible := visible
        if visible {
            this.apply_button.Visible := true
        }
    }

    SetBehaviorVisible(visible) {
        this.behavior_group.Visible := visible
        this.show_tips.Visible := visible
        this.show_tips_time_label.Visible := visible
        this.show_tips_time.Visible := visible
        this.global_ascii.Visible := visible
        this.fix_candidate_box.Visible := visible
        this.use_legacy_candidate_box.Visible := visible
        this.bypass_password_fields.Visible := visible
        this.behavior_status.Visible := visible
    }

    SetDictionaryVisible(visible) {
        this.dictionary_group.Visible := visible
        this.dictionary_text.Visible := visible
        this.dictionary_button.Visible := visible
    }

    SetMaintenanceVisible(visible) {
        this.maintenance_group.Visible := visible
        this.maintenance_text.Visible := visible
        this.deploy_button.Visible := visible
        this.sync_button.Visible := visible
        this.operation_status.Visible := visible
    }

    SetAboutVisible(visible) {
        this.about_group.Visible := visible
        this.about_name.Visible := visible
        this.about_version.Visible := visible
        this.about_description.Visible := visible
        this.about_project_link.Visible := visible
        this.about_license_link.Visible := visible
        this.about_copyright.Visible := visible
    }

    OnLinkClick(ctrl, index, link) {
        return this.OpenLink(link)
    }

    OpenLink(link) {
        try {
            Run(link)
            return true
        } catch as error {
            MsgBox("无法打开链接：`n" . error.Message, "【玉兔毫】", "Ok Iconx")
            return false
        }
    }

    EnsureAppearanceSettings() {
        if this.appearance_settings {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateUIStyleSettings") {
            this.appearance_status.Value := "当前环境无法读取外观设置。"
            return false
        }
        try {
            this.appearance_settings := this.workflow.CreateUIStyleSettings()
            this.PopulateAppearanceSettings()
            try {
                this.CreateAppearancePreview()
                this.PreviewAppearance(this.appearance_list.Value)
            } catch as error {
                this.appearance_status.Value := "无法显示预览：" . error.Message
            }
            return true
        } catch as error {
            this.appearance_status.Value := error.Message
            return false
        }
    }

    CreateAppearancePreview() {
        local factory
        if this.old_windows || this.appearance_preview {
            return
        }
        factory := this.preview_factory
        this.appearance_preview := factory(this.appearance_preview_img)
    }

    PopulateAppearanceSettings() {
        local active, active_index, i, info, names := []
        this.appearance_loading := true
        try {
            active := this.appearance_settings.GetActiveColorScheme()
            active_index := 0
            this.appearance_presets := this.appearance_settings.GetPresetColorSchemes()
            for i, info in this.appearance_presets {
                names.Push(info.name)
                if info.color_scheme_id = active {
                    active_index := i
                }
            }
            this.appearance_list.Delete()
            this.appearance_list.Add(names)
            if active_index > 0 {
                this.appearance_list.Choose(active_index)
                this.ShowAppearanceDetails(active_index)
                this.PreviewAppearance(active_index)
            }
            this.appearance_dirty := false
            this.appearance_status.Value := names.Length ? "" : "没有找到可用的配色。"
        } finally {
            this.appearance_loading := false
        }
    }

    OnAppearanceSelectionChange() {
        local index := this.appearance_list.Value
        if this.appearance_loading || index < 1 || index > this.appearance_presets.Length {
            return
        }
        this.appearance_settings.SelectColorScheme(this.appearance_presets[index].color_scheme_id)
        this.ShowAppearanceDetails(index)
        this.PreviewAppearance(index)
        this.appearance_dirty := true
        this.footer_status.Value := "外观设置尚未保存。"
        this.UpdateApplyButton()
    }

    ShowAppearanceDetails(index) {
        local info
        if index < 1 || index > this.appearance_presets.Length {
            return
        }
        info := this.appearance_presets[index]
        this.appearance_details.Value := info.author ? "作者：" . info.author : ""
    }

    PreviewAppearance(index) {
        local box_height, box_width, box_x, box_y, info
        if !this.appearance_preview || index < 1 || index > this.appearance_presets.Length {
            return
        }
        info := this.appearance_presets[index]
        this.appearance_preview.Build(info.style, &box_width, &box_height)
        box_width /= this.appearance_preview.dpiScale
        box_height /= this.appearance_preview.dpiScale
        box_x := 526 + Round((248 - box_width) / 2)
        box_y := 196 + Round((144 - box_height) / 2)
        this.appearance_preview_img.Move(box_x, box_y, box_width, box_height)
        this.appearance_preview.Render(["输入法", "输入", "数", "书", "输"], 1)
    }

    ApplyAppearanceSettings() {
        local deploy_result
        if !this.appearance_settings || !this.appearance_dirty {
            return false
        }
        this.Opt("+Disabled")
        this.appearance_status.Value := "正在保存…"
        try {
            if !this.appearance_settings.Save() {
                this.appearance_status.Value := "未能保存外观设置。"
                return false
            }
            deploy_result := this.workflow.UpdateWorkspace(true)
            if deploy_result != 0 {
                this.appearance_status.Value := "设置已保存，但重新部署失败。"
                return false
            }
            this.appearance_dirty := false
            this.appearance_status.Value := "外观设置已保存。"
            this.footer_status.Value := "设置内容将在确认后统一保存和部署。"
            this.UpdateApplyButton()
            return true
        } catch as error {
            this.appearance_status.Value := "保存失败：" . error.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    ApplyCurrentPage() {
        switch this.selected_page {
            case 1:
                return this.ApplyAppearanceSettings()
            case 2:
                return this.ApplySwitcherSettings()
            case 3:
                return this.ApplyBehaviorSettings()
        }
        return false
    }

    UpdateApplyButton() {
        this.apply_button.Visible := this.selected_page >= 1 && this.selected_page <= 3
        switch this.selected_page {
            case 1:
                this.apply_button.Enabled := this.appearance_dirty
            case 2:
                this.apply_button.Enabled := this.switcher_dirty
            case 3:
                this.apply_button.Enabled := this.behavior_dirty
            default:
                this.apply_button.Enabled := false
        }
    }

    EnsureBehaviorSettings() {
        if this.behavior_model {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateBehaviorSettingsModel") {
            this.behavior_status.Value := "当前环境无法读取输入与行为设置。"
            return false
        }
        try {
            this.behavior_model := this.workflow.CreateBehaviorSettingsModel()
            this.PopulateBehaviorSettings()
            return true
        } catch as error {
            this.behavior_status.Value := error.Message
            return false
        }
    }

    PopulateBehaviorSettings() {
        this.behavior_loading := true
        try {
            this.show_tips.Value := this.behavior_model.show_tips
            this.show_tips_time.Value := this.behavior_model.show_tips_time
            this.global_ascii.Value := this.behavior_model.global_ascii
            this.fix_candidate_box.Value := this.behavior_model.fix_candidate_box
            this.use_legacy_candidate_box.Value := this.behavior_model.use_legacy_candidate_box
            this.bypass_password_fields.Value := this.behavior_model.bypass_password_fields
            this.show_tips_time.Enabled := !!this.show_tips.Value
            this.behavior_dirty := false
            this.behavior_status.Value := ""
        } finally {
            this.behavior_loading := false
        }
    }

    OnBehaviorChanged() {
        if this.behavior_loading || !this.behavior_model {
            return
        }
        this.show_tips_time.Enabled := !!this.show_tips.Value
        this.behavior_dirty := true
        this.footer_status.Value := "输入与行为设置尚未保存。"
        this.UpdateApplyButton()
    }

    GetBehaviorValues() {
        local show_tips_time := Trim(this.show_tips_time.Value)
        if !RegExMatch(show_tips_time, "^\d+$") || Number(show_tips_time) > 2147483647 {
            throw ValueError("状态提示显示时长必须是非负整数。")
        }
        return {
            show_tips: !!this.show_tips.Value,
            show_tips_time: Number(show_tips_time),
            global_ascii: !!this.global_ascii.Value,
            fix_candidate_box: !!this.fix_candidate_box.Value,
            use_legacy_candidate_box: !!this.use_legacy_candidate_box.Value,
            bypass_password_fields: !!this.bypass_password_fields.Value,
        }
    }

    ApplyBehaviorSettings() {
        local deploy_result, values
        if !this.behavior_model || !this.behavior_dirty {
            return false
        }
        try {
            values := this.GetBehaviorValues()
        } catch as error {
            this.behavior_status.Value := error.Message
            return false
        }

        this.Opt("+Disabled")
        this.behavior_status.Value := "正在保存…"
        try {
            if !this.behavior_model.Save(values) {
                this.behavior_status.Value := "未能保存输入与行为设置。"
                return false
            }
            deploy_result := this.workflow.UpdateWorkspace(true)
            if deploy_result != 0 {
                this.behavior_status.Value := "设置已保存，但重新部署失败。"
                return false
            }
            this.behavior_dirty := false
            this.behavior_status.Value := "输入与行为设置已保存。"
            this.footer_status.Value := "设置内容将在确认后统一保存和部署。"
            this.UpdateApplyButton()
            return true
        } catch as error {
            this.behavior_status.Value := "保存失败：" . error.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    EnsureSwitcherSettings() {
        if this.switcher_model {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateSwitcherSettingsModel") {
            this.switcher_status.Value := "当前环境无法读取输入方案。"
            return false
        }
        try {
            this.switcher_model := this.workflow.CreateSwitcherSettingsModel()
            this.PopulateSwitcherSettings()
            return true
        } catch as error {
            this.switcher_status.Value := error.Message
            return false
        }
    }

    PopulateSwitcherSettings() {
        local row
        this.switcher_loading := true
        try {
            this.switcher_items := Map()
            this.switcher_list.Delete()
            for item in this.switcher_model.items {
                row := this.switcher_list.Add(item.selected ? "Check" : "", item.name)
                this.switcher_items[row] := item
            }
            this.switcher_list.ModifyCol(1, 228)
            this.switcher_hotkeys.Value := this.switcher_model.hotkeys
            this.switcher_dirty := false
            this.UpdateApplyButton()
            this.switcher_status.Value := ""
            if this.switcher_list.GetCount() > 0 {
                this.switcher_list.Modify(1, "Select Focus")
                this.ShowSwitcherDetails(1)
            }
        } finally {
            this.switcher_loading := false
        }
    }

    ShowSwitcherDetails(row) {
        local details, item
        if row < 1 || !this.switcher_items.Has(row) {
            return
        }
        item := this.switcher_items[row]
        details := item.name
        if item.author {
            details .= "`r`n`r`n" . item.author
        }
        if item.description {
            details .= "`r`n`r`n" . item.description
        }
        this.switcher_details.Value := details
    }

    MarkSwitcherDirty() {
        if this.switcher_loading || !this.switcher_model {
            return
        }
        this.switcher_dirty := true
        this.footer_status.Value := "输入方案设置尚未保存。"
        this.UpdateApplyButton()
    }

    SelectedSchemaIds() {
        local ids := []
        local row := 0
        while (row := this.switcher_list.GetNext(row, "Checked")) {
            if this.switcher_items.Has(row) {
                ids.Push(this.switcher_items[row].id)
            }
        }
        return ids
    }

    ApplySwitcherSettings() {
        local schema_ids, deploy_result
        if !this.switcher_model || !this.switcher_dirty {
            return false
        }
        schema_ids := this.SelectedSchemaIds()
        if schema_ids.Length = 0 {
            MsgBox("至少要选用一项输入方案。", "【玉兔毫】", "Ok Icon!")
            return false
        }

        this.Opt("+Disabled")
        this.switcher_status.Value := "正在保存…"
        try {
            if !this.switcher_model.Save(schema_ids, Trim(this.switcher_hotkeys.Value)) {
                this.switcher_status.Value := "未能保存输入方案设置。"
                return false
            }
            deploy_result := this.workflow.UpdateWorkspace(true)
            if deploy_result != 0 {
                this.switcher_status.Value := "设置已保存，但重新部署失败。"
                return false
            }
            this.switcher_dirty := false
            this.switcher_status.Value := "输入方案设置已保存。"
            this.footer_status.Value := "设置内容将在确认后统一保存和部署。"
            this.UpdateApplyButton()
            return true
        } catch as error {
            this.switcher_status.Value := "保存失败：" . error.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    RunDictionaryManagement() {
        if !this.workflow {
            return false
        }
        try {
            return this.workflow.DictManagement() = 0
        } catch as error {
            MsgBox("未能打开用户词典管理：`n" . error.Message, "【玉兔毫】", "Ok Iconx")
            return false
        }
    }

    RunDeploy() {
        return this.RunMaintenanceAction(
            (*) => this.workflow.UpdateWorkspace(true),
            "部署完成。",
            "部署失败。"
        )
    }

    RunSync() {
        return this.RunMaintenanceAction(
            (*) => this.workflow.SyncUserData(),
            "同步完成。",
            "同步失败。"
        )
    }

    RunMaintenanceAction(action, success_message, failure_message) {
        local result
        if !this.workflow {
            return false
        }
        this.Opt("+Disabled")
        this.operation_status.Value := "正在执行…"
        try {
            result := action.Call()
            this.operation_status.Value := result = 0 ? success_message : failure_message
            return result = 0
        } catch as error {
            this.operation_status.Value := failure_message . " " . error.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    WaitClose() {
        local hwnd := this.Hwnd
        WinWaitClose("ahk_id " . hwnd)
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
        try {
            if this.appearance_preview {
                this.appearance_preview.Dispose()
                this.appearance_preview := 0
            }
        } finally {
            try {
                if this.appearance_settings {
                    this.appearance_settings.Dispose()
                    this.appearance_settings := 0
                }
            } finally {
                try {
                    if this.switcher_model {
                        this.switcher_model.Dispose()
                        this.switcher_model := 0
                    }
                } finally {
                    try {
                        if this.behavior_model {
                            this.behavior_model.Dispose()
                            this.behavior_model := 0
                        }
                    } finally {
                        try this.Destroy()
                    }
                }
            }
        }
    }
}
