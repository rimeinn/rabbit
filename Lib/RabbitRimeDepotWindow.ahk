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

#Include RabbitCommon.ahk
#Include RabbitDialogPlacement.ahk
#Include RabbitI18n.ahk
#Include RabbitRimeDepotSettings.ahk
#Include RabbitWindowTheme.ahk
#Include RimeDepot\RimeDepot.ahk

/** Rabbit-owned asynchronous browser for RPPI and direct package installs. */
class RabbitRimeDepotWindow extends Gui {
    static WINDOW_WIDTH := 1040
    ; The former settings editor occupied the first 136 pixels.  Settings
    ; now belong to RabbitSettingsWindow, so keep the browser compact while
    ; retaining enough room for the catalog/details and direct-install forms.
    static RPPI_HEIGHT := 584
    static DIRECT_HEIGHT := 334
    ; Keep the fixed name for callers which used the RPPI window height.
    static WINDOW_HEIGHT := RabbitRimeDepotWindow.RPPI_HEIGHT
    static PBS_MARQUEE := 0x08
    static PBM_SETMARQUEE := 0x040A
    static GWL_STYLE := -16
    static UNCATEGORIZED := "__uncategorized__"

    static CreateForWorkflow(owner, workflow) {
        local settings, service, cache_path, rime_directory, options, sentinel
        if IsObject(owner) && HasMethod(owner, "GetRimeDepotSettings")
            && (settings := owner.GetRimeDepotSettings()) {
        } else {
            settings := workflow.CreateRimeDepotSettings()
        }
        settings := settings is RabbitRimeDepotSettings
            ? RabbitRimeDepotSettings(settings.ToMap())
            : RabbitRimeDepotSettings(settings)
        cache_path := RimeDepotUtil.JoinPath(RabbitUserDataPath(), "depot")
        rime_directory := RabbitUserDataPath()
        options := settings.ToServiceOptions(cache_path, rime_directory)
        sentinel := this.MissingIniPath()
        service := RimeDepotService(options, sentinel)
        return this(
            owner,
            service,
            settings,
            ObjBindMethod(owner, "RefreshSwitcherAfterRimeDepotInstall")
        )
    }

    static MissingIniPath() {
        local path := A_Temp . "\\rabbit-rime-depot-settings-" . DllCall("GetCurrentProcessId") . ".sentinel.ini"
        while FileExist(path) || DirExist(path) {
            path .= ".missing"
        }
        return path
    }

    __New(
        owner,
        service,
        settings := 0,
        install_callback := 0,
        theme_factory := RabbitWindowThemeController
    ) {
        local owner_hwnd := 0, initial_dark_mode := false, factory, gui_options
        if IsObject(owner) && HasProp(owner, "Hwnd") {
            owner_hwnd := owner.Hwnd
        }
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        gui_options := owner_hwnd
            ? "+Owner" . owner_hwnd . " -MinimizeBox -MaximizeBox"
            : "-MinimizeBox -MaximizeBox"
        super.__New(gui_options, RabbitI18n.Text("depot.title"), this)

        this.owner_window := owner
        this.service := service
        ; Rabbit owns persistence for this window.  Never trust an injected
        ; service's Config.IniPath: a caller-provided depot INI would make the
        ; library read settings outside Rabbit's merged configuration.
        this.ini_path := RabbitRimeDepotWindow.MissingIniPath()
        this.settings := settings is RabbitRimeDepotSettings
            ? RabbitRimeDepotSettings(settings.ToMap())
            : RabbitRimeDepotSettings(settings)
        this.install_callback := install_callback
        this.initial_dark_mode := initial_dark_mode
        this.mode := "rppi"
        this.busy := false
        this.active_job := 0
        this.active_kind := ""
        this.operation_token := 0
        this.catalog := 0
        this.catalog_url := ""
        this.active_catalog_url := ""
        this.catalog_entries := []
        this.visible_entries := Map()
        this.category_paths := [""]
        this.category_leaf_counts := Map()
        this.catalog_stale := false
        this.host_busy := false
        this.disposed := false
        this.window_shown := false
        this.initial_load_started := false
        this.initial_load_callback := this.StartInitialLoad.Bind(this)
        this.progress_callback := 0
        this.complete_callback := 0
        this.error_callback := 0

        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )
        this.CreateControls()
        this.ApplyServiceSettings()
        this.SetMode("rppi")
        this.OnEvent("Close", this.OnClose.Bind(this))
        this.OnEvent("Escape", this.OnClose.Bind(this))

