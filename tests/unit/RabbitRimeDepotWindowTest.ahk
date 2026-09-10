/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitRimeDepotWindow.ahk

try {
    RabbitRimeDepotWindowTestMain()
} catch as err {
    TestReportFailure("unhandled test error", err)
    ExitApp(1)
}

RabbitRimeDepotWindowTestMain() {
    RunTest("Rabbit Depot consumes fixed paths and an accepted snapshot", RabbitRimeDepotWindowConstructionTest.Bind())
    RunTest("Rabbit Depot reconfigures and invalidates only on URL changes", RabbitRimeDepotWindowSettingsTest.Bind())
    RunTest("Rabbit Depot treats case-only RPPI URL changes as stale", RabbitRimeDepotWindowCaseSensitiveUrlTest.Bind())
    RunTest("Rabbit Depot rejects reconfiguration while busy", RabbitRimeDepotWindowBusySettingsTest.Bind())
    RunTest("Rabbit Depot loads catalog and filters hierarchy", RabbitRimeDepotWindowCatalogTest.Bind())
    RunTest("Rabbit Depot forwards six direct-install options", RabbitRimeDepotWindowDirectTest.Bind())
    RunTest("Rabbit Depot forces archive installs away from Git", RabbitRimeDepotWindowRppiInstallTest.Bind())
    RunTest("Rabbit Depot cancels and ignores stale callbacks", RabbitRimeDepotWindowLifecycleTest.Bind())
    RunTest("Rabbit Depot uses compact mode geometry", RabbitRimeDepotWindowGeometryTest.Bind())
    RunTest("Rabbit Depot opens with the real dark theme controller", RabbitRimeDepotWindowDarkThemeTest.Bind())
    ExitApp(0)
}

RabbitRimeDepotWindowConstructionTest() {
    local workflow := RabbitRimeDepotWindowWorkflowProbe()
    local owner := RabbitRimeDepotWindowOwnerProbe()
    local window := RabbitRimeDepotWindow.CreateForWorkflow(owner, workflow)
    local expected_cache := RimeDepotUtil.JoinPath(RabbitUserDataPath(), "depot")
    local expected_ini, injected_service, injected_window
    try {
        expected_ini := window.service.Config.IniPath
        AssertEqual(expected_cache, window.service.Config.CachePath,
            "The Rabbit-owned cache path was not forwarded to RimeDepot.")
        AssertEqual(RabbitUserDataPath(), window.service.Config.RimeDirectory,
            "The authoritative Rabbit user directory was not forwarded to RimeDepot.")
        AssertEqual("https://example.invalid/index.json", window.service.Config.RppiIndexUrl,
            "The accepted RPPI URL was not forwarded to the service config.")
        AssertEqual("http://proxy.invalid:8080", window.service.Config.Proxy,
            "The accepted proxy was not forwarded to the service config.")
        AssertTrue(window.service.Config.UseGit && window.service.Config.GitPath = "C:\\Tools\\git.exe",
            "The accepted Git settings were not forwarded to the service config.")
        AssertTrue(expected_ini != "" && !FileExist(expected_ini) && !DirExist(expected_ini),
            "The service did not receive a non-existent sentinel INI path.")
        AssertTrue(!HasProp(window, "settings_group") && !HasProp(window, "rppi_url_edit")
            && !HasProp(window, "proxy_edit") && !HasProp(window, "use_git_checkbox")
            && !HasProp(window, "git_path_edit") && !HasProp(window, "git_path_browse_button")
            && !HasProp(window, "save_settings_button") && !HasProp(window, "save_callback")
            && !HasProp(window, "deploy_callback") && !HasMethod(window, "SaveSettings"),
            "The child still exposes removed downloader settings or save callbacks.")

        injected_service := RabbitRimeDepotWindowFakeService()
        injected_window := RabbitRimeDepotWindow(0, injected_service, RabbitRimeDepotSettings())
        AssertTrue(injected_window.ini_path != injected_service.InjectedIniPath,
            "The window trusted an injected service Config.IniPath instead of using its Rabbit sentinel: "
                . injected_window.ini_path . " / " . injected_service.InjectedIniPath)
    } finally {
        if injected_window {
            injected_window.Dispose()
        }
        window.Dispose()
    }
}

