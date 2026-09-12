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

#Include RabbitAppearanceSettingsPage.ahk
#Include RabbitAbout.ahk
#Include RabbitCommon.ahk
#Include RabbitDeploymentPlan.ahk
#Include RabbitI18n.ahk
#Include RabbitApplicationSettingsModel.ahk
#Include RabbitKeyBindingDialog.ahk
#Include RabbitRimeDepotSettings.ahk
#Include RabbitRimeDepotWindow.ahk
#Include RabbitWindowTheme.ahk

class RabbitSettingsWindow extends Gui {
    language_reload_callback := 0
    language_reload_state := 0
    deployment_pending := false

    static WINDOW_WIDTH := 820
    static APPEARANCE_HEIGHT := 580
    static BEHAVIOR_HEIGHT := 692
    ; Leave a padded action row below the switcher tab control.  The nested
    ; downloader tab remains inside the existing input-schemes page so the
    ; root navigation and its persisted page indices stay stable.
    static SWITCHER_HEIGHT := 700
    static ABOUT_HEIGHT := 684
    static COMPACT_HEIGHT := 500
    static SWITCH_ACTION_VALUES := [
        "noop",
        "inline_ascii",
        "commit_text",
        "commit_code",
        "clear",
        "set_ascii_mode",
        "unset_ascii_mode",
    ]
    static SWITCH_ACTION_LABELS => [
        RabbitI18n.Text("controls.noop"),
        RabbitI18n.Text("controls.inline_ascii"),
        RabbitI18n.Text("controls.commit_text"),
        RabbitI18n.Text("controls.commit_code"),
        RabbitI18n.Text("controls.clear_input"),
        RabbitI18n.Text("controls.set_ascii"),
        RabbitI18n.Text("controls.unset_ascii"),
    ]
    static CAPS_LOCK_ACTION_VALUES := ["noop", "commit_text", "commit_code", "clear"]
    static CAPS_LOCK_ACTION_LABELS => [RabbitI18n.Text("controls.noop"), RabbitI18n.Text("controls.commit_text"), RabbitI18n.Text("controls.commit_code"), RabbitI18n.Text("controls.clear_input")]
    static pages {
        get {
            return [
                {
                    id: "appearance", title: RabbitI18n.Text("pages.appearance"),
                    description: RabbitI18n.Text("pages.appearance_description")
                },
                {
                    id: "input-schemes", title: RabbitI18n.Text("pages.input_schemes"),
                    description: RabbitI18n.Text("pages.input_schemes_description")
                },
                {
                    id: "behavior", title: RabbitI18n.Text("pages.behavior"),
                    description: RabbitI18n.Text("pages.behavior_description")
                },
                {
                    id: "applications", title: RabbitI18n.Text("pages.applications"),
                    description: RabbitI18n.Text("pages.applications_description")
                },
                {
                    id: "dictionary", title: RabbitI18n.Text("pages.dictionary"),
                    description: RabbitI18n.Text("pages.dictionary_description")
                },
                {
                    id: "maintenance", title: RabbitI18n.Text("pages.maintenance"),
                    description: RabbitI18n.Text("pages.maintenance_description")
                },
                {
                    id: "about", title: RabbitI18n.Text("pages.about"),
                    description: RabbitI18n.Text("pages.about_description")
                },
            ]
        }
    }

    static CalculateAppearanceLayout(dark_mode, height := 0) {
        local color_actions_y, color_list_y
        if !height {
            height := RabbitSettingsWindow.APPEARANCE_HEIGHT
        }
        ; Anchor the bottom controls to the page edge so the color list absorbs height changes.
        color_list_y := dark_mode ? 240 : 216
        color_actions_y := height - 182
        return {
            tabs_height: height - 210,
            color_list_y: color_list_y,
            color_list_height: Max(1, color_actions_y - 12 - color_list_y),
            color_actions_y: color_actions_y,
            color_details_y: height - 140,
            typesetting_layout_height: height - 440,
            status_y: height - 72
        }
    }

