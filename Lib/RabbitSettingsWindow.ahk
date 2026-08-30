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

#Include RabbitAppearancePreview.ahk
#Include RabbitCommon.ahk
#Include RabbitApplicationSettingsModel.ahk
#Include RabbitKeyBindingDialog.ahk
#Include RabbitWindowTheme.ahk

class RabbitSettingsWindow extends Gui {
    static WINDOW_WIDTH := 820
    static APPEARANCE_HEIGHT := 660
    static BEHAVIOR_HEIGHT := 660
    static COMPACT_HEIGHT := 500
    static SWITCH_ACTION_VALUES := ["noop", "inline_ascii", "commit_text", "commit_code", "clear"]
    static SWITCH_ACTION_LABELS := ["不切换", "临时英文", "提交文字", "提交编码", "清空输入"]
    static pages := [
        { id: "appearance", title: "外观", description: "配置候选窗口的配色和排版。" },
        { id: "input-schemes", title: "输入方案", description: "选择输入方案并设置方案选单快捷键。" },
        { id: "behavior", title: "输入与行为", description: "设置玉兔毫的输入、提示和候选行为。" },
        { id: "applications", title: "应用适配", description: "按应用程序设置默认输入状态。" },
        { id: "dictionary", title: "用户词典", description: "备份、恢复、导入和导出用户词典。" },
        { id: "maintenance", title: "维护与同步", description: "重新部署、同步用户资料并查看诊断信息。" },
        { id: "about", title: "关于", description: "查看版本、许可证和项目链接。" },
    ]

    __New(
        workflow := 0,
        old_windows := RabbitIsOldWindows(),
        preview_factory := RabbitAppearancePreview,
        close_prompt := 0,
        initial_page_id := "",
        installing := false,
        theme_factory := RabbitWindowThemeController
    ) {
        local controls, initial_dark_mode := false, initial_page, key, factory
        local surface_options := ""
        local page_names := []
        initial_page := RabbitSettingsWindow.PageIndex(initial_page_id)
        if !initial_page {
            throw ValueError("未知的设置页面：" . initial_page_id)
        }
        if installing && RabbitSettingsWindow.pages[initial_page].id != "input-schemes" {
            throw ValueError("首次安装必须打开输入方案页面。")
        }
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】设置", this)
        this.workflow := workflow
        this.old_windows := old_windows
        this.preview_factory := preview_factory
        this.close_prompt := close_prompt
        this.installing := installing
        this.appearance_settings := 0
        this.appearance_presets := []
        this.appearance_preview := 0
        this.appearance_loading := false
        this.appearance_dirty := false
        this.appearance_style := RabbitUIStyleSnapshot()
        this.appearance_light_scheme := ""
        this.appearance_dark_scheme := ""
        this.behavior_model := 0
        this.behavior_loading := false
        this.behavior_dirty := false
        this.bindings := []
        this.application_model := 0
        this.application_rules := Map()
        this.application_changes := Map()
        this.application_loading := false
        this.application_dirty := false
        this.dictionary_model := 0
        this.switcher_model := 0
        this.switcher_items := Map()
        this.switcher_loading := false
        this.switcher_dirty := false
        this.disposed := false
        this.selected_page := 0
        this.window_shown := false
        this.initial_dark_mode := initial_dark_mode

        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )
        surface_options := initial_dark_mode ? " cF0F0F0 Background2B2B2B" : ""
        this.MarginX := 20
        this.MarginY := 20

        this.SetFont("s16 w600")
        this.AddText("x20 y20 w170 h32 Center", "玉兔毫")
        this.SetFont("s9 w400")
        this.sidebar_subtitle := this.AddText("x20 y52 w170 h22 Center cGray", "控制面板")

        for page in RabbitSettingsWindow.pages {
            page_names.Push(page.title)
        }
        this.navigation := this.AddListBox("x20 y88 w170 h330 -Multi +0x100", page_names)
        this.navigation.OnEvent("Change", (*) => this.SelectPage(this.navigation.Value))
        this.apply_button := this.AddButton("x20 y594 w170 h36 Disabled", "应用并重新部署")
        this.apply_button.OnEvent("Click", (*) => this.ApplyAllPendingSettings())

        this.sidebar_divider := this.AddText("x205 y20 w1 h598 +0x10")
        this.SetFont("s18 w600")
        this.page_title := this.AddText("x230 y28 w570 h38", "")
        this.SetFont("s10 w400")
        this.page_description := this.AddText("x230 y72 w570 h28 cGray", "")
        this.header_divider := this.AddText("x230 y112 w570 h1 +0x10")

        this.appearance_tabs := this.AddTab3(
            "x230 y136 w570 h450 Hidden"
                . (initial_dark_mode ? " cF0F0F0 Background202020" : ""),
            ["配色", "排版"]
        )
        this.appearance_tabs.OnEvent("Change", (*) => this.OnAppearanceTabChanged())
        this.appearance_tabs.UseTab(1)
        this.appearance_target_label := this.AddText("x250 y178 w80 h22 Hidden", "设置对象：")
        this.appearance_target := this.AddDropDownList(
            "x334 y174 w446 Choose1 Hidden",
            ["浅色模式", "深色模式"]
        )
        this.appearance_target.OnEvent("Change", (*) => this.OnAppearanceTargetChange())
        this.appearance_list_label := this.AddText("x250 y216 w120 h22 Hidden", "配色方案：")
        this.appearance_list := this.AddListBox("x250 y240 w530 h278 -Multi Hidden")
        this.appearance_list.OnEvent("Change", (*) => this.OnAppearanceSelectionChange())
        this.appearance_details := this.AddText("x250 y528 w530 h36 Hidden", "")