RabbitRimeDepotWindowSettingsTest() {
    local service := RabbitRimeDepotWindowFakeService()
    local old_settings := RabbitRimeDepotSettings(Map(
        "rppi_url", "https://example.invalid/old-index.json",
        "proxy", "http://proxy.invalid:8080"
    ))
    local window := RabbitRimeDepotWindow(0, service, old_settings, 0, RabbitRimeDepotWindowTestTheme)
    local job, new_settings
    try {
        AssertTrue(window.StartCatalogLoad(false), "The baseline catalog job did not start.")
        job := service.last_job
        job.DeliverCatalog()
        AssertEqual(5, window.catalog_entries.Length, "The baseline catalog did not load.")

        new_settings := RabbitRimeDepotSettings(Map(
            "rppi_url", "https://example.invalid/new-index.json",
            "proxy", "http://proxy.invalid:3128",
            "use_git", true,
            "git_path", "C:\\Tools\\git.exe"
        ))
        AssertTrue(window.SetSettings(new_settings), "The accepted settings snapshot was not applied.")
        AssertEqual(new_settings.rppi_url, window.settings.rppi_url,
            "SetSettings did not replace the accepted snapshot.")
        AssertEqual(new_settings.rppi_url, service.config.RppiIndexUrl,
            "SetSettings did not reconfigure the service URL.")
        AssertTrue(window.catalog_url = "" && window.catalog_entries.Length = 0
            && window.catalog_list.GetCount() = 0,
            "Changing RPPI URL did not invalidate the old catalog generation.")

        AssertTrue(window.StartCatalogLoad(false), "The catalog could not reload for the accepted URL.")
        job := service.last_job
        job.DeliverCatalog()
        AssertEqual(5, window.catalog_list.GetCount(), "The reloaded catalog was not displayed.")
        new_settings.proxy := "http://proxy.invalid:9999"
        AssertTrue(window.SetSettings(new_settings), "A non-URL settings update was rejected.")
        AssertEqual(5, window.catalog_list.GetCount(),
            "Changing proxy/Git settings invalidated a catalog whose URL stayed unchanged.")
    } finally {
        window.Dispose()
    }
}

RabbitRimeDepotWindowCaseSensitiveUrlTest() {
    local service := RabbitRimeDepotWindowFakeService()
    local window := RabbitRimeDepotWindow(
        0,
        service,
        RabbitRimeDepotSettings(Map("rppi_url", "https://example.invalid/index.json")),
        0,
        RabbitRimeDepotWindowTestTheme
    )
    local job, replacement
    try {
        AssertTrue(window.StartCatalogLoad(false), "The baseline catalog job did not start.")
        job := service.last_job
        job.DeliverCatalog()
        replacement := RabbitRimeDepotSettings(Map(
            "rppi_url", "https://example.invalid/INDEX.json"
        ))
        AssertTrue(window.SetSettings(replacement), "The case-only RPPI URL update was rejected.")
        AssertTrue(window.catalog_url = "" && window.catalog_entries.Length = 0
            && window.catalog_list.GetCount() = 0,
            "A case-only RPPI URL change did not invalidate the catalog generation.")
    } finally {
        window.Dispose()
    }
}

RabbitRimeDepotWindowBusySettingsTest() {
    local service := RabbitRimeDepotWindowFakeService()
    local window := RabbitRimeDepotWindow(
        0,
        service,
        RabbitRimeDepotSettings(Map("rppi_url", "https://example.invalid/old-index.json")),
        0,
        RabbitRimeDepotWindowTestTheme
    )
    local replacement := RabbitRimeDepotSettings(Map("rppi_url", "https://example.invalid/new-index.json"))
    try {
        window.SetOwnerBusy(true)
        AssertTrue(!window.SetSettings(replacement) && window.settings.rppi_url != replacement.rppi_url,
            "SetSettings bypassed the parent busy lock.")
        window.SetOwnerBusy(false)
        window.SetBusy(true)
        AssertTrue(!window.SetSettings(replacement) && window.settings.rppi_url != replacement.rppi_url,
            "SetSettings bypassed the active child-job lock.")
        window.SetBusy(false)
        AssertTrue(window.SetSettings(replacement), "SetSettings did not recover after the locks cleared.")
    } finally {
        window.Dispose()
    }
}

