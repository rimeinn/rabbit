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

    Complete(result) {
        local callback := this.completion_callback
        this.completion_callback := 0
        callback.Call(result, true)
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
