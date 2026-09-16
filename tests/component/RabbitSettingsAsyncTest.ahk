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

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitSettingsWindow.ahk

RunTest("settings retain activation pending after worker failure", TestActivationPendingRetry.Bind())
RunTest("settings preserve drafts while backend models detach", TestMaintenanceDraftPreservation.Bind())
RunTest("first install stays locked until worker completion", TestInstallationWaitsForWorker.Bind())
RunTest("failed first-install worker keeps settings locked", TestInstallationFailureStaysLocked.Bind())
RunTest("schema settings reload after worker completion", TestSchemaSettingsWaitForWorker.Bind())

TestActivationPendingRetry() {
    local workflow := RabbitAsyncSettingsWorkflowProbe()
    local window := RabbitSettingsWindow(workflow)
    try {
        AssertEqual(0, window.Deploy(RabbitDeploymentPlan.RabbitConfig()), "The async deployment was rejected.")
        AssertTrue(window.activation_pending, "Accepted settings were not marked pending.")
        AssertTrue(window.deploying, "The settings window did not enter its deploying state.")
        workflow.Complete(4)
        AssertTrue(window.activation_pending, "Worker failure discarded the pending deployment plan.")
        AssertTrue(!window.deploying, "Worker failure left the settings window deploying.")
        AssertTrue(window.apply_button.Enabled, "Worker failure did not enable retry.")

        AssertTrue(window.ApplyAllPendingSettings(), "The pending deployment could not be retried.")
        AssertEqual(2, workflow.submissions, "Retry did not resubmit the deployment plan.")
        workflow.Complete(0)
        AssertTrue(!window.activation_pending, "Successful retry retained activation pending.")
        AssertTrue(window.pending_plan.IsEmpty(), "Successful retry retained an obsolete plan.")
    } finally {
        window.Dispose()
    }
}

TestMaintenanceDraftPreservation() {
    local workflow := RabbitDraftSettingsWorkflowProbe()
    local window := RabbitSettingsWindow(workflow)
    try {
        local hwnd := window.Hwnd
        window.selected_page := 3
        window.behavior_dirty := true
        window.menu_labels_values := ["draft"]
        window.behavior_model := RabbitDraftModelProbe()
        AssertTrue(window.PrepareForMaintenance(), "The settings window could not detach its backend.")
        AssertTrue(!window.behavior_model, "The old behavior model survived maintenance preparation.")
        window.ResumeAfterMaintenance(workflow, 0)
        AssertEqual(hwnd, window.Hwnd, "Maintenance replaced the top-level settings window.")
        AssertTrue(window.behavior_model is RabbitDraftModelProbe, "The behavior model was not rebound.")
        AssertEqual("draft", window.menu_labels_values[1], "The unsaved behavior draft was overwritten.")
        AssertTrue(window.behavior_dirty, "The unsaved behavior draft lost its dirty state.")
    } finally {
        window.Dispose()
    }
}

TestInstallationWaitsForWorker() {
    local workflow := RabbitAsyncInstallWorkflowProbe()
    local window := RabbitSettingsWindow(
        workflow,
        false,
        RabbitAppearancePreview,
        0,
        "input-schemes",
        true
    )
    try {
        AssertTrue(window.CompleteInstallation(), "The first-install deployment was rejected.")
        AssertTrue(window.installing, "Submitting the worker unlocked install mode early.")
        AssertTrue(!window.navigation.Enabled, "Submitting the worker enabled navigation early.")
        AssertTrue(!window.apply_button.Enabled, "Install mode allowed a second deployment while one was running.")
        workflow.Complete(0)
        AssertTrue(window.installing, "The worker callback unlocked install mode before returning.")
        Sleep(20)
        AssertTrue(!window.installing, "Worker success did not unlock install mode.")
        AssertTrue(window.navigation.Enabled, "Worker success did not enable navigation.")
        AssertEqual(2, workflow.model_create_count, "Worker success did not reload the switcher model.")
    } finally {
        window.Dispose()
    }
}