RabbitRimeDepotWindowCatalogTest() {
    local service := RabbitRimeDepotWindowFakeService()
    local window := RabbitRimeDepotWindow(
        0,
        service,
        RabbitRimeDepotSettings(Map("rppi_url", "https://example.invalid/index.json")),
        0,
        RabbitRimeDepotWindowTestTheme
    )
    local job, paths
    try {
        AssertTrue(window.StartCatalogLoad(false), "The catalog job did not start.")
        AssertTrue(window.busy, "The window did not lock controls during catalog loading.")
        job := service.last_job
        job.DeliverCatalog()
        AssertTrue(!window.busy, "The window stayed busy after catalog completion.")
        AssertEqual(5, window.catalog_entries.Length, "The catalog result count was not displayed.")
        AssertTrue(InStr(window.status_text.Value, "1") > 0,
            "The catalog warning count was not included in the completion status.")
        AssertEqual(RabbitI18n.Text("depot.state_fetching"), window.ProgressStateText("fetching"),
            "A known progress state was not localized.")
        AssertEqual(RabbitI18n.Text("depot.state_generic"), window.ProgressStateText("unknown-state"),
            "An unknown progress state did not use the localized generic status.")
        paths := RabbitRimeDepotWindowJoin(window.category_paths, "|")
        AssertEqual(
            "Packages|Packages / Chinese|Packages / Japanese|Standalone|"
                . RabbitRimeDepotWindow.UNCATEGORIZED . "|Other|Other / Chinese",
            paths,
            "The category filter did not keep parent and child categories contiguous in source order."
        )
        window.category_filter.Choose(RabbitRimeDepotWindowCategoryIndex(window, "Packages / Chinese"))
        local first_chinese := window.category_filter.Text
        window.category_filter.Choose(RabbitRimeDepotWindowCategoryIndex(window, "Other / Chinese"))
        local other_chinese := window.category_filter.Text
        AssertTrue(first_chinese != other_chinese && InStr(first_chinese, "Packages")
            && InStr(other_chinese, "Other"),
            "Duplicate category leaves were not disambiguated by their parent paths.")

        window.category_filter.Choose(RabbitRimeDepotWindowCategoryIndex(window, "Packages"))
        window.RefreshCatalogView()
        AssertEqual(2, window.catalog_list.GetCount(),
            "Selecting a parent category did not include its child entries.")
        window.search_edit.Value := "japanese"
        window.RefreshCatalogView()
        AssertEqual(1, window.catalog_list.GetCount(), "Catalog search did not narrow the visible entries.")
        window.ShowDetails(window.catalog_entries[2])
        AssertTrue(InStr(window.detail_schemas.Value, "japanese.schema")
            && InStr(window.detail_dependencies.Value, "base"),
            "Scheme details omitted schemas or dependencies.")
        AssertTrue(InStr(window.detail_recipe.Value, "recipes") || InStr(window.detail_recipe.Value, "fluent"),
            "Scheme details omitted object-valued Recipe or Recipes metadata.")
    } finally {
        window.Dispose()
    }
}

