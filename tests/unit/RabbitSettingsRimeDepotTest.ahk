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
#Include ..\..\Lib\RabbitSettingsWindow.ahk

try {
    RabbitSettingsRimeDepotTestMain()
} catch as err {
    TestReportFailure("unhandled test error", err)
    ExitApp(1)
}

RabbitSettingsRimeDepotTestMain() {
    RunTest("settings window keeps the Depot tab nested and lazy", RabbitSettingsRimeDepotTabTest.Bind())
    RunTest("settings window marks only Depot drafts dirty", RabbitSettingsRimeDepotDraftTest.Bind())
    RunTest("opening Depot saves, deploys once, then creates one child", RabbitSettingsRimeDepotOpenTest.Bind())
    RunTest("opening Depot isolates other dirty settings", RabbitSettingsRimeDepotIsolationTest.Bind())
    RunTest("opening Depot recovers from save and deploy failures", RabbitSettingsRimeDepotFailureTest.Bind())
    RunTest("opening Depot leaves clean state after child failure", RabbitSettingsRimeDepotChildFailureTest.Bind())
    RunTest("global Apply saves a dirty Depot draft without opening it", RabbitSettingsRimeDepotGlobalApplyTest.Bind())
    RunTest("global Apply skips a clean Depot draft", RabbitSettingsRimeDepotGlobalApplyCleanTest.Bind())
    RunTest("successful settings deployment reconfigures an idle child", RabbitSettingsRimeDepotSyncTest.Bind())
    RunTest("sync failures dispose stale children and reopen safely", RabbitSettingsRimeDepotSyncFailureTest.Bind())
    RunTest("existing downloader activation failures recover safely", RabbitSettingsRimeDepotActivationFailureTest.Bind())
    RunTest("settings window blocks Depot transactions while busy", RabbitSettingsRimeDepotBusyTest.Bind())
    RunTest("installed packages refresh schemes without creating unsaved state",
        RabbitSettingsRimeDepotRefreshTest.Bind())
    ExitApp(0)
}

RabbitSettingsRimeDepotNewWindow(workflow, factory := 0) {
    return RabbitSettingsWindow(
        workflow,
        false,
        RabbitAppearancePreview,
        0,
        "input-schemes",
        false,
        RabbitSettingsRimeDepotThemeProbe,
        false,
        factory
    )
}

RabbitSettingsRimeDepotSelectTab(window) {
    window.switcher_tabs.Choose(3)
    window.OnSwitcherTabChanged()
    AssertEqual(3, window.switcher_tabs.Value, "The nested Depot tab could not be selected.")
    AssertTrue(window.rime_depot_url_edit.Visible && window.rime_depot_open_button.Visible,
        "The third nested tab did not reveal its downloader controls.")
}

RabbitSettingsRimeDepotSetDraft(window, values) {
    window.rime_depot_url_edit.Value := values["rppi_url"]
    window.rime_depot_proxy_edit.Value := values["proxy"]
    window.rime_depot_use_git.Value := values["use_git"] ? 1 : 0
    window.rime_depot_git_path_edit.Value := values["git_path"]
    window.OnRimeDepotSettingsChanged()
}

RabbitSettingsRimeDepotDefaultValues() {
    return Map(
        "rppi_url", "https://example.invalid/index.json",
        "proxy", "http://proxy.invalid:8080",
        "use_git", true,
        "git_path", "C:\\Tools\\git.exe"
    )
}

RabbitSettingsRimeDepotTabTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow)
    try {
        AssertTrue(!HasProp(window, "switcher_depot_button"),
            "The obsolete standalone Depot button still exists.")
        AssertTrue(window.switcher_tabs.Value != 3 && !window.rime_depot_settings,
            "The third tab's model was created before the tab was selected.")
        RabbitSettingsRimeDepotSelectTab(window)
        AssertTrue(window.rime_depot_url_label.Text = RabbitI18n.Text("depot.rppi_url"),
            "The nested tab did not expose the RPPI URL field label.")
        AssertTrue(window.rime_depot_proxy_label.Text = RabbitI18n.Text("depot.proxy"),
            "The nested tab did not expose the proxy field label.")
        AssertEqual(RabbitI18n.Text("depot.open_downloader"), window.rime_depot_open_button.Text,
            "The nested tab did not use the Open downloader label.")
        AssertTrue(!HasProp(window, "rime_depot_open_hint"),
            "The obsolete Open downloader explanatory text still exists.")
        AssertTrue(!window.rime_depot_git_path_edit.Enabled && !window.rime_depot_git_path_browse.Enabled,
            "Git path controls were enabled while Use Git was off.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotDraftTest() {
    local window := RabbitSettingsRimeDepotNewWindow(RabbitSettingsRimeDepotWorkflowProbe())
    local original
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        original := window.GetRimeDepotSettings().ToMap()
        RabbitSettingsRimeDepotSetDraft(window, RabbitSettingsRimeDepotDefaultValues())
        AssertTrue(window.rime_depot_dirty && window.HasUnsavedSettings(),
            "Editing a downloader field did not participate in global dirty state.")
        AssertEqual(RabbitI18n.Text("depot.save_and_open_downloader"), window.rime_depot_open_button.Text,
            "A dirty downloader tab did not offer to save before opening.")
        AssertTrue(window.rime_depot_git_path_edit.Enabled && window.rime_depot_git_path_browse.Enabled,
            "Enabling Use Git did not enable Git path controls.")
        window.rime_depot_use_git.Value := 0
        window.OnRimeDepotSettingsChanged()
        AssertTrue(!window.rime_depot_git_path_edit.Enabled && !window.rime_depot_git_path_browse.Enabled,
            "Disabling Use Git did not disable Git path controls.")
        RabbitSettingsRimeDepotSetDraft(window, original)
        AssertTrue(!window.rime_depot_dirty,
            "Restoring the accepted downloader values did not clear dirty state.")
        AssertEqual(RabbitI18n.Text("depot.open_downloader"), window.rime_depot_open_button.Text,
            "Restoring the accepted downloader values did not restore the Open label.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotOpenTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local factory := RabbitSettingsRimeDepotFactoryProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow, factory)
    local values := RabbitSettingsRimeDepotDefaultValues()
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        RabbitSettingsRimeDepotSetDraft(window, values)
        AssertTrue(window.OpenRimeDepot(), "The downloader tab did not complete its open transaction.")
        AssertEqual(1, workflow.save_count, "Open downloader did not save the four downloader keys once.")
        AssertEqual(1, workflow.deploy_count, "Open downloader did not perform exactly one deployment.")
        AssertTrue(workflow.last_deployment_plan.rabbit_config_changed,
            "Open downloader did not deploy rabbit.yaml.")
        AssertTrue(!workflow.last_deployment_plan.default_config_changed
            && !workflow.last_deployment_plan.full_workspace_required,
            "Open downloader performed unrelated deployment work.")
        AssertEqual(1, factory.create_count, "Open downloader did not create exactly one child.")
        AssertTrue(!window.rime_depot_dirty && !window.parent_operation_busy && !window.rime_depot_busy,
            "Open downloader left the parent dirty or locked after success.")
        AssertEqual(values["rppi_url"], factory.child.settings.rppi_url,
            "The child did not receive the accepted RPPI URL snapshot.")
        AssertTrue(!factory.child.owner_busy, "The child retained the parent operation lock after opening.")
        AssertTrue(window.OpenRimeDepot(), "Reopening the downloader did not complete its transaction.")
        AssertEqual(1, workflow.save_count,
            "Opening unchanged downloader settings saved them again.")
        AssertEqual(1, workflow.deploy_count,
            "Opening unchanged downloader settings deployed again.")
        AssertEqual(1, factory.create_count, "Reopening the downloader created a duplicate child.")
        AssertEqual(2, factory.child.show_count, "Reopening the downloader did not activate the child.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotIsolationTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local factory := RabbitSettingsRimeDepotFactoryProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow, factory)
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        RabbitSettingsRimeDepotSetDraft(window, RabbitSettingsRimeDepotDefaultValues())
        window.application_dirty := true
        window.application_changes := Map("unrelated", true)
        AssertTrue(window.OpenRimeDepot(), "Open downloader failed with another page dirty.")
        AssertEqual(1, workflow.save_count, "Open downloader saved an unexpected number of setting groups.")
        AssertEqual(1, workflow.deploy_count, "Open downloader did not deploy once with another page dirty.")
        AssertTrue(window.application_dirty && window.application_changes.Has("unrelated"),
            "Open downloader cleared or changed another page's unsaved settings.")
        AssertTrue(!window.rime_depot_dirty, "Open downloader retained its accepted draft as dirty.")
        AssertEqual(RabbitI18n.Text("controls.save_hint"), window.footer_status.Value,
            "Open downloader replaced the global unsaved status with all-saved feedback.")
        AssertTrue(window.apply_button.Enabled,
            "Open downloader disabled Apply while another page remained dirty.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotFailureTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local factory := RabbitSettingsRimeDepotFactoryProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow, factory)
    local saved_before
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        RabbitSettingsRimeDepotSetDraft(window, RabbitSettingsRimeDepotDefaultValues())
        window.rime_depot_url_edit.Value := "not-a-url"
        window.OnRimeDepotSettingsChanged()
        saved_before := workflow.save_count
        AssertTrue(!window.OpenRimeDepot(), "An invalid RPPI URL was accepted by Open downloader.")
        AssertEqual(saved_before, workflow.save_count, "URL validation attempted persistence.")
        AssertTrue(window.rime_depot_dirty && !window.parent_operation_busy,
            "URL validation did not preserve dirty state and unlock the parent.")
        window.rime_depot_url_edit.Value := RabbitSettingsRimeDepotDefaultValues()["rppi_url"]
        window.OnRimeDepotSettingsChanged()
        workflow.fail_save := true
        AssertTrue(!window.OpenRimeDepot(), "A failed downloader save was reported as successful.")
        AssertEqual(0, workflow.deploy_count, "A failed downloader save still deployed.")
        AssertEqual(0, factory.create_count, "A failed downloader save created a child.")
        AssertTrue(window.rime_depot_dirty && !window.parent_operation_busy,
            "A failed downloader save did not preserve dirty state and unlock the parent.")

        workflow.fail_save := false
        workflow.deploy_result := 1
        AssertTrue(!window.OpenRimeDepot(), "A failed downloader deployment was reported as successful.")
        AssertEqual(1, workflow.deploy_count, "A failed downloader deployment did not run exactly once.")
        AssertEqual(0, factory.create_count, "A failed downloader deployment created a child.")
        AssertTrue(window.rime_depot_dirty && !window.parent_operation_busy,
            "A failed downloader deployment did not preserve dirty state and unlock the parent.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotChildFailureTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local factory := RabbitSettingsRimeDepotFactoryProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow, factory)
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        RabbitSettingsRimeDepotSetDraft(window, RabbitSettingsRimeDepotDefaultValues())
        factory.fail_create := true
        AssertTrue(!window.OpenRimeDepot(), "A child creation failure was reported as successful.")
        AssertEqual(1, workflow.deploy_count, "Child creation failure did not retain the successful deployment.")
        AssertTrue(!window.rime_depot_dirty && !window.parent_operation_busy,
            "Child creation failure incorrectly rolled back accepted downloader settings or lock state.")
        AssertTrue(InStr(window.rime_depot_status.Value, "fake child creation failure") > 0,
            "Child creation failure did not report an open error.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotGlobalApplyTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow)
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        RabbitSettingsRimeDepotSetDraft(window, RabbitSettingsRimeDepotDefaultValues())
        window.EnsurePageControls(4)
        window.application_model := RabbitSettingsRimeDepotApplicationProbe()
        window.application_dirty := true
        window.application_changes := Map("unrelated", true)
        AssertTrue(window.ApplyAllPendingSettings(), "Global Apply did not save a dirty downloader draft: "
            . window.footer_status.Value . " save=" . workflow.save_count . " deploy=" . workflow.deploy_count)
        AssertEqual(1, workflow.save_count, "Global Apply did not save downloader settings once.")
        AssertEqual(1, workflow.deploy_count, "Global Apply did not deploy once.")
        AssertTrue(workflow.last_deployment_plan.rabbit_config_changed,
            "Global Apply did not deploy its Rabbit settings.")
        AssertTrue(!workflow.last_deployment_plan.default_config_changed
            && !workflow.last_deployment_plan.full_workspace_required,
            "Rabbit-only global changes performed unrelated deployment work.")
        AssertEqual(1, window.application_model.save_count, "Global Apply did not save the other dirty page.")
        AssertTrue(!window.rime_depot_dirty && !window.application_dirty && !window.rime_depot_window,
            "Global Apply left dirty state or opened the downloader child.")
        AssertEqual(RabbitI18n.Text("depot.settings_saved"), window.rime_depot_status.Value,
            "Global Apply left the downloader tab showing unsaved changes after success.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotGlobalApplyCleanTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow)
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        window.EnsurePageControls(4)
        window.application_model := RabbitSettingsRimeDepotApplicationProbe()
        window.application_dirty := true
        window.application_changes := Map("unrelated", true)
        AssertTrue(window.ApplyAllPendingSettings(), "Global Apply failed with a clean downloader draft: "
            . window.footer_status.Value . " deploy=" . workflow.deploy_count)
        AssertEqual(0, workflow.save_count, "Global Apply saved a clean downloader draft.")
        AssertEqual(1, workflow.deploy_count, "Global Apply did not deploy the other dirty page once.")
        AssertTrue(!window.rime_depot_window, "Global Apply opened the downloader child.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotSyncTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local factory := RabbitSettingsRimeDepotFactoryProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow, factory)
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        AssertTrue(window.StartRimeDepot(), "The synchronization test could not create the child.")
        window.EnsurePageControls(4)
        window.application_model := RabbitSettingsRimeDepotApplicationProbe()
        window.application_dirty := true
        window.application_changes := Map("unrelated", true)
        AssertTrue(window.ApplyAllPendingSettings(),
            "A successful unrelated settings deployment failed while a child was open.")
        AssertEqual(1, factory.child.set_settings_count,
            "A successful settings deployment did not reconfigure the idle child once.")
        AssertTrue(!window.application_dirty && !window.parent_operation_busy && !factory.child.owner_busy,
            "The settings deployment left the parent or child locked.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotSyncFailureTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local factory := RabbitSettingsRimeDepotFactoryProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow, factory)
    local stale_child, replacement := RabbitSettingsRimeDepotDefaultValues()
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        AssertTrue(window.StartRimeDepot(), "The sync-failure test could not create the initial child.")
        stale_child := factory.child
        stale_child.fail_set_settings := true
        replacement["rppi_url"] := "https://example.invalid/reconfigured-index.json"
        RabbitSettingsRimeDepotSetDraft(window, replacement)
        AssertTrue(window.OpenRimeDepot(),
            "Open downloader did not recover by creating a fresh child after sync failure.")
        AssertTrue(stale_child.disposed && factory.create_count = 2 && factory.child !== stale_child,
            "Open downloader left the stale child active instead of recreating it.")
        AssertEqual(replacement["rppi_url"], factory.child.settings.rppi_url,
            "The recreated child did not receive the accepted settings snapshot.")

        factory.child.fail_set_settings := true
        window.EnsurePageControls(4)
        window.application_model := RabbitSettingsRimeDepotApplicationProbe()
        window.application_dirty := true
        window.application_changes := Map("unrelated", true)
        AssertTrue(window.ApplyAllPendingSettings(),
            "Global Apply failed even though child reconfiguration was the only post-deploy failure.")
        AssertTrue(factory.child.disposed && !window.rime_depot_window,
            "Global Apply retained a stale child after reconfiguration failed.")
        AssertTrue(InStr(window.rime_depot_status.Value, RabbitI18n.Text("depot.reconfigure_error")) > 0,
            "Global Apply did not report the child reconfiguration warning.")
        AssertEqual(window.rime_depot_status.Value, window.footer_status.Value,
            "Global Apply hid the child reconfiguration warning behind all-saved feedback.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotActivationFailureTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local factory := RabbitSettingsRimeDepotFactoryProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow, factory)
    local stale_child
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        AssertTrue(window.StartRimeDepot(), "The activation-failure test could not create the initial child.")
        stale_child := factory.child
        stale_child.fail_show := true
        AssertTrue(window.StartRimeDepot(),
            "An existing child Show exception was not recovered by creating a fresh child.")
        AssertTrue(stale_child.disposed && factory.create_count = 2 && factory.child !== stale_child,
            "The child with a Show exception remained activatable or was not recreated.")

        stale_child := factory.child
        stale_child.Hwnd := 12345
        AssertTrue(window.StartRimeDepot(),
            "An invalid existing child HWND was not recovered by creating a fresh child.")
        AssertTrue(stale_child.disposed && factory.create_count = 3 && factory.child !== stale_child,
            "The invalid child HWND remained active instead of being recreated.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotBusyTest() {
    local workflow := RabbitSettingsRimeDepotWorkflowProbe()
    local factory := RabbitSettingsRimeDepotFactoryProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow, factory)
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        RabbitSettingsRimeDepotSetDraft(window, RabbitSettingsRimeDepotDefaultValues())
        AssertTrue(window.OpenRimeDepot(), "The busy test could not open the child.")
        factory.child.SetBusy(true)
        AssertTrue(!window.OpenRimeDepot(), "Open downloader bypassed an active child operation.")
        AssertEqual(1, workflow.deploy_count, "Busy rejection deployed another transaction.")
        AssertTrue(window.rime_depot_busy && !window.parent_operation_busy && !window.apply_button.Enabled,
            "The parent did not stay locked while the child was busy.")
        factory.child.SetBusy(false)
        AssertTrue(!window.rime_depot_busy && DllCall("IsWindowEnabled", "Ptr", window.Hwnd, "Int"),
            "The parent did not recover after the child operation ended.")
    } finally {
        window.Dispose()
    }
}

RabbitSettingsRimeDepotRefreshTest() {
    local workflow := RabbitSettingsRimeDepotRefreshWorkflowProbe()
    local window := RabbitSettingsRimeDepotNewWindow(workflow)
    try {
        RabbitSettingsRimeDepotSelectTab(window)
        AssertEqual(1, workflow.switcher_create_count,
            "The initial scheme list did not load through the workflow Levers model.")
        AssertTrue(window.RefreshSwitcherAfterRimeDepotInstall(),
            "A successful package install did not refresh the scheme list.")
        AssertEqual(2, workflow.switcher_create_count,
            "The package install did not create one fresh Levers-backed scheme model.")
        AssertEqual(2, window.switcher_list.GetCount(),
            "The refreshed scheme list omitted the newly installed scheme.")
        AssertTrue(!window.switcher_dirty && !window.HasUnsavedSettings(),
            "Refreshing installed schemes incorrectly created unsaved settings or blocked closing.")

        window.switcher_hotkeys.Value := "Control+grave"
        window.switcher_list.Modify(2, "Check")
        window.MarkSwitcherDirty()
        AssertTrue(window.RefreshSwitcherAfterRimeDepotInstall(),
            "Refreshing after another install failed with an existing scheme draft.")
        AssertTrue(window.switcher_dirty && window.HasUnsavedSettings()
            && window.switcher_hotkeys.Value = "Control+grave"
            && window.SelectedSchemaIds().Length = 2,
            "Refreshing installed schemes lost an existing draft or bypassed close protection.")
    } finally {
        window.Dispose()
    }
}

class RabbitSettingsRimeDepotThemeProbe {
    static Prepare() {
        return false
    }

    __New(window) {
    }

    RegisterMuted(controls*) {
    }

    RegisterSurface(controls*) {
    }

    Apply() {
    }

    Register() {
    }

    Dispose() {
    }
}

class RabbitSettingsRimeDepotWorkflowProbe {
    __New() {
        this.deploy_count := 0
        this.save_count := 0
        this.fail_save := false
        this.deploy_result := 0
        this.saved_values := 0
        this.last_deployment_plan := RabbitDeploymentPlan()
    }

    CreateRimeDepotSettings() {
        return RabbitRimeDepotSettings()
    }

    SaveRimeDepotSettings(values) {
        this.save_count += 1
        if this.fail_save {
            return false
        }
        this.saved_values := RabbitRimeDepotSettings(values).ToMap()
        return true
    }

    Deploy(plan, *) {
        this.deploy_count += 1
        this.last_deployment_plan := plan
        return this.deploy_result
    }

    UpdateWorkspace(*) {
        this.deploy_count += 1
        this.last_deployment_plan := RabbitDeploymentPlan.FullRedeploy()
        return this.deploy_result
    }
}

class RabbitSettingsRimeDepotRefreshWorkflowProbe extends RabbitSettingsRimeDepotWorkflowProbe {
    __New() {
        super.__New()
        this.switcher_create_count := 0
    }

    CreateSwitcherSettingsModel() {
        this.switcher_create_count += 1
        return RabbitSettingsRimeDepotSwitcherProbe(this.switcher_create_count > 1)
    }
}

class RabbitSettingsRimeDepotSwitcherProbe {
    __New(include_installed := false) {
        this.items := [{
            id: "existing",
            name: "Existing scheme",
            author: "",
            description: "",
            file_path: "",
            selected: true,
        }]
        if include_installed {
            this.items.Push({
                id: "installed",
                name: "Installed scheme",
                author: "",
                description: "",
                file_path: "",
                selected: false,
            })
        }
        this.hotkeys := ""
        this.caption := ":-)"
        this.save_options := []
        this.fold_options := false
        this.abbreviate_options := false
        this.option_list_prefix := ""
        this.option_list_suffix := ""
        this.option_list_separator := " "
        this.fix_schema_list_order := false
        this.disposed := false
    }

    GetOptionItems(*) {
        return []
    }

    SetCurrentValues(values) {
        local selected := Map(), ordered := [], item, schema_id
        for schema_id in values.schema_ids {
            selected[schema_id] := true
            for item in this.items {
                if item.id = schema_id {
                    item.selected := true
                    ordered.Push(item)
                    break
                }
            }
        }
        for item in this.items {
            if !selected.Has(item.id) {
                item.selected := false
                ordered.Push(item)
            }
        }
        this.items := ordered
        this.hotkeys := values.hotkeys
        this.caption := values.caption
        this.save_options := values.save_options.Clone()
        this.fold_options := values.fold_options
        this.abbreviate_options := values.abbreviate_options
        this.option_list_prefix := values.option_list_prefix
        this.option_list_suffix := values.option_list_suffix
        this.option_list_separator := values.option_list_separator
        this.fix_schema_list_order := values.fix_schema_list_order
    }

    Dispose() {
        this.disposed := true
    }
}

class RabbitSettingsRimeDepotApplicationProbe {
    __New() {
        this.save_count := 0
    }

    Save(values) {
        this.save_count += 1
        return true
    }

    Dispose() {
    }
}

class RabbitSettingsRimeDepotFactoryProbe {
    __New() {
        this.create_count := 0
        this.fail_create := false
        this.child := 0
        this.children := []
    }

    Call(owner, workflow) {
        if this.fail_create {
            throw Error("fake child creation failure")
        }
        this.create_count += 1
        this.child := RabbitSettingsRimeDepotChildProbe()
        this.children.Push(this.child)
        this.child.owner := owner
        this.child.settings := owner.GetRimeDepotSettings()
        return this.child
    }
}

class RabbitSettingsRimeDepotChildProbe {
    __New() {
        this.disposed := false
        this.busy := false
        this.owner_busy := false
        this.owner := 0
        this.show_count := 0
        this.fail_show := false
        this.settings := RabbitRimeDepotSettings()
        this.set_settings_count := 0
        this.fail_set_settings := false
    }

    Show(*) {
        if this.fail_show {
            throw Error("fake child Show failure")
        }
        this.show_count += 1
    }

    IsBusy() {
        return this.busy
    }

    SetBusy(value) {
        this.busy := !!value
        if this.owner && HasMethod(this.owner, "SetRimeDepotBusy") {
            this.owner.SetRimeDepotBusy(this.busy)
        }
    }

    SetOwnerBusy(value) {
        this.owner_busy := !!value
    }

    SetSettings(settings) {
        if this.disposed || this.busy || this.owner_busy {
            return false
        }
        if this.fail_set_settings {
            return false
        }
        this.settings := RabbitRimeDepotSettings(settings.ToMap())
        this.set_settings_count += 1
        return true
    }

    Dispose() {
        this.disposed := true
        this.owner_busy := false
    }
}