        this.appearance_tabs.UseTab(2)
        this.appearance_font_group := this.AddGroupBox("x246 y170 w538 h180 Hidden", "字体")
        this.appearance_font_label := this.AddText("x260 y196 w72 h22 Hidden", "候选文字：")
        this.appearance_font := this.AddComboBox("x334 y192 w320 Hidden", [])
        this.appearance_font.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_font_point_label := this.AddText("x664 y196 w42 h22 Hidden", "字号：")
        this.appearance_font_point := this.AddEdit("x708 y192 w58 r1 Number -Multi Hidden")
        this.appearance_font_point.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_preedit_font_label := this.AddText("x260 y226 w72 h22 Hidden", "预编辑：")
        this.appearance_preedit_font := this.AddComboBox("x334 y222 w432 Hidden", [])
        this.appearance_preedit_font.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_label_font_label := this.AddText("x260 y256 w72 h22 Hidden", "候选序号：")
        this.appearance_label_font := this.AddComboBox("x334 y252 w320 Hidden", [])
        this.appearance_label_font.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_label_font_point := this.AddEdit("x708 y252 w58 r1 Number -Multi Hidden")
        this.appearance_label_font_point.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_comment_font_label := this.AddText("x260 y286 w72 h22 Hidden", "候选注释：")
        this.appearance_comment_font := this.AddComboBox("x334 y282 w320 Hidden", [])
        this.appearance_comment_font.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_comment_font_point := this.AddEdit("x708 y282 w58 r1 Number -Multi Hidden")
        this.appearance_comment_font_point.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_label_format_label := this.AddText("x260 y316 w72 h22 Hidden", "序号格式：")
        this.appearance_label_format := this.AddEdit("x334 y312 w432 r1 -Multi Hidden")
        this.appearance_label_format.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())

        this.appearance_layout_group := this.AddGroupBox("x246 y356 w538 h212 Hidden", "布局")
        this.appearance_layout_type_label := this.AddText("x260 y382 w72 h22 Hidden", "候选排列：")
        this.appearance_layout_type := this.AddDropDownList(
            "x334 y378 w160 Choose1 Hidden",
            ["纵向堆叠", "横向流式", "竖排文字"]
        )
        this.appearance_layout_type.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_align_type_label := this.AddText("x510 y382 w72 h22 Hidden", "对齐方式：")
        this.appearance_align_type := this.AddDropDownList(
            "x584 y378 w182 Choose1 Hidden",
            ["顶部", "居中", "底部"]
        )
        this.appearance_align_type.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_margin_x_label := this.AddText("x260 y414 w72 h22 Hidden", "水平边距：")
        this.appearance_margin_x := this.AddEdit("x334 y410 w120 r1 Number -Multi Hidden")
        this.appearance_margin_x.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_margin_y_label := this.AddText("x478 y414 w72 h22 Hidden", "垂直边距：")
        this.appearance_margin_y := this.AddEdit("x552 y410 w120 r1 Number -Multi Hidden")
        this.appearance_margin_y.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_border_width_label := this.AddText("x260 y446 w72 h22 Hidden", "边框宽度：")
        this.appearance_border_width := this.AddEdit("x334 y442 w120 r1 Number -Multi Hidden")
        this.appearance_border_width.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_corner_radius_label := this.AddText("x478 y446 w72 h22 Hidden", "窗口圆角：")
        this.appearance_corner_radius := this.AddEdit("x552 y442 w120 r1 Number -Multi Hidden")
        this.appearance_corner_radius.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_round_corner_label := this.AddText("x260 y478 w112 h22 Hidden", "候选及高亮圆角：")
        this.appearance_round_corner := this.AddEdit("x374 y474 w48 r1 Number -Multi Hidden")
        this.appearance_round_corner.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_min_width_label := this.AddText("x438 y478 w112 h22 Hidden", "堆叠最小宽度：")
        this.appearance_min_width := this.AddEdit("x552 y474 w48 r1 Number -Multi Hidden")
        this.appearance_min_width.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_min_height_label := this.AddText("x616 y478 w112 h22 Hidden", "竖排最小高度：")
        this.appearance_min_height := this.AddEdit("x730 y474 w48 r1 Number -Multi Hidden")
        this.appearance_min_height.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_flow_rows_label := this.AddText("x260 y510 w72 h22 Hidden", "展开页数：")
        this.appearance_flow_rows := this.AddEdit("x334 y506 w120 r1 Number -Multi Hidden")
        this.appearance_flow_rows.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_vertical_direction := this.AddCheckbox(
            "x478 y508 w288 h24 Hidden",
            "竖排候选从左向右排列"
        )
        this.appearance_vertical_direction.OnEvent("Click", (*) => this.OnAppearanceControlsChanged())
        this.appearance_floating_preedit := this.AddCheckbox(
            "x260 y538 w190 h24 Hidden",
            "显示浮动预编辑框"
        )
        this.appearance_floating_preedit.OnEvent("Click", (*) => this.OnAppearanceControlsChanged())
        this.appearance_floating_opacity_label := this.AddText("x478 y540 w72 h22 Hidden", "不透明度：")
        this.appearance_floating_opacity := this.AddEdit("x552 y536 w60 r1 Number -Multi Hidden")
        this.appearance_floating_opacity.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_floating_height_label := this.AddText("x628 y540 w72 h22 Hidden", "最小高度：")
        this.appearance_floating_height := this.AddEdit("x702 y536 w64 r1 Number -Multi Hidden")
        this.appearance_floating_height.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_tabs.UseTab()

        this.appearance_color_controls := [
            this.appearance_target_label,
            this.appearance_target,
            this.appearance_list_label,
            this.appearance_list,
            this.appearance_details,
        ]
        this.appearance_typesetting_controls := [
            this.appearance_font_group,
            this.appearance_font_label,
            this.appearance_font,
            this.appearance_font_point_label,
            this.appearance_font_point,
            this.appearance_preedit_font_label,
            this.appearance_preedit_font,
            this.appearance_label_font_label,
            this.appearance_label_font,
            this.appearance_label_font_point,
            this.appearance_comment_font_label,
            this.appearance_comment_font,
            this.appearance_comment_font_point,
            this.appearance_label_format_label,
            this.appearance_label_format,
            this.appearance_layout_group,
            this.appearance_layout_type_label,
            this.appearance_layout_type,
            this.appearance_align_type_label,
            this.appearance_align_type,
            this.appearance_margin_x_label,
            this.appearance_margin_x,
            this.appearance_margin_y_label,
            this.appearance_margin_y,
            this.appearance_border_width_label,
            this.appearance_border_width,
            this.appearance_corner_radius_label,
            this.appearance_corner_radius,
            this.appearance_round_corner_label,
            this.appearance_round_corner,
            this.appearance_min_width_label,
            this.appearance_min_width,
            this.appearance_min_height_label,
            this.appearance_min_height,
            this.appearance_flow_rows_label,
            this.appearance_flow_rows,
            this.appearance_vertical_direction,
            this.appearance_floating_preedit,
            this.appearance_floating_opacity_label,
            this.appearance_floating_opacity,
            this.appearance_floating_height_label,
            this.appearance_floating_height,
        ]
        this.appearance_status := this.AddText("x230 y588 w570 h20 Hidden", "")

        this.placeholder := this.AddGroupBox("x230 y136 w570 h290", "页面内容")
        this.placeholder_text := this.AddText(
            "x254 y174 w520 h80",
            "这里将逐步迁入现有部署器功能。当前页面骨架不会读取或修改配置。"
        )

        this.switcher_group := this.AddGroupBox("x230 y136 w570 h290 Hidden", "输入方案")
        this.switcher_list_header := this.AddText(
            "x254 y174 w250 h24 Center +0x200 Hidden" . surface_options,
            "方案名称"
        )
        this.switcher_list := this.AddListView(
            (initial_dark_mode ? "x254 y198 w250 h154 -Hdr" : "x254 y174 w250 h178")
                . " Checked NoSort -Multi Hidden",
            ["方案名称"]
        )
        this.switcher_list.OnEvent("Click", (ctrl, row) => this.ShowSwitcherDetails(row))
        this.switcher_list.OnEvent("ItemCheck", (*) => this.MarkSwitcherDirty())
        this.switcher_details := this.AddText(
            "x526 y174 w248 h178 Hidden",
            "选择左侧方案以查看简介。"
        )
        this.switcher_hotkeys_label := this.AddText("x254 y374 w116 h24 Hidden", "方案选单快捷键：")
        this.switcher_hotkeys := this.AddEdit("x374 y370 w400 r1 -Multi Hidden")
        this.switcher_hotkeys.OnEvent("Change", (*) => this.MarkSwitcherDirty())
        this.switcher_status := this.AddText("x254 y402 w520 h20 Hidden", "")

        this.behavior_tabs := this.AddTab3(
            "x230 y136 w570 h450 Hidden"
                . (initial_dark_mode ? " cF0F0F0 Background202020" : ""),
            ["常规", "按键绑定"]
        )
        this.behavior_tabs.OnEvent("Change", (*) => this.OnBehaviorTabChanged())
        this.behavior_group := this.behavior_tabs

        this.behavior_tabs.UseTab(1)
        this.behavior_rabbit_group := this.AddGroupBox("x246 y170 w538 h190 Hidden", "玉兔毫行为")
        this.show_tips := this.AddCheckbox("x260 y196 w190 h24 Hidden", "显示输入状态提示")
        this.show_tips.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.show_tips_time_label := this.AddText("x478 y198 w130 h22 Hidden", "显示时长（毫秒）：")
        this.show_tips_time := this.AddEdit("x612 y194 w80 r1 Number -Multi Hidden")
        this.show_tips_time.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.suspend_hotkey_label := this.AddText("x260 y228 w132 h22 Hidden", "暂停/恢复快捷键：")
        this.suspend_hotkey := this.AddEdit("x394 y224 w372 r1 -Multi Hidden")
        this.SetEditCue(this.suspend_hotkey, "例如：Control+Shift+F12")
        this.suspend_hotkey.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.clipboard_mode_label := this.AddText("x260 y260 w96 h22 Hidden", "剪贴板上屏：")
        this.clipboard_mode := this.AddDropDownList(
            "x358 y256 w164 Choose3 Hidden",
            ["从不使用", "始终使用", "达到指定长度时"]
        )
        this.clipboard_mode.OnEvent("Change", (*) => this.OnClipboardModeChanged())
        this.clipboard_length_label := this.AddText("x536 y260 w110 h22 Hidden", "指定长度（字）：")
        this.clipboard_length := this.AddEdit("x648 y256 w118 r1 Number -Multi Hidden")
        this.clipboard_length.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.global_ascii := this.AddCheckbox("x260 y286 w490 h24 Hidden", "在所有程序之间共享中西文状态")
        this.global_ascii.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.fix_candidate_box := this.AddCheckbox("x260 y312 w238 h24 Hidden", "组字时保持候选窗位置不变")
        this.fix_candidate_box.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.use_legacy_candidate_box := this.AddCheckbox("x510 y312 w238 h24 Hidden", "使用旧版候选窗")
        this.use_legacy_candidate_box.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.bypass_password_fields := this.AddCheckbox("x260 y336 w490 h24 Hidden", "在密码输入框中绕过 Rime")
        this.bypass_password_fields.OnEvent("Click", (*) => this.OnBehaviorChanged())

        this.ascii_switch_group := this.AddGroupBox("x246 y366 w538 h110 Hidden", "中西文切换键")
        this.ascii_switch_controls := Map()
        this.AddAsciiSwitchControl("Shift_L", "左 Shift：", 260, 392)
        this.AddAsciiSwitchControl("Shift_R", "右 Shift：", 432, 392)
        this.AddAsciiSwitchControl("Caps_Lock", "Caps Lock：", 604, 392)
        this.AddAsciiSwitchControl("Control_L", "左 Ctrl：", 260, 432)
        this.AddAsciiSwitchControl("Control_R", "右 Ctrl：", 432, 432)
        this.AddAsciiSwitchControl("Eisu_toggle", "英数键：", 604, 432)

        this.menu_group := this.AddGroupBox("x246 y482 w538 h86 Hidden", "候选与翻页")
        this.menu_page_size_label := this.AddText("x260 y508 w88 h22 Hidden", "每页候选数：")
        this.menu_page_size := this.AddEdit("x350 y504 w68 r1 Number -Multi Hidden")
        this.SetEditCue(this.menu_page_size, "5")
        this.menu_page_size.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.menu_labels_label := this.AddText("x438 y508 w90 h22 Hidden", "候选序号：")
        this.menu_labels := this.AddEdit("x530 y504 w236 r1 -Multi Hidden")
        this.SetEditCue(this.menu_labels, "1, 2, 3, 4, 5, 6, 7, 8, 9, 10")
        this.menu_labels.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.menu_help := this.AddText(
            "x260 y538 w506 h22 cGray Hidden",
            "候选序号请用逗号分隔；具体输入方案仍可覆盖候选设置。"
        )

        this.behavior_tabs.UseTab(2)
        this.binding_list := this.AddListView(
            (initial_dark_mode ? "x250 y198 w530 h270 -Hdr" : "x250 y174 w530 h294")
                . " -Multi NoSort Hidden",
            ["接收按键", "生效条件", "动作"]
        )
        this.binding_accept_header := this.AddText(
            "x250 y174 w150 h24 +0x200 Hidden" . surface_options,
            "  接收按键"
        )
        this.binding_when_header := this.AddText(
            "x400 y174 w100 h24 +0x200 Hidden" . surface_options,
            "  生效条件"
        )
        this.binding_action_header := this.AddText(
            "x500 y174 w280 h24 +0x200 Hidden" . surface_options,
            "  动作"
        )
        this.binding_list.OnEvent("DoubleClick", (ctrl, row) => this.EditBinding(row))
        this.binding_add := this.AddButton("x250 y478 w86 h32 Hidden", "添加")
        this.binding_add.OnEvent("Click", (*) => this.AddBinding())
        this.binding_edit := this.AddButton("x344 y478 w86 h32 Hidden", "编辑")
        this.binding_edit.OnEvent("Click", (*) => this.EditBinding())
        this.binding_delete := this.AddButton("x438 y478 w86 h32 Hidden", "删除")
        this.binding_delete.OnEvent("Click", (*) => this.DeleteBinding())
        this.binding_up := this.AddButton("x532 y478 w86 h32 Hidden", "上移")
        this.binding_up.OnEvent("Click", (*) => this.MoveBinding(-1))
        this.binding_down := this.AddButton("x626 y478 w86 h32 Hidden", "下移")
        this.binding_down.OnEvent("Click", (*) => this.MoveBinding(1))
        this.binding_help := this.AddText(
            "x250 y520 w530 h48 cGray Hidden",
            "这里显示当前生效的完整列表。修改后，default.custom.yaml 将完整接管此列表；" .
                "要恢复默认值，请手动删除对应的 custom 配置。"
        )
        this.behavior_tabs.UseTab()

        this.behavior_common_controls := [
            this.behavior_rabbit_group,
            this.show_tips,
            this.show_tips_time_label,
            this.show_tips_time,
            this.suspend_hotkey_label,
            this.suspend_hotkey,
            this.clipboard_mode_label,
            this.clipboard_mode,
            this.clipboard_length_label,
            this.clipboard_length,
            this.global_ascii,
            this.fix_candidate_box,
            this.use_legacy_candidate_box,
            this.bypass_password_fields,
            this.ascii_switch_group,
            this.menu_group,
            this.menu_page_size_label,
            this.menu_page_size,
            this.menu_labels_label,
            this.menu_labels,
            this.menu_help,
        ]
        for key, controls in this.ascii_switch_controls {
            this.behavior_common_controls.Push(controls.label)
            this.behavior_common_controls.Push(controls.dropdown)
        }
        this.behavior_binding_controls := [
            this.binding_list,
            this.binding_add,
            this.binding_edit,
            this.binding_delete,
            this.binding_up,
            this.binding_down,
            this.binding_help,
        ]
        if initial_dark_mode {
            this.behavior_binding_controls.InsertAt(
                1,
                this.binding_accept_header,
                this.binding_when_header,
                this.binding_action_header
            )
        }
        this.behavior_status := this.AddText("x230 y588 w570 h24 Hidden", "")

        this.application_group := this.AddGroupBox("x230 y136 w570 h290 Hidden", "应用适配")
        this.application_process_header := this.AddText(
            "x254 y174 w210 h24 +0x200 Hidden" . surface_options,
            "  应用程序"
        )
        this.application_mode_header := this.AddText(
            "x464 y174 w110 h24 +0x200 Hidden" . surface_options,
            "  默认状态"
        )
        this.application_list := this.AddListView(
            (initial_dark_mode ? "x254 y198 w320 h150 -Hdr" : "x254 y174 w320 h174")
                . " -Multi NoSort Hidden",
            ["应用程序", "默认状态"]
        )
        this.application_list.OnEvent(
            "ItemSelect",
            (ctrl, row, selected) => this.OnApplicationSelection(row, selected)
        )
        this.application_process_label := this.AddText("x596 y176 w178 h22 Hidden", "进程文件名：")
        this.application_process := this.AddEdit("x596 y200 w178 r1 -Multi Hidden")
        this.application_mode_label := this.AddText("x596 y238 w178 h22 Hidden", "默认输入状态：")
        this.application_mode := this.AddDropDownList("x596 y262 w178 Choose2 Hidden", ["中文", "英文"])
        this.application_update_button := this.AddButton("x596 y304 w178 h32 Hidden", "添加或更新")
        this.application_update_button.OnEvent("Click", (*) => this.StageApplicationRule())
        this.application_reset_button := this.AddButton("x596 y346 w178 h32 Hidden", "恢复默认或移除")
        this.application_reset_button.OnEvent("Click", (*) => this.ResetSelectedApplicationRule())
        this.application_status := this.AddText("x254 y390 w320 h24 Hidden", "")

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

        this.dictionary_group := this.AddGroupBox("x230 y136 w570 h290 Hidden", "用户词典")
        this.dictionary_list_label := this.AddText("x254 y170 w218 h22 Hidden", "用户词典列表：")
        this.dictionary_list := this.AddListBox("x254 y194 w218 h204 -Multi Hidden")
        this.dictionary_list.OnEvent("Change", (*) => this.OnDictionarySelectionChange())
        this.dictionary_snapshot_text := this.AddText(
            "x496 y170 w278 h44 Hidden",
            "使用词典快照在不同的 Rime 系统之间迁移输入习惯。"
        )
        this.dictionary_backup := this.AddButton("x496 y220 w134 h32 Disabled Hidden", "输出词典快照")
        this.dictionary_backup.OnEvent("Click", (*) => this.BackupSelectedDictionary())
        this.dictionary_restore := this.AddButton("x640 y220 w134 h32 Disabled Hidden", "合入词典快照")
        this.dictionary_restore.OnEvent("Click", (*) => this.RestoreDictionarySnapshot())
        this.dictionary_table_text := this.AddText(
            "x496 y270 w278 h44 Hidden",
            "使用文本码表查看、编辑或导入词条；迁移数据请优先使用快照。"
        )
        this.dictionary_export := this.AddButton("x496 y320 w134 h32 Disabled Hidden", "导出文本码表")
        this.dictionary_export.OnEvent("Click", (*) => this.ExportSelectedDictionary())
        this.dictionary_import := this.AddButton("x640 y320 w134 h32 Disabled Hidden", "导入文本码表")
        this.dictionary_import.OnEvent("Click", (*) => this.ImportSelectedDictionary())
        this.dictionary_status := this.AddText("x496 y370 w278 h32 Hidden", "")

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
            "x230 y612 w570 h22 cGray",
            "设置内容将在确认后统一保存和部署。"
        )
        this.OnEvent("Close", this.OnClose.Bind(this))
        this.OnEvent("Escape", this.OnClose.Bind(this))

        this.SelectPage(initial_page)
        this.navigation.Enabled := !installing
        if installing {
            this.footer_status.Value := "请选择输入方案，然后完成首次部署。"
        }
        this.UpdateApplyButton()
        factory := theme_factory
        this.window_theme := factory(this)
        this.window_theme.RegisterMuted(
            this.sidebar_subtitle,
            this.page_description,
            this.menu_help,
            this.binding_help,
            this.about_copyright,
            this.footer_status
        )
        this.window_theme.RegisterSurface(
            this.switcher_list_header,
            this.binding_accept_header,
            this.binding_when_header,
            this.binding_action_header,
            this.application_process_header,
            this.application_mode_header
        )
        this.window_theme.Register()
    }

    static PageIndex(page_id := "") {
        local index, page
        if !page_id {
            return 1
        }
        for index, page in RabbitSettingsWindow.pages {
            if page.id = page_id {
                return index
            }
        }
        return 0
    }

    AddAsciiSwitchControl(key, label, x, y) {
        local label_ctrl := this.AddText(Format("x{} y{} w68 h22 Hidden", x, y), label)
        local dropdown := this.AddDropDownList(
            Format("x{} y{} w96 Choose1 Hidden", x + 68, y - 4),
            RabbitSettingsWindow.SWITCH_ACTION_LABELS
        )
        dropdown.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.ascii_switch_controls[key] := { label: label_ctrl, dropdown: dropdown }
    }

    SetEditCue(ctrl, text) {
        static EM_SETCUEBANNER := 0x1501
        DllCall(
            "User32\SendMessageW",
            "Ptr",
            ctrl.Hwnd,
            "UInt",
            EM_SETCUEBANNER,
            "Ptr",
            true,
            "WStr",
            text,
            "Ptr"
        )
    }

    SelectPage(index) {
        local page
        if index < 1 || index > RabbitSettingsWindow.pages.Length {
            return false
        }
        if this.installing && RabbitSettingsWindow.pages[index].id != "input-schemes" {
            if this.selected_page && this.navigation.Value != this.selected_page {
                this.navigation.Choose(this.selected_page)
            }
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
            index != 1 && index != 2 && index != 3 && index != 4 && index != 5 && index != 6 && index != 7
        )
        this.SetAppearanceVisible(index = 1)
        this.SetSwitcherVisible(index = 2)
        this.SetBehaviorVisible(index = 3)
        this.SetApplicationVisible(index = 4)
        this.SetDictionaryVisible(index = 5)
        this.SetMaintenanceVisible(index = 6)
        this.SetAboutVisible(index = 7)
        this.ResizeForPage(index)
        if index = 1 {
            this.EnsureAppearanceSettings()
            this.PreviewAppearance()
        } else if index = 2 {
            this.EnsureSwitcherSettings()
        } else if index = 3 {
            this.EnsureBehaviorSettings()
        } else if index = 4 {
            this.EnsureApplicationSettings()
        } else if index = 5 {
            this.EnsureDictionarySettings()
        }
        this.UpdateApplyButton()
        return true
    }

    GetPageWindowHeight(index := 0) {
        if !index {
            index := this.selected_page
        }
        if index = 1 {
            return RabbitSettingsWindow.APPEARANCE_HEIGHT
        }
        return index = 3 ? RabbitSettingsWindow.BEHAVIOR_HEIGHT : RabbitSettingsWindow.COMPACT_HEIGHT
    }

    ResizeForPage(index := 0) {
        local height := this.GetPageWindowHeight(index)
        this.LayoutSharedControls(height)
        if !this.window_shown {
            return
        }
        super.Show(Format(
            "NA w{} h{}",
            RabbitSettingsWindow.WINDOW_WIDTH,
            height
        ))
        this.ClampWindowToWorkArea()
    }

    LayoutSharedControls(height) {
        this.navigation.Move(, , , height - 170)
        this.apply_button.Move(, height - 66)
        this.sidebar_divider.Move(, , , height - 62)
        this.footer_status.Move(, height - 48)
    }

    ClampWindowToWorkArea() {
        local height, info, width, x, y
        WinGetPos(&x, &y, &width, &height, "ahk_id " . this.Hwnd)
        info := RabbitPopupPlacement.GetWorkAreaAt(x + width / 2, y + height / 2)
        if !info {
            return
        }
        local clamped_y := Min(Max(y, info.work.top), Max(info.work.top, info.work.bottom - height))
        if clamped_y != y {
            WinMove(x, clamped_y, , , "ahk_id " . this.Hwnd)
        }
    }

    SetPlaceholderVisible(visible) {
        this.placeholder.Visible := visible
        this.placeholder_text.Visible := visible
    }

    SetAppearanceVisible(visible) {
        this.appearance_tabs.Visible := visible
        this.SetAppearanceTabControlsVisible(visible)
        this.appearance_status.Visible := visible
        if !visible && this.appearance_preview && HasMethod(this.appearance_preview, "Hide") {
            this.appearance_preview.Hide()
        }
    }

    SetAppearanceTabControlsVisible(visible) {
        local color_visible := visible && this.appearance_tabs.Value = 1
        local typesetting_visible := visible && this.appearance_tabs.Value = 2
        for ctrl in this.appearance_color_controls {
            ctrl.Visible := color_visible
        }
        for ctrl in this.appearance_typesetting_controls {
            ctrl.Visible := typesetting_visible
        }
    }

    OnAppearanceTabChanged() {
        this.SetAppearanceTabControlsVisible(this.selected_page = 1)
    }

    SetSwitcherVisible(visible) {
        this.switcher_group.Visible := visible
        this.switcher_list_header.Visible := visible && this.initial_dark_mode
        this.switcher_list.Visible := visible
        this.switcher_details.Visible := visible
        this.switcher_hotkeys_label.Visible := visible
        this.switcher_hotkeys.Visible := visible
        this.switcher_status.Visible := visible
    }

    SetBehaviorVisible(visible) {
        this.behavior_tabs.Visible := visible
        this.SetBehaviorTabControlsVisible(visible)
        this.behavior_status.Visible := visible
    }

    SetBehaviorTabControlsVisible(visible) {
        local common_visible := visible && this.behavior_tabs.Value = 1
        local bindings_visible := visible && this.behavior_tabs.Value = 2
        for ctrl in this.behavior_common_controls {
            ctrl.Visible := common_visible
        }
        for ctrl in this.behavior_binding_controls {
            ctrl.Visible := bindings_visible
        }
    }

    OnBehaviorTabChanged() {
        this.SetBehaviorTabControlsVisible(this.selected_page = 3)
    }

    SetApplicationVisible(visible) {
        this.application_group.Visible := visible
        this.application_process_header.Visible := visible && this.initial_dark_mode
        this.application_mode_header.Visible := visible && this.initial_dark_mode
        this.application_list.Visible := visible
        this.application_process_label.Visible := visible
        this.application_process.Visible := visible
        this.application_mode_label.Visible := visible
        this.application_mode.Visible := visible
        this.application_update_button.Visible := visible
        this.application_reset_button.Visible := visible
        this.application_status.Visible := visible
    }

    SetDictionaryVisible(visible) {
        this.dictionary_group.Visible := visible
        this.dictionary_list_label.Visible := visible
        this.dictionary_list.Visible := visible
        this.dictionary_snapshot_text.Visible := visible
        this.dictionary_backup.Visible := visible
        this.dictionary_restore.Visible := visible
        this.dictionary_table_text.Visible := visible
        this.dictionary_export.Visible := visible
        this.dictionary_import.Visible := visible
        this.dictionary_status.Visible := visible
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
        } catch as err {
            MsgBox("无法打开链接：`n" . err.Message, "【玉兔毫】", "Ok Iconx")
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
            if this.old_windows {
                this.appearance_status.Value := "旧版 Windows 暂不支持预览。"
            } else try {
                this.CreateAppearancePreview()
                this.PreviewAppearance()
            } catch as err {
                this.appearance_status.Value := "无法显示预览：" . err.Message
            }
            return true
        } catch as err {
            this.appearance_status.Value := err.Message
            return false
        }
    }

    CreateAppearancePreview() {
        local factory
        if this.old_windows || this.appearance_preview {
            return
        }
        factory := this.preview_factory
        this.appearance_preview := factory(this)
    }

    PopulateAppearanceSettings() {
        local style
        this.appearance_loading := true
        try {
            this.appearance_light_scheme := this.appearance_settings.GetActiveColorScheme()
            this.appearance_dark_scheme := HasMethod(this.appearance_settings, "GetActiveColorSchemeDark")
                ? this.appearance_settings.GetActiveColorSchemeDark()
                : ""
            style := HasMethod(this.appearance_settings, "GetCurrentStyle")
                ? this.appearance_settings.GetCurrentStyle()
                : RabbitUIStyleSnapshot()
            this.appearance_style := style
            this.appearance_presets := this.appearance_settings.GetPresetColorSchemes()
            this.PopulateAppearanceColorList()
            this.PopulateAppearanceStyle(style)
            this.appearance_dirty := false
            this.appearance_status.Value := this.appearance_presets.Length
                ? ""
                : "没有找到可用的配色。"
        } finally {
            this.appearance_loading := false
        }
        this.UpdateAppearanceConditionalControls()
        this.PreviewAppearance()
    }

    PopulateAppearanceColorList() {
        local active_index := 0
        local names := []
        local selected_id := this.appearance_target.Value = 2
            ? this.appearance_dark_scheme
            : this.appearance_light_scheme
        for i, info in this.appearance_presets {
            names.Push(info.name)
            if info.color_scheme_id = selected_id {
                active_index := i
            }
        }
        this.appearance_list.Delete()
        this.appearance_list.Add(names)
        if active_index > 0 {
            this.appearance_list.Choose(active_index)
            this.ShowAppearanceDetails(active_index)
        } else {
            this.appearance_list.Choose(0)
            this.appearance_details.Value := this.appearance_target.Value = 2
                ? "深色模式当前跟随浅色配色。"
                : ""
        }
    }

    PopulateAppearanceStyle(style) {
        this.SetAppearanceFontValue(this.appearance_font, style.font_face)
        this.SetAppearanceFontValue(this.appearance_preedit_font, style.preedit_font_face)
        this.SetAppearanceFontValue(this.appearance_label_font, style.label_font_face)
        this.SetAppearanceFontValue(this.appearance_comment_font, style.comment_font_face)
        this.appearance_font_point.Value := style.font_point
        this.appearance_label_font_point.Value := style.label_font_point
        this.appearance_comment_font_point.Value := style.comment_font_point
        this.appearance_label_format.Value := style.label_format
        this.appearance_layout_type.Choose(
            style.layout_type = "flow" ? 2 : style.layout_type = "vertical_text" ? 3 : 1)
        this.appearance_align_type.Choose(
            style.align_type = "center" ? 2 : style.align_type = "bottom" ? 3 : 1)
        this.appearance_margin_x.Value := style.margin_x
        this.appearance_margin_y.Value := style.margin_y
        this.appearance_border_width.Value := style.border_width
        this.appearance_corner_radius.Value := style.corner_radius
        this.appearance_round_corner.Value := style.round_corner
        this.appearance_min_width.Value := style.min_width
        this.appearance_min_height.Value := style.min_height
        this.appearance_flow_rows.Value := style.flow_rows
        this.appearance_vertical_direction.Value := style.vertical_text_left_to_right
        this.appearance_floating_preedit.Value := style.floating_preedit
        this.appearance_floating_opacity.Value := Round(style.floating_preedit_opacity * 100)
        this.appearance_floating_height.Value := style.floating_preedit_min_height
    }

    SetAppearanceFontValue(ctrl, value) {
        local fonts := RabbitSettingsWindow.GetInstalledFontFaces()
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

    OnAppearanceTargetChange() {
        if this.appearance_loading {
            return
        }
        this.appearance_loading := true
        try {
            this.PopulateAppearanceColorList()
        } finally {
            this.appearance_loading := false
        }
        this.PreviewAppearance()
    }

    OnAppearanceSelectionChange() {
        local index := this.appearance_list.Value
        if this.appearance_loading || index < 1 || index > this.appearance_presets.Length {
            return
        }
        local scheme_id := this.appearance_presets[index].color_scheme_id
        if this.appearance_target.Value = 2 {
            if HasMethod(this.appearance_settings, "SelectDarkColorScheme") {
                this.appearance_settings.SelectDarkColorScheme(scheme_id)
            }
            this.appearance_dark_scheme := scheme_id
        } else {
            this.appearance_settings.SelectColorScheme(scheme_id)
            this.appearance_light_scheme := scheme_id
        }
        this.ShowAppearanceDetails(index)
        this.MarkAppearanceDirty()
        this.PreviewAppearance()
    }

    ShowAppearanceDetails(index) {
        local info
        if index < 1 || index > this.appearance_presets.Length {
            return
        }
        info := this.appearance_presets[index]
        this.appearance_details.Value := info.author ? "作者：" . info.author : ""
    }

    OnAppearanceControlsChanged() {
        if this.appearance_loading {
            return
        }
        this.UpdateAppearanceConditionalControls()
        try {
            local values := this.GetAppearanceValues()
            if this.appearance_settings && HasMethod(this.appearance_settings, "SetStyleValues") {
                this.appearance_settings.SetStyleValues(values)
            }
            this.appearance_status.Value := ""
            this.MarkAppearanceDirty()
            this.PreviewAppearance(values)
        } catch as err {
            this.appearance_status.Value := err.Message
        }
    }

    UpdateAppearanceConditionalControls() {
        local flow := this.appearance_layout_type.Value = 2
        local vertical := this.appearance_layout_type.Value = 3
        local stacked := !flow && !vertical
        local floating := !!this.appearance_floating_preedit.Value
        this.appearance_align_type.Enabled := flow
        this.appearance_flow_rows.Enabled := flow
        this.appearance_vertical_direction.Enabled := vertical
        this.appearance_min_width_label.Enabled := stacked
        this.appearance_min_width.Enabled := stacked
        this.appearance_min_height_label.Enabled := vertical
        this.appearance_min_height.Enabled := vertical
        this.appearance_floating_opacity.Enabled := floating
        this.appearance_floating_height.Enabled := floating
    }

    MarkAppearanceDirty() {
        this.appearance_dirty := true
        this.footer_status.Value := "外观设置尚未保存。"
        this.UpdateApplyButton()
    }

    GetAppearanceValues() {
        local font_face := Trim(this.appearance_font.Text)
        local preedit_font_face := Trim(this.appearance_preedit_font.Text)
        local label_font_face := Trim(this.appearance_label_font.Text)
        local comment_font_face := Trim(this.appearance_comment_font.Text)
        local label_format := this.appearance_label_format.Value
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
            "font_point", this.ReadAppearanceNumber(this.appearance_font_point, "候选字号", 6, 72),
            "label_font_point", this.ReadAppearanceNumber(
                this.appearance_label_font_point, "候选序号字号", 6, 72),
            "comment_font_point", this.ReadAppearanceNumber(
                this.appearance_comment_font_point, "候选注释字号", 6, 72),
            "label_format", label_format,
            "layout_type", ["stacked", "flow", "vertical_text"][this.appearance_layout_type.Value],
            "align_type", ["top", "center", "bottom"][this.appearance_align_type.Value],
            "margin_x", this.ReadAppearanceNumber(this.appearance_margin_x, "水平边距", 0, 500),
            "margin_y", this.ReadAppearanceNumber(this.appearance_margin_y, "垂直边距", 0, 500),
            "border_width", this.ReadAppearanceNumber(
                this.appearance_border_width, "边框宽度", 0, 500),
            "corner_radius", this.ReadAppearanceNumber(
                this.appearance_corner_radius, "窗口圆角", 0, 500),
            "round_corner", this.ReadAppearanceNumber(
                this.appearance_round_corner, "候选及高亮圆角", 0, 500),
            "min_width", this.ReadAppearanceNumber(this.appearance_min_width, "堆叠最小宽度", 0, 2000),
            "min_height", this.ReadAppearanceNumber(this.appearance_min_height, "竖排最小高度", 0, 2000),
            "flow_rows", this.ReadAppearanceNumber(this.appearance_flow_rows, "展开页数", 1, 9),
            "vertical_text_left_to_right", !!this.appearance_vertical_direction.Value,
            "floating_preedit", !!this.appearance_floating_preedit.Value,
            "floating_preedit_opacity", this.ReadAppearanceNumber(
                this.appearance_floating_opacity, "浮动预编辑不透明度", 0, 100) / 100,
            "floating_preedit_min_height", this.ReadAppearanceNumber(
                this.appearance_floating_height, "浮动预编辑最小高度", 0, 500)
        )
    }

    ReadAppearanceNumber(ctrl, name, minimum, maximum) {
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

    FindAppearancePreset(color_scheme_id) {
        for index, info in this.appearance_presets {
            if info.color_scheme_id = color_scheme_id {
                return index
            }
        }
        return 0
    }

    PreviewAppearance(values := 0) {
        local index, info, selected_id, style
        if !this.appearance_preview || !this.appearance_presets.Length {
            return false
        }
        try {
            selected_id := this.appearance_target.Value = 2 && this.appearance_dark_scheme
                ? this.appearance_dark_scheme
                : this.appearance_light_scheme
            index := this.FindAppearancePreset(selected_id)
            if !index {
                index := 1
            }
            info := this.appearance_presets[index]
            if !values {
                try values := this.GetAppearanceValues()
            }
            style := values ? info.style.With(values) : info.style
            this.appearance_preview.Render(style, this.GetAppearancePreviewLabels())
            if InStr(this.appearance_status.Value, "无法显示预览：") = 1 {
                this.appearance_status.Value := ""
            }
            return true
        } catch as err {
            this.appearance_status.Value := "无法显示预览：" . err.Message
            return false
        }
    }

    GetAppearancePreviewLabels() {
        local label
        local labels := []
        if !this.behavior_model {
            if !this.workflow || !HasMethod(this.workflow, "CreateBehaviorSettingsModel") {
                return labels
            }
            if !this.EnsureBehaviorSettings() {
                return labels
            }
        }
        Loop Parse this.menu_labels.Value, "," {
            if (label := Trim(A_LoopField)) {
                labels.Push(label)
            }
        }
        return labels
    }

    ApplyAppearanceSettings() {
        local deploy_result, values
        if !this.appearance_settings || !this.appearance_dirty {
            return false
        }
        try {
            values := this.GetAppearanceValues()
            if HasMethod(this.appearance_settings, "SetStyleValues") {
                this.appearance_settings.SetStyleValues(values)
            }
        } catch as err {
            this.appearance_status.Value := err.Message
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
        } catch as err {
            this.appearance_status.Value := "保存失败：" . err.Message
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
            case 4:
                return this.ApplyApplicationSettings()
        }
        return false
    }

    HasUnsavedSettings() {
        return this.appearance_dirty || this.switcher_dirty || this.behavior_dirty ||
            this.application_dirty
    }

    PromptUnsavedSettings() {
        if this.close_prompt {
            return this.close_prompt.Call()
        }
        return MsgBox(
            "设置窗口中有尚未保存的更改。`n`n" .
                "选择“是”保存并部署；选择“否”放弃更改；选择“取消”继续编辑。",
            "【玉兔毫】",
            "YesNoCancel Icon!"
        )
    }

    ApplyAllPendingSettings() {
        local appearance_values := 0
        local behavior_values := 0
        local deploy_result, schema_ids := 0
        if this.installing {
            return this.CompleteInstallation()
        }
        if !this.HasUnsavedSettings() {
            return true
        }

        if this.switcher_dirty {
            schema_ids := this.SelectedSchemaIds()
            if schema_ids.Length = 0 {
                this.SelectPage(2)
                this.switcher_status.Value := "至少要选用一项输入方案。"
                return false
            }
        }
        if this.appearance_dirty {
            try {
                appearance_values := this.GetAppearanceValues()
            } catch as err {
                this.SelectPage(1)
                this.appearance_status.Value := err.Message
                return false
            }
        }
        if this.behavior_dirty {
            try {
                behavior_values := this.GetBehaviorValues()
            } catch as err {
                this.SelectPage(3)
                this.behavior_status.Value := err.Message
                return false
            }
        }

        this.Opt("+Disabled")
        this.footer_status.Value := "正在保存所有更改…"
        try {
            if this.appearance_dirty {
                if this.appearance_settings && HasMethod(this.appearance_settings, "SetStyleValues") {
                    this.appearance_settings.SetStyleValues(appearance_values)
                }
                if !this.appearance_settings || !this.appearance_settings.Save() {
                    this.SelectPage(1)
                    this.appearance_status.Value := "未能保存外观设置。"
                    return false
                }
            }
            if this.switcher_dirty {
                if !this.switcher_model || !this.switcher_model.Save(
                    schema_ids,
                    Trim(this.switcher_hotkeys.Value)
                ) {
                    this.SelectPage(2)
                    this.switcher_status.Value := "未能保存输入方案设置。"
                    return false
                }
            }
            if this.behavior_dirty {
                if !this.behavior_model || !this.behavior_model.Save(behavior_values) {
                    this.SelectPage(3)
                    this.behavior_status.Value := "未能保存输入与行为设置。"
                    return false
                }
            }
            if this.application_dirty {
                if !this.application_model || !this.application_model.Save(this.application_changes) {
                    this.SelectPage(4)
                    this.application_status.Value := "未能保存应用适配设置。"
                    return false
                }
            }

            deploy_result := this.workflow.UpdateWorkspace(true)
            if deploy_result != 0 {
                this.footer_status.Value := "设置已保存，但重新部署失败。"
                return false
            }

            if this.appearance_dirty {
                this.appearance_dirty := false
                this.appearance_status.Value := "外观设置已保存。"
            }
            if this.switcher_dirty {
                this.switcher_dirty := false
                this.switcher_status.Value := "输入方案设置已保存。"
            }
            if this.behavior_dirty {
                this.behavior_dirty := false
                this.behavior_status.Value := "输入与行为设置已保存。"
            }
            if this.application_dirty {
                this.application_dirty := false
                this.application_changes := Map()
                this.application_status.Value := "应用适配设置已保存。"
            }
            this.footer_status.Value := "所有更改均已保存并部署。"
            this.UpdateApplyButton()
            return true
        } catch as err {
            this.footer_status.Value := "保存失败：" . err.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    CompleteInstallation() {
        local deploy_result, reloaded, schema_ids
        if !this.installing || !this.EnsureSwitcherSettings() {
            return false
        }
        schema_ids := this.SelectedSchemaIds()
        if schema_ids.Length = 0 {
            this.switcher_status.Value := "至少要选用一项输入方案。"
            return false
        }

        this.Opt("+Disabled")
        this.footer_status.Value := "正在保存输入方案并完成首次部署…"
        try {
            if !this.switcher_model.Save(schema_ids, Trim(this.switcher_hotkeys.Value)) {
                this.switcher_status.Value := "未能保存输入方案设置。"
                return false
            }
            this.DisposeSwitcherSettings()
            deploy_result := this.workflow.UpdateWorkspace(true)
            if deploy_result != 0 {
                this.EnsureSwitcherSettings()
                this.footer_status.Value := "首次部署失败，请重试。"
                return false
            }

            this.installing := false
            this.navigation.Enabled := true
            reloaded := this.EnsureSwitcherSettings()
            this.switcher_dirty := false
            if reloaded {
                this.switcher_status.Value := "输入方案设置已保存。"
                this.footer_status.Value := "首次部署完成，其他设置页面已解锁。"
            } else {
                this.footer_status.Value := "首次部署完成，但无法重新读取输入方案；其他页面已解锁。"
            }
            this.UpdateApplyButton()
            return true
        } catch as err {
            this.EnsureSwitcherSettings()
            this.footer_status.Value := "首次部署失败：" . err.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    UpdateApplyButton() {
        if this.installing {
            this.apply_button.Text := "完成安装并部署"
            this.apply_button.Enabled := true
            return
        }
        this.apply_button.Text := "应用并重新部署"
        this.apply_button.Enabled := this.HasUnsavedSettings()
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
        } catch as err {
            this.behavior_status.Value := err.Message
            return false
        }
    }

    PopulateBehaviorSettings() {
        local controls, key
        this.behavior_loading := true
        try {
            this.show_tips.Value := this.behavior_model.show_tips
            this.show_tips_time.Value := this.behavior_model.show_tips_time
            this.suspend_hotkey.Value := this.behavior_model.suspend_hotkey
            this.clipboard_mode.Choose(
                this.behavior_model.send_by_clipboard_length < 0
                    ? 1
                    : this.behavior_model.send_by_clipboard_length = 0 ? 2 : 3
            )
            this.clipboard_length.Value := this.behavior_model.send_by_clipboard_length > 0
                ? this.behavior_model.send_by_clipboard_length
                : 8
            this.global_ascii.Value := this.behavior_model.global_ascii
            this.fix_candidate_box.Value := this.behavior_model.fix_candidate_box
            this.use_legacy_candidate_box.Value := this.behavior_model.use_legacy_candidate_box
            this.bypass_password_fields.Value := this.behavior_model.bypass_password_fields
            for key, controls in this.ascii_switch_controls {
                controls.dropdown.Choose(this.SwitchActionIndex(this.behavior_model.switch_key[key]))
            }
            this.menu_page_size.Value := this.behavior_model.page_size
            this.menu_labels.Value := RabbitBehaviorSettingsModel.Join(
                this.behavior_model.alternative_select_labels,
                ", "
            )
            this.bindings := this.behavior_model.GetBindings()
            this.RefreshBindingList()
            this.show_tips_time.Enabled := !!this.show_tips.Value
            this.UpdateClipboardControls()
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

    OnClipboardModeChanged() {
        this.UpdateClipboardControls()
        this.OnBehaviorChanged()
    }

    UpdateClipboardControls() {
        local use_threshold := this.clipboard_mode.Value = 3
        this.clipboard_length_label.Enabled := use_threshold
        this.clipboard_length.Enabled := use_threshold
    }

    GetBehaviorValues() {
        local controls, key, label
        local labels := []
        local page_size := Trim(this.menu_page_size.Value)
        local show_tips_time := Trim(this.show_tips_time.Value)
        local clipboard_length := Trim(this.clipboard_length.Value)
        if !RegExMatch(show_tips_time, "^\d+$") || Number(show_tips_time) > 2147483647 {
            throw ValueError("状态提示显示时长必须是非负整数。")
        }
        if !page_size {
            page_size := "5"
        }
        if !RegExMatch(page_size, "^\d+$") || Number(page_size) < 1 || Number(page_size) > 10 {
            throw ValueError("每页候选数必须是 1 到 10 之间的整数。")
        }
        if this.clipboard_mode.Value = 3
            && (!RegExMatch(clipboard_length, "^\d+$")
                || Number(clipboard_length) < 1
                || Number(clipboard_length) > 2147483647) {
            throw ValueError("剪贴板上屏的指定长度必须是正整数。")
        }
        Loop Parse this.menu_labels.Value, "," {
            if (label := Trim(A_LoopField)) {
                labels.Push(label)
            }
        }
        local switch_key := Map()
        for key, controls in this.ascii_switch_controls {
            switch_key[key] := RabbitSettingsWindow.SWITCH_ACTION_VALUES[controls.dropdown.Value]
        }
        return {
            show_tips: !!this.show_tips.Value,
            show_tips_time: Number(show_tips_time),
            suspend_hotkey: Trim(this.suspend_hotkey.Value),
            send_by_clipboard_length: this.clipboard_mode.Value = 1
                ? -1
                : this.clipboard_mode.Value = 2 ? 0 : Number(clipboard_length),
            global_ascii: !!this.global_ascii.Value,
            fix_candidate_box: !!this.fix_candidate_box.Value,
            use_legacy_candidate_box: !!this.use_legacy_candidate_box.Value,
            bypass_password_fields: !!this.bypass_password_fields.Value,
            switch_key: switch_key,
            page_size: Number(page_size),
            alternative_select_labels: labels,
            bindings: RabbitBehaviorSettingsModel.CloneValue(this.bindings),
        }
    }

    ApplyBehaviorSettings() {
        local deploy_result, values
        if !this.behavior_model || !this.behavior_dirty {
            return false
        }
        try {
            values := this.GetBehaviorValues()
        } catch as err {
            this.behavior_status.Value := err.Message
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
        } catch as err {
            this.behavior_status.Value := "保存失败：" . err.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    EnsureApplicationSettings() {
        if this.application_model {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateApplicationSettingsModel") {
            this.application_status.Value := "当前环境无法读取应用适配设置。"
            return false
        }
        try {
            this.application_model := this.workflow.CreateApplicationSettingsModel()
            this.PopulateApplicationSettings()
            return true
        } catch as err {
            this.application_status.Value := err.Message
            return false
        }
    }

    PopulateApplicationSettings() {
        local ascii_mode, process_name
        local first_row := 0
        this.application_loading := true
        try {
            this.application_list.Delete()
            this.application_rules := Map()
            this.application_changes := Map()
            for process_name, ascii_mode in this.application_model.rules {
                this.application_rules[process_name] := ascii_mode
                if !first_row {
                    first_row := this.application_list.Add("", process_name, this.ApplicationModeText(ascii_mode))
                } else {
                    this.application_list.Add("", process_name, this.ApplicationModeText(ascii_mode))
                }
            }
            this.application_list.ModifyCol(1, 210)
            this.application_list.ModifyCol(2, 86)
            this.application_process.Value := ""
            this.application_mode.Choose(2)
            this.application_dirty := false
            this.UpdateApplyButton()
            this.application_status.Value := this.application_rules.Count ? "" : "尚未设置应用规则。"
        } finally {
            this.application_loading := false
        }
        if first_row {
            this.application_list.Modify(first_row, "Select Focus")
            this.OnApplicationSelection(first_row, true)
        }
    }

    ApplicationModeText(ascii_mode) {
        return ascii_mode ? "英文" : "中文"
    }

    OnApplicationSelection(row, selected) {
        local process_name
        if this.application_loading || !selected || row < 1 {
            return
        }
        process_name := this.application_list.GetText(row, 1)
        if !this.application_rules.Has(process_name) {
            return
        }
        this.application_process.Value := process_name
        this.application_mode.Choose(this.application_rules[process_name] ? 2 : 1)
    }

    StageApplicationRule() {
        local ascii_mode, process_name, row
        if !this.application_model {
            return false
        }
        process_name := RabbitApplicationSettingsModel.NormalizeProcessName(this.application_process.Value)
        if !RabbitApplicationSettingsModel.IsValidProcessName(process_name) {
            this.application_status.Value := "请输入进程文件名，例如 code.exe。"
            return false
        }
        ascii_mode := this.application_mode.Value = 2
        row := this.FindApplicationRow(process_name)
        if row {
            this.application_list.Modify(row, "", process_name, this.ApplicationModeText(ascii_mode))
        } else {
            row := this.application_list.Add("", process_name, this.ApplicationModeText(ascii_mode))
        }
        this.application_rules[process_name] := ascii_mode
        this.application_changes[process_name] := { reset: false, ascii_mode: ascii_mode }
        this.application_process.Value := process_name
        this.application_list.Modify(row, "Select Focus Vis")
        this.MarkApplicationDirty("应用规则尚未保存。")
        return true
    }

    ResetSelectedApplicationRule() {
        local process_name
        local row := this.application_list.GetNext(0)
        if !this.application_model {
            return false
        }
        if !row {
            this.application_status.Value := "请先选择一条应用规则。"
            return false
        }
        process_name := this.application_list.GetText(row, 1)
        this.application_changes[process_name] := { reset: true }
        this.application_rules.Delete(process_name)
        this.application_list.Delete(row)
        this.application_process.Value := ""
        this.application_mode.Choose(2)
        this.MarkApplicationDirty("保存后将恢复默认值或移除自定义规则。")
        return true
    }

    FindApplicationRow(process_name) {
        Loop this.application_list.GetCount() {
            if this.application_list.GetText(A_Index, 1) = process_name {
                return A_Index
            }
        }
        return 0
    }

    MarkApplicationDirty(message) {
        this.application_dirty := true
        this.application_status.Value := message
        this.footer_status.Value := "应用适配设置尚未保存。"
        this.UpdateApplyButton()
    }

    ApplyApplicationSettings() {
        local deploy_result
        if !this.application_model || !this.application_dirty {
            return false
        }
        this.Opt("+Disabled")
        this.application_status.Value := "正在保存…"
        try {
            if !this.application_model.Save(this.application_changes) {
                this.application_status.Value := "未能保存应用适配设置。"
                return false
            }
            deploy_result := this.workflow.UpdateWorkspace(true)
            if deploy_result != 0 {
                this.application_status.Value := "设置已保存，但重新部署失败。"
                return false
            }
            if !this.application_model.Load() {
                this.application_status.Value := "设置已保存，但无法重新读取应用规则。"
                return false
            }
            this.PopulateApplicationSettings()
            this.application_status.Value := "应用适配设置已保存。"
            this.footer_status.Value := "设置内容将在确认后统一保存和部署。"
            return true
        } catch as err {
            this.application_status.Value := "保存失败：" . err.Message
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
        } catch as err {
            this.switcher_status.Value := err.Message
            return false
        }
    }

    DisposeSwitcherSettings() {
        if this.switcher_model {
            this.switcher_model.Dispose()
            this.switcher_model := 0
        }
        this.switcher_items := Map()
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
        } catch as err {
            this.switcher_status.Value := "保存失败：" . err.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    EnsureDictionarySettings() {
        if this.dictionary_model {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateDictionarySettingsModel") {
            this.dictionary_status.Value := "当前环境无法读取用户词典。"
            return false
        }
        try {
            this.dictionary_model := this.workflow.CreateDictionarySettingsModel()
            this.PopulateDictionarySettings()
            return true
        } catch as err {
            this.dictionary_restore.Enabled := false
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    PopulateDictionarySettings() {
        local dict_name
        this.dictionary_list.Delete()
        for dict_name in this.dictionary_model.dictionaries {
            this.dictionary_list.Add([dict_name])
        }
        this.dictionary_list.Choose(0)
        this.OnDictionarySelectionChange()
        this.dictionary_restore.Enabled := true
        this.dictionary_status.Value := this.dictionary_model.dictionaries.Length ? "" : "没有找到用户词典。"
    }

    OnDictionarySelectionChange() {
        local enabled := this.dictionary_list.Value > 0
        this.dictionary_backup.Enabled := enabled
        this.dictionary_export.Enabled := enabled
        this.dictionary_import.Enabled := enabled
    }

    SelectedDictionaryName() {
        local index := this.dictionary_list.Value
        if !this.dictionary_model {
            this.dictionary_status.Value := "当前环境无法访问用户词典。"
            return ""
        }
        if index <= 0 || index > this.dictionary_model.dictionaries.Length {
            this.dictionary_status.Value := "请先选择一个用户词典。"
            return ""
        }
        return this.dictionary_list.Text
    }

    BackupSelectedDictionary() {
        local dict_name, file, path
        if !(dict_name := this.SelectedDictionaryName()) {
            return false
        }
        try {
            path := this.dictionary_model.GetUserDataSyncDir()
            if !DirExist(path) {
                DirCreate(path)
            }
            file := path . "\" . dict_name . ".userdb.txt"
            this.dictionary_status.Value := "正在输出词典快照…"
            if !this.dictionary_model.Backup(dict_name) {
                throw Error("未能输出词典快照。")
            }
            if !FileExist(file) {
                throw Error("输出的词典快照文件没有找到。")
            }
            this.dictionary_status.Value := "词典快照已输出。"
            Run("explorer.exe /select,`"" . file . "`"")
            return true
        } catch as err {
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    RestoreDictionarySnapshot() {
        local selected_path
        local filter := "词典快照 (*.userdb.txt; *.userdb.kct.snapshot)"
        if !this.dictionary_model {
            this.dictionary_status.Value := "当前环境无法访问用户词典。"
            return false
        }
        if !(selected_path := FileSelect("1", , "打开", filter)) {
            return false
        }
        try {
            this.dictionary_status.Value := "正在合入词典快照…"
            if !this.dictionary_model.Restore(selected_path) {
                throw Error("未能合入词典快照。")
            }
            this.dictionary_status.Value := "词典快照已合入。"
            return true
        } catch as err {
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    ExportSelectedDictionary() {
        local dict_name, result, selected_path
        local filter := "文本文档 (*.txt)"
        if !(dict_name := this.SelectedDictionaryName()) {
            return false
        }
        if !(selected_path := FileSelect("S18", dict_name . "_export.txt", "另存为", filter)) {
            return false
        }
        if StrLower(SubStr(selected_path, -4)) != ".txt" {
            selected_path .= ".txt"
        }
        try {
            this.dictionary_status.Value := "正在导出文本码表…"
            result := this.dictionary_model.Export(dict_name, selected_path)
            if result < 0 {
                throw Error("未能导出文本码表。")
            }
            if !FileExist(selected_path) {
                throw Error("导出的文本码表文件没有找到。")
            }
            this.dictionary_status.Value := "已导出 " . result . " 条记录。"
            Run("explorer.exe /select,`"" . selected_path . "`"")
            return true
        } catch as err {
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    ImportSelectedDictionary() {
        local dict_name, result, selected_path
        local filter := "文本文档 (*.txt)"
        if !(dict_name := this.SelectedDictionaryName()) {
            return false
        }
        if !(selected_path := FileSelect("1", dict_name . "_export.txt", "打开", filter)) {
            return false
        }
        try {
            this.dictionary_status.Value := "正在导入文本码表…"
            result := this.dictionary_model.Import(dict_name, selected_path)
            if result < 0 {
                throw Error("未能导入文本码表。")
            }
            this.dictionary_status.Value := "已导入 " . result . " 条记录。"
            return true
        } catch as err {
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    RunDictionaryManagement() {
        if !this.workflow {
            return false
        }
        try {
            return this.workflow.DictManagement() = 0
        } catch as err {
            MsgBox("未能打开用户词典管理：`n" . err.Message, "【玉兔毫】", "Ok Iconx")
            return false
        }
    }

    RunDeploy() {
        if this.installing {
            return this.CompleteInstallation()
        }
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
        } catch as err {
            this.operation_status.Value := failure_message . " " . err.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    SwitchActionIndex(action) {
        local index, value
        for index, value in RabbitSettingsWindow.SWITCH_ACTION_VALUES {
            if value = action {
                return index
            }
        }
        return 1
    }

    RefreshBindingList(selected_row := 0) {
        local action_key, action_value, binding, row
        this.binding_list.Delete()
        for binding in this.bindings {
            action_key := RabbitKeyBindingDialog.FindAction(binding, &action_value)
            row := this.binding_list.Add(
                "",
                binding.Has("accept") ? this.BindingValueText(binding["accept"]) : "",
                binding.Has("when") ? this.BindingValueText(binding["when"]) : "",
                action_key ? action_key . ": " . this.BindingValueText(action_value) : ""
            )
        }
        this.binding_list.ModifyCol(1, 150)
        this.binding_list.ModifyCol(2, 100)
        this.binding_list.ModifyCol(3, 252)
        if selected_row && selected_row <= this.bindings.Length {
            this.binding_list.Modify(selected_row, "Select Focus Vis")
        }
    }

    BindingValueText(value) {
        if value is Map || value is Array {
            return "…"
        }
        return String(value)
    }

    AddBinding() {
        local binding := RabbitKeyBindingDialog(this, 0, this.window_theme.dark_mode_reader).ShowModal()
        if !binding {
            return false
        }
        this.bindings.Push(binding)
        this.RefreshBindingList(this.bindings.Length)
        this.MarkBindingsDirty()
        return true
    }

    EditBinding(row := 0) {
        local binding
        if !row {
            row := this.binding_list.GetNext(0)
        }
        if row < 1 || row > this.bindings.Length {
            this.behavior_status.Value := "请先选择一条快捷键规则。"
            return false
        }
        binding := RabbitKeyBindingDialog(
            this,
            this.bindings[row],
            this.window_theme.dark_mode_reader
        ).ShowModal()
        if !binding {
            return false
        }
        this.bindings[row] := binding
        this.RefreshBindingList(row)
        this.MarkBindingsDirty()
        return true
    }

    DeleteBinding() {
        local row := this.binding_list.GetNext(0)
        if row < 1 || row > this.bindings.Length {
            this.behavior_status.Value := "请先选择一条快捷键规则。"
            return false
        }
        this.bindings.RemoveAt(row)
        this.RefreshBindingList(Min(row, this.bindings.Length))
        this.MarkBindingsDirty()
        return true
    }

    MoveBinding(offset) {
        local binding, target
        local row := this.binding_list.GetNext(0)
        if row < 1 || row > this.bindings.Length {
            this.behavior_status.Value := "请先选择一条快捷键规则。"
            return false
        }
        target := row + offset
        if target < 1 || target > this.bindings.Length {
            return false
        }
        binding := this.bindings.RemoveAt(row)
        this.bindings.InsertAt(target, binding)
        this.RefreshBindingList(target)
        this.MarkBindingsDirty()
        return true
    }

    MarkBindingsDirty() {
        this.behavior_status.Value := ""
        this.OnBehaviorChanged()
    }

    Show(options := "") {
        local height := this.GetPageWindowHeight()
        this.LayoutSharedControls(height)
        super.Show(Trim(options . Format(
            " w{} h{}",
            RabbitSettingsWindow.WINDOW_WIDTH,
            height
        )))
        this.window_shown := true
        this.ClampWindowToWorkArea()
        if this.selected_page = 1 {
            this.PreviewAppearance()
        }
    }

    WaitClose() {
        local hwnd := this.Hwnd
        WinWaitClose("ahk_id " . hwnd)
    }

    OnClose(*) {
        local decision
        if this.disposed {
            return true
        }
        if this.installing {
            this.footer_status.Value := "首次安装尚未完成，请先点击“完成安装并部署”。"
            return true
        }
        if this.HasUnsavedSettings() {
            decision := this.PromptUnsavedSettings()
            if decision = "Cancel" {
                return true
            }
            if decision = "Yes" && !this.ApplyAllPendingSettings() {
                return true
            }
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
                        this.DisposeSwitcherSettings()
                    } finally {
                        try {
                            if this.behavior_model {
                                this.behavior_model.Dispose()
                                this.behavior_model := 0
                            }
                        } finally {
                            try {
                                if this.application_model {
                                    this.application_model.Dispose()
                                    this.application_model := 0
                                }
                            } finally {
                                try {
                                    if this.dictionary_model {
                                        this.dictionary_model.Dispose()
                                        this.dictionary_model := 0
                                    }
                                } finally {
                                    try this.Destroy()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