RabbitRimeDepotWindowDirectTest() {
    local service := RabbitRimeDepotWindowFakeService()
    local owner := RabbitRimeDepotWindowOwnerProbe()
    local settings := RabbitRimeDepotSettings(Map(
        "rppi_url", "https://example.invalid/index.json",
        "proxy", "http://proxy.invalid:3128",
        "use_git", true,
        "git_path", "C:\\Tools\\git.exe"
    ))
    local window := RabbitRimeDepotWindow(
        owner,
        service,
        settings,
        ObjBindMethod(owner, "RefreshSwitcherAfterRimeDepotInstall"),
        RabbitRimeDepotWindowTestTheme
    )
    local call, target, options, job
    try {
        AssertTrue(window.SetMode("direct"), "The window did not switch to direct mode.")
        window.direct_source_edit.Value := "https://github.com/example/direct"
        window.direct_ref_kind.Choose(2)
        window.direct_ref_edit.Value := "feature/rppi"
        window.direct_recipe_edit.Value := "custom"
        AssertTrue(window.InstallSelected(), "The direct install job did not start.")
        call := service.calls[service.calls.Length]
        target := call["target"]
        options := call["options"]
        AssertTrue(target is Map && target["repo"] = "https://github.com/example/direct"
            && target["ref_kind"] = "branch" && target["ref"] = "feature/rppi"
            && target["recipe"] = "custom",
            "The direct install did not pass a structured target.")
        AssertTrue(options.Count = 6 && options["UseGit"] && options["Proxy"] = "http://proxy.invalid:3128"
            && options["GitPath"] = "C:\\Tools\\git.exe"
            && options["RppiIndexUrl"] = "https://example.invalid/index.json"
            && options["CachePath"] = RimeDepotUtil.JoinPath(RabbitUserDataPath(), "depot")
            && options["RimeDirectory"] = RabbitUserDataPath(),
            "The direct install did not forward the complete six-option map.")
        job := service.last_job
        job.callbacks.ReportProgress(job, Map("phase", "recipe", "state", "downloading"))
        AssertTrue(RabbitRimeDepotWindowProgressHasMarquee(window.progress_bar)
            && InStr(window.status_text.Value, RabbitI18n.Text("depot.state_downloading")),
            "An indeterminate recipe stage did not use marquee progress and localized status.")
        job.callbacks.ReportProgress(job, Map("phase", "git", "state", "clone", "fraction", 0.25))
        AssertTrue(!RabbitRimeDepotWindowProgressHasMarquee(window.progress_bar)
            && window.progress_bar.Value = 25
            && InStr(window.status_text.Value, RabbitI18n.Text("depot.state_git")),
            "A numeric Git progress update did not switch to localized determinate progress.")
        job.DeliverInstall()
        AssertTrue(!window.busy && owner.refresh_count = 1,
            "The direct install did not refresh the scheme list exactly once after completion.")
    } finally {
        window.Dispose()
    }
}

RabbitRimeDepotWindowRppiInstallTest() {
    local service := RabbitRimeDepotWindowFakeService()
    local owner := RabbitRimeDepotWindowOwnerProbe()
    local window := RabbitRimeDepotWindow(
        owner,
        service,
        RabbitRimeDepotSettings(Map("use_git", true, "proxy", "http://proxy.invalid:8080")),
        ObjBindMethod(owner, "RefreshSwitcherAfterRimeDepotInstall"),
        RabbitRimeDepotWindowTestTheme
    )
    local job, call
    try {
        window.catalog_entries := [{ name: "Archive scheme", repo: "owner/archive", schemas: ["archive.schema"] }]
        window.catalog_url := window.settings.rppi_url
        window.UpdateCategoryFilter()
        window.RefreshCatalogView()
        window.catalog_list.Modify(1, "Select")
        AssertTrue(window.InstallSelected(), "The RPPI install job did not start.")
        call := service.calls[service.calls.Length]
        AssertEqual("entry", call["kind"], "RPPI mode called direct install.")
        AssertTrue(call["options"].Count = 6 && !call["options"]["UseGit"]
            && call["options"]["Proxy"] = "http://proxy.invalid:8080",
            "RPPI mode did not force archive install while forwarding all options.")
        job := service.last_job
        job.DeliverInstall()
        AssertTrue(owner.refresh_count = 1 && !owner.busy,
            "Successful install did not refresh the scheme list once and restore the owner.")
        AssertTrue(!HasProp(window, "needs_deploy")
            && window.status_text.Value = RabbitI18n.Text(
                "depot.install_complete_refreshed",
                Map("count", 2, "changed", 2, "warnings", 1)
            ),
            "Install completion retained a deployment requirement or omitted the refresh result.")

        window.catalog_list.Modify(1, "Select")
        AssertTrue(window.InstallSelected(), "The empty-result install job did not start.")
        job := service.last_job
        job.DeliverEmptyInstall()
        AssertEqual(1, owner.refresh_count,
            "An install result with no installed packages refreshed the scheme list.")
    } finally {
        window.Dispose()
    }
}