        factory := theme_factory
        this.window_theme := factory(this)
        this.window_theme.RegisterMuted(
            this.status_text,
            this.detail_summary,
            this.detail_schemas,
            this.detail_dependencies,
            this.detail_reverse_dependencies,
            this.detail_labels,
            this.detail_license,
            this.detail_recipe
        )
        this.window_theme.Register()
    }

    CreateControls() {
        this.MarginX := 12
        this.MarginY := 12

        this.mode_label := this.AddText("x22 y30 w54 h24 +0x200", RabbitI18n.Text("depot.mode"))
        this.mode_selector := this.AddDropDownList(
            "x78 y26 w170 R2 Choose1",
            [RabbitI18n.Text("depot.mode_rppi"), RabbitI18n.Text("depot.mode_direct")]
        )
        this.search_label := this.AddText("x260 y30 w48 h24 +0x200", RabbitI18n.Text("depot.search"))
        this.search_edit := this.AddEdit("x312 y26 w120 r1 -Multi")
        this.category_label := this.AddText("x440 y30 w58 h24 +0x200", RabbitI18n.Text("depot.category"))
        this.category_filter := this.AddDropDownList(
            "x502 y26 w146 R10 Choose1",
            [RabbitI18n.Text("depot.all_categories")]
        )
        this.load_button := this.AddButton("x654 y26 w70 h28 +0x2000", RabbitI18n.Text("depot.load"))
        this.refresh_button := this.AddButton("x730 y26 w70 h28 +0x2000", RabbitI18n.Text("depot.refresh"))
        this.install_button := this.AddButton("x806 y26 w140 h28 Disabled +0x2000", RabbitI18n.Text("depot.install"))
        this.cancel_button := this.AddButton("x952 y26 w76 h28 Disabled +0x2000", RabbitI18n.Text("depot.cancel"))

        this.catalog_list := this.AddListView(
            "x22 y62 w1006 h220 -Multi Grid",
            [
                RabbitI18n.Text("depot.category"),
                RabbitI18n.Text("depot.scheme"),
                RabbitI18n.Text("depot.schemas"),
                RabbitI18n.Text("depot.repository"),
                RabbitI18n.Text("depot.ref"),
            ]
        )
        this.catalog_list.ModifyCol(1, 166)
        this.catalog_list.ModifyCol(2, 200)
        this.catalog_list.ModifyCol(3, 180)
        this.catalog_list.ModifyCol(4, 300)
        this.catalog_list.ModifyCol(5, 130)
        this.catalog_list.OnEvent("ItemSelect", this.OnCatalogSelection.Bind(this))
        this.catalog_list.OnEvent("DoubleClick", this.InstallSelected.Bind(this))

        this.details_group := this.AddGroupBox(
            "x12 y294 w1016 h220",
            RabbitI18n.Text("depot.details")
        )
        this.detail_title := this.AddText("x28 y320 w990 h24", RabbitI18n.Text("depot.no_selection"))
        this.detail_summary := this.AddText("x28 y348 w990 h42 cGray", "")
        this.detail_schemas := this.AddText(
            "x28 y394 w990 h22",
            RabbitI18n.Text("depot.schemas_value", Map("value", ""))
        )
        this.detail_dependencies := this.AddText(
            "x28 y418 w990 h22",
            RabbitI18n.Text("depot.dependencies_value", Map("value", ""))
        )
        this.detail_reverse_dependencies := this.AddText(
            "x28 y442 w990 h22",
            RabbitI18n.Text("depot.reverse_dependencies_value", Map("value", ""))
        )
        this.detail_labels := this.AddText("x28 y466 w640 h22", RabbitI18n.Text("depot.labels_value", Map("value", "")))
        this.detail_license := this.AddText(
            "x676 y466 w342 h22",
            RabbitI18n.Text("depot.license_value", Map("value", ""))
        )
        this.detail_recipe := this.AddText(
            "x28 y490 w990 h22",
            RabbitI18n.Text("depot.recipe_value", Map("recipe", "", "recipes", ""))
        )

        this.direct_group := this.AddGroupBox(
            "x12 y62 w1016 h220",
            RabbitI18n.Text("depot.direct_source")
        )
        this.direct_source_label := this.AddText("x28 y94 w64 h24 +0x200", RabbitI18n.Text("depot.source"))
        this.direct_source_edit := this.AddEdit("x98 y90 w912 r1 -Multi")
        this.direct_ref_kind_label := this.AddText("x28 y134 w64 h24 +0x200", RabbitI18n.Text("depot.ref_kind"))
        this.direct_ref_kind := this.AddDropDownList(
            "x98 y130 w180 R4 Choose1",
            [
                RabbitI18n.Text("depot.ref_default"),
                RabbitI18n.Text("depot.ref_branch"),
                RabbitI18n.Text("depot.ref_tag"),
                RabbitI18n.Text("depot.ref_commit"),
            ]
        )
        this.direct_ref_label := this.AddText("x298 y134 w40 h24 +0x200", RabbitI18n.Text("depot.ref"))
        this.direct_ref_edit := this.AddEdit("x344 y130 w666 r1 -Multi")
        this.direct_recipe_label := this.AddText("x28 y174 w64 h24 +0x200", RabbitI18n.Text("depot.recipe"))
        this.direct_recipe_edit := this.AddEdit("x98 y170 w912 r1 -Multi")
        this.direct_hint := this.AddText(
            "x28 y208 w982 h42 cGray",
            RabbitI18n.Text("depot.direct_hint")
        )

        this.status_text := this.AddText("x22 y526 w700 h24 cGray", RabbitI18n.Text("depot.ready"))
        this.progress_bar := this.AddProgress("x730 y528 w298 h18", 0)
        this.progress_bar.Value := 0

        this.rppi_controls := [
            this.search_label,
            this.search_edit,
            this.category_label,
            this.category_filter,
            this.load_button,
            this.refresh_button,
            this.catalog_list,
            this.details_group,
            this.detail_title,
            this.detail_summary,
            this.detail_schemas,
            this.detail_dependencies,
            this.detail_reverse_dependencies,
            this.detail_labels,
            this.detail_license,
            this.detail_recipe,
        ]
        this.direct_controls := [
            this.direct_group,
            this.direct_source_label,
            this.direct_source_edit,
            this.direct_ref_kind_label,
            this.direct_ref_kind,
            this.direct_ref_label,
            this.direct_ref_edit,
            this.direct_recipe_label,
            this.direct_recipe_edit,
            this.direct_hint,
        ]

        this.mode_selector.OnEvent("Change", this.OnModeChanged.Bind(this))
        this.search_edit.OnEvent("Change", this.RefreshCatalogView.Bind(this))
        this.category_filter.OnEvent("Change", this.RefreshCatalogView.Bind(this))
        this.direct_source_edit.OnEvent("Change", this.OnDirectInputChanged.Bind(this))
        this.load_button.OnEvent("Click", (*) => this.StartCatalogLoad(false))
        this.refresh_button.OnEvent("Click", (*) => this.StartCatalogLoad(true))
        this.install_button.OnEvent("Click", this.InstallSelected.Bind(this))
        this.cancel_button.OnEvent("Click", this.CancelActiveJob.Bind(this))
    }

    Show(options := "") {
        local show_options := Trim(String(options))
        if !RegExMatch(show_options, "i)(^|[ \\t])w(?:idth)?\\s*[-+]?\\d") {
            show_options .= (show_options = "" ? "" : " ") . "w" . RabbitRimeDepotWindow.WINDOW_WIDTH
        }
        if !RegExMatch(show_options, "i)(^|[ \\t])h(?:eight)?\\s*[-+]?\\d") {
            show_options .= (show_options = "" ? "" : " ") . "h" . this.ModeWindowHeight()
        }
        super.Show(show_options)
        this.window_shown := true
        if !this.initial_load_started {
            this.initial_load_started := true
            SetTimer(this.initial_load_callback, -1)
        }
    }

    ModeWindowHeight() {
        return this.mode = "direct" ? RabbitRimeDepotWindow.DIRECT_HEIGHT : RabbitRimeDepotWindow.RPPI_HEIGHT
    }

    StartInitialLoad(*) {
        if !this.disposed && this.mode = "rppi" {
            this.StartCatalogLoad(false)
        }
    }

    CurrentRppiUrl() {
        return this.settings.rppi_url
    }

    /** Apply a newly accepted Rabbit snapshot without exposing edit controls in this window. */
    SetSettings(settings) {
        local accepted, url_changed, previous
        if this.disposed || this.busy || this.host_busy {
            return false
        }
        accepted := settings is RabbitRimeDepotSettings
            ? RabbitRimeDepotSettings(settings.ToMap())
            : RabbitRimeDepotSettings(settings)
        url_changed := accepted.rppi_url !== this.settings.rppi_url
        previous := this.settings
        this.settings := accepted
        try {
            this.ApplyServiceSettings()
        } catch {
            this.settings := previous
            return false
        }
        if url_changed {
            this.InvalidateCatalog()
        }
        return true
    }

    InvalidateCatalogIfUrlChanged() {
        if this.catalog_url != "" && this.CurrentRppiUrl() !== this.catalog_url {
            this.InvalidateCatalog()
            this.SetStatus(RabbitI18n.Text("depot.catalog_url_changed"), true)
            return true
        }
        if this.catalog_stale {
            this.RestoreCatalogView()
        }
        return false
    }

    HideCatalogForUrlChange() {
        this.catalog_stale := true
        this.visible_entries := Map()
        if HasProp(this, "catalog_list") {
            this.catalog_list.Delete()
        }
        if HasProp(this, "category_filter") {
            this.category_filter.Delete()
            this.category_filter.Add([RabbitI18n.Text("depot.all_categories")])
            this.category_filter.Choose(1)
        }
        if HasProp(this, "detail_title") {
            this.ClearDetails()
        }
        this.UpdateInstallButton()
    }

    RestoreCatalogView() {
        if !this.catalog_stale {
            return false
        }
        this.catalog_stale := false
        this.UpdateCategoryFilter()
        this.RefreshCatalogView()
        return true
    }

    InvalidateCatalog() {
        this.catalog := 0
        this.catalog_url := ""
        this.active_catalog_url := ""
        this.catalog_entries := []
        this.visible_entries := Map()
        this.category_paths := [""]
        this.category_leaf_counts := Map()
        this.catalog_stale := false
        if HasProp(this, "catalog_list") {
            this.catalog_list.Delete()
        }
        if HasProp(this, "category_filter") {
            this.category_filter.Delete()
            this.category_filter.Add([RabbitI18n.Text("depot.all_categories")])
            this.category_filter.Choose(1)
        }
        if HasProp(this, "detail_title") {
            this.ClearDetails()
        }
        this.UpdateInstallButton()
    }

    ApplyServiceSettings() {
        local options, config
        if !IsObject(this.service) {
            return
        }
        options := this.settings.ToServiceOptions(
            RimeDepotUtil.JoinPath(RabbitUserDataPath(), "depot"),
            RabbitUserDataPath()
        )
        ; Keep the sentinel on every reconfiguration as well.  Constructing
        ; directly avoids reopening any INI; the Rabbit adapter owns all
        ; persistence for this window.
        config := RimeDepotConfig(options)
        config.IniPath := this.ini_path
        if HasMethod(this.service, "SetConfig") {
            this.service.SetConfig(config)
        } else if HasMethod(this.service, "Configure") {
            this.service.Configure(config)
        } else if HasProp(this.service, "Config") {
            this.service.Config := config
        } else if HasProp(this.service, "config") {
            this.service.config := config
        }
    }

    OperationOptions(use_git := false) {
        return Map(
            "CachePath", RimeDepotUtil.JoinPath(RabbitUserDataPath(), "depot"),
            "RimeDirectory", RabbitUserDataPath(),
            "RppiIndexUrl", this.settings.rppi_url,
            "Proxy", this.settings.proxy,
            "UseGit", !!use_git,
            "GitPath", this.settings.git_path
        )
    }

    OnModeChanged(ctrl, index := 0, *) {
        local selected := IsNumber(index) && index >= 1 && index <= 2 ? index : ctrl.Value
        return this.SetMode(selected = 2 ? "direct" : "rppi")
    }

    SetMode(mode) {
        local direct := StrLower(String(mode)) = "direct"
        if this.busy || this.host_busy {
            return false
        }
        this.mode := direct ? "direct" : "rppi"
        if this.mode_selector.Value != (direct ? 2 : 1) {
            this.mode_selector.Choose(direct ? 2 : 1)
        }
        for control in this.rppi_controls {
            control.Visible := !direct
        }
        for control in this.direct_controls {
            control.Visible := direct
        }
        this.ApplyModeLayout(direct)
        this.install_button.Text := direct
            ? RabbitI18n.Text("depot.install_direct")
            : RabbitI18n.Text("depot.install")
        this.UpdateInstallButton()
        return true
    }

    ApplyModeLayout(direct) {
        local action_y := 26, status_y := direct ? 298 : 526
        this.install_button.Move(806, action_y, 140, 28)
        this.cancel_button.Move(952, action_y, 76, 28)
        this.status_text.Move(22, status_y, 700, 24)
        this.progress_bar.Move(730, status_y + 2, 298, 18)
        if this.window_shown {
            super.Show(Format("h{}", this.ModeWindowHeight()))
        }
    }

    UpdateInstallButton() {
        if this.busy || this.host_busy {
            this.install_button.Enabled := false
            return
        }
        if this.mode = "direct" {
            this.install_button.Enabled := Trim(this.direct_source_edit.Value) != ""
            return
        }
        if this.catalog_url = "" || this.CurrentRppiUrl() !== this.catalog_url {
            this.install_button.Enabled := false
            return
        }
        this.install_button.Enabled := this.catalog_list.GetNext(0) > 0
    }

    OnDirectInputChanged(*) {
        if this.mode = "direct" && !this.busy && !this.host_busy {
            this.UpdateInstallButton()
        }
    }

    StartCatalogLoad(refresh := false) {
        local token, callbacks, job
        if this.disposed || this.busy || this.host_busy || this.mode != "rppi" {
            return false
        }
        if !IsObject(this.service) {
            this.SetStatus(RabbitI18n.Text("depot.no_service"), true)
            return false
        }
        try {
            this.active_catalog_url := this.settings.rppi_url
            token := ++this.operation_token
            this.active_kind := "catalog"
            this.SetProgressMarquee(true)
            this.progress_bar.Value := 0
            this.SetStatus(refresh ? RabbitI18n.Text("depot.refreshing") : RabbitI18n.Text("depot.loading"))
            callbacks := this.CreateCallbacks(token, "catalog")
            this.SetBusy(true)
            job := refresh
                ? this.service.RefreshCatalog(this.OperationOptions(false), callbacks)
                : this.service.LoadCatalog(this.OperationOptions(false), callbacks)
            if !IsObject(job) {
                throw Error(RabbitI18n.Text("depot.job_missing"))
            }
            if token = this.operation_token && this.busy {
                this.active_job := job
                if HasMethod(job, "IsDone") && job.IsDone() {
                    this.FinishOperation(token)
                }
            }
            return true
        } catch as err {
            this.FinishOperation(token ?? this.operation_token)
            this.SetStatus(
                RabbitI18n.Text("depot.operation_error", Map("reason", err.Message)),
                true
            )
            return false
        }
    }

    CreateCallbacks(token, kind) {
        this.progress_callback := ObjBindMethod(this, "OnProgress", token)
        this.complete_callback := kind = "install"
            ? ObjBindMethod(this, "OnInstallComplete", token)
            : ObjBindMethod(this, "OnCatalogComplete", token)
        this.error_callback := ObjBindMethod(this, "OnOperationError", token)
        return RimeDepotCallbacks(this.progress_callback, this.complete_callback, this.error_callback)
    }

    InstallSelected(*) {
        if this.mode = "direct" {
            return this.InstallDirect()
        }
        local row := this.catalog_list.GetNext(0), entry, token, callbacks, job
        if this.disposed || this.busy || this.host_busy || row < 1 || !this.visible_entries.Has(row) {
            return false
        }
        entry := this.visible_entries[row]
        try {
            if this.catalog_url = "" || this.settings.rppi_url !== this.catalog_url {
                this.InvalidateCatalog()
                this.SetStatus(RabbitI18n.Text("depot.catalog_url_changed"), true)
                return false
            }
            token := ++this.operation_token
            this.active_kind := "install"
            this.SetProgressMarquee(true)
            this.progress_bar.Value := 0
            this.SetStatus(RabbitI18n.Text(
                "depot.installing",
                Map("name", this.EntryText(entry, ["Name", "name"], ""))
            ))
            callbacks := this.CreateCallbacks(token, "install")
            this.SetBusy(true)
            job := this.service.InstallEntry(entry, this.OperationOptions(false), callbacks)
            if !IsObject(job) {
                throw Error(RabbitI18n.Text("depot.job_missing"))
            }
            if token = this.operation_token && this.busy {
                this.active_job := job
                if HasMethod(job, "IsDone") && job.IsDone() {
                    this.FinishOperation(token)
                }
            }
            return true
        } catch as err {
            this.FinishOperation(token ?? this.operation_token)
            this.SetStatus(
                RabbitI18n.Text("depot.operation_error", Map("reason", err.Message)),
                true
            )
            return false
        }
    }

    InstallDirect() {
        local source := Trim(this.direct_source_edit.Value), kind_index, kind, ref, recipe
        local target, token, callbacks, job
        if this.disposed || this.busy || this.host_busy {
            return false
        }
        if source = "" {
            this.SetStatus(RabbitI18n.Text("depot.source_required"), true)
            return false
        }
        kind_index := this.direct_ref_kind.Value
        kind := ["default", "branch", "tag", "sha"][kind_index]
        ref := Trim(this.direct_ref_edit.Value)
        recipe := Trim(this.direct_recipe_edit.Value)
        if kind = "default" && ref != "" {
            this.SetStatus(RabbitI18n.Text("depot.ref_kind_required"), true)
            return false
        }
        if kind != "default" && ref = "" {
            this.SetStatus(RabbitI18n.Text("depot.ref_required"), true)
            return false
        }
        target := Map("repo", source, "ref_kind", kind)
        if ref != "" {
            target["ref"] := ref
        }
        if recipe != "" {
            target["recipe"] := recipe
        }
        try {
            RimeDepotTarget(target)
            token := ++this.operation_token
            this.active_kind := "install"
            this.SetProgressMarquee(true)
            this.progress_bar.Value := 0
            this.SetStatus(RabbitI18n.Text("depot.installing_direct"))
            callbacks := this.CreateCallbacks(token, "install")
            this.SetBusy(true)
            job := this.service.InstallTarget(target, this.OperationOptions(!!this.settings.use_git), callbacks)
            if !IsObject(job) {
                throw Error(RabbitI18n.Text("depot.job_missing"))
            }
            if token = this.operation_token && this.busy {
                this.active_job := job
                if HasMethod(job, "IsDone") && job.IsDone() {
                    this.FinishOperation(token)
                }
            }
            return true
        } catch as err {
            this.FinishOperation(token ?? this.operation_token)
            this.SetStatus(
                RabbitI18n.Text("depot.operation_error", Map("reason", err.Message)),
                true
            )
            return false
        }
    }

    CancelActiveJob(*) {
        local job := this.active_job
        if this.disposed || !this.busy || !IsObject(job) {
            return false
        }
        try {
            if !HasMethod(job, "Cancel") {
                throw Error(RabbitI18n.Text("depot.cancel_unavailable"))
            }
            job.Cancel()
            if this.busy {
                this.SetStatus(RabbitI18n.Text("depot.canceling"))
            }
            return true
        } catch as err {
            this.SetStatus(
                RabbitI18n.Text("depot.cancel_error", Map("reason", err.Message)),
                true
            )
            return false
        }
    }

    OnProgress(token, job, value) {
        local index, total, percent_value, percent, state, phase
        if this.disposed || token != this.operation_token || !this.busy {
            return
        }
        if IsObject(value) {
            index := this.GetValue(value, ["index", "Index"], 0)
            total := this.GetValue(value, ["total", "Total"], 0)
            phase := this.GetValue(value, ["phase", "Phase"], "")
            state := this.ProgressStateText(this.GetValue(value, ["state", "State"], ""), phase)
            if this.active_kind = "install" {
                if total > 0 {
                    this.SetProgressMarquee(false)
                    percent := Min(100, Max(0, Round(index * 100 / total)))
                    this.progress_bar.Value := percent
                    this.SetStatus(RabbitI18n.Text(
                        "depot.progress_install",
                        Map("index", index, "total", total, "state", state)
                    ))
                } else {
                    percent_value := this.GetValue(value, ["percent", "percentage", "progress", "fraction"], "")
                    if percent_value != "" && IsNumber(percent_value) {
                        percent := Number(percent_value)
                        if percent >= 0 && percent <= 1 {
                            percent *= 100
                        }
                        percent := Min(100, Max(0, Round(percent)))
                        this.SetProgressMarquee(false)
                        this.progress_bar.Value := percent
                        this.SetStatus(RabbitI18n.Text(
                            "depot.progress_install_percent",
                            Map("percent", percent, "state", state)
                        ))
                    } else {
                        this.SetProgressMarquee(true)
                        this.SetStatus(RabbitI18n.Text(
                            "depot.progress_install_state",
                            Map("state", state)
                        ))
                    }
                }
            } else if this.active_kind = "catalog" {
                this.SetProgressMarquee(true)
                this.SetStatus(RabbitI18n.Text("depot.progress_catalog"))
            }
        }
    }

    OnCatalogComplete(token, job, value) {
        local entries, loaded_url, warning_count
        if this.disposed || token != this.operation_token {
            return
        }
        loaded_url := this.active_catalog_url
        if loaded_url = "" || loaded_url !== this.CurrentRppiUrl() {
            this.InvalidateCatalog()
            this.SetProgressMarquee(false)
            this.SetStatus(RabbitI18n.Text("depot.catalog_url_changed"), true)
            this.FinishOperation(token)
            return
        }
        this.catalog := value
        this.catalog_url := loaded_url
        entries := value is RimeDepotCatalog
            ? value.ToArray()
            : (value is Array ? value : this.GetValue(value, ["entries", "Entries"], []))
        this.catalog_entries := entries is Array ? entries : []
        warning_count := this.WarningCount(value)
        this.UpdateCategoryFilter()
        this.RefreshCatalogView()
        this.SetProgressMarquee(false)
        this.progress_bar.Value := 100
        this.SetStatus(RabbitI18n.Text(
            "depot.catalog_loaded",
            Map("count", this.catalog_entries.Length, "warnings", warning_count)
        ))
        this.FinishOperation(token)
    }

    OnInstallComplete(token, job, value) {
        local count := 0, changed_count := 0, warning_count := 0, entries := [], changed := [], warnings := []
        local refresh_result := 0, status_key := "depot.install_complete"
        if this.disposed || token != this.operation_token {
            return
        }
        if IsObject(value) {
            entries := this.GetValue(value, ["entries", "Entries"], [])
            changed := this.GetValue(value, ["changed", "Changed"], [])
            warnings := this.GetValue(value, ["warnings", "Warnings"], [])
        }
        count := this.CountValue(entries)
        changed_count := this.CountValue(changed)
        warning_count := this.CountValue(warnings)
        if count > 0 && this.install_callback {
            try {
                refresh_result := this.install_callback.Call() ? 1 : -1
            } catch {
                refresh_result := -1
            }
            status_key := refresh_result > 0
                ? "depot.install_complete_refreshed"
                : "depot.install_complete_refresh_error"
        }
        this.SetProgressMarquee(false)
        this.progress_bar.Value := 100
        this.SetStatus(RabbitI18n.Text(
            status_key,
            Map("count", count, "changed", changed_count, "warnings", warning_count)
        ))
        this.FinishOperation(token)
    }

    ProgressStateText(state, phase := "") {
        local normalized := IsObject(state) ? "" : StrLower(Trim(String(state)))
        phase := IsObject(phase) ? "" : StrLower(Trim(String(phase)))
        switch normalized {
            case "fetching":
                return RabbitI18n.Text("depot.state_fetching")
            case "recipe":
                return RabbitI18n.Text("depot.state_recipe")
            case "staged":
                return RabbitI18n.Text("depot.state_staged")
            case "downloading":
                return RabbitI18n.Text("depot.state_downloading")
            case "loaded":
                return RabbitI18n.Text("depot.state_loaded")
            case "warning":
                return RabbitI18n.Text("depot.state_warning")
            case "clone", "fetch", "checkout", "init", "remote", "submodule":
                return RabbitI18n.Text("depot.state_git")
        }
        if phase = "git" {
            return RabbitI18n.Text("depot.state_git")
        }
        return RabbitI18n.Text("depot.state_generic")
    }

    OnOperationError(token, job, error) {
        local message := IsObject(error) && HasProp(error, "Message") ? error.Message : String(error)
        if this.disposed || token != this.operation_token {
            return
        }
        this.SetProgressMarquee(false)
        if IsObject(job) && HasMethod(job, "IsCancelled") && job.IsCancelled() {
            this.SetStatus(RabbitI18n.Text("depot.canceled"), true)
        } else {
            this.SetStatus(RabbitI18n.Text("depot.operation_error", Map("reason", message)), true)
        }
        this.FinishOperation(token)
    }

    FinishOperation(token) {
        if !token || token != this.operation_token {
            return
        }
        this.active_job := 0
        this.active_kind := ""
        this.SetBusy(false)
    }

    SetBusy(value) {
        this.busy := !!value
        this.UpdateControlState()
        if IsObject(this.owner_window) {
            if HasMethod(this.owner_window, "SetRimeDepotBusy") {
                try this.owner_window.SetRimeDepotBusy(!!value)
            } else if HasMethod(this.owner_window, "UpdateApplyButton") {
                try this.owner_window.UpdateApplyButton()
            }
        }
    }

    SetOwnerBusy(value) {
        this.host_busy := !!value
        if !this.disposed {
            this.UpdateControlState()
        }
    }

    UpdateControlState() {
        local enabled := !this.busy && !this.host_busy
        this.mode_selector.Enabled := enabled
        for control in this.rppi_controls {
            control.Enabled := enabled
        }
        for control in this.direct_controls {
            control.Enabled := enabled
        }
        if enabled {
            this.UpdateInstallButton()
        } else {
            this.install_button.Enabled := false
        }
        ; An active child job must remain cancellable even when its owner is
        ; running another synchronous settings operation.
        this.cancel_button.Enabled := !!this.busy
    }

    SetStatus(value, error := false) {
        this.status_text.Value := value
        this.status_text.Opt(error ? "cRed" : "cGray")
    }

    SetProgressMarquee(enabled) {
        local hwnd := this.progress_bar.Hwnd, style
        if !hwnd {
            return false
        }
        style := this.GetProgressStyle(hwnd)
        if enabled {
            if !(style & RabbitRimeDepotWindow.PBS_MARQUEE) {
                this.SetProgressStyle(hwnd, style | RabbitRimeDepotWindow.PBS_MARQUEE)
            }
            DllCall(
                "SendMessageW",
                "Ptr", hwnd,
                "UInt", RabbitRimeDepotWindow.PBM_SETMARQUEE,
                "Ptr", 1,
                "Ptr", 30,
                "Ptr"
            )
        } else {
            DllCall(
                "SendMessageW",
                "Ptr", hwnd,
                "UInt", RabbitRimeDepotWindow.PBM_SETMARQUEE,
                "Ptr", 0,
                "Ptr", 0,
                "Ptr"
            )
            if style & RabbitRimeDepotWindow.PBS_MARQUEE {
                this.SetProgressStyle(hwnd, style & ~RabbitRimeDepotWindow.PBS_MARQUEE)
            }
        }
        return true
    }

    GetProgressStyle(hwnd) {
        if A_PtrSize = 8 {
            return DllCall("GetWindowLongPtrW", "Ptr", hwnd, "Int", RabbitRimeDepotWindow.GWL_STYLE, "Ptr")
        }
        return DllCall("GetWindowLongW", "Ptr", hwnd, "Int", RabbitRimeDepotWindow.GWL_STYLE, "Int")
    }

    SetProgressStyle(hwnd, style) {
        if A_PtrSize = 8 {
            DllCall("SetWindowLongPtrW", "Ptr", hwnd, "Int", RabbitRimeDepotWindow.GWL_STYLE, "Ptr", style, "Ptr")
        } else {
            DllCall("SetWindowLongW", "Ptr", hwnd, "Int", RabbitRimeDepotWindow.GWL_STYLE, "Int", style, "Int")
        }
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x27)
    }

    UpdateCategoryFilter() {
        local selected := this.SelectedCategoryPath()
        local paths, category_tree, category_node, category_child
        local category, parts, part, path, index, entry, selected_index := 1, leaf_counts := Map()
        category_tree := Map("path", "", "children", Map(), "order", [])
        for entry in this.catalog_entries {
            category := this.CategoryPathForEntry(entry)
            parts := category = RabbitRimeDepotWindow.UNCATEGORIZED
                ? [RabbitRimeDepotWindow.UNCATEGORIZED]
                : StrSplit(category, " / ")
            category_node := category_tree
            for _, part in parts {
                if part = "" {
                    continue
                }
                if !category_node["children"].Has(part) {
                    path := category_node["path"] = ""
                        ? part
                        : category_node["path"] . " / " . part
                    category_child := Map("path", path, "children", Map(), "order", [])
                    category_node["children"][part] := category_child
                    category_node["order"].Push(part)
                }
                category_node := category_node["children"][part]
            }
        }
        paths := [""]
        this.AppendCategoryTreePreorder(category_tree, paths)
        this.category_paths := paths
        for index, path in paths {
            if index > 1 {
                category := this.CategoryLeafName(path)
                leaf_counts[category] := leaf_counts.Has(category) ? leaf_counts[category] + 1 : 1
            }
        }
        this.category_leaf_counts := leaf_counts
        values := [RabbitI18n.Text("depot.all_categories")]
        for index, path in paths {
            if index > 1 {
                values.Push(this.CategoryDisplayText(path, leaf_counts))
            }
        }
        this.category_filter.Delete()
        this.category_filter.Add(values)
        if selected != "" {
            for index, path in paths {
                if path = selected {
                    selected_index := index
                    break
                }
            }
        }
        this.category_filter.Choose(selected_index)
    }

    AppendCategoryTreePreorder(root, paths) {
        local stack := [Map("node", root, "index", 1)]
        local frame, node, child_name, child
        while stack.Length {
            frame := stack[stack.Length]
            node := frame["node"]
            if frame["index"] > node["order"].Length {
                stack.Pop()
                continue
            }
            child_name := node["order"][frame["index"]]
            frame["index"] += 1
            child := node["children"][child_name]
            paths.Push(child["path"])
            stack.Push(Map("node", child, "index", 1))
        }
    }

    CategoryPathForEntry(entry) {
        local path := Trim(this.EntryText(entry, ["CategoryPath", "category_path", "Category", "category"], ""))
        local parts, canonical := "", part
        if path = "" {
            return RabbitRimeDepotWindow.UNCATEGORIZED
        }
        parts := StrSplit(path, " / ")
        for _, part in parts {
            part := Trim(part)
            if part != "" {
                canonical := canonical = "" ? part : canonical . " / " . part
            }
        }
        return canonical = "" ? RabbitRimeDepotWindow.UNCATEGORIZED : canonical
    }

    CategoryLeafName(path) {
        local parts := StrSplit(path, " / ")
        return parts[parts.Length]
    }

    CategoryParentPath(path) {
        local parts := StrSplit(path, " / "), parent := "", index
        if parts.Length <= 1 {
            return ""
        }
        Loop parts.Length - 1 {
            index := A_Index
            parent := parent = "" ? parts[index] : parent . " / " . parts[index]
        }
        return parent
    }

    CategoryDisplayText(path, leaf_counts := 0) {
        local parts, leaf, indent := "", suffix
        if path = RabbitRimeDepotWindow.UNCATEGORIZED {
            return RabbitI18n.Text("depot.uncategorized")
        }
        parts := StrSplit(path, " / ")
        leaf := parts[parts.Length]
        Loop parts.Length - 1 {
            indent .= "    "
        }
        if IsObject(leaf_counts) && leaf_counts.Has(leaf) && leaf_counts[leaf] > 1 {
            suffix := this.CategoryParentPath(path)
            leaf .= " (" . (suffix != "" ? suffix : RabbitI18n.Text("depot.top_level")) . ")"
        }
        return indent . leaf
    }

    SelectedCategoryPath() {
        local index := this.category_filter.Value
        return index >= 1 && index <= this.category_paths.Length ? this.category_paths[index] : ""
    }

    RefreshCatalogView(*) {
        if this.catalog_stale {
            this.catalog_list.Delete()
            this.visible_entries := Map()
            this.ClearDetails()
            this.UpdateInstallButton()
            return
        }
        local query := StrLower(Trim(this.search_edit.Value)), category := this.SelectedCategoryPath()
        local entry, row, entry_category, name, repo, schemas, ref, search_text
        this.catalog_list.Delete()
        this.visible_entries := Map()
        for entry in this.catalog_entries {
            entry_category := this.CategoryPathForEntry(entry)
            if category = RabbitRimeDepotWindow.UNCATEGORIZED {
                if entry_category != RabbitRimeDepotWindow.UNCATEGORIZED {
                    continue
                }
            } else if category != "" && entry_category != category
                && SubStr(entry_category, 1, StrLen(category) + 3) != category . " / " {
                continue
            }
            name := this.EntryText(entry, ["Name", "name", "Id", "id"], "")
            repo := this.EntryText(entry, ["Repo", "repo", "Repository", "repository"], "")
            schemas := this.JoinValue(this.EntryValue(entry, ["Schemas", "schemas"], []))
            ref := this.EntryText(entry, ["Ref", "ref", "Branch", "branch", "Tag", "tag", "Sha", "sha"], "")
            search_text := StrLower(name . " " . entry_category . " " . repo . " " . schemas . " "
                . this.EntryText(entry, ["Description", "description"], ""))
            if query != "" && !InStr(search_text, query) {
                continue
            }
            row := this.catalog_list.Add(
                "",
                entry_category = RabbitRimeDepotWindow.UNCATEGORIZED
                    ? RabbitI18n.Text("depot.uncategorized")
                    : entry_category,
                name,
                schemas,
                repo,
                ref
            )
            this.visible_entries[row] := entry
        }
        this.ClearDetails()
        this.UpdateInstallButton()
    }

    OnCatalogSelection(ctrl, row, selected) {
        local current_row := ctrl.GetNext(0)
        if current_row > 0 && this.visible_entries.Has(current_row) {
            this.ShowDetails(this.visible_entries[current_row])
        } else {
            this.ClearDetails()
        }
        this.UpdateInstallButton()
    }

    ShowDetails(entry) {
        local name := this.EntryText(entry, ["Name", "name", "Id", "id"], RabbitI18n.Text("depot.no_selection"))
        local description := this.EntryText(entry, ["Description", "description", "Summary", "summary"], "")
        local repo := this.EntryText(entry, ["Repo", "repo", "Repository", "repository"], "")
        local ref := this.EntryText(entry, ["Ref", "ref", "Branch", "branch", "Tag", "tag", "Sha", "sha"], "")
        local recipe := this.EntryValue(entry, ["Recipe", "recipe"], "")
        local recipes := this.EntryValue(entry, ["Recipes", "recipes"], "")
        this.detail_title.Value := name
        this.detail_summary.Value := RabbitI18n.Text(
            "depot.summary_value",
            Map("description", description, "repository", repo, "ref", ref)
        )
        this.detail_schemas.Value := RabbitI18n.Text(
            "depot.schemas_value",
            Map("value", this.JoinValue(this.EntryValue(entry, ["Schemas", "schemas"], [])))
        )
        this.detail_dependencies.Value := RabbitI18n.Text(
            "depot.dependencies_value",
            Map("value", this.JoinDependencies(this.EntryValue(entry, ["Dependencies", "dependencies"], [])))
        )
        this.detail_reverse_dependencies.Value := RabbitI18n.Text(
            "depot.reverse_dependencies_value",
            Map("value", this.JoinDependencies(
                this.EntryValue(entry, ["ReverseDependencies", "reverse_dependencies"], [])
            ))
        )
        this.detail_labels.Value := RabbitI18n.Text(
            "depot.labels_value",
            Map("value", this.JoinValue(this.EntryValue(entry, ["Labels", "labels"], [])))
        )
        this.detail_license.Value := RabbitI18n.Text(
            "depot.license_value",
            Map("value", this.EntryText(entry, ["License", "license"], ""))
        )
        this.detail_recipe.Value := RabbitI18n.Text(
            "depot.recipe_value",
            Map(
                "recipe", this.FormatDetailValue(recipe),
                "recipes", this.FormatDetailValue(recipes)
            )
        )
    }

    ClearDetails() {
        this.detail_title.Value := RabbitI18n.Text("depot.no_selection")
        this.detail_summary.Value := ""
        this.detail_schemas.Value := RabbitI18n.Text("depot.schemas_value", Map("value", ""))
        this.detail_dependencies.Value := RabbitI18n.Text("depot.dependencies_value", Map("value", ""))
        this.detail_reverse_dependencies.Value := RabbitI18n.Text("depot.reverse_dependencies_value", Map("value", ""))
        this.detail_labels.Value := RabbitI18n.Text("depot.labels_value", Map("value", ""))
        this.detail_license.Value := RabbitI18n.Text("depot.license_value", Map("value", ""))
        this.detail_recipe.Value := RabbitI18n.Text("depot.recipe_value", Map("recipe", "", "recipes", ""))
    }

    EntryValue(entry, keys, fallback := "") {
        local key
        for key in keys {
            if entry is Map {
                if entry.Has(key) {
                    return entry[key]
                }
            } else if HasProp(entry, key) {
                return entry.%key%
            }
        }
        return fallback
    }

    EntryText(entry, keys, fallback := "") {
        local value := this.EntryValue(entry, keys, fallback)
        return IsObject(value) ? fallback : String(value)
    }

    JoinValue(value) {
        local result := "", item
        if !IsObject(value) {
            return String(value)
        }
        for item in value {
            result .= (result = "" ? "" : ", ") . this.FormatDetailValue(item)
        }
        return result
    }

    JoinDependencies(value) {
        local result := "", item, dependency
        if !IsObject(value) {
            return String(value)
        }
        for item in value {
            dependency := RimeDepotCatalog.DependencyValue(item)
            if dependency = "" {
                dependency := this.FormatDetailValue(item)
            }
            result .= (result = "" ? "" : ", ") . dependency
        }
        return result
    }

    FormatDetailValue(value, depth := 0) {
        local result := "", key, item, separator := ""
        if !IsObject(value) {
            return String(value)
        }
        if depth >= 3 {
            return Type(value)
        }
        if value is Array {
            for item in value {
                result .= separator . this.FormatDetailValue(item, depth + 1)
                separator := ", "
            }
            return result
        }
        if value is Map {
            for key, item in value {
                result .= separator . String(key) . "=" . this.FormatDetailValue(item, depth + 1)
                separator := ", "
            }
            return result
        }
        if value is RimeDepotRecipe {
            return this.FormatDetailValue(Map(
                "name", value.Name,
                "rx", value.Rx,
                "description", value.Description
            ), depth + 1)
        }
        if HasProp(value, "Name") && value.Name != "" {
            return String(value.Name)
        }
        return Type(value)
    }

    JoinValues(values, separator) {
        local result := "", value
        for value in values {
            result .= (result = "" ? "" : separator) . String(value)
        }
        return result
    }

    GetValue(value, keys, fallback := "") {
        local key
        if !IsObject(value) {
            return fallback
        }
        for key in keys {
            if value is Map {
                if value.Has(key) {
                    return value[key]
                }
            } else if HasProp(value, key) {
                return value.%key%
            }
        }
        return fallback
    }

    CountValue(value) {
        if value is Array {
            return value.Length
        }
        if value is Map {
            return value.Count
        }
        if !IsObject(value) {
            return value = "" ? 0 : 1
        }
        try {
            return value.Length
        } catch {
            return 1
        }
    }

    WarningCount(value) {
        return this.CountValue(this.GetValue(value, ["Warnings", "warnings"], []))
    }

    IsBusy() {
        return this.busy
    }

    OnClose(*) {
        this.Dispose()
        return true
    }

    Dispose() {
        local job := this.active_job, callback, owner := this.owner_window
        if this.disposed {
            return
        }
        this.disposed := true
        this.operation_token += 1
        SetTimer(this.initial_load_callback, 0)
        if IsObject(job) && HasMethod(job, "Cancel") {
            try job.Cancel()
        }
        this.active_job := 0
        this.busy := false
        if IsObject(owner) {
            if HasMethod(owner, "SetRimeDepotBusy") {
                try owner.SetRimeDepotBusy(false)
            } else if HasMethod(owner, "UpdateApplyButton") {
                try owner.UpdateApplyButton()
            }
        }
        callback := this.window_theme
        this.window_theme := 0
        if callback {
            try callback.Dispose()
        }
        this.progress_callback := 0
        this.complete_callback := 0
        this.error_callback := 0
        try this.Destroy()
    }
}