    __New(
        workflow := 0,
        old_windows := RabbitIsOldWindows(),
        preview_factory := RabbitAppearancePreview,
        close_prompt := 0,
        initial_page_id := "",
        installing := false,
        theme_factory := RabbitWindowThemeController,
        load_after_show := false,
        rime_depot_factory := 0
    ) {
        local appearance_layout, initial_dark_mode := false, initial_page, index, factory
        local surface_options := ""
        local page_names := []
        initial_page := RabbitSettingsWindow.PageIndex(initial_page_id)
        if !initial_page {
            throw ValueError(RabbitI18n.Text("messages.unknown_page", Map("page", initial_page_id)))
        }
        if installing && RabbitSettingsWindow.pages[initial_page].id != "input-schemes" {
            throw ValueError(RabbitI18n.Text("controls.install_page_required"))
        }
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        appearance_layout := RabbitSettingsWindow.CalculateAppearanceLayout(initial_dark_mode)
        super.__New("-MaximizeBox -MinimizeBox", RabbitI18n.Text("settings.title"), this)
        this.workflow := workflow
        this.old_windows := old_windows
        this.preview_factory := preview_factory
        this.close_prompt := close_prompt
        this.installing := installing
        this.appearance_page := 0
        this.behavior_model := 0
        this.behavior_loading := false
        this.behavior_dirty := false
        this.bindings := []
        this.application_model := 0
        this.application_rules := Map()
        this.application_changes := Map()
        this.application_loading := false
        this.application_dirty := false
        this.appearance_preview_labels := []
        this.appearance_preview_labels_loaded := false
        this.dictionary_model := 0
        this.switcher_model := 0
        this.switcher_items := Map()
        this.switcher_option_items := Map()
        this.switcher_option_selection := Map()
        this.switcher_custom_options := Map()
        this.switcher_removed_options := Map()
        this.switcher_loading := false
        this.switcher_dirty := false
        this.rime_depot_window := 0
        this.rime_depot_settings := 0
        this.rime_depot_loading := false
        this.rime_depot_dirty := false
        this.rime_depot_sync_pending := false
        this.rime_depot_busy := false
        this.parent_operation_busy := false
        this.parent_operation_restore_enabled := true
        this.disposed := false
        this.selected_page := 0
        this.window_shown := false
        this.initial_page_load_pending := !!load_after_show
        this.initial_page_load_callback := this.LoadInitialPage.Bind(this)
        this.initial_dark_mode := initial_dark_mode
        this.rime_depot_factory := rime_depot_factory
            ? rime_depot_factory
            : ObjBindMethod(RabbitRimeDepotWindow, "CreateForWorkflow")

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
        this.AddText("x20 y20 w170 h32 Center", RabbitI18n.Text("settings.product"))
        this.SetFont("s9 w400")
        this.sidebar_subtitle := this.AddText("x20 y52 w170 h22 Center cGray", RabbitI18n.Text("settings.subtitle"))

        for page in RabbitSettingsWindow.pages {
            page_names.Push(page.title)
        }
        this.navigation := this.AddListBox("x20 y88 w170 h330 -Multi +0x100", page_names)
        this.navigation.OnEvent("Change", (*) => this.SelectPage(this.navigation.Value))
        this.apply_button := this.AddButton("x20 y594 w170 h36 +0x2000 Disabled", RabbitI18n.Text("settings.apply"))
        this.apply_button.OnEvent("Click", (*) => this.ApplyAllPendingSettings())

        this.sidebar_divider := this.AddText("x205 y20 w1 h598 +0x10")
        this.SetFont("s18 w600")
        this.page_title := this.AddText("x230 y28 w570 h38", "")
        this.SetFont("s10 w400")
        this.page_description := this.AddText("x230 y72 w570 h36 cGray", "")
        this.header_divider := this.AddText("x230 y112 w570 h1 +0x10")

        this.appearance_tabs := this.AddTab3(
            Format("x230 y136 w570 h{} Hidden", appearance_layout.tabs_height)
                . (initial_dark_mode ? " cF0F0F0 Background202020" : ""),
            [RabbitI18n.Text("controls.colors"), RabbitI18n.Text("controls.fonts"), RabbitI18n.Text("controls.layout"),
                RabbitI18n.Text("controls.preedit_group")]
        )
        this.appearance_tabs.OnEvent("Change", (*) => this.OnAppearanceTabChanged())
        this.appearance_tabs.UseTab(1)
        this.appearance_target_label := this.AddText("x250 y178 w80 h22 Hidden",
            RabbitI18n.Text("controls.appearance_target"))
        this.appearance_target := this.AddDropDownList(
            "x334 y174 w200 Choose1 Hidden",
            [RabbitI18n.Text("controls.light"), RabbitI18n.Text("controls.dark")]
        )
        this.appearance_target.OnEvent("Change", (*) => this.OnAppearanceTargetChange())
        this.appearance_follow_light := this.AddCheckbox("x552 y174 w228 h24 Hidden",
            RabbitI18n.Text("controls.follow_light"))
        this.appearance_follow_light.OnEvent("Click", (*) => this.appearance_page.OnFollowLightChange())
        this.appearance_list := this.AddListView(
            Format(
                "x250 y{} w530 h{}{}",
                appearance_layout.color_list_y,
                appearance_layout.color_list_height,
                initial_dark_mode ? " -Hdr" : ""
            )
                . " -Multi NoSort Hidden",
            [RabbitI18n.Text("controls.current"), RabbitI18n.Text("controls.scheme_name"), RabbitI18n.Text("controls.scheme_id"), RabbitI18n.Text("controls.source")]
        )
        this.appearance_current_header := this.AddText(
            "x250 y216 w54 h24 +0x200 Hidden" . surface_options,
            " " . RabbitI18n.Text("controls.current")
        )
        this.appearance_name_header := this.AddText(
            "x304 y216 w210 h24 +0x200 Hidden" . surface_options,
            " " . RabbitI18n.Text("controls.scheme_name")
        )
        this.appearance_id_header := this.AddText(
            "x514 y216 w156 h24 +0x200 Hidden" . surface_options,
            " " . RabbitI18n.Text("controls.scheme_id")
        )
        this.appearance_source_header := this.AddText(
            "x670 y216 w90 h24 +0x200 Hidden" . surface_options,
            " " . RabbitI18n.Text("controls.source")
        )
        this.appearance_list.OnEvent("ItemSelect", (ctrl, row, selected) =>
            selected ? this.OnAppearanceSelectionChange() : 0)
        this.appearance_list.OnEvent("DoubleClick", (ctrl, row) => this.appearance_page.EditColorScheme(row))
        this.appearance_add := this.AddButton(
            Format("x250 y{} w86 h32 Hidden", appearance_layout.color_actions_y),
            RabbitI18n.Text("controls.new")
        )
        this.appearance_add.OnEvent("Click", (*) => this.appearance_page.AddColorScheme())
        this.appearance_copy := this.AddButton(
            Format("x344 y{} w86 h32 Hidden", appearance_layout.color_actions_y),
            RabbitI18n.Text("controls.copy")
        )
        this.appearance_copy.OnEvent("Click", (*) => this.appearance_page.CopyColorScheme())
        this.appearance_edit := this.AddButton(
            Format("x438 y{} w86 h32 Hidden", appearance_layout.color_actions_y),
            RabbitI18n.Text("controls.view_edit")
        )
        this.appearance_edit.OnEvent("Click", (*) => this.appearance_page.EditColorScheme())
        this.appearance_delete := this.AddButton(
            Format("x532 y{} w86 h32 Hidden", appearance_layout.color_actions_y),
            RabbitI18n.Text("controls.delete")
        )
        this.appearance_delete.OnEvent("Click", (*) => this.appearance_page.DeleteColorScheme())
        this.appearance_use := this.AddButton(
            Format("x626 y{} w86 h32 Hidden", appearance_layout.color_actions_y),
            RabbitI18n.Text("controls.set_current")
        )
        this.appearance_use.OnEvent("Click", (*) => this.appearance_page.UseSelectedColorScheme())
        this.appearance_details := this.AddText(
            Format("x250 y{} w530 h48 Hidden", appearance_layout.color_details_y),
            ""
        )

        this.appearance_typesetting_controls := []
        this.appearance_font_controls := []
        this.appearance_preedit_controls := []
        this.appearance_typesetting_created := false
        this.appearance_tabs.UseTab()

        this.appearance_color_controls := [
            this.appearance_target_label,
            this.appearance_target,
            this.appearance_follow_light,
            this.appearance_list,
            this.appearance_add,
            this.appearance_copy,
            this.appearance_edit,
            this.appearance_delete,
            this.appearance_use,
            this.appearance_details,
        ]
        if initial_dark_mode {
            this.appearance_color_controls.InsertAt(
                1,
                this.appearance_current_header,
                this.appearance_name_header,
                this.appearance_id_header,
                this.appearance_source_header
            )
        }
        this.appearance_status := this.AddText(
            Format("x230 y{} w570 h20 Hidden", appearance_layout.status_y),
            ""
        )
        this.appearance_page := RabbitAppearanceSettingsPage(
            this,
            workflow,
            old_windows,
            preview_factory
        )

        this.placeholder := this.AddGroupBox("x230 y136 w570 h290", RabbitI18n.Text("controls.page_content"))
        this.placeholder_text := this.AddText(
            "x254 y174 w520 h80",
            RabbitI18n.Text("controls.placeholder")
        )
        this.page_controls_created := Map(1, true)

        this.footer_status := this.AddText(
            "x230 y612 w570 h22 cGray",
            RabbitI18n.Text("controls.save_hint")
        )
        this.OnEvent("Close", this.OnClose.Bind(this))
        this.OnEvent("Escape", this.OnClose.Bind(this))

        this.SelectPage(initial_page)
        this.navigation.Enabled := !installing
        if installing {
            this.footer_status.Value := RabbitI18n.Text("controls.first_install_hint")
        }
        this.UpdateApplyButton()
        factory := theme_factory
        this.window_theme := factory(this)
        this.RegisterSharedControlThemes()
        for index in this.page_controls_created {
            this.RegisterPageControlThemes(index)
        }
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

    EnsurePageControls(index) {
        if this.page_controls_created.Has(index) {
            return false
        }
        switch index {
            case 2:
                this.CreateSwitcherControls()
            case 3:
                this.CreateBehaviorControls()
            case 4:
                this.CreateApplicationControls()
            case 5:
                this.CreateDictionaryControls()
            case 6:
                this.CreateMaintenanceControls()
            case 7:
                this.CreateAboutControls()
            default:
                return false
        }
        this.page_controls_created[index] := true
        if HasProp(this, "window_theme") && this.window_theme {
            this.RegisterPageControlThemes(index)
            if HasMethod(this.window_theme, "Apply") {
                this.window_theme.Apply()
            }
        }
        return true
    }

    RegisterSharedControlThemes() {
        this.window_theme.RegisterMuted(
            this.sidebar_subtitle,
            this.page_description,
            this.footer_status
        )
    }

    RegisterPageControlThemes(index) {
        switch index {
            case 1:
                this.window_theme.RegisterSurface(
                    this.appearance_current_header,
                    this.appearance_name_header,
                    this.appearance_id_header,
                    this.appearance_source_header
                )
            case 2:
                this.window_theme.RegisterMuted(
                    this.switcher_schema_help,
                    this.switcher_order_help,
                    this.switcher_preview,
                    this.switcher_save_help,
                    this.switcher_option_note,
                    this.rime_depot_git_path_hint,
                    this.rime_depot_status
                )
                this.window_theme.RegisterSurface(this.switcher_list_header)
                this.window_theme.RegisterSurface(
                    this.switcher_option_name_header,
                    this.switcher_option_source_header
                )
            case 3:
                this.window_theme.RegisterMuted(this.menu_help, this.binding_help, this.language_help)
                this.window_theme.RegisterSurface(
                    this.binding_accept_header,
                    this.binding_when_header,
                    this.binding_action_header
                )
            case 4:
                this.window_theme.RegisterSurface(
                    this.application_process_header,
                    this.application_mode_header
                )
            case 7:
                this.about_page.RegisterTheme(this.window_theme)
        }
    }

    CreateSwitcherControls() {
        local surface_options := this.initial_dark_mode ? " cF0F0F0 Background2B2B2B" : ""
        this.switcher_tabs := this.AddTab3(
            "x230 y136 w570 h450 Hidden"
                . (this.initial_dark_mode ? " cF0F0F0 Background202020" : ""),
            [RabbitI18n.Text("controls.schemes"), RabbitI18n.Text("controls.scheme_menu"),
                RabbitI18n.Text("controls.more_schemes")]
        )
        this.switcher_tabs.OnEvent("Change", (*) => this.OnSwitcherTabChanged())
        this.switcher_group := this.switcher_tabs

        this.switcher_tabs.UseTab(1)
        this.switcher_list_header := this.AddText(
            "x254 y174 w250 h24 Center +0x200 Hidden" . surface_options,
            RabbitI18n.Text("controls.scheme_name")
        )
        this.switcher_list := this.AddListView(
            (this.initial_dark_mode ? "x254 y198 w250 h250 -Hdr" : "x254 y174 w250 h274")
                . " Checked NoSort -Multi Hidden",
            [RabbitI18n.Text("controls.scheme_name")]
        )
        this.switcher_list.OnEvent(
            "ItemSelect",
            (ctrl, row, selected) => selected ? this.OnSwitcherSchemaSelected(row) : 0
        )
        this.switcher_list.OnEvent(
            "ItemCheck",
            (ctrl, row, checked) => this.OnSwitcherSchemaCheck(row, checked)
        )
        this.switcher_details := this.AddText(
            "x526 y174 w248 h274 Hidden",
            RabbitI18n.Text("controls.scheme_hint")
        )
        this.switcher_move_up := this.AddButton("x254 y456 w84 h30 Disabled Hidden +0x2000",
            RabbitI18n.Text("controls.move_up"))
        this.switcher_move_up.OnEvent("Click", (*) => this.MoveSwitcherSchema(-1))
        this.switcher_move_down := this.AddButton("x348 y456 w84 h30 Disabled Hidden +0x2000",
            RabbitI18n.Text("controls.move_down"))
        this.switcher_move_down.OnEvent("Click", (*) => this.MoveSwitcherSchema(1))
        this.switcher_order_help := this.AddText(
            "x448 y460 w326 h24 cGray Hidden",
            RabbitI18n.Text("controls.reorder_hint")
        )
        this.switcher_fix_order := this.AddCheckbox(
            "x254 y496 w510 h24 Hidden",
            RabbitI18n.Text("controls.always_first")
        )
        this.switcher_fix_order.OnEvent("Click", (*) => this.MarkSwitcherDirty())
        this.switcher_schema_help := this.AddText(
            "x254 y526 w520 h32 cGray Hidden",
            RabbitI18n.Text("controls.restore_scheme_hint")
        )
        this.switcher_schema_controls := [
            this.switcher_list_header,
            this.switcher_list,
            this.switcher_details,
            this.switcher_move_up,
            this.switcher_move_down,
            this.switcher_order_help,
            this.switcher_fix_order,
            this.switcher_schema_help,
        ]

        this.switcher_tabs.UseTab(2)
        this.switcher_caption_label := this.AddText("x254 y174 w88 h24 Hidden", RabbitI18n.Text("controls.menu_title"))
        this.switcher_caption := this.AddEdit("x344 y170 w430 r1 -Multi Hidden")
        this.switcher_caption.OnEvent("Change", (*) => this.MarkSwitcherDirty())
        this.switcher_hotkeys_label := this.AddText("x254 y206 w88 h24 Hidden", RabbitI18n.Text("controls.hotkeys"))
        this.switcher_hotkeys := this.AddEdit("x344 y202 w430 r1 -Multi Hidden")
        this.SetEditCue(this.switcher_hotkeys, RabbitI18n.Text("controls.hotkeys_hint"))
        this.switcher_hotkeys.OnEvent("Change", (*) => this.MarkSwitcherDirty())
        this.switcher_fold_options := this.AddCheckbox("x254 y234 w208 h24 Hidden",
            RabbitI18n.Text("controls.fold_options"))
        this.switcher_fold_options.OnEvent("Click", (*) => this.OnSwitcherFoldChanged())
        this.switcher_abbreviate_options := this.AddCheckbox("x478 y234 w208 h24 Hidden",
            RabbitI18n.Text("controls.abbreviate"))
        this.switcher_abbreviate_options.OnEvent("Click", (*) => this.OnSwitcherDisplayChanged())
        this.switcher_prefix_label := this.AddText("x254 y270 w48 h24 Hidden", RabbitI18n.Text("controls.prefix"))
        this.switcher_prefix := this.AddEdit("x304 y266 w100 r1 -Multi Hidden")
        this.switcher_prefix.OnEvent("Change", (*) => this.OnSwitcherDisplayChanged())
        this.switcher_separator_label := this.AddText("x416 y270 w64 h24 Hidden", RabbitI18n.Text("controls.separator"))
        this.switcher_separator := this.AddEdit("x482 y266 w100 r1 -Multi Hidden")
        this.switcher_separator.OnEvent("Change", (*) => this.OnSwitcherDisplayChanged())
        this.switcher_suffix_label := this.AddText("x594 y270 w48 h24 Hidden", RabbitI18n.Text("controls.suffix"))
        this.switcher_suffix := this.AddEdit("x644 y266 w130 r1 -Multi Hidden")
        this.switcher_suffix.OnEvent("Change", (*) => this.OnSwitcherDisplayChanged())
        this.switcher_preview := this.AddText("x254 y298 w520 h24 cGray Hidden", "")

        this.switcher_save_group := this.AddGroupBox("x246 y326 w538 h228 Hidden", RabbitI18n.Text("controls.remember"))
        this.switcher_save_help := this.AddText(
            "x260 y348 w510 h38 cGray Hidden",
            RabbitI18n.Text("controls.remember_hint")
        )
        this.switcher_save_list := this.AddListView(
            (this.initial_dark_mode ? "x260 y408 w510 h92 -Hdr" : "x260 y384 w510 h116")
                . " Checked NoSort -Multi Hidden",
            [RabbitI18n.Text("controls.option_id"), RabbitI18n.Text("controls.source")]
        )
        this.switcher_option_name_header := this.AddText(
            "x260 y384 w232 h24 +0x200 Hidden" . surface_options,
            "  " . RabbitI18n.Text("controls.option_id")
        )
        this.switcher_option_source_header := this.AddText(
            "x492 y384 w278 h24 +0x200 Hidden" . surface_options,
            "  " . RabbitI18n.Text("controls.source")
        )
        this.switcher_save_list.OnEvent(
            "ItemCheck",
            (ctrl, row, checked) => this.OnSwitcherOptionCheck(row, checked)
        )
        this.switcher_option_add := this.AddButton("x260 y510 w92 h30 Hidden +0x2000",
            RabbitI18n.Text("controls.add_custom"))
        this.switcher_option_add.OnEvent("Click", (*) => this.AddSwitcherOption())
        this.switcher_option_delete := this.AddButton("x362 y510 w92 h30 Hidden +0x2000",
            RabbitI18n.Text("controls.delete"))
        this.switcher_option_delete.OnEvent("Click", (*) => this.DeleteSwitcherOption())
        this.switcher_option_note := this.AddText(
            "x468 y512 w302 h34 cGray Hidden",
            RabbitI18n.Text("controls.remember_menu_only")
        )
        this.switcher_menu_controls := [
            this.switcher_caption_label,
            this.switcher_caption,
            this.switcher_hotkeys_label,
            this.switcher_hotkeys,
            this.switcher_fold_options,
            this.switcher_abbreviate_options,
            this.switcher_prefix_label,
            this.switcher_prefix,
            this.switcher_separator_label,
            this.switcher_separator,
            this.switcher_suffix_label,
            this.switcher_suffix,
            this.switcher_preview,
            this.switcher_save_group,
            this.switcher_save_help,
            this.switcher_save_list,
            this.switcher_option_add,
            this.switcher_option_delete,
            this.switcher_option_note,
        ]
        if this.initial_dark_mode {
            this.switcher_menu_controls.InsertAt(
                1,
                this.switcher_option_name_header,
                this.switcher_option_source_header
            )
        }

        this.switcher_tabs.UseTab(3)
        this.rime_depot_settings_group := this.AddGroupBox(
            "x246 y174 w538 h294 Hidden",
            RabbitI18n.Text("depot.settings")
        )
        this.rime_depot_url_label := this.AddText(
            "x260 y202 w92 h24 Hidden",
            RabbitI18n.Text("depot.rppi_url")
        )
        this.rime_depot_url_edit := this.AddEdit("x358 y198 w412 r1 -Multi Hidden")
        this.rime_depot_proxy_label := this.AddText(
            "x260 y238 w92 h24 Hidden",
            RabbitI18n.Text("depot.proxy")
        )
        this.rime_depot_proxy_edit := this.AddEdit("x358 y234 w412 r1 -Multi Hidden")
        this.rime_depot_use_git := this.AddCheckbox(
            "x260 y270 w250 h24 Hidden",
            RabbitI18n.Text("depot.use_git")
        )
        this.rime_depot_git_path_label := this.AddText(
            "x260 y306 w58 h24 Hidden",
            RabbitI18n.Text("depot.git_path")
        )
        this.rime_depot_git_path_edit := this.AddEdit("x324 y302 w354 r1 -Multi Hidden")
        this.rime_depot_git_path_browse := this.AddButton(
            "x688 y302 w82 h26 +0x2000 Hidden",
            RabbitI18n.Text("depot.browse")
        )
        this.rime_depot_git_path_hint := this.AddText(
            "x260 y336 w510 h22 cGray Hidden",
            RabbitI18n.Text("depot.git_path_hint")
        )
        this.rime_depot_open_button := this.AddButton(
            "x260 y374 w200 h30 +0x2000 Hidden",
            RabbitI18n.Text("depot.open_downloader")
        )
        this.rime_depot_status := this.AddText("x260 y416 w510 h22 cGray Hidden", "")
        this.rime_depot_controls := [
            this.rime_depot_settings_group,
            this.rime_depot_url_label,
            this.rime_depot_url_edit,
            this.rime_depot_proxy_label,
            this.rime_depot_proxy_edit,
            this.rime_depot_use_git,
            this.rime_depot_git_path_label,
            this.rime_depot_git_path_edit,
            this.rime_depot_git_path_browse,
            this.rime_depot_git_path_hint,
            this.rime_depot_open_button,
            this.rime_depot_status,
        ]
        this.rime_depot_url_edit.OnEvent("Change", (*) => this.OnRimeDepotSettingsChanged())
        this.rime_depot_proxy_edit.OnEvent("Change", (*) => this.OnRimeDepotSettingsChanged())
        this.rime_depot_use_git.OnEvent("Click", (*) => this.OnRimeDepotSettingsChanged())
        this.rime_depot_git_path_edit.OnEvent("Change", (*) => this.OnRimeDepotSettingsChanged())
        this.rime_depot_git_path_browse.OnEvent("Click", (*) => this.BrowseRimeDepotGitPath())
        this.rime_depot_open_button.OnEvent("Click", (*) => this.OpenRimeDepot())
        this.switcher_tabs.UseTab()
        this.switcher_status := this.AddText("x230 y628 w570 h18 Hidden", "")
    }

    CreateBehaviorControls() {
        local controls, key
        local surface_options := this.initial_dark_mode ? " cF0F0F0 Background2B2B2B" : ""
        this.behavior_tabs := this.AddTab3(
            "x230 y136 w570 h482 Hidden"
                . (this.initial_dark_mode ? " cF0F0F0 Background202020" : ""),
            [RabbitI18n.Text("controls.general"), RabbitI18n.Text("controls.key_bindings"),
                RabbitI18n.Text("language.tab")]
        )
        this.behavior_tabs.OnEvent("Change", (*) => this.OnBehaviorTabChanged())
        this.behavior_group := this.behavior_tabs

        this.behavior_tabs.UseTab(1)
        this.behavior_rabbit_group := this.AddGroupBox("x246 y170 w538 h190 Hidden",
            RabbitI18n.Text("controls.rabbit_behavior"))
        this.show_tips := this.AddCheckbox("x260 y196 w190 h24 Hidden", RabbitI18n.Text("controls.show_tips"))
        this.show_tips.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.show_tips_time_label := this.AddText("x478 y198 w130 h22 Hidden", RabbitI18n.Text("controls.tip_duration"))
        this.show_tips_time := this.AddEdit("x612 y194 w80 r1 Number -Multi Hidden")
        this.show_tips_time.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.suspend_hotkey_label := this.AddText("x260 y228 w132 h22 Hidden",
            RabbitI18n.Text("controls.suspend_hotkey"))
        this.suspend_hotkey := this.AddEdit("x394 y224 w372 r1 -Multi Hidden")
        this.SetEditCue(this.suspend_hotkey, RabbitI18n.Text("controls.suspend_example"))
        this.suspend_hotkey.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.clipboard_mode_label := this.AddText("x260 y260 w96 h22 Hidden", RabbitI18n.Text("controls.clipboard"))
        this.clipboard_mode := this.AddDropDownList(
            "x358 y256 w164 Choose3 Hidden",
            [RabbitI18n.Text("controls.clipboard_never"), RabbitI18n.Text("controls.clipboard_always"), RabbitI18n.Text("controls.clipboard_threshold")]
        )
        this.clipboard_mode.OnEvent("Change", (*) => this.OnClipboardModeChanged())
        this.clipboard_length_label := this.AddText("x536 y260 w110 h22 Hidden",
            RabbitI18n.Text("controls.clipboard_length"))
        this.clipboard_length := this.AddEdit("x648 y256 w118 r1 Number -Multi Hidden")
        this.clipboard_length.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.global_ascii := this.AddCheckbox("x260 y286 w490 h24 Hidden", RabbitI18n.Text("controls.global_ascii"))
        this.global_ascii.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.fix_candidate_box := this.AddCheckbox("x260 y312 w238 h24 Hidden",
            RabbitI18n.Text("controls.fixed_candidate"))
        this.fix_candidate_box.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.use_legacy_candidate_box := this.AddCheckbox("x510 y312 w238 h24 Hidden",
            RabbitI18n.Text("controls.legacy_candidates"))
        this.use_legacy_candidate_box.OnEvent("Click", (*) => this.OnBehaviorChanged())
        this.bypass_password_fields := this.AddCheckbox("x260 y336 w490 h24 Hidden",
            RabbitI18n.Text("controls.password_bypass"))
        this.bypass_password_fields.OnEvent("Click", (*) => this.OnBehaviorChanged())

        this.ascii_switch_group := this.AddGroupBox("x246 y366 w538 h142 Hidden",
            RabbitI18n.Text("controls.ascii_keys"))
        this.ascii_switch_controls := Map()
        this.AddAsciiSwitchControl("Shift_L", RabbitI18n.Text("controls.left_shift"), 260, 392)
        this.AddAsciiSwitchControl("Shift_R", RabbitI18n.Text("controls.right_shift"), 432, 392)
        this.AddAsciiSwitchControl("Caps_Lock", "Caps Lock：", 604, 392)
        this.AddAsciiSwitchControl("Control_L", RabbitI18n.Text("controls.left_ctrl"), 260, 432)
        this.AddAsciiSwitchControl("Control_R", RabbitI18n.Text("controls.right_ctrl"), 432, 432)
        this.AddAsciiSwitchControl("Eisu_toggle", RabbitI18n.Text("controls.eisu"), 604, 432)
        this.good_old_caps_lock := this.AddCheckbox(
            "x260 y464 w310 h24 Hidden",
            RabbitI18n.Text("controls.caps_lock")
        )
        this.good_old_caps_lock.OnEvent("Click", (*) => this.OnBehaviorChanged())

        this.menu_group := this.AddGroupBox("x246 y514 w538 h86 Hidden", RabbitI18n.Text("controls.candidate_paging"))
        this.menu_page_size_label := this.AddText("x260 y540 w88 h22 Hidden", RabbitI18n.Text("controls.page_size"))
        this.menu_page_size := this.AddEdit("x350 y536 w68 r1 Number -Multi Hidden")
        this.SetEditCue(this.menu_page_size, "5")
        this.menu_page_size.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.menu_labels_label := this.AddText("x438 y540 w90 h22 Hidden", RabbitI18n.Text("controls.labels"))
        this.menu_labels := this.AddEdit("x530 y536 w236 r1 -Multi Hidden")
        this.SetEditCue(this.menu_labels, "1, 2, 3, 4, 5, 6, 7, 8, 9, 10")
        this.menu_labels.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.menu_help := this.AddText(
            "x260 y570 w506 h22 cGray Hidden",
            RabbitI18n.Text("controls.labels_hint")
        )

        this.behavior_tabs.UseTab(2)
        this.binding_list := this.AddListView(
            (this.initial_dark_mode ? "x250 y198 w530 h302 -Hdr" : "x250 y174 w530 h326")
                . " -Multi NoSort Hidden",
            [RabbitI18n.Text("controls.accept"), RabbitI18n.Text("controls.when"), RabbitI18n.Text("controls.action")]
        )
        this.binding_accept_header := this.AddText(
            "x250 y174 w150 h24 +0x200 Hidden" . surface_options,
            "  " . RabbitI18n.Text("controls.accept")
        )
        this.binding_when_header := this.AddText(
            "x400 y174 w100 h24 +0x200 Hidden" . surface_options,
            "  " . RabbitI18n.Text("controls.when")
        )
        this.binding_action_header := this.AddText(
            "x500 y174 w280 h24 +0x200 Hidden" . surface_options,
            "  " . RabbitI18n.Text("controls.action")
        )
        this.binding_list.OnEvent("DoubleClick", (ctrl, row) => this.EditBinding(row))
        this.binding_add := this.AddButton("x250 y510 w86 h32 Hidden +0x2000", RabbitI18n.Text("controls.add"))
        this.binding_add.OnEvent("Click", (*) => this.AddBinding())
        this.binding_edit := this.AddButton("x344 y510 w86 h32 Hidden +0x2000", RabbitI18n.Text("controls.edit"))
        this.binding_edit.OnEvent("Click", (*) => this.EditBinding())
        this.binding_delete := this.AddButton("x438 y510 w86 h32 Hidden +0x2000", RabbitI18n.Text("controls.delete"))
        this.binding_delete.OnEvent("Click", (*) => this.DeleteBinding())
        this.binding_up := this.AddButton("x532 y510 w86 h32 Hidden +0x2000", RabbitI18n.Text("controls.move_up"))
        this.binding_up.OnEvent("Click", (*) => this.MoveBinding(-1))
        this.binding_down := this.AddButton("x626 y510 w86 h32 Hidden +0x2000", RabbitI18n.Text("controls.move_down"))
        this.binding_down.OnEvent("Click", (*) => this.MoveBinding(1))
        this.binding_help := this.AddText(
            "x250 y552 w530 h48 cGray Hidden",
            RabbitI18n.Text("messages.binding_list_hint")
        )
        this.behavior_tabs.UseTab(3)
        this.language_label := this.AddText("x260 y190 w506 Hidden", RabbitI18n.Text("language.label"))
        this.language_choice := this.AddDropDownList("x260 y222 w300 Hidden")
        this.PopulateLanguageChoices()
        this.language_choice.OnEvent("Change", (*) => this.OnBehaviorChanged())
        this.language_help := this.AddText("x260 y268 w506 Hidden cGray", RabbitI18n.Text("language.hint"))
        this.behavior_interface_controls := [this.language_label, this.language_choice, this.language_help]
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
            this.good_old_caps_lock,
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
        if this.initial_dark_mode {
            this.behavior_binding_controls.InsertAt(
                1,
                this.binding_accept_header,
                this.binding_when_header,
                this.binding_action_header
            )
        }
        this.behavior_status := this.AddText("x230 y620 w570 h24 Hidden", "")
    }

    CreateApplicationControls() {
        local surface_options := this.initial_dark_mode ? " cF0F0F0 Background2B2B2B" : ""
        this.application_group := this.AddGroupBox("x230 y136 w570 h290 Hidden", RabbitI18n.Text("pages.applications"))
        this.application_process_header := this.AddText(
            "x254 y174 w210 h24 +0x200 Hidden" . surface_options,
            "  " . RabbitI18n.Text("controls.process")
        )
        this.application_mode_header := this.AddText(
            "x464 y174 w110 h24 +0x200 Hidden" . surface_options,
            "  " . RabbitI18n.Text("controls.default_mode")
        )
        this.application_list := this.AddListView(
            (this.initial_dark_mode ? "x254 y198 w320 h150 -Hdr" : "x254 y174 w320 h174")
                . " -Multi NoSort Hidden",
            [RabbitI18n.Text("controls.process"), RabbitI18n.Text("controls.default_mode")]
        )
        this.application_list.OnEvent(
            "ItemSelect",
            (ctrl, row, selected) => this.OnApplicationSelection(row, selected)
        )
        this.application_process_label := this.AddText("x596 y176 w178 h22 Hidden",
            RabbitI18n.Text("controls.process_filename"))
        this.application_process := this.AddEdit("x596 y200 w178 r1 -Multi Hidden")
        this.application_mode_label := this.AddText("x596 y238 w178 h22 Hidden", RabbitI18n.Text("controls.input_mode"))
        this.application_mode := this.AddDropDownList("x596 y262 w178 Choose2 Hidden", [RabbitI18n.Text("controls.chinese"), RabbitI18n.Text("controls.english")])
        this.application_update_button := this.AddButton("x596 y304 w178 h32 Hidden +0x2000",
            RabbitI18n.Text("controls.update_rule"))
        this.application_update_button.OnEvent("Click", (*) => this.StageApplicationRule())
        this.application_reset_button := this.AddButton("x596 y346 w178 h32 Hidden +0x2000",
            RabbitI18n.Text("controls.reset_rule"))
        this.application_reset_button.OnEvent("Click", (*) => this.ResetSelectedApplicationRule())
        this.application_status := this.AddText("x254 y390 w320 h24 Hidden", "")
    }

    CreateAboutControls() {
        this.about_page := RabbitAboutPage(this, 230, 136, 570, this.ShowMessage.Bind(this))
    }

    CreateDictionaryControls() {
        this.dictionary_group := this.AddGroupBox("x230 y136 w570 h290 Hidden", RabbitI18n.Text("pages.dictionary"))
        this.dictionary_list_label := this.AddText("x254 y170 w218 h22 Hidden",
            RabbitI18n.Text("controls.dictionary_list"))
        this.dictionary_list := this.AddListBox("x254 y194 w218 h204 -Multi Hidden")
        this.dictionary_list.OnEvent("Change", (*) => this.OnDictionarySelectionChange())
        this.dictionary_snapshot_text := this.AddText(
            "x496 y170 w278 h44 Hidden",
            RabbitI18n.Text("controls.snapshot_hint")
        )
        this.dictionary_backup := this.AddButton("x496 y220 w134 h32 Disabled Hidden +0x2000",
            RabbitI18n.Text("controls.backup"))
        this.dictionary_backup.OnEvent("Click", (*) => this.BackupSelectedDictionary())
        this.dictionary_restore := this.AddButton("x640 y220 w134 h32 Disabled Hidden +0x2000",
            RabbitI18n.Text("controls.restore"))
        this.dictionary_restore.OnEvent("Click", (*) => this.RestoreDictionarySnapshot())
        this.dictionary_table_text := this.AddText(
            "x496 y270 w278 h44 Hidden",
            RabbitI18n.Text("controls.text_table_hint")
        )
        this.dictionary_export := this.AddButton("x496 y320 w134 h32 Disabled Hidden +0x2000",
            RabbitI18n.Text("controls.export"))
        this.dictionary_export.OnEvent("Click", (*) => this.ExportSelectedDictionary())
        this.dictionary_import := this.AddButton("x640 y320 w134 h32 Disabled Hidden +0x2000",
            RabbitI18n.Text("controls.import"))
        this.dictionary_import.OnEvent("Click", (*) => this.ImportSelectedDictionary())
        this.dictionary_status := this.AddText("x496 y370 w278 h32 Hidden", "")
    }

    CreateMaintenanceControls() {
        this.maintenance_group := this.AddGroupBox("x230 y136 w570 h220 Hidden", RabbitI18n.Text("pages.maintenance"))
        this.maintenance_text := this.AddText(
            "x254 y174 w520 h52 Hidden",
            RabbitI18n.Text("controls.maintenance_hint")
        )
        this.deploy_button := this.AddButton("x254 y246 w130 h32 Hidden +0x2000", RabbitI18n.Text("tray.deploy"))
        this.deploy_button.OnEvent("Click", (*) => this.RunDeploy())
        this.sync_button := this.AddButton("x398 y246 w130 h32 Hidden +0x2000", RabbitI18n.Text("controls.sync"))
        this.sync_button.OnEvent("Click", (*) => this.RunSync())
        this.operation_status := this.AddText("x254 y302 w520 h28 Hidden", "")
    }

    EnsureAppearanceTypesettingControls() {
        local appearance_layout, controls_elapsed, controls_started_at := A_TickCount
        local loading, populate_elapsed, populate_started_at, theme_elapsed, theme_started_at
        if this.appearance_typesetting_created {
            return false
        }
        appearance_layout := RabbitSettingsWindow.CalculateAppearanceLayout(this.initial_dark_mode)
        this.appearance_tabs.UseTab(2)
        this.appearance_font_label := this.AddText("x260 y196 w72 h22 Hidden",
            RabbitI18n.Text("controls.candidate_font"))
        this.appearance_font := this.AddComboBox("x334 y192 w320 r10 Hidden", [])
        this.appearance_font.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_font.OnCommand(
            RabbitAppearanceSettingsPage.CBN_DROPDOWN,
            (*) => this.appearance_page.LoadFontChoices(this.appearance_font)
        )
        this.appearance_font_point_label := this.AddText("x664 y196 w42 h22 Hidden",
            RabbitI18n.Text("controls.font_size"))
        this.appearance_font_point := this.AddEdit("x708 y192 w58 r1 Number -Multi Hidden")
        this.appearance_font_point.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_preedit_font_label := this.AddText("x260 y226 w72 h22 Hidden",
            RabbitI18n.Text("controls.preedit_font"))
        this.appearance_preedit_font := this.AddComboBox("x334 y222 w432 r10 Hidden", [])
        this.appearance_preedit_font.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_preedit_font.OnCommand(
            RabbitAppearanceSettingsPage.CBN_DROPDOWN,
            (*) => this.appearance_page.LoadFontChoices(this.appearance_preedit_font)
        )
        this.appearance_label_font_label := this.AddText("x260 y256 w72 h22 Hidden", RabbitI18n.Text("controls.labels"))
        this.appearance_label_font := this.AddComboBox("x334 y252 w320 r10 Hidden", [])
        this.appearance_label_font.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_label_font.OnCommand(
            RabbitAppearanceSettingsPage.CBN_DROPDOWN,
            (*) => this.appearance_page.LoadFontChoices(this.appearance_label_font)
        )
        this.appearance_label_font_point_label := this.AddText("x664 y268 w42 h22 Hidden",
            RabbitI18n.Text("controls.font_size"))
        this.appearance_label_font_point := this.AddEdit("x708 y252 w58 r1 Number -Multi Hidden")
        this.appearance_label_font_point.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_comment_font_label := this.AddText("x260 y286 w72 h22 Hidden",
            RabbitI18n.Text("controls.comment_font"))
        this.appearance_comment_font := this.AddComboBox("x334 y282 w320 r10 Hidden", [])
        this.appearance_comment_font.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_comment_font.OnCommand(
            RabbitAppearanceSettingsPage.CBN_DROPDOWN,
            (*) => this.appearance_page.LoadFontChoices(this.appearance_comment_font)
        )
        this.appearance_comment_font_point_label := this.AddText("x664 y304 w42 h22 Hidden",
            RabbitI18n.Text("controls.font_size"))
        this.appearance_comment_font_point := this.AddEdit("x708 y282 w58 r1 Number -Multi Hidden")
        this.appearance_comment_font_point.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_label_format_label := this.AddText("x260 y316 w72 h22 Hidden",
            RabbitI18n.Text("controls.label_format"))
        this.appearance_label_format := this.AddEdit("x334 y312 w288 r1 -Multi Hidden")
        this.appearance_label_format.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_advanced_font := this.AddButton(
            "x634 y310 w132 h30 Hidden",
            RabbitI18n.Text("controls.advanced_fonts")
        )
        this.appearance_advanced_font.OnEvent("Click", (*) => this.OpenAdvancedFontSettings())

        this.appearance_tabs.UseTab(3)
        this.appearance_layout_type_label := this.AddText("x260 y382 w72 h22 Hidden",
            RabbitI18n.Text("controls.candidate_layout"))
        this.appearance_layout_type := this.AddDropDownList(
            "x334 y378 w160 Choose1 Hidden",
            [RabbitI18n.Text("controls.stacked"), RabbitI18n.Text("controls.flow"), RabbitI18n.Text("controls.vertical")]
        )
        this.appearance_layout_type.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_align_type_label := this.AddText("x510 y382 w72 h22 Hidden",
            RabbitI18n.Text("controls.alignment"))
        this.appearance_align_type := this.AddDropDownList(
            "x584 y378 w182 Choose1 Hidden",
            [RabbitI18n.Text("controls.top"), RabbitI18n.Text("controls.center"), RabbitI18n.Text("controls.bottom")]
        )
        this.appearance_align_type.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_margin_x_label := this.AddText("x260 y410 w112 h22 Hidden",
            RabbitI18n.Text("controls.margin_x"))
        this.appearance_margin_x := this.AddEdit("x374 y406 w80 r1 Number -Multi Hidden")
        this.appearance_margin_x.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_margin_y_label := this.AddText("x478 y410 w112 h22 Hidden",
            RabbitI18n.Text("controls.margin_y"))
        this.appearance_margin_y := this.AddEdit("x592 y406 w80 r1 Number -Multi Hidden")
        this.appearance_margin_y.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_tabs.UseTab(4)
        this.appearance_preedit_margin_x_label := this.AddText("x260 y438 w112 h22 Hidden",
            RabbitI18n.Text("controls.preedit_margin_x"))
        this.appearance_preedit_margin_x := this.AddEdit("x374 y434 w80 r1 Number -Multi Hidden")
        this.appearance_preedit_margin_x.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_preedit_margin_y_label := this.AddText("x478 y438 w112 h22 Hidden",
            RabbitI18n.Text("controls.preedit_margin_y"))
        this.appearance_preedit_margin_y := this.AddEdit("x592 y434 w80 r1 Number -Multi Hidden")
        this.appearance_preedit_margin_y.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_tabs.UseTab(3)
        this.appearance_candidate_padding_x_label := this.AddText(
            "x260 y466 w112 h22 Hidden",
            RabbitI18n.Text("controls.padding_x")
        )
        this.appearance_candidate_padding_x := this.AddEdit("x374 y462 w80 r1 Number -Multi Hidden")
        this.appearance_candidate_padding_x.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_candidate_padding_y_label := this.AddText(
            "x478 y466 w112 h22 Hidden",
            RabbitI18n.Text("controls.padding_y")
        )
        this.appearance_candidate_padding_y := this.AddEdit("x592 y462 w80 r1 Number -Multi Hidden")
        this.appearance_candidate_padding_y.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_candidate_spacing_label := this.AddText("x260 y494 w72 h22 Hidden",
            RabbitI18n.Text("controls.spacing"))
        this.appearance_candidate_spacing := this.AddEdit("x334 y490 w120 r1 Number -Multi Hidden")
        this.appearance_candidate_spacing.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_border_width_label := this.AddText("x478 y494 w72 h22 Hidden",
            RabbitI18n.Text("controls.border"))
        this.appearance_border_width := this.AddEdit("x552 y490 w120 r1 Number -Multi Hidden")
        this.appearance_border_width.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_corner_radius_label := this.AddText("x260 y522 w72 h22 Hidden",
            RabbitI18n.Text("controls.corner"))
        this.appearance_corner_radius := this.AddEdit("x334 y518 w120 r1 Number -Multi Hidden")
        this.appearance_corner_radius.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_round_corner_label := this.AddText("x478 y522 w112 h22 Hidden",
            RabbitI18n.Text("controls.round_corner"))
        this.appearance_round_corner := this.AddEdit("x592 y518 w80 r1 Number -Multi Hidden")
        this.appearance_round_corner.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_tabs.UseTab(4)
        this.appearance_preedit_border_width_label := this.AddText("x260 y550 w92 h22 Hidden",
            RabbitI18n.Text("controls.preedit_border_width"))
        this.appearance_preedit_border_width := this.AddEdit("x356 y546 w58 r1 Number -Multi Hidden")
        this.appearance_preedit_border_width.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_preedit_corner_radius_label := this.AddText("x428 y550 w92 h22 Hidden",
            RabbitI18n.Text("controls.preedit_corner_radius"))
        this.appearance_preedit_corner_radius := this.AddEdit("x524 y546 w58 r1 Number -Multi Hidden")
        this.appearance_preedit_corner_radius.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_preedit_round_corner_label := this.AddText("x596 y550 w92 h22 Hidden",
            RabbitI18n.Text("controls.preedit_round_corner"))
        this.appearance_preedit_round_corner := this.AddEdit("x692 y546 w58 r1 Number -Multi Hidden")
        this.appearance_preedit_round_corner.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_tabs.UseTab(3)
        this.appearance_min_width_label := this.AddText("x260 y578 w112 h22 Hidden",
            RabbitI18n.Text("controls.min_width"))
        this.appearance_min_width := this.AddEdit("x374 y574 w80 r1 Number -Multi Hidden")
        this.appearance_min_width.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_min_height_label := this.AddText("x478 y578 w112 h22 Hidden",
            RabbitI18n.Text("controls.min_height"))
        this.appearance_min_height := this.AddEdit("x592 y574 w80 r1 Number -Multi Hidden")
        this.appearance_min_height.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_flow_rows_label := this.AddText("x260 y606 w72 h22 Hidden",
            RabbitI18n.Text("controls.flow_rows"))
        this.appearance_flow_rows := this.AddEdit("x334 y602 w120 r1 Number -Multi Hidden")
        this.appearance_flow_rows.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_vertical_direction := this.AddCheckbox(
            "x478 y604 w288 h24 Hidden",
            RabbitI18n.Text("controls.vertical_ltr")
        )
        this.appearance_vertical_direction.OnEvent("Click", (*) => this.OnAppearanceControlsChanged())
        this.appearance_tabs.UseTab(4)
        this.appearance_preedit_type_label := this.AddText("x260 y634 w112 h22 Hidden",
            RabbitI18n.Text("controls.preedit_type"))
        this.appearance_preedit_type := this.AddDropDownList(
            "x374 y630 w180 Choose1 Hidden",
            [RabbitI18n.Text("controls.preedit_composition"), RabbitI18n.Text("controls.preedit_preview")]
        )
        this.appearance_preedit_type.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_floating_preedit := this.AddCheckbox(
            "x260 y634 w190 h24 Hidden",
            RabbitI18n.Text("controls.floating_preedit")
        )
        this.appearance_floating_preedit.OnEvent("Click", (*) => this.OnAppearanceControlsChanged())
        this.appearance_floating_opacity_label := this.AddText("x478 y636 w72 h22 Hidden",
            RabbitI18n.Text("controls.opacity"))
        this.appearance_floating_opacity := this.AddEdit("x552 y632 w60 r1 Number -Multi Hidden")
        this.appearance_floating_opacity.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_floating_height_label := this.AddText("x628 y636 w72 h22 Hidden",
            RabbitI18n.Text("controls.floating_height"))
        this.appearance_floating_height := this.AddEdit("x702 y632 w64 r1 Number -Multi Hidden")
        this.appearance_floating_height.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_tabs.UseTab(3)
        this.appearance_shadow_radius_label := this.AddText("x260 y662 w72 h22 Hidden",
            RabbitI18n.Text("controls.shadow_radius"))
        this.appearance_shadow_radius := this.AddEdit("x334 y658 w80 r1 -Multi Hidden")
        this.appearance_shadow_radius.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_shadow_offset_x_label := this.AddText("x424 y662 w72 h22 Hidden",
            RabbitI18n.Text("controls.shadow_x"))
        this.appearance_shadow_offset_x := this.AddEdit("x498 y658 w80 r1 -Multi Hidden")
        this.appearance_shadow_offset_x.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_shadow_offset_y_label := this.AddText("x588 y662 w72 h22 Hidden",
            RabbitI18n.Text("controls.shadow_y"))
        this.appearance_shadow_offset_y := this.AddEdit("x662 y658 w80 r1 -Multi Hidden")
        this.appearance_shadow_offset_y.OnEvent("Change", (*) => this.OnAppearanceControlsChanged())
        this.appearance_tabs.UseTab()
        this.appearance_typesetting_controls := [
            this.appearance_font_label,
            this.appearance_font,
            this.appearance_font_point_label,
            this.appearance_font_point,
            this.appearance_preedit_font_label,
            this.appearance_preedit_font,
            this.appearance_label_font_label,
            this.appearance_label_font,
            this.appearance_label_font_point_label,
            this.appearance_label_font_point,
            this.appearance_comment_font_label,
            this.appearance_comment_font,
            this.appearance_comment_font_point_label,
            this.appearance_comment_font_point,
            this.appearance_label_format_label,
            this.appearance_label_format,
            this.appearance_advanced_font,
            this.appearance_layout_type_label,
            this.appearance_layout_type,
            this.appearance_align_type_label,
            this.appearance_align_type,
            this.appearance_margin_x_label,
            this.appearance_margin_x,
            this.appearance_margin_y_label,
            this.appearance_margin_y,
            this.appearance_preedit_margin_x_label,
            this.appearance_preedit_margin_x,
            this.appearance_preedit_margin_y_label,
            this.appearance_preedit_margin_y,
            this.appearance_candidate_padding_x_label,
            this.appearance_candidate_padding_x,
            this.appearance_candidate_padding_y_label,
            this.appearance_candidate_padding_y,
            this.appearance_candidate_spacing_label,
            this.appearance_candidate_spacing,
            this.appearance_shadow_radius_label,
            this.appearance_shadow_radius,
            this.appearance_shadow_offset_x_label,
            this.appearance_shadow_offset_x,
            this.appearance_shadow_offset_y_label,
            this.appearance_shadow_offset_y,
            this.appearance_border_width_label,
            this.appearance_border_width,
            this.appearance_corner_radius_label,
            this.appearance_corner_radius,
            this.appearance_round_corner_label,
            this.appearance_round_corner,
            this.appearance_preedit_border_width_label,
            this.appearance_preedit_border_width,
            this.appearance_preedit_corner_radius_label,
            this.appearance_preedit_corner_radius,
            this.appearance_preedit_round_corner_label,
            this.appearance_preedit_round_corner,
            this.appearance_min_width_label,
            this.appearance_min_width,
            this.appearance_min_height_label,
            this.appearance_min_height,
            this.appearance_flow_rows_label,
            this.appearance_flow_rows,
            this.appearance_vertical_direction,
            this.appearance_preedit_type_label,
            this.appearance_preedit_type,
            this.appearance_floating_preedit,
            this.appearance_floating_opacity_label,
            this.appearance_floating_opacity,
            this.appearance_floating_height_label,
            this.appearance_floating_height,
        ]
        this.LayoutPreeditControls()
        controls_elapsed := A_TickCount - controls_started_at
        this.appearance_typesetting_created := true
        populate_started_at := A_TickCount
        if this.appearance_page.settings {
            loading := this.appearance_page.loading
            this.appearance_page.loading := true
            try {
                this.appearance_page.PopulateStyle(this.appearance_page.style)
            } finally {
                this.appearance_page.loading := loading
            }
            this.appearance_page.UpdateConditionalControls()
        }
        populate_elapsed := A_TickCount - populate_started_at
        theme_started_at := A_TickCount
        if HasProp(this, "window_theme") && this.window_theme {
            this.window_theme.Apply()
        }
        theme_elapsed := A_TickCount - theme_started_at
        RabbitDebug(
            Format(
                "typesetting controls initialized: total_ms={} create_ms={} populate_ms={} theme_ms={}",
                A_TickCount - controls_started_at,
                controls_elapsed,
                populate_elapsed,
                theme_elapsed
            ),
            Format("RabbitSettingsWindow.ahk:{}", A_LineNumber),
            1
        )
        return true
    }

    LayoutPreeditControls() {
        local name, pair, row, col, label, edit, width, measured, label_width := 112
        local ctrl, y, preedit_handles := Map(), common_controls := []
        for ctrl in this.appearance_typesetting_controls {
            if ctrl.Type = "Edit" {
                ctrl.Move(, , , 24)
            }
        }
        local common_rows := [
            ["margin_x", "margin_y"],
            ["candidate_padding_x", "candidate_padding_y"],
            ["candidate_spacing", "border_width"],
            ["corner_radius", "round_corner"],
            ["min_width", "min_height"]
        ]
        for name, y in Map("preedit_font", 232, "label_font", 268, "comment_font", 304, "label_format", 340) {
            this.%"appearance_" . name . "_label"%.Move(, y)
            this.%"appearance_" . name%.Move(, y - 4)
        }
        this.appearance_label_font_point.Move(, 264)
        this.appearance_comment_font_point.Move(, 300)
        this.appearance_advanced_font.Move(, 334)
        this.LayoutFontControls()
        this.appearance_layout_type_label.Move(, 196)
        this.appearance_layout_type.Move(, 192)
        this.appearance_align_type_label.Move(, 196)
        this.appearance_align_type.Move(, 192)
        for row, pair in common_rows {
            for col, name in pair {
                label := this.%"appearance_" . name . "_label"%
                edit := this.%"appearance_" . name%
                label.Move(, 232 + (row - 1) * 32)
                edit.Move(, 228 + (row - 1) * 32)
            }
        }
        for pair in common_rows {
            for name in pair {
                label := this.%"appearance_" . name . "_label"%
                measured := this.AddText("Hidden", label.Text)
                measured.GetPos(, , &width)
                label_width := Max(label_width, width + 8)
            }
        }
        for row, pair in common_rows {
            for col, name in pair {
                this.%"appearance_" . name . "_label"%.Move(260 + (col - 1) * 254, , label_width)
                this.%"appearance_" . name%.Move(260 + (col - 1) * 254 + label_width, ,
                    Max(48, 244 - label_width))
            }
        }
        label_width := 112
        this.appearance_flow_rows_label.Move(, 392)
        this.appearance_flow_rows.Move(, 388)
        this.appearance_vertical_direction.Move(, 390)
        for name in ["shadow_radius", "shadow_offset_x", "shadow_offset_y"] {
            this.%"appearance_" . name . "_label"%.Move(, 428)
            this.%"appearance_" . name%.Move(, 424)
        }
        this.appearance_preedit_controls := [
            this.appearance_preedit_type_label,
            this.appearance_preedit_type,
            this.appearance_floating_preedit,
        ]
        measured := this.AddText("Hidden", this.appearance_preedit_type_label.Text)
        measured.GetPos(, , &width)
        label_width := Max(112, width + 8)
        this.appearance_preedit_type_label.Move(260, 196, label_width)
        this.appearance_preedit_type.Move(260 + label_width, 192, Min(220, 506 - label_width))
        this.appearance_floating_preedit.Move(260, 226, 506)
        label_width := 112
        local pairs := [
            ["floating_opacity", "floating_height"],
            ["preedit_margin_x", "preedit_margin_y"],
            ["preedit_border_width", "preedit_corner_radius"],
            ["preedit_round_corner"]
        ]
        for pair in pairs {
            for name in pair {
                label := this.%"appearance_" . name . "_label"%
                measured := this.AddText("Hidden", label.Text)
                measured.GetPos(, , &width)
                label_width := Max(label_width, width + 8)
            }
        }
        for row, pair in pairs {
            for col, name in pair {
                label := this.%"appearance_" . name . "_label"%
                edit := this.%"appearance_" . name%
                label.Move(260 + (col - 1) * 254, 260 + (row - 1) * 28, label_width, 22)
                edit.Move(260 + (col - 1) * 254 + label_width, 256 + (row - 1) * 28,
                    Max(48, 244 - label_width))
                this.appearance_preedit_controls.Push(label, edit)
            }
        }
        this.appearance_tabs.UseTab(4)
        this.appearance_preedit_hint := this.AddText("x260 y380 w510 h32 Hidden",
            RabbitI18n.Text("controls.preedit_hint"))
        this.appearance_tabs.UseTab()
        this.appearance_preedit_controls.Push(this.appearance_preedit_hint)
        for ctrl in this.appearance_preedit_controls {
            preedit_handles[ctrl.Hwnd] := true
        }
        for ctrl in this.appearance_typesetting_controls {
            if !preedit_handles.Has(ctrl.Hwnd) {
                common_controls.Push(ctrl)
            }
        }
        ; Font controls precede the first layout label in creation order.
        local collecting_fonts := true
        this.appearance_typesetting_controls := []
        for ctrl in common_controls {
            if ctrl = this.appearance_layout_type_label {
                collecting_fonts := false
            }
            if collecting_fonts {
                this.appearance_font_controls.Push(ctrl)
            } else {
                this.appearance_typesetting_controls.Push(ctrl)
            }
        }
    }

    LayoutFontControls() {
        local name, label, measured, width, label_width := 72, size_width, button_width, input_x
        ; Measure localized text with the dialog font rather than assuming Chinese label lengths.
        for name in ["font", "preedit_font", "label_font", "comment_font", "label_format"] {
            label := this.%"appearance_" . name . "_label"%
            measured := this.AddText("Hidden", label.Text)
            measured.GetPos(, , &width)
            label_width := Max(label_width, width + 8)
        }
        input_x := 260 + label_width
        measured := this.AddText("Hidden", this.appearance_font_point_label.Text)
        measured.GetPos(, , &width)
        size_width := Max(42, width + 8)
        for name in ["font_point", "label_font_point", "comment_font_point"] {
            this.%"appearance_" . name . "_label"%.Move(708 - size_width, , size_width)
        }
        for name in ["font", "preedit_font", "label_font", "comment_font", "label_format"] {
            this.%"appearance_" . name . "_label"%.Move(260, , label_width)
            this.%"appearance_" . name%.Move(input_x, ,
                (name = "preedit_font" ? 766 : 698 - size_width) - input_x)
        }
        measured := this.AddText("Hidden", this.appearance_advanced_font.Text)
        measured.GetPos(, , &width)
        button_width := Max(180, width + 32)
        this.appearance_advanced_font.Move(766 - button_width, , button_width)
        this.appearance_label_format.Move(input_x, , 754 - button_width - input_x)
    }

    AddAsciiSwitchControl(key, label, x, y) {
        local labels := key = "Caps_Lock"
            ? RabbitSettingsWindow.CAPS_LOCK_ACTION_LABELS
            : RabbitSettingsWindow.SWITCH_ACTION_LABELS
        local values := key = "Caps_Lock"
            ? RabbitSettingsWindow.CAPS_LOCK_ACTION_VALUES
            : RabbitSettingsWindow.SWITCH_ACTION_VALUES
        local label_ctrl := this.AddText(Format("x{} y{} w68 h22 Hidden", x, y), label)
        local dropdown := this.AddDropDownList(
            Format("x{} y{} w96 Choose1 Hidden", x + 68, y - 4),
            labels
        )
        dropdown.OnEvent("Change", (*) => this.OnAsciiSwitchChanged(key))
        this.ascii_switch_controls[key] := {
            label: label_ctrl,
            dropdown: dropdown,
            values: values.Clone(),
        }
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
        local page, was_pending := false
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
        if this.initial_page_load_pending && !this.window_shown {
            this.footer_status.Value := RabbitI18n.Text("settings.loading")
            this.UpdateApplyButton()
            return true
        }
        if this.initial_page_load_pending {
            was_pending := true
            this.initial_page_load_pending := false
            SetTimer(this.initial_page_load_callback, 0)
        }
        this.LoadPageSettings(index)
        if was_pending {
            this.FinishInitialPageLoad()
        }
        this.UpdateApplyButton()
        return true
    }

    LoadPageSettings(index) {
        if index = 1 {
            this.EnsureAppearanceSettings()
            if this.window_shown {
                this.PreviewAppearance()
            }
        } else if index = 2 {
            this.EnsureSwitcherSettings()
            if this.switcher_tabs.Value = 3 {
                this.EnsureRimeDepotSettings()
            }
        } else if index = 3 {
            this.EnsureBehaviorSettings()
        } else if index = 4 {
            this.EnsureApplicationSettings()
        } else if index = 5 {
            this.EnsureDictionarySettings()
        }
    }

    LoadInitialPage() {
        if this.disposed || !this.initial_page_load_pending {
            return
        }
        this.initial_page_load_pending := false
        this.LoadPageSettings(this.selected_page)
        this.FinishInitialPageLoad()
        this.UpdateApplyButton()
    }

    FinishInitialPageLoad() {
        if this.footer_status.Value = RabbitI18n.Text("settings.loading") {
            this.footer_status.Value := this.installing
                ? RabbitI18n.Text("controls.first_install_hint")
                : RabbitI18n.Text("controls.save_hint")
        }
    }

    GetPageWindowHeight(index := 0) {
        if !index {
            index := this.selected_page
        }
        if index = 1 {
            return RabbitSettingsWindow.APPEARANCE_HEIGHT
        }
        if index = 2 {
            return RabbitSettingsWindow.SWITCHER_HEIGHT
        }
        if index = 7 {
            return Max(RabbitSettingsWindow.ABOUT_HEIGHT, 136 + (HasProp(this, "about_page") ? this.about_page.height : 0) + 68)
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
        this.appearance_page.SetVisible(visible)
    }

    SetAppearanceTabControlsVisible(visible) {
        this.appearance_page.SetTabControlsVisible(visible)
    }

    OnAppearanceTabChanged() {
        if this.appearance_tabs.Value >= 2 {
            this.EnsureAppearanceTypesettingControls()
        }
        this.appearance_page.OnTabChanged()
    }

    SetSwitcherVisible(visible) {
        if visible {
            this.EnsurePageControls(2)
        }
        if !this.page_controls_created.Has(2) {
            return
        }
        this.switcher_tabs.Visible := visible
        this.SetSwitcherTabControlsVisible(visible)
        this.switcher_status.Visible := visible
        if visible && this.switcher_tabs.Value = 3 {
            this.EnsureRimeDepotSettings()
        }
    }

    SetSwitcherTabControlsVisible(visible) {
        local schema_visible := visible && this.switcher_tabs.Value = 1
        local menu_visible := visible && this.switcher_tabs.Value = 2
        local depot_visible := visible && this.switcher_tabs.Value = 3
        for ctrl in this.switcher_schema_controls {
            ctrl.Visible := schema_visible && (ctrl != this.switcher_list_header || this.initial_dark_mode)
        }
        for ctrl in this.switcher_menu_controls {
            ctrl.Visible := menu_visible
        }
        for ctrl in this.rime_depot_controls {
            ctrl.Visible := depot_visible
        }
        if depot_visible {
            this.UpdateRimeDepotGitPathState()
        }
    }

    OnSwitcherTabChanged() {
        if this.switcher_tabs.Value = 2 {
            this.RefreshSwitcherOptions()
        } else if this.switcher_tabs.Value = 3 {
            this.EnsureRimeDepotSettings()
        }
        this.SetSwitcherTabControlsVisible(this.selected_page = 2)
    }

    SetBehaviorVisible(visible) {
        if visible {
            this.EnsurePageControls(3)
        }
        if !this.page_controls_created.Has(3) {
            return
        }
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
        for ctrl in this.behavior_interface_controls {
            ctrl.Visible := visible && this.behavior_tabs.Value = 3
        }
    }

    OnBehaviorTabChanged() {
        this.SetBehaviorTabControlsVisible(this.selected_page = 3)
    }

    SetApplicationVisible(visible) {
        if visible {
            this.EnsurePageControls(4)
        }
        if !this.page_controls_created.Has(4) {
            return
        }
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
        if visible {
            this.EnsurePageControls(5)
        }
        if !this.page_controls_created.Has(5) {
            return
        }
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
        if visible {
            this.EnsurePageControls(6)
        }
        if !this.page_controls_created.Has(6) {
            return
        }
        this.maintenance_group.Visible := visible
        this.maintenance_text.Visible := visible
        this.deploy_button.Visible := visible
        this.sync_button.Visible := visible
        this.operation_status.Visible := visible
    }

    SetAboutVisible(visible) {
        if visible {
            this.EnsurePageControls(7)
        }
        if !this.page_controls_created.Has(7) {
            return
        }
        this.about_page.SetVisible(visible)
    }

    RunOwnedDialog(callback) {
        this.Opt("+OwnDialogs")
        try {
            return callback.Call()
        } finally {
            this.Opt("-OwnDialogs")
        }
    }

    ShowMessage(text, title := "", options := "") {
        return this.RunOwnedDialog(MsgBox.Bind(text, title, options))
    }

    SelectFile(options := "", root_dir_or_file := "", title := "", filter := "") {
        return this.RunOwnedDialog(FileSelect.Bind(options, root_dir_or_file, title, filter))
    }

    EnsureAppearanceSettings() {
        return this.appearance_page.EnsureSettings()
    }

    CreateAppearancePreview() {
        this.appearance_page.CreatePreview()
    }

    PopulateAppearanceSettings() {
        this.appearance_page.PopulateSettings()
        if this.window_shown {
            this.PreviewAppearance()
        }
    }

    PopulateAppearanceColorList() {
        this.appearance_page.PopulateColorList()
    }

    PopulateAppearanceStyle(style) {
        this.EnsureAppearanceTypesettingControls()
        this.appearance_page.PopulateStyle(style)
    }

    SetAppearanceFontValue(ctrl, value) {
        this.appearance_page.SetFontValue(ctrl, value)
    }

    static GetInstalledFontFaces() {
        return RabbitAppearanceSettingsPage.GetInstalledFontFaces()
    }

    OnAppearanceTargetChange() {
        this.appearance_page.OnTargetChange()
    }

    OnAppearanceSelectionChange() {
        this.appearance_page.OnSelectionChange()
    }

    ShowAppearanceDetails(index) {
        this.appearance_page.ShowDetails(index)
    }

    OnAppearanceControlsChanged() {
        this.appearance_page.OnControlsChanged()
    }

    OpenAdvancedFontSettings() {
        return this.appearance_page.OpenAdvancedFontSettings()
    }

    UpdateAppearanceConditionalControls() {
        this.appearance_page.UpdateConditionalControls()
    }

    MarkAppearanceDirty() {
        this.appearance_page.MarkDirty()
    }

    GetAppearanceValues() {
        return this.appearance_page.GetValues()
    }

    ReadAppearanceNumber(ctrl, name, minimum, maximum) {
        return this.appearance_page.ReadNumber(ctrl, name, minimum, maximum)
    }

    FindAppearancePreset(color_scheme_id) {
        return this.appearance_page.FindPreset(color_scheme_id)
    }

    PreviewAppearance(values := 0) {
        return this.appearance_page.RenderPreview(values)
    }

    GetAppearancePreviewLabels() {
        local label
        local labels := []
        if this.behavior_model || (HasProp(this, "menu_labels") && Trim(this.menu_labels.Value)) {
            Loop Parse this.menu_labels.Value, "," {
                if (label := Trim(A_LoopField)) {
                    labels.Push(label)
                }
            }
            return labels
        }

        if !this.appearance_preview_labels_loaded {
            this.appearance_preview_labels_loaded := true
            if this.workflow && HasMethod(this.workflow, "ReadCandidateLabels") {
                try {
                    labels := this.workflow.ReadCandidateLabels()
                    if labels is Array {
                        this.appearance_preview_labels := labels.Clone()
                    }
                }
            }
        }
        return this.appearance_preview_labels.Clone()
    }

    ApplyAppearanceSettings() {
        if this.IsRimeDepotBusy() || this.parent_operation_busy {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        ; RabbitAppearanceSettingsPage owns the save/deploy transaction and
        ; acquires TryBeginParentOperation itself after validating controls.
        return this.appearance_page.ApplySettings()
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
        return this.appearance_page.dirty || this.switcher_dirty || this.behavior_dirty ||
            this.application_dirty || this.rime_depot_dirty
    }

    PromptUnsavedSettings() {
        if this.close_prompt {
            return this.close_prompt.Call()
        }
        return this.ShowMessage(
            RabbitI18n.Text("messages.close_prompt"),
            RabbitI18n.Text("about.message_title"),
            "YesNoCancel Icon!"
        )
    }

    PromptInstallationClose() {
        if this.close_prompt {
            return this.close_prompt.Call()
        }
        return this.ShowMessage(
            RabbitI18n.Text("messages.install_close_prompt"),
            RabbitI18n.Text("about.message_title"),
            "YesNo Icon!"
        )
    }

    ApplyAllPendingSettings() {
        local appearance_values := 0
        local behavior_values := 0
        local switcher_values := 0
        local rime_depot_values := 0
        local deployment_plan := RabbitDeploymentPlan()
        local deploy_result
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        if this.installing {
            return this.CompleteInstallation()
        }
        if !this.HasUnsavedSettings() {
            return true
        }

        if this.switcher_dirty {
            try {
                switcher_values := this.GetSwitcherValues()
            } catch as err {
                this.SelectPage(2)
                this.switcher_status.Value := err.Message
                return false
            }
            if switcher_values.schema_ids.Length = 0 {
                this.SelectPage(2)
                this.switcher_status.Value := RabbitI18n.Text("controls.need_scheme")
                return false
            }
            deployment_plan.Merge(this.switcher_model.GetDeploymentPlan(switcher_values))
        }
        if this.appearance_page.dirty {
            try {
                appearance_values := this.GetAppearanceValues()
            } catch as err {
                this.SelectPage(1)
                this.appearance_status.Value := err.Message
                return false
            }
            deployment_plan.RequireRabbitConfig()
        }
        if this.behavior_dirty {
            try {
                behavior_values := this.GetBehaviorValues()
            } catch as err {
                this.SelectPage(3)
                this.behavior_status.Value := err.Message
                return false
            }
            deployment_plan.Merge(this.behavior_model.GetDeploymentPlan(behavior_values))
        }
        if this.rime_depot_dirty {
            if !this.EnsureRimeDepotSettings() {
                return false
            }
            try {
                rime_depot_values := this.GetRimeDepotSettingsFromControls()
            } catch as err {
                this.ShowRimeDepotSettingsError(err.Message)
                return false
            }
            deployment_plan.RequireRabbitConfig()
        }
        if this.application_dirty {
            deployment_plan.RequireRabbitConfig()
        }

        if !this.TryBeginParentOperation() {
            return false
        }
        this.footer_status.Value := RabbitI18n.Text("controls.saving_all")
        try {
            if this.appearance_page.dirty {
                if this.appearance_page.settings {
                    this.appearance_page.PrepareSave(appearance_values)
                }
                if !this.appearance_page.settings || !this.appearance_page.settings.Save() {
                    this.SelectPage(1)
                    this.appearance_status.Value := RabbitI18n.Text("controls.appearance_save_error")
                    return false
                }
            }
            if this.switcher_dirty {
                if !this.switcher_model || !this.switcher_model.Save(switcher_values) {
                    this.SelectPage(2)
                    this.switcher_status.Value := RabbitI18n.Text("controls.schemes_save_error")
                    return false
                }
            }
            if this.behavior_dirty {
                if !this.behavior_model || !this.behavior_model.Save(behavior_values) {
                    this.SelectPage(3)
                    this.behavior_status.Value := RabbitI18n.Text("controls.behavior_save_error")
                    return false
                }
            }
            if this.application_dirty {
                if !this.application_model || !this.application_model.Save(this.application_changes) {
                    this.SelectPage(4)
                    this.application_status.Value := RabbitI18n.Text("controls.applications_save_error")
                    return false
                }
            }
            if this.rime_depot_dirty && !this.PersistRimeDepotSettings(rime_depot_values) {
                this.ShowRimeDepotSettingsError(RabbitI18n.Text("depot.settings_save_error"))
                return false
            }

            deploy_result := this.Deploy(deployment_plan)
            if deploy_result != 0 {
                this.footer_status.Value := RabbitI18n.Text("controls.redeploy_error")
                return false
            }

            if this.appearance_page.dirty {
                this.appearance_page.dirty := false
                this.appearance_page.selection_dirty := false
                this.appearance_status.Value := RabbitI18n.Text("controls.appearance_saved")
            }
            if this.switcher_dirty {
                this.switcher_dirty := false
                this.switcher_status.Value := RabbitI18n.Text("controls.schemes_saved")
            }
            if this.behavior_dirty {
                this.behavior_dirty := false
                this.behavior_status.Value := RabbitI18n.Text("controls.behavior_saved")
            }
            if this.application_dirty {
                this.application_dirty := false
                this.application_changes := Map()
                this.application_status.Value := RabbitI18n.Text("controls.applications_saved")
            }
            if this.rime_depot_dirty {
                this.AcceptRimeDepotSettings(rime_depot_values)
                this.rime_depot_dirty := false
                this.rime_depot_sync_pending := true
                this.SetRimeDepotStatus(RabbitI18n.Text("depot.settings_saved"))
            }
            this.footer_status.Opt("cGray")
            this.footer_status.Value := RabbitI18n.Text("controls.all_saved")
            this.UpdateApplyButton()
            return true
        } catch as err {
            this.footer_status.Value := RabbitI18n.Text("messages.save_error", Map("reason", err.Message))
            return false
        } finally {
            if !this.EndParentOperation() {
                this.SurfaceRimeDepotSyncWarning()
            }
        }
    }

    CompleteInstallation() {
        local deploy_result, reloaded, values
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        if !this.installing || !this.EnsureSwitcherSettings() {
            return false
        }
        try {
            values := this.GetSwitcherValues()
        } catch as err {
            this.switcher_status.Value := err.Message
            return false
        }
        if values.schema_ids.Length = 0 {
            this.switcher_status.Value := RabbitI18n.Text("controls.need_scheme")
            return false
        }

        if !this.TryBeginParentOperation() {
            return false
        }
        this.footer_status.Value := RabbitI18n.Text("controls.install_saving")
        try {
            if !this.switcher_model.Save(values, true) {
                this.switcher_status.Value := RabbitI18n.Text("controls.schemes_save_error")
                return false
            }
            this.DisposeSwitcherSettings()
            deploy_result := this.UpdateWorkspace()
            if deploy_result != 0 {
                this.EnsureSwitcherSettings()
                this.footer_status.Value := RabbitI18n.Text("controls.install_error")
                return false
            }

            this.installing := false
            this.navigation.Enabled := true
            reloaded := this.EnsureSwitcherSettings()
            this.switcher_dirty := false
            if reloaded {
                this.switcher_status.Value := RabbitI18n.Text("controls.schemes_saved")
                this.footer_status.Value := RabbitI18n.Text("controls.install_done")
            } else {
                this.footer_status.Value := RabbitI18n.Text("controls.install_reload_error")
            }
            this.UpdateApplyButton()
            return true
        } catch as err {
            this.EnsureSwitcherSettings()
            this.footer_status.Value := RabbitI18n.Text("messages.install_error", Map("reason", err.Message))
            return false
        } finally {
            this.EndParentOperation()
        }
    }

    UpdateApplyButton() {
        if this.installing {
            this.apply_button.Text := RabbitI18n.Text("settings.install")
            this.apply_button.Enabled := !this.IsRimeDepotBusy() && !this.parent_operation_busy
            return
        }
        this.apply_button.Text := RabbitI18n.Text("settings.apply")
        this.apply_button.Enabled := this.HasUnsavedSettings()
            && !this.IsRimeDepotBusy() && !this.parent_operation_busy
    }

    EnsureBehaviorSettings() {
        this.EnsurePageControls(3)
        if this.behavior_model {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateBehaviorSettingsModel") {
            this.behavior_status.Value := RabbitI18n.Text("controls.behavior_unavailable")
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

    PopulateLanguageChoices(preference := "auto") {
        local language, index, selected := 0
        local alias := RabbitI18n.OfficialAlias(preference)
        local names := [RabbitI18n.Text("language.auto")]
        this.language_values := ["auto"]
        for language in RabbitI18n.GetLanguages() {
            this.language_values.Push(language.code)
            names.Push(language.name)
        }
        for index, language in this.language_values {
            if preference = language || (alias && alias = language) {
                selected := index
                ; Preserve an existing alias unless the user selects a different language.
                this.language_values[index] := preference
                break
            }
        }
        if !selected {
            ; Show the effective fallback without adding a metadata-less catalog to the picker.
            ; Preserve the saved preference when the user only edits unrelated settings.
            for index, language in this.language_values {
                if language = RabbitI18n.ResolveLocale(preference) {
                    selected := index
                    this.language_values[index] := preference
                    break
                }
            }
        }
        this.language_choice.Delete()
        this.language_choice.Add(names)
        this.language_choice.Choose(selected)
    }

    PopulateBehaviorSettings() {
        local controls, key
        this.behavior_loading := true
        try {
            this.PopulateLanguageChoices(this.behavior_model.language)
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
            this.good_old_caps_lock.Value := this.behavior_model.good_old_caps_lock
            for key, controls in this.ascii_switch_controls {
                this.SelectAsciiSwitchAction(controls, this.behavior_model.switch_key[key])
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
            this.UpdateGoodOldCapsLockControl()
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
        this.footer_status.Value := RabbitI18n.Text("controls.behavior_dirty")
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
            throw ValueError(RabbitI18n.Text("controls.tip_duration_invalid"))
        }
        if !page_size {
            page_size := "5"
        }
        if !RegExMatch(page_size, "^\d+$") || Number(page_size) < 1 || Number(page_size) > 10 {
            throw ValueError(RabbitI18n.Text("controls.page_size_invalid"))
        }
        if this.clipboard_mode.Value = 3
            && (!RegExMatch(clipboard_length, "^\d+$")
                || Number(clipboard_length) < 1
                || Number(clipboard_length) > 2147483647) {
            throw ValueError(RabbitI18n.Text("controls.clipboard_invalid"))
        }
        Loop Parse this.menu_labels.Value, "," {
            if (label := Trim(A_LoopField)) {
                labels.Push(label)
            }
        }
        local switch_key := Map()
        for key, controls in this.ascii_switch_controls {
            switch_key[key] := controls.values[controls.dropdown.Value]
        }
        return {
            language: this.language_values[this.language_choice.Value],
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
            good_old_caps_lock: !!this.good_old_caps_lock.Value,
            switch_key: switch_key,
            page_size: Number(page_size),
            alternative_select_labels: labels,
            bindings: RabbitBehaviorSettingsModel.CloneValue(this.bindings),
        }
    }

    ApplyBehaviorSettings() {
        local deployment_plan, deploy_result, values
        if !this.behavior_model || !this.behavior_dirty {
            return false
        }
        try {
            values := this.GetBehaviorValues()
        } catch as err {
            this.behavior_status.Value := err.Message
            return false
        }
        deployment_plan := this.behavior_model.GetDeploymentPlan(values)

        if !this.TryBeginParentOperation() {
            return false
        }
        this.behavior_status.Value := RabbitI18n.Text("controls.saving")
        try {
            if !this.behavior_model.Save(values) {
                this.behavior_status.Value := RabbitI18n.Text("controls.behavior_save_error")
                return false
            }
            deploy_result := this.Deploy(deployment_plan)
            if deploy_result != 0 {
                this.behavior_status.Value := RabbitI18n.Text("controls.redeploy_error")
                return false
            }
            this.behavior_dirty := false
            this.behavior_status.Value := RabbitI18n.Text("controls.behavior_saved")
            this.footer_status.Value := RabbitI18n.Text("controls.save_hint")
            this.UpdateApplyButton()
            return true
        } catch as err {
            this.behavior_status.Value := RabbitI18n.Text("messages.save_error", Map("reason", err.Message))
            return false
        } finally {
            this.EndParentOperation()
        }
    }

    EnsureApplicationSettings() {
        if this.application_model {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateApplicationSettingsModel") {
            this.application_status.Value := RabbitI18n.Text("controls.applications_unavailable")
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
            this.application_status.Value := this.application_rules.Count ? "" : RabbitI18n.Text("controls.no_rules")
        } finally {
            this.application_loading := false
        }
        if first_row {
            this.application_list.Modify(first_row, "Select Focus")
            this.OnApplicationSelection(first_row, true)
        }
    }

    ApplicationModeText(ascii_mode) {
        return ascii_mode ? RabbitI18n.Text("controls.english") : RabbitI18n.Text("controls.chinese")
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
            this.application_status.Value := RabbitI18n.Text("controls.process_required")
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
        this.MarkApplicationDirty(RabbitI18n.Text("controls.rules_dirty"))
        return true
    }

    ResetSelectedApplicationRule() {
        local process_name
        local row := this.application_list.GetNext(0)
        if !this.application_model {
            return false
        }
        if !row {
            this.application_status.Value := RabbitI18n.Text("controls.select_rule")
            return false
        }
        process_name := this.application_list.GetText(row, 1)
        this.application_changes[process_name] := { reset: true }
        this.application_rules.Delete(process_name)
        this.application_list.Delete(row)
        this.application_process.Value := ""
        this.application_mode.Choose(2)
        this.MarkApplicationDirty(RabbitI18n.Text("controls.reset_pending"))
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
        this.footer_status.Value := RabbitI18n.Text("controls.applications_dirty")
        this.UpdateApplyButton()
    }

    ApplyApplicationSettings() {
        local deploy_result
        if !this.application_model || !this.application_dirty {
            return false
        }
        if !this.TryBeginParentOperation() {
            return false
        }
        this.application_status.Value := RabbitI18n.Text("controls.saving")
        try {
            if !this.application_model.Save(this.application_changes) {
                this.application_status.Value := RabbitI18n.Text("controls.applications_save_error")
                return false
            }
            deploy_result := this.Deploy(RabbitDeploymentPlan.RabbitConfig())
            if deploy_result != 0 {
                this.application_status.Value := RabbitI18n.Text("controls.redeploy_error")
                return false
            }
            if !this.application_model.Load() {
                this.application_status.Value := RabbitI18n.Text("controls.rules_reload_error")
                return false
            }
            this.PopulateApplicationSettings()
            this.application_status.Value := RabbitI18n.Text("controls.applications_saved")
            this.footer_status.Value := RabbitI18n.Text("controls.save_hint")
            return true
        } catch as err {
            this.application_status.Value := RabbitI18n.Text("messages.save_error", Map("reason", err.Message))
            return false
        } finally {
            this.EndParentOperation()
        }
    }

    EnsureRimeDepotSettings() {
        if this.rime_depot_settings {
            return true
        }
        if !this.page_controls_created.Has(2) {
            this.EnsurePageControls(2)
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateRimeDepotSettings") {
            this.SetRimeDepotStatus(RabbitI18n.Text("depot.unavailable"), true)
            return false
        }
        try {
            this.rime_depot_settings := this.workflow.CreateRimeDepotSettings()
            this.rime_depot_settings := this.rime_depot_settings is RabbitRimeDepotSettings
                ? RabbitRimeDepotSettings(this.rime_depot_settings.ToMap())
                : RabbitRimeDepotSettings(this.rime_depot_settings)
            this.PopulateRimeDepotSettings()
            return true
        } catch as err {
            this.SetRimeDepotStatus(err.Message, true)
            return false
        }
    }

    PopulateRimeDepotSettings() {
        if !this.rime_depot_settings || !HasProp(this, "rime_depot_url_edit") {
            return false
        }
        this.rime_depot_loading := true
        try {
            this.rime_depot_url_edit.Value := this.rime_depot_settings.rppi_url
            this.rime_depot_proxy_edit.Value := this.rime_depot_settings.proxy
            this.rime_depot_use_git.Value := this.rime_depot_settings.use_git ? 1 : 0
            this.rime_depot_git_path_edit.Value := this.rime_depot_settings.git_path
            this.rime_depot_dirty := false
            this.UpdateRimeDepotGitPathState()
            this.UpdateRimeDepotOpenButton()
        } finally {
            this.rime_depot_loading := false
        }
        return true
    }

    GetRimeDepotSettingsFromControls() {
        local values, rppi_url
        if !this.EnsureRimeDepotSettings() {
            throw Error(RabbitI18n.Text("depot.unavailable"))
        }
        rppi_url := Trim(this.rime_depot_url_edit.Value)
        if rppi_url = "" {
            throw ValueError(RabbitI18n.Text("depot.rppi_url_required"))
        }
        if !RegExMatch(rppi_url, "i)^https?://[^\s]+$") {
            throw ValueError(RabbitI18n.Text("depot.rppi_url_invalid"))
        }
        values := RabbitRimeDepotSettings(Map(
            "rppi_url", rppi_url,
            "proxy", Trim(this.rime_depot_proxy_edit.Value),
            "use_git", !!this.rime_depot_use_git.Value,
            "git_path", Trim(this.rime_depot_git_path_edit.Value)
        ))
        return values
    }

    OnRimeDepotSettingsChanged(*) {
        if this.disposed || this.rime_depot_loading {
            return
        }
        this.rime_depot_dirty := this.RimeDepotSettingsDiffer()
        this.SetRimeDepotStatus(RabbitI18n.Text(
            this.rime_depot_dirty ? "depot.settings_dirty" : "depot.settings_saved"
        ))
        this.UpdateRimeDepotGitPathState()
        this.UpdateRimeDepotOpenButton()
        this.UpdateApplyButton()
    }

    RimeDepotSettingsDiffer() {
        if !this.rime_depot_settings {
            return true
        }
        return Trim(this.rime_depot_url_edit.Value) !== this.rime_depot_settings.rppi_url
            || Trim(this.rime_depot_proxy_edit.Value) !== this.rime_depot_settings.proxy
            || !!this.rime_depot_use_git.Value != !!this.rime_depot_settings.use_git
            || Trim(this.rime_depot_git_path_edit.Value) !== this.rime_depot_settings.git_path
    }

    UpdateRimeDepotOpenButton() {
        if !HasProp(this, "rime_depot_open_button") {
            return false
        }
        this.rime_depot_open_button.Text := RabbitI18n.Text(
            this.rime_depot_dirty ? "depot.save_and_open_downloader" : "depot.open_downloader"
        )
        return true
    }

    UpdateRimeDepotGitPathState() {
        local enabled
        if !HasProp(this, "rime_depot_git_path_edit") {
            return false
        }
        enabled := !this.disposed && !this.parent_operation_busy && !this.rime_depot_busy
            && !!this.rime_depot_use_git.Value
        this.rime_depot_git_path_edit.Enabled := enabled
        this.rime_depot_git_path_browse.Enabled := enabled
        return true
    }

    BrowseRimeDepotGitPath(*) {
        local selected
        if this.disposed || this.parent_operation_busy || this.rime_depot_busy {
            return false
        }
        try {
            selected := FileSelect(3, A_WinDir, RabbitI18n.Text("depot.select_git"), "Executable (*.exe)")
            if selected {
                this.rime_depot_git_path_edit.Value := selected
                this.OnRimeDepotSettingsChanged()
            }
            return true
        } catch as err {
            this.SetRimeDepotStatus(
                RabbitI18n.Text("depot.browse_error", Map("reason", err.Message)),
                true
            )
            return false
        }
    }

    ShowRimeDepotSettingsError(message) {
        this.SelectPage(2)
        if this.switcher_tabs.Value != 3 {
            this.switcher_tabs.Choose(3)
            this.OnSwitcherTabChanged()
        }
        this.SetRimeDepotStatus(message, true)
        return false
    }

    PersistRimeDepotSettings(values) {
        if !this.workflow || !HasMethod(this.workflow, "SaveRimeDepotSettings") {
            return false
        }
        return !!this.workflow.SaveRimeDepotSettings(values.ToMap())
    }

    AcceptRimeDepotSettings(values) {
        this.rime_depot_settings := RabbitRimeDepotSettings(values.ToMap())
        return this.PopulateRimeDepotSettings()
    }

    GetRimeDepotSettings() {
        if !this.rime_depot_settings && !this.EnsureRimeDepotSettings() {
            return 0
        }
        return RabbitRimeDepotSettings(this.rime_depot_settings.ToMap())
    }

    SyncRimeDepotWindowSettings() {
        local child := this.rime_depot_window, message := ""
        if !IsObject(child) || (HasProp(child, "disposed") && child.disposed) {
            if child {
                this.DisposeRimeDepotWindow()
            }
            return true
        }
        if !HasMethod(child, "SetSettings") || (HasMethod(child, "IsBusy") && child.IsBusy()) {
            message := RabbitI18n.Text("depot.reconfigure_error")
        } else {
            try {
                if child.SetSettings(this.rime_depot_settings) {
                    return true
                }
                message := RabbitI18n.Text("depot.reconfigure_error")
            } catch as err {
                message := RabbitI18n.Text(
                    "depot.reconfigure_error_reason",
                    Map("reason", err.Message)
                )
            }
        }
        ; A child which rejected the accepted snapshot is stale.  Clear it
        ; before returning so callers cannot activate it with old settings.
        this.DisposeRimeDepotWindow()
        this.SetRimeDepotStatus(message, true)
        return false
    }

    DisposeRimeDepotWindow() {
        local child := this.rime_depot_window, dispose_succeeded := true
        this.rime_depot_window := 0
        if IsObject(child) && HasMethod(child, "Dispose") {
            try child.Dispose()
            catch {
                dispose_succeeded := false
            }
        }
        ; A failed disposal must not strand the parent in the child-busy state
        ; after the stale reference has been cleared.
        this.SetRimeDepotBusy(false)
        return dispose_succeeded
    }

    OpenRimeDepot(*) {
        local values := 0, deploy_result, transaction_succeeded := false, sync_succeeded := true
        if this.disposed || this.parent_operation_busy || this.IsRimeDepotBusy() {
            if !this.disposed {
                this.SetRimeDepotStatus(RabbitI18n.Text("depot.busy"), true)
            }
            return false
        }
        if !this.EnsureRimeDepotSettings() {
            return false
        }
        if !this.rime_depot_dirty {
            return this.StartRimeDepot()
        }
        try {
            values := this.GetRimeDepotSettingsFromControls()
        } catch as err {
            return this.ShowRimeDepotSettingsError(err.Message)
        }
        if !this.TryBeginParentOperation() {
            return false
        }
        this.footer_status.Value := RabbitI18n.Text("controls.saving")
        try {
            if !this.PersistRimeDepotSettings(values) {
                this.ShowRimeDepotSettingsError(RabbitI18n.Text("depot.settings_save_error"))
                return false
            }
            deploy_result := this.Deploy(RabbitDeploymentPlan.RabbitConfig())
            if deploy_result != 0 {
                this.footer_status.Value := RabbitI18n.Text("controls.redeploy_error")
                return false
            }
            this.AcceptRimeDepotSettings(values)
            this.rime_depot_dirty := false
            this.rime_depot_sync_pending := true
            this.SetRimeDepotStatus(RabbitI18n.Text("depot.settings_saved"))
            this.footer_status.Opt("cGray")
            this.footer_status.Value := this.HasUnsavedSettings()
                ? RabbitI18n.Text("controls.save_hint")
                : RabbitI18n.Text("controls.all_saved")
            transaction_succeeded := true
        } catch as err {
            this.footer_status.Value := RabbitI18n.Text(
                "messages.save_error",
                Map("reason", err.Message)
            )
            return false
        } finally {
            sync_succeeded := this.EndParentOperation()
        }
        if !transaction_succeeded {
            return false
        }
        ; EndParentOperation clears a child which rejected the accepted
        ; snapshot.  A successful Open transaction must then create a fresh
        ; child rather than activating that stale instance.
        if !sync_succeeded && this.rime_depot_window {
            this.DisposeRimeDepotWindow()
        }
        return this.StartRimeDepot()
    }

    StartRimeDepot() {
        local window := 0, factory, window_height
        if this.disposed || this.parent_operation_busy || this.IsRimeDepotBusy() {
            if !this.disposed {
                this.footer_status.Value := RabbitI18n.Text("depot.busy")
            }
            return false
        }
        if this.rime_depot_window && (!HasProp(this.rime_depot_window, "disposed")
            || !this.rime_depot_window.disposed) {
            try {
                if HasProp(this.rime_depot_window, "Hwnd") && this.rime_depot_window.Hwnd {
                    if !WinExist("ahk_id " . this.rime_depot_window.Hwnd) {
                        throw Error("The downloader window handle is no longer valid.")
                    }
                    WinActivate("ahk_id " . this.rime_depot_window.Hwnd)
                } else if HasMethod(this.rime_depot_window, "Show") {
                    this.rime_depot_window.Show()
                } else {
                    throw Error("The downloader window cannot be shown.")
                }
                return true
            } catch {
                ; Activation/display failure makes the existing instance
                ; unusable.  Dispose it before falling through to recreation.
                this.DisposeRimeDepotWindow()
            }
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateRimeDepotSettings") {
            this.SetRimeDepotStatus(RabbitI18n.Text("depot.unavailable"), true)
            return false
        }
        if !this.EnsureRimeDepotSettings() {
            return false
        }
        try {
            factory := this.rime_depot_factory
            window := factory.Call(this, this.workflow)
            if !window {
                throw Error(RabbitI18n.Text("depot.unavailable"))
            }
            this.rime_depot_window := window
            if HasMethod(window, "IsBusy") {
                this.SetRimeDepotBusy(window.IsBusy())
            }
            if IsObject(window) && HasProp(window, "Hwnd") && window.Hwnd {
                window_height := HasMethod(window, "ModeWindowHeight")
                    ? window.ModeWindowHeight()
                    : RabbitRimeDepotWindow.WINDOW_HEIGHT
                RabbitDialogPlacement.ShowOnOwnerMonitor(
                    window,
                    this.Hwnd,
                    Format("w{} h{}", RabbitRimeDepotWindow.WINDOW_WIDTH, window_height)
                )
            } else if HasMethod(window, "Show") {
                window.Show()
            }
            return true
        } catch as err {
            if window && HasMethod(window, "Dispose") {
                try window.Dispose()
            }
            this.rime_depot_window := 0
            this.SetRimeDepotStatus(RabbitI18n.Text(
                "depot.open_error",
                Map("reason", err.Message)
            ), true)
            return false
        }
    }

    SetRimeDepotStatus(value, error := false) {
        if HasProp(this, "rime_depot_status") && this.rime_depot_status {
            this.rime_depot_status.Value := value
            this.rime_depot_status.Opt(error ? "cRed" : "cGray")
            return true
        }
        if HasProp(this, "switcher_status") && this.switcher_status {
            this.switcher_status.Value := value
            this.switcher_status.Opt(error ? "cRed" : "cGray")
            return true
        }
        if HasProp(this, "footer_status") && this.footer_status {
            this.footer_status.Value := value
            this.footer_status.Opt(error ? "cRed" : "cGray")
            return true
        }
        return false
    }

    SurfaceRimeDepotSyncWarning() {
        local message := RabbitI18n.Text("depot.reconfigure_error")
        if HasProp(this, "rime_depot_status") && this.rime_depot_status.Value != "" {
            message := this.rime_depot_status.Value
        }
        if HasProp(this, "footer_status") && this.footer_status {
            this.footer_status.Value := message
            this.footer_status.Opt("cRed")
            return true
        }
        return false
    }

    IsRimeDepotBusy() {
        return this.rime_depot_busy || (this.rime_depot_window
            && (!HasProp(this.rime_depot_window, "disposed") || !this.rime_depot_window.disposed)
            && HasMethod(this.rime_depot_window, "IsBusy")
            && this.rime_depot_window.IsBusy())
    }

    IsParentOperationBusy() {
        return this.parent_operation_busy
    }

    SetRimeDepotBusy(busy) {
        this.rime_depot_busy := !!busy
        if this.disposed {
            return
        }
        this.SetRimeDepotOwnerBusy(this.parent_operation_busy || this.rime_depot_busy)
        if this.parent_operation_busy || this.rime_depot_busy {
            this.Opt("+Disabled")
        } else {
            this.Opt("-Disabled")
        }
        this.UpdateRimeDepotGitPathState()
        this.UpdateApplyButton()
    }

    SetRimeDepotOwnerBusy(busy) {
        local child := this.rime_depot_window
        if !IsObject(child) || (HasProp(child, "disposed") && child.disposed)
            || !HasMethod(child, "SetOwnerBusy") {
            return false
        }
        try {
            child.SetOwnerBusy(!!busy)
            return true
        } catch {
            return false
        }
    }

    ParentWindowIsEnabled() {
        return !!DllCall("IsWindowEnabled", "Ptr", this.Hwnd, "Int")
    }

    TryBeginParentOperation() {
        if this.disposed || this.parent_operation_busy || this.IsRimeDepotBusy() {
            if !this.disposed {
                this.footer_status.Value := RabbitI18n.Text("depot.busy")
            }
            return false
        }
        this.parent_operation_restore_enabled := this.ParentWindowIsEnabled()
        this.parent_operation_busy := true
        this.SetRimeDepotOwnerBusy(true)
        this.Opt("+Disabled")
        return true
    }

    EndParentOperation() {
        local sync_succeeded := true
        if !this.parent_operation_busy {
            return false
        }
        this.parent_operation_busy := false
        this.SetRimeDepotOwnerBusy(this.rime_depot_busy)
        if !this.disposed && !this.rime_depot_busy && this.parent_operation_restore_enabled {
            this.Opt("-Disabled")
        }
        if this.rime_depot_sync_pending {
            this.rime_depot_sync_pending := false
            sync_succeeded := this.SyncRimeDepotWindowSettings()
        }
        this.UpdateRimeDepotGitPathState()
        this.UpdateApplyButton()
        return sync_succeeded
    }

    RefreshSwitcherAfterRimeDepotInstall() {
        local draft := 0, old_model := this.switcher_model, refreshed_model := 0
        local was_dirty := this.switcher_dirty
        if this.disposed || !this.workflow || !HasMethod(this.workflow, "CreateSwitcherSettingsModel") {
            return false
        }
        if !this.page_controls_created.Has(2) {
            this.EnsurePageControls(2)
        }
        if old_model && was_dirty {
            draft := this.GetSwitcherValues(false)
        }
        try {
            refreshed_model := this.workflow.CreateSwitcherSettingsModel()
            if !refreshed_model {
                return false
            }
            if draft && HasMethod(refreshed_model, "SetCurrentValues") {
                refreshed_model.SetCurrentValues(draft)
            } else if draft {
                throw Error(RabbitI18n.Text("models.switcher_read"))
            }
            this.switcher_model := refreshed_model
            this.PopulateSwitcherSettings()
            if was_dirty {
                this.switcher_dirty := true
                this.switcher_status.Value := RabbitI18n.Text("controls.schemes_dirty")
                this.footer_status.Value := RabbitI18n.Text("controls.schemes_dirty")
                this.UpdateApplyButton()
            }
            if old_model && old_model !== refreshed_model && HasMethod(old_model, "Dispose") {
                try old_model.Dispose()
            }
            return true
        } catch {
            this.switcher_model := old_model
            this.switcher_dirty := was_dirty
            if refreshed_model && refreshed_model !== old_model && HasMethod(refreshed_model, "Dispose") {
                try refreshed_model.Dispose()
            }
            if old_model && draft && HasMethod(old_model, "SetCurrentValues") {
                try {
                    old_model.SetCurrentValues(draft)
                    this.PopulateSwitcherSettings()
                    this.switcher_dirty := true
                    this.UpdateApplyButton()
                }
            }
            return false
        }
    }

    DeployRimeDepotSettings() {
        if !this.TryBeginParentOperation() {
            return 1
        }
        try {
            return this.UpdateWorkspace()
        } finally {
            this.EndParentOperation()
        }
    }

    EnsureSwitcherSettings() {
        if this.switcher_model {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateSwitcherSettingsModel") {
            this.switcher_status.Value := RabbitI18n.Text("controls.schemes_unavailable")
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
        this.switcher_option_items := Map()
        this.switcher_option_selection := Map()
        this.switcher_custom_options := Map()
        this.switcher_removed_options := Map()
    }

    PopulateSwitcherSettings() {
        local option_name, row
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
            this.switcher_caption.Value := this.switcher_model.caption
            this.switcher_fold_options.Value := this.switcher_model.fold_options
            this.switcher_abbreviate_options.Value := this.switcher_model.abbreviate_options
            this.switcher_prefix.Value := this.switcher_model.option_list_prefix
            this.switcher_suffix.Value := this.switcher_model.option_list_suffix
            this.switcher_separator.Value := this.switcher_model.option_list_separator
            this.switcher_fix_order.Value := this.switcher_model.fix_schema_list_order
            this.switcher_option_selection := Map()
            this.switcher_custom_options := Map()
            this.switcher_removed_options := Map()
            for option_name in this.switcher_model.save_options {
                this.switcher_option_selection[option_name] := true
            }
            this.RefreshSwitcherOptions()
            this.UpdateSwitcherFoldControls()
            this.UpdateSwitcherPreview()
            this.switcher_dirty := false
            this.UpdateApplyButton()
            this.switcher_status.Value := ""
            if this.switcher_list.GetCount() > 0 {
                this.switcher_list.Modify(1, "Select Focus")
                this.ShowSwitcherDetails(1)
                this.UpdateSwitcherMoveButtons(1)
            }
        } finally {
            this.switcher_loading := false
        }
    }

    RefreshSwitcherOptions() {
        local existing_names := Map()
        local item, option_name, row
        local option_items := []
        local visible_items := []
        local was_loading := this.switcher_loading
        if !HasProp(this, "switcher_save_list") || !this.switcher_model {
            return
        }
        this.switcher_loading := true
        try {
            if HasMethod(this.switcher_model, "GetOptionItems") {
                option_items := this.switcher_model.GetOptionItems(this.SelectedSchemaIds())
            }
            for item in option_items {
                if item.custom && this.switcher_removed_options.Has(item.name) {
                    continue
                }
                visible_items.Push(item)
                existing_names[item.name] := true
                if !this.switcher_option_selection.Has(item.name) {
                    this.switcher_option_selection[item.name] := !!item.selected
                }
                if item.custom {
                    this.switcher_custom_options[item.name] := true
                }
            }
            for option_name in this.switcher_custom_options {
                if !existing_names.Has(option_name) {
                    visible_items.Push({
                        name: option_name,
                        source: RabbitI18n.Text("controls.custom"),
                        custom: true,
                        selected: this.switcher_option_selection.Has(option_name)
                            && this.switcher_option_selection[option_name],
                    })
                }
            }

            this.switcher_option_items := Map()
            this.switcher_save_list.Delete()
            for item in visible_items {
                row := this.switcher_save_list.Add(
                    this.switcher_option_selection.Has(item.name)
                        && this.switcher_option_selection[item.name] ? "Check" : "",
                    item.name,
                    item.source
                )
                this.switcher_option_items[row] := item
            }
            this.switcher_save_list.ModifyCol(1, 232)
            this.switcher_save_list.ModifyCol(2, 250)
        } finally {
            this.switcher_loading := was_loading
        }
    }

    OnSwitcherOptionCheck(row, checked) {
        if this.switcher_loading || !this.switcher_option_items.Has(row) {
            return
        }
        this.switcher_option_selection[this.switcher_option_items[row].name] := !!checked
        this.MarkSwitcherDirty()
    }

    AddSwitcherOption() {
        local item, name, option_row, result
        result := InputBox(
            RabbitI18n.Text("controls.option_prompt"),
            RabbitI18n.Text("controls.option_title"),
            "w420 h150"
        )
        if result.Result != "OK" {
            return
        }
        name := Trim(result.Value)
        if !name || RegExMatch(name, "[\s/]") {
            this.ShowMessage(RabbitI18n.Text("controls.option_invalid"), RabbitI18n.Text("about.message_title"), "Ok Icon!")
            return
        }
        for option_row, item in this.switcher_option_items {
            if item.name = name {
                this.ShowMessage(RabbitI18n.Text("controls.option_exists"), RabbitI18n.Text("about.message_title"), "Ok Icon!")
                return
            }
        }
        this.switcher_custom_options[name] := true
        if this.switcher_removed_options.Has(name) {
            this.switcher_removed_options.Delete(name)
        }
        this.switcher_option_selection[name] := true
        this.RefreshSwitcherOptions()
        this.MarkSwitcherDirty()
    }

    DeleteSwitcherOption() {
        local item, row := this.switcher_save_list.GetNext(0)
        if !row || !this.switcher_option_items.Has(row) {
            return
        }
        item := this.switcher_option_items[row]
        if !item.custom {
            this.ShowMessage(RabbitI18n.Text("controls.option_builtin"), RabbitI18n.Text("about.message_title"), "Ok Icon!")
            return
        }
        this.switcher_custom_options.Delete(item.name)
        this.switcher_option_selection.Delete(item.name)
        this.switcher_removed_options[item.name] := true
        this.RefreshSwitcherOptions()
        this.MarkSwitcherDirty()
    }

    OnSwitcherFoldChanged() {
        this.UpdateSwitcherFoldControls()
        this.OnSwitcherDisplayChanged()
    }

    OnSwitcherDisplayChanged() {
        this.UpdateSwitcherPreview()
        this.MarkSwitcherDirty()
    }

    UpdateSwitcherFoldControls() {
        local enabled := !!this.switcher_fold_options.Value
        this.switcher_abbreviate_options.Enabled := enabled
        this.switcher_prefix.Enabled := enabled
        this.switcher_separator.Enabled := enabled
        this.switcher_suffix.Enabled := enabled
    }

    UpdateSwitcherPreview() {
        local suffix := this.switcher_abbreviate_options.Value ? "_abbr" : ""
        local labels := [
            RabbitI18n.Text("frontend.chinese" . suffix),
            RabbitI18n.Text("frontend.half" . suffix),
            RabbitI18n.Text("frontend.simplified" . suffix)
        ]
        this.switcher_preview.Value := RabbitI18n.Text("messages.summary", Map("summary", this.switcher_prefix.Value
            . labels[1] . this.switcher_separator.Value . labels[2]
            . this.switcher_separator.Value . labels[3] . this.switcher_suffix.Value))
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

    OnSwitcherSchemaSelected(row) {
        this.ShowSwitcherDetails(row)
        this.UpdateSwitcherMoveButtons(row)
    }

    OnSwitcherSchemaCheck(row, checked) {
        if this.switcher_loading {
            return
        }
        this.switcher_list.Modify(row, "Select Focus")
        this.MarkSwitcherDirty()
        this.UpdateSwitcherMoveButtons(row, checked)
    }

    GetCheckedSwitcherRows() {
        local row := 0
        local rows := []
        while (row := this.switcher_list.GetNext(row, "Checked")) {
            rows.Push(row)
        }
        return rows
    }

    UpdateSwitcherMoveButtons(row := 0, checked := -1) {
        local checked_index, checked_row, insert_at := 0, index := 0
        local rows := this.GetCheckedSwitcherRows()
        if !row {
            row := this.switcher_list.GetNext(0)
        }
        if checked = 0 {
            this.switcher_move_up.Enabled := false
            this.switcher_move_down.Enabled := false
            return
        }
        if checked < 0 && this.switcher_list.GetNext(Max(0, row - 1), "Checked") != row {
            this.switcher_move_up.Enabled := false
            this.switcher_move_down.Enabled := false
            return
        }
        for checked_index, checked_row in rows {
            if checked_row = row {
                index := checked_index
                break
            }
        }
        if !index && checked > 0 {
            insert_at := rows.Length + 1
            for checked_index, checked_row in rows {
                if row < checked_row {
                    insert_at := checked_index
                    break
                }
            }
            rows.InsertAt(insert_at, row)
            for checked_index, checked_row in rows {
                if checked_row = row {
                    index := checked_index
                    break
                }
            }
        }
        this.switcher_move_up.Enabled := index > 1
        this.switcher_move_down.Enabled := index > 0 && index < rows.Length
    }

    MoveSwitcherSchema(direction) {
        local checked_index, checked_row, current_item, index := 0
        local row := this.switcher_list.GetNext(0)
        local rows := this.GetCheckedSwitcherRows()
        local target_row
        if !row || (direction != -1 && direction != 1) {
            return false
        }
        for checked_index, checked_row in rows {
            if checked_row = row {
                index := checked_index
                break
            }
        }
        if !index || index + direction < 1 || index + direction > rows.Length {
            return false
        }
        target_row := rows[index + direction]
        current_item := this.switcher_items[row]
        this.switcher_items[row] := this.switcher_items[target_row]
        this.switcher_items[target_row] := current_item
        this.switcher_list.Modify(row, "", this.switcher_items[row].name)
        this.switcher_list.Modify(target_row, "Select Focus Vis", this.switcher_items[target_row].name)
        this.ShowSwitcherDetails(target_row)
        this.UpdateSwitcherMoveButtons(target_row)
        this.MarkSwitcherDirty()
        return true
    }

    MarkSwitcherDirty() {
        if this.switcher_loading || !this.switcher_model {
            return
        }
        this.switcher_dirty := true
        this.footer_status.Value := RabbitI18n.Text("controls.schemes_dirty")
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

    GetSwitcherValues(validate := true) {
        local save_options := []
        local row := 0
        if validate && !Trim(this.switcher_caption.Value) {
            throw ValueError(RabbitI18n.Text("controls.caption_required"))
        }
        while (row := this.switcher_save_list.GetNext(row, "Checked")) {
            if this.switcher_option_items.Has(row) {
                save_options.Push(this.switcher_option_items[row].name)
            }
        }
        return {
            schema_ids: this.SelectedSchemaIds(),
            hotkeys: Trim(this.switcher_hotkeys.Value),
            caption: this.switcher_caption.Value,
            save_options: save_options,
            fold_options: !!this.switcher_fold_options.Value,
            abbreviate_options: !!this.switcher_abbreviate_options.Value,
            option_list_prefix: this.switcher_prefix.Value,
            option_list_suffix: this.switcher_suffix.Value,
            option_list_separator: this.switcher_separator.Value,
            fix_schema_list_order: !!this.switcher_fix_order.Value,
        }
    }

    ApplySwitcherSettings() {
        local deployment_plan, deploy_result, values
        if !this.switcher_model || !this.switcher_dirty {
            return false
        }
        try {
            values := this.GetSwitcherValues()
        } catch as err {
            this.switcher_status.Value := err.Message
            return false
        }
        if values.schema_ids.Length = 0 {
            this.ShowMessage(RabbitI18n.Text("controls.need_scheme"), RabbitI18n.Text("about.message_title"), "Ok Icon!")
            return false
        }
        deployment_plan := this.switcher_model.GetDeploymentPlan(values)

        if !this.TryBeginParentOperation() {
            return false
        }
        this.switcher_status.Value := RabbitI18n.Text("controls.saving")
        try {
            if !this.switcher_model.Save(values) {
                this.switcher_status.Value := RabbitI18n.Text("controls.schemes_save_error")
                return false
            }
            deploy_result := this.Deploy(deployment_plan)
            if deploy_result != 0 {
                this.switcher_status.Value := RabbitI18n.Text("controls.redeploy_error")
                return false
            }
            this.switcher_dirty := false
            this.switcher_status.Value := RabbitI18n.Text("controls.schemes_saved")
            this.footer_status.Value := RabbitI18n.Text("controls.save_hint")
            this.UpdateApplyButton()
            return true
        } catch as err {
            this.switcher_status.Value := RabbitI18n.Text("messages.save_error", Map("reason", err.Message))
            return false
        } finally {
            this.EndParentOperation()
        }
    }

    EnsureDictionarySettings() {
        if this.dictionary_model {
            return true
        }
        if !this.workflow || !HasMethod(this.workflow, "CreateDictionarySettingsModel") {
            this.dictionary_status.Value := RabbitI18n.Text("controls.dictionaries_unavailable")
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
        this.dictionary_status.Value := this.dictionary_model.dictionaries.Length ? "" : RabbitI18n.Text("controls.no_dictionaries")
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
            this.dictionary_status.Value := RabbitI18n.Text("controls.dictionary_access_error")
            return ""
        }
        if index <= 0 || index > this.dictionary_model.dictionaries.Length {
            this.dictionary_status.Value := RabbitI18n.Text("controls.select_dictionary")
            return ""
        }
        return this.dictionary_list.Text
    }

    BackupSelectedDictionary() {
        local dict_name, file, path
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        if !(dict_name := this.SelectedDictionaryName()) {
            return false
        }
        try {
            path := this.dictionary_model.GetUserDataSyncDir()
            if !DirExist(path) {
                DirCreate(path)
            }
            file := path . "\" . dict_name . ".userdb.txt"
            this.dictionary_status.Value := RabbitI18n.Text("controls.backing_up")
            if !this.dictionary_model.Backup(dict_name) {
                throw Error(RabbitI18n.Text("controls.backup_error"))
            }
            if !FileExist(file) {
                throw Error(RabbitI18n.Text("controls.backup_missing"))
            }
            this.dictionary_status.Value := RabbitI18n.Text("controls.backup_done")
            Run("explorer.exe /select,`"" . file . "`"")
            return true
        } catch as err {
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    RestoreDictionarySnapshot() {
        local selected_path
        local filter := RabbitI18n.Text("controls.snapshot_filter")
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        if !this.dictionary_model {
            this.dictionary_status.Value := RabbitI18n.Text("controls.dictionary_access_error")
            return false
        }
        if !(selected_path := this.SelectFile("1", "", RabbitI18n.Text("controls.open"), filter)) {
            return false
        }
        try {
            this.dictionary_status.Value := RabbitI18n.Text("controls.restoring")
            if !this.dictionary_model.Restore(selected_path) {
                throw Error(RabbitI18n.Text("controls.restore_error"))
            }
            this.dictionary_status.Value := RabbitI18n.Text("controls.restore_done")
            return true
        } catch as err {
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    ExportSelectedDictionary() {
        local dict_name, result, selected_path
        local filter := RabbitI18n.Text("controls.text_filter")
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        if !(dict_name := this.SelectedDictionaryName()) {
            return false
        }
        if !(selected_path := this.SelectFile("S18", dict_name . "_export.txt", RabbitI18n.Text("controls.save_as"), filter)) {
            return false
        }
        if StrLower(SubStr(selected_path, -4)) != ".txt" {
            selected_path .= ".txt"
        }
        try {
            this.dictionary_status.Value := RabbitI18n.Text("controls.exporting")
            result := this.dictionary_model.Export(dict_name, selected_path)
            if result < 0 {
                throw Error(RabbitI18n.Text("controls.export_error"))
            }
            if !FileExist(selected_path) {
                throw Error(RabbitI18n.Text("controls.export_missing"))
            }
            this.dictionary_status.Value := RabbitI18n.Text("messages.exported", Map("count", result))
            Run("explorer.exe /select,`"" . selected_path . "`"")
            return true
        } catch as err {
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    ImportSelectedDictionary() {
        local dict_name, result, selected_path
        local filter := RabbitI18n.Text("controls.text_filter")
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        if !(dict_name := this.SelectedDictionaryName()) {
            return false
        }
        if !(selected_path := this.SelectFile("1", dict_name . "_export.txt", RabbitI18n.Text("controls.open"), filter)) {
            return false
        }
        try {
            this.dictionary_status.Value := RabbitI18n.Text("controls.importing")
            result := this.dictionary_model.Import(dict_name, selected_path)
            if result < 0 {
                throw Error(RabbitI18n.Text("controls.import_error"))
            }
            this.dictionary_status.Value := RabbitI18n.Text("messages.imported", Map("count", result))
            return true
        } catch as err {
            this.dictionary_status.Value := err.Message
            return false
        }
    }

    RunDictionaryManagement() {
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        if !this.workflow {
            return false
        }
        try {
            return this.workflow.DictManagement() = 0
        } catch as err {
            this.ShowMessage(RabbitI18n.Text("messages.dictionary_error", Map("reason", err.Message)), RabbitI18n.Text("about.message_title"), "Ok Iconx")
            return false
        }
    }

    RunDeploy() {
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        if this.installing {
            return this.CompleteInstallation()
        }
        return this.RunMaintenanceAction(
            (*) => this.UpdateWorkspace(),
            RabbitI18n.Text("controls.deploy_done"),
            RabbitI18n.Text("controls.deploy_error")
        )
    }

    RunSync() {
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        return this.RunMaintenanceAction(
            (*) => this.workflow.SyncUserData(),
            RabbitI18n.Text("controls.sync_done"),
            RabbitI18n.Text("controls.sync_error")
        )
    }

    RunMaintenanceAction(action, success_message, failure_message) {
        local result
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return false
        }
        this.EnsurePageControls(6)
        if !this.workflow {
            return false
        }
        if !this.TryBeginParentOperation() {
            return false
        }
        this.operation_status.Value := RabbitI18n.Text("controls.working")
        try {
            result := action.Call()
            this.operation_status.Value := result = 0 ? success_message : failure_message
            return result = 0
        } catch as err {
            this.operation_status.Value := failure_message . " " . err.Message
            return false
        } finally {
            this.EndParentOperation()
        }
    }

    SwitchActionIndex(action, values := 0) {
        local index, value
        if !values {
            values := RabbitSettingsWindow.SWITCH_ACTION_VALUES
        }
        for index, value in values {
            if value = action {
                return index
            }
        }
        return 0
    }

    SelectAsciiSwitchAction(controls, action) {
        local index := this.SwitchActionIndex(action, controls.values)
        if !index {
            controls.values.Push(action)
            controls.dropdown.Add([RabbitI18n.Text("messages.custom_action", Map("action", action))])
            index := controls.values.Length
        }
        controls.dropdown.Choose(index)
    }

    OnAsciiSwitchChanged(key) {
        if key = "Caps_Lock" {
            this.UpdateGoodOldCapsLockControl()
        }
        this.OnBehaviorChanged()
    }

    UpdateGoodOldCapsLockControl() {
        local controls, index
        if !HasProp(this, "good_old_caps_lock") || !this.ascii_switch_controls.Has("Caps_Lock") {
            return
        }
        controls := this.ascii_switch_controls["Caps_Lock"]
        index := controls.dropdown.Value
        this.good_old_caps_lock.Enabled := index && controls.values[index] != "noop"
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
            this.behavior_status.Value := RabbitI18n.Text("controls.select_binding")
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
            this.behavior_status.Value := RabbitI18n.Text("controls.select_binding")
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
            this.behavior_status.Value := RabbitI18n.Text("controls.select_binding")
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
        if this.initial_page_load_pending {
            SetTimer(this.initial_page_load_callback, -1)
        } else if this.selected_page = 1 {
            this.PreviewAppearance()
        }
    }

    UpdateWorkspace() {
        return this.Deploy(RabbitDeploymentPlan.FullRedeploy())
    }

    Deploy(plan) {
        if this.IsRimeDepotBusy() {
            this.footer_status.Value := RabbitI18n.Text("depot.busy")
            return 1
        }
        this.deployment_pending := false
        if plan.IsEmpty() {
            return 0
        }
        local result := HasMethod(this.workflow, "Deploy")
            ? this.workflow.Deploy(plan, true)
            : this.workflow.UpdateWorkspace(true)
        this.deployment_pending := result = 0
        if result = 0 {
            if IsObject(this.rime_depot_window)
                && (!HasProp(this.rime_depot_window, "disposed") || !this.rime_depot_window.disposed) {
                ; Parent settings operations hold the child host lock until
                ; EndParentOperation, when the accepted snapshot is ready.
                if this.parent_operation_busy {
                    this.rime_depot_sync_pending := true
                } else {
                    this.SyncRimeDepotWindowSettings()
                }
            }
        }
        return result
    }

    WaitClose() {
        local hwnd := this.Hwnd
        if !this.language_reload_callback {
            WinWaitClose("ahk_id " . hwnd)
            return
        }
        ; This waiting thread resumes only after the GUI event callback has returned,
        ; so saving, dirty-state cleanup and finally blocks finish before reconstruction.
        while !WinWaitClose("ahk_id " . hwnd, , 0.1) {
            if this.deployment_pending && !this.HasUnsavedSettings() {
                this.deployment_pending := false
                this.language_reload_callback.Call(this)
            }
        }
    }

    CaptureLanguageReloadState() {
        local x, y, tab := 0
        WinGetPos(&x, &y, , , "ahk_id " . this.Hwnd)
        switch this.selected_page {
            case 1: tab := this.appearance_tabs.Value
            case 2: tab := this.switcher_tabs.Value
            case 3: tab := this.behavior_tabs.Value
        }
        return {page_id: RabbitSettingsWindow.pages[this.selected_page].id,
            installing: this.installing, x: x, y: y, tab: tab}
    }

    RestoreLanguageReloadState(state) {
        if !state.tab {
            return
        }
        switch this.selected_page {
            case 1:
                this.appearance_tabs.Choose(state.tab)
                this.OnAppearanceTabChanged()
            case 2:
                this.switcher_tabs.Choose(state.tab)
                this.OnSwitcherTabChanged()
            case 3:
                this.behavior_tabs.Choose(state.tab)
                this.OnBehaviorTabChanged()
        }
    }

    OnClose(*) {
        local decision
        if this.disposed {
            return true
        }
        if this.installing {
            decision := this.PromptInstallationClose()
            if decision = "Yes" {
                if !this.DeployInstallationWithoutSaving() {
                    return true
                }
                this.Dispose()
            }
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

    DeployInstallationWithoutSaving() {
        local deploy_result
        if !this.TryBeginParentOperation() {
            return false
        }
        this.footer_status.Value := RabbitI18n.Text("controls.install_without_save")
        try {
            deploy_result := this.UpdateWorkspace()
            if deploy_result != 0 {
                this.footer_status.Value := RabbitI18n.Text("controls.install_error")
                return false
            }
            return true
        } catch as err {
            this.footer_status.Value := RabbitI18n.Text("messages.install_error", Map("reason", err.Message))
            return false
        } finally {
            this.EndParentOperation()
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        SetTimer(this.initial_page_load_callback, 0)
        if this.rime_depot_window {
            try this.rime_depot_window.Dispose()
            this.rime_depot_window := 0
        }
        try {
            if this.window_theme {
                this.window_theme.Dispose()
                this.window_theme := 0
            }
        } finally {
            try {
                if this.appearance_page {
                    this.appearance_page.Dispose()
                    this.appearance_page := 0
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