RabbitRimeDepotWindowLifecycleTest() {
    local service := RabbitRimeDepotWindowFakeService()
    local owner := RabbitRimeDepotWindowOwnerProbe()
    local window := RabbitRimeDepotWindow(owner, service, 0, 0, RabbitRimeDepotWindowTestTheme)
    local job, stale_callback
    try {
        window.SetOwnerBusy(true)
        AssertTrue(window.host_busy && !window.mode_selector.Enabled
            && !window.StartCatalogLoad(false) && !window.SetMode("direct"),
            "The parent operation lock did not block child loading and mode changes.")
        window.SetOwnerBusy(false)
        AssertTrue(!window.host_busy && window.mode_selector.Enabled,
            "The child controls did not recover after the parent operation lock ended.")
        AssertTrue(window.StartCatalogLoad(false), "The lifecycle catalog job did not start.")
        AssertTrue(owner.busy, "The parent owner was not locked while the child job was active.")
        job := service.last_job
        stale_callback := job.callbacks
        window.Dispose()
        AssertTrue(job.cancelled && window.disposed && !owner.busy,
            "Closing the window did not cancel its active job or restore the parent owner.")
        stale_callback.ReportComplete(job, [])
        stale_callback.ReportProgress(job, Map("phase", "catalog", "state", "late"))
        AssertTrue(window.disposed, "A stale callback revived the disposed window.")
    } finally {
        window.Dispose()
    }
}

RabbitRimeDepotWindowGeometryTest() {
    local window := RabbitRimeDepotWindow(
        0,
        RabbitRimeDepotWindowFakeService(),
        0,
        0,
        RabbitRimeDepotWindowTestTheme
    )
    local x, y, width, height, direct_height, rppi_height
    local mode_closed_height, category_closed_height, ref_closed_height
    local mode_popup_height, category_popup_height, ref_popup_height
    try {
        window.initial_load_started := true
        window.Show("Hide")
        window.GetClientPos(&x, &y, &width, &rppi_height)
        window.mode_selector.GetPos(&x, &y, &width, &mode_closed_height)
        window.category_filter.GetPos(&x, &y, &width, &category_closed_height)
        mode_popup_height := RabbitRimeDepotWindowDropdownHeight(window.mode_selector)
        category_popup_height := RabbitRimeDepotWindowDropdownHeight(window.category_filter)
        AssertTrue(mode_popup_height > mode_closed_height && category_popup_height > mode_popup_height,
            "Mode/category drop-down heights did not reflect their R2/R10 row settings.")
        window.install_button.GetPos(&x, &y, &width, &height)
        AssertTrue(y = 26 && width >= 140,
            "The localized RPPI install button is too narrow for a single-line label.")

        AssertTrue(window.SetMode("direct"), "The geometry test could not enter Direct mode.")
        window.GetClientPos(&x, &y, &width, &direct_height)
        AssertTrue(direct_height < rppi_height && direct_height <= 350,
            "Direct mode did not compact the package window.")
        window.direct_ref_kind.GetPos(&x, &y, &width, &ref_closed_height)
        ref_popup_height := RabbitRimeDepotWindowDropdownHeight(window.direct_ref_kind)
        AssertTrue(ref_popup_height > mode_popup_height && ref_popup_height > ref_closed_height,
            "The Direct ref-kind drop-down height did not reflect its R4 row setting.")
        window.direct_source_edit.GetPos(&x, &y, &width, &height)
        AssertTrue(y >= 90, "The Direct source field overlaps its group title.")
        window.install_button.GetPos(&x, &y, &width, &height)
        AssertTrue(y = 26 && width >= 140,
            "The localized Direct install button overlaps the source group content or is too narrow.")
        window.status_text.GetPos(&x, &y, &width, &height)
        AssertEqual(298, y, "The Direct status is not directly below the source group.")

        window.SetMode("rppi")
        window.details_group.GetPos(&x, &y, &width, &height)
        local details_bottom := y + height
        window.detail_recipe.GetPos(&x, &y, &width, &height)
        AssertTrue(y + height <= details_bottom,
            "The recipe details extend through the details group border.")
    } finally {
        window.Dispose()
    }
}