TestInstallationFailureStaysLocked() {
    local workflow := RabbitAsyncInstallWorkflowProbe()
    local window := RabbitSettingsWindow(
        workflow,
        false,
        RabbitAppearancePreview,
        0,
        "input-schemes",
        true
    )
    try {
        AssertTrue(window.CompleteInstallation(), "The first-install deployment was rejected.")
        workflow.Complete(5)
        Sleep(20)
        AssertTrue(window.installing, "Worker failure unlocked install mode.")
        AssertTrue(!window.navigation.Enabled, "Worker failure enabled settings navigation.")
        AssertTrue(window.apply_button.Enabled, "Worker failure did not allow deployment retry.")
        AssertEqual(2, workflow.model_create_count, "Worker failure did not restore the switcher model.")
    } finally {
        window.Dispose()
    }
}

TestSchemaSettingsWaitForWorker() {
    local workflow := RabbitAsyncSchemaWorkflowProbe()
    local window := RabbitSettingsWindow(workflow)
    try {
        AssertTrue(window.SelectPage(2), "The settings window rejected the switcher page.")
        window.switcher_list.Modify(1, "Select Focus")
        window.OnSwitcherSchemaSelected(1)
        AssertTrue(window.OpenSelectedSchemaSettings(), "The schema build was rejected.")
        AssertEqual(1, workflow.schema_model.load_count, "Schema settings reloaded before the worker completed.")
        workflow.Complete(0)
        AssertEqual(1, workflow.schema_model.load_count, "Schema settings reloaded inside the worker callback.")
        Sleep(20)
        AssertEqual(2, workflow.schema_model.load_count, "Schema settings were not reloaded after worker completion.")
        AssertEqual(
            RabbitI18n.Text("controls.scheme_settings_read_error"),
            window.switcher_status.Value,
            "A failed post-build schema read did not report an error."
        )
    } finally {
        window.Dispose()
    }
}

class RabbitAsyncSettingsWorkflowProbe {
    __New() {
        this.submissions := 0
        this.completion_callback := 0
    }

    Submit(plan, completion_callback) {
        this.submissions += 1
        this.plan := plan
        this.completion_callback := completion_callback
        return true
    }

    Complete(result, resumed := true) {
        local callback := this.completion_callback
        this.completion_callback := 0
        callback.Call(result, resumed)
    }
}

class RabbitAsyncInstallWorkflowProbe extends RabbitAsyncSettingsWorkflowProbe {
    __New() {
        super.__New()
        this.model_create_count := 0
    }

    CreateSwitcherSettingsModel() {
        this.model_create_count += 1
        return RabbitAsyncSwitcherModelProbe()
    }
}

class RabbitAsyncSchemaWorkflowProbe extends RabbitAsyncSettingsWorkflowProbe {
    __New() {
        super.__New()
        this.schema_model := RabbitAsyncSchemaModelProbe()
    }

    CreateSwitcherSettingsModel() {
        return RabbitAsyncSwitcherModelProbe()
    }

    CreateSchemaSettingsModel(*) {
        return this.schema_model
    }
}

class RabbitAsyncSwitcherModelProbe {
    __New() {
        this.hotkeys := "Control+grave"
        this.caption := "〔方案选单〕"
        this.save_options := []
        this.fold_options := false
        this.abbreviate_options := false
        this.option_list_prefix := ""
        this.option_list_suffix := ""
        this.option_list_separator := " "
        this.fix_schema_list_order := false
        this.items := [{
            id: "schema_a",
            name: "方案 A",
            author: "",
            description: "",
            selected: true,
        }]
    }

    GetOptionItems(*) {
        return []
    }

    Save(*) {
        return true
    }

    Dispose() {
    }
}

class RabbitAsyncSchemaModelProbe {
    load_count := 0

    Load() {
        this.load_count += 1
        return false
    }
}

class RabbitDraftSettingsWorkflowProbe {
    CreateBehaviorSettingsModel() {
        return RabbitDraftModelProbe()
    }
}

class RabbitDraftModelProbe {
    Dispose() {
    }
}