RabbitRimeDepotWindowDarkThemeTest() {
    local header_height, header_y, list_y, window := 0
    try {
        window := RabbitRimeDepotWindow(
            0,
            RabbitRimeDepotWindowFakeService(),
            0,
            0,
            RabbitRimeDepotWindowDarkThemeFactory
        )
        AssertTrue(window.initial_dark_mode && window.window_theme.dark_mode,
            "The downloader did not complete real dark-theme initialization.")
        AssertTrue(window.catalog_category_header.Visible && window.catalog_scheme_header.Visible
            && window.catalog_schemas_header.Visible && window.catalog_repository_header.Visible
            && window.catalog_ref_header.Visible,
            "The dark catalog did not replace its native header with themed controls.")
        window.catalog_category_header.GetPos(, &header_y, , &header_height)
        window.catalog_list.GetPos(, &list_y)
        AssertEqual(header_y + header_height, list_y,
            "The dark catalog rows do not begin directly below the themed header.")
        AssertTrue(WinGetStyle("ahk_id " . window.catalog_list.Hwnd) & 0x4000,
            "The light native catalog header remains enabled in dark mode.")
        window.SetBusy(true)
        AssertTrue(window.catalog_list.Enabled && !window.search_edit.Enabled
            && !window.load_button.Enabled && !window.install_button.Enabled,
            "Loading disabled the dark catalog view or left an operation control enabled.")
        window.SetBusy(false)
        window.SetMode("direct")
        AssertTrue(!window.catalog_category_header.Visible && !window.catalog_scheme_header.Visible
            && !window.catalog_schemas_header.Visible && !window.catalog_repository_header.Visible
            && !window.catalog_ref_header.Visible,
            "The themed catalog headers remained visible in Direct mode.")
    } finally {
        if window {
            window.Dispose()
        }
    }
}

RabbitRimeDepotWindowCategoryIndex(window, path) {
    local index, value
    for index, value in window.category_paths {
        if value = path {
            return index
        }
    }
    return 1
}

RabbitRimeDepotWindowJoin(values, separator) {
    local result := "", value
    for value in values {
        result .= (result = "" ? "" : separator) . value
    }
    return result
}

RabbitRimeDepotWindowDropdownHeight(control) {
    local rect := Buffer(16, 0), result, top, bottom
    result := DllCall("SendMessageW", "Ptr", control.Hwnd, "UInt", 0x0152,
        "Ptr", 0, "Ptr", rect.Ptr, "Ptr")
    AssertTrue(result != 0, "CB_GETDROPPEDCONTROLRECT failed for a hidden DropDownList.")
    top := NumGet(rect, 4, "Int")
    bottom := NumGet(rect, 12, "Int")
    return bottom - top
}

RabbitRimeDepotWindowProgressHasMarquee(control) {
    local style
    if A_PtrSize = 8 {
        style := DllCall("GetWindowLongPtrW", "Ptr", control.Hwnd, "Int", -16, "Ptr")
    } else {
        style := DllCall("GetWindowLongW", "Ptr", control.Hwnd, "Int", -16, "Int")
    }
    return !!(style & RabbitRimeDepotWindow.PBS_MARQUEE)
}

class RabbitRimeDepotWindowTestTheme {
    static Prepare() {
        return false
    }

    __New(window) {
    }

    RegisterMuted(controls*) {
    }

    RegisterSurface(controls*) {
    }

    Register() {
    }

    Dispose() {
    }
}

class RabbitRimeDepotWindowDarkThemeFactory {
    static Prepare() {
        RabbitWindowThemeNative.SetPreferredAppMode(true)
        return true
    }

    static Call(window) {
        return RabbitWindowThemeController(window, RabbitRimeDepotWindowDarkModeReader)
    }
}

class RabbitRimeDepotWindowDarkModeReader {
    static Call() {
        return true
    }
}

class RabbitRimeDepotWindowFakeService {
    __New() {
        this.Config := RimeDepotConfig()
        this.InjectedIniPath := A_Temp . "\\injected-rime-depot.ini"
        this.Config.IniPath := this.InjectedIniPath
        this.config := 0
        this.calls := []
        this.last_job := 0
    }

    SetConfig(config) {
        this.config := config
        this.Config := config
    }

    Configure(config) {
        this.SetConfig(config)
    }

    LoadCatalog(options, callbacks) {
        this.last_job := RabbitRimeDepotWindowFakeJob(callbacks, "catalog")
        return this.last_job
    }

    RefreshCatalog(options, callbacks) {
        return this.LoadCatalog(options, callbacks)
    }

    InstallEntry(entry, options, callbacks) {
        this.calls.Push(Map("kind", "entry", "entry", entry, "options", RabbitRimeDepotWindowCopy(options)))
        this.last_job := RabbitRimeDepotWindowFakeJob(callbacks, "install")
        return this.last_job
    }

    InstallTarget(target, options, callbacks) {
        this.calls.Push(Map("kind", "target", "target", target, "options", RabbitRimeDepotWindowCopy(options)))
        this.last_job := RabbitRimeDepotWindowFakeJob(callbacks, "install")
        return this.last_job
    }
}

class RabbitRimeDepotWindowFakeJob {
    __New(callbacks, kind) {
        this.callbacks := callbacks
        this.kind := kind
        this.cancelled := false
        this.done := false
    }

    IsDone() {
        return this.done
    }

    IsCancelled() {
        return this.cancelled
    }

    Cancel() {
        if this.done {
            return false
        }
        this.cancelled := true
        this.done := true
        this.callbacks.ReportError(this, Error("fake cancellation"))
        return true
    }

    DeliverCatalog() {
        if this.done {
            return
        }
        this.callbacks.ReportProgress(this, Map("phase", "catalog", "state", "fetching"))
        this.done := true
        this.callbacks.ReportComplete(this, Map(
            "entries", [
            { category_path: "Packages / Chinese", name: "Chinese scheme", repo: "owner/chinese",
                schemas: ["chinese.schema"], dependencies: [Map("id", "base")], labels: ["zh"] },
            { category_path: "Packages / Japanese", name: "Japanese scheme", repo: "owner/japanese",
                schemas: ["japanese.schema"], dependencies: [Map("id", "base")], labels: ["ja"],
                recipe: Map("rx", "japanese"), recipes: Map("fluent", Map("rx", "japanese")) },
            { category_path: "Standalone", name: "Standalone scheme", repo: "owner/standalone",
                schemas: ["standalone.schema"] },
            { name: "No category", repo: "owner/uncategorized", schemas: ["uncategorized.schema"] },
            { category_path: "Other / Chinese", name: "Other Chinese scheme", repo: "owner/other-chinese",
                schemas: ["other-chinese.schema"] },
            ],
            "warnings", [Map("kind", "stale")]
        ))
    }

    DeliverInstall() {
        if this.done {
            return
        }
        this.callbacks.ReportProgress(this, Map("phase", "install", "state", "fetching", "index", 1, "total", 2))
        this.done := true
        this.callbacks.ReportComplete(this, Map(
            "entries", ["fake-entry", "fake-dependency"],
            "changed", ["weasel.yaml", "weasel.dict.yaml"],
            "warnings", [Map("kind", "catalog")]
        ))
    }

    DeliverEmptyInstall() {
        if this.done {
            return
        }
        this.done := true
        this.callbacks.ReportComplete(this, Map(
            "entries", [],
            "changed", [],
            "warnings", []
        ))
    }
}

RabbitRimeDepotWindowCopy(value) {
    local result := Map(), key, item
    if IsObject(value) {
        for key, item in value {
            result[key] := item
        }
    }
    return result
}

class RabbitRimeDepotWindowWorkflowProbe {
    CreateRimeDepotSettings() {
        return RabbitRimeDepotSettings(Map(
            "rppi_url", "https://example.invalid/index.json",
            "proxy", "http://proxy.invalid:8080",
            "use_git", true,
            "git_path", "C:\\Tools\\git.exe"
        ))
    }

    SaveRimeDepotSettings(values) {
        return true
    }
}

class RabbitRimeDepotWindowOwnerProbe {
    __New() {
        this.busy := false
        this.refresh_count := 0
        this.refresh_result := true
    }

    GetRimeDepotSettings() {
        return RabbitRimeDepotWindowWorkflowProbe().CreateRimeDepotSettings()
    }

    RefreshSwitcherAfterRimeDepotInstall() {
        this.refresh_count += 1
        return this.refresh_result
    }

    SetRimeDepotBusy(busy) {
        this.busy := !!busy
    }
}
