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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitDeployerWorkflow.ahk

RunTest("deploy workflow ownership", TestDeployWorkflowOwnership.Bind())
RunTest("sync workflow ownership", TestSyncWorkflowOwnership.Bind())
RunTest("deploy workflow failure cleanup", TestDeployWorkflowFailureCleanup.Bind())
RunTest("valid custom system input deploys without dialog", TestValidSystemInputDeploysWithoutDialog.Bind())
RunTest("incompatible custom system input requires selection", TestIncompatibleSystemInputRequiresSelection.Bind())
RunTest("selected system input saves before deployment", TestSelectedSystemInputSavesBeforeDeployment.Bind())

TestDeployWorkflowOwnership() {
    local calls := []
    local workflow := RabbitDeployerWorkflowProbe(
        RabbitDeployerWorkflowRimeProbe(calls),
        calls
    )

    AssertEqual(0, workflow.UpdateWorkspace(), "The deploy workflow failed.")
    AssertEqual(
        "mutex_create,deploy,deploy_config,mutex_close",
        JoinWorkflowCalls(calls),
        "The deploy workflow created unrelated services or released its mutex out of order."
    )
}

TestSyncWorkflowOwnership() {
    local calls := []
    local workflow := RabbitDeployerWorkflowProbe(
        RabbitDeployerWorkflowRimeProbe(calls),
        calls
    )

    AssertEqual(0, workflow.SyncUserData(), "The synchronization workflow failed.")
    AssertEqual(
        "mutex_create,sync,join,mutex_close",
        JoinWorkflowCalls(calls),
        "The synchronization workflow created unrelated services or released its mutex out of order."
    )
}

TestDeployWorkflowFailureCleanup() {
    local calls := []
    local workflow := RabbitDeployerWorkflowProbe(
        RabbitDeployerWorkflowRimeProbe(calls, true),
        calls
    )

    AssertThrows(
        workflow.UpdateWorkspace.Bind(workflow),
        "The deploy workflow swallowed an injected deployment failure."
    )
    AssertEqual(
        "mutex_create,deploy,mutex_close",
        JoinWorkflowCalls(calls),
        "A deployment failure skipped mutex cleanup."
    )
}

TestValidSystemInputDeploysWithoutDialog() {
    local calls := []
    local us := RabbitCreateWorkflowKeyboardProfile("00000409", true)
    local workflow := RabbitSystemInputDeployerWorkflowProbe(calls, "00000409", [us])

    local outcome := workflow.ConfigureSystemInput("none")

    AssertTrue(outcome.restart, "A valid saved keyboard did not restart Rabbit after deployment.")
    AssertEqual(0, outcome.result, "A valid saved keyboard failed deployment.")
    AssertEqual(
        "load,enumerate,deploy",
        JoinWorkflowCalls(calls),
        "A valid custom keyboard unnecessarily opened the dialog or skipped deployment."
    )
}

TestIncompatibleSystemInputRequiresSelection() {
    local calls := []
    local arabic := RabbitCreateWorkflowKeyboardProfile("00000401", true)
    local us := RabbitCreateWorkflowKeyboardProfile("00000409", true)
    local workflow := RabbitSystemInputDeployerWorkflowProbe(
        calls,
        "00000401",
        [arabic, us],
        us
    )

    local outcome := workflow.ConfigureSystemInput("none")

    AssertTrue(outcome.restart, "Replacing an incompatible saved keyboard did not restart Rabbit.")
    AssertEqual(
        "load,enumerate,available,dialog,activate:00000409:0,save:00000409,deploy",
        JoinWorkflowCalls(calls),
        "An incompatible saved keyboard bypassed selection or was deployed again."
    )
}

TestSelectedSystemInputSavesBeforeDeployment() {
    local calls := []
    local original := RabbitSystemInputProfile(
        RabbitSystemInputProfile.INPUT_PROCESSOR,
        0x0804,
        "{81D4E9C9-1D3B-41BC-9E6C-4B40BF79E35E}",
        "{FA550B04-5AD7-411F-A5AC-CA038EC515D7}",
        0
    )
    local state := RabbitSystemInputRestoreState(original, false).Serialize()
    local us := RabbitCreateWorkflowKeyboardProfile("00000409", true)
    local workflow := RabbitSystemInputDeployerWorkflowProbe(calls, "", [us], us)

    local outcome := workflow.ConfigureSystemInput(state)
    local restored := RabbitSystemInputRestoreState.Deserialize(outcome.serialized_state)

    AssertTrue(outcome.restart, "An accepted keyboard did not restart Rabbit.")
    AssertTrue(restored.pending, "The deployer switch was not marked for final restoration.")
    AssertEqual(
        "load,enumerate,available,dialog,activate:00000409:0,save:00000409,deploy",
        JoinWorkflowCalls(calls),
        "The system input workflow did not save before deploying."
    )
}

RabbitCreateWorkflowKeyboardProfile(klid, enabled) {
    local profile := RabbitSystemInputProfile(
        RabbitSystemInputProfile.KEYBOARD_LAYOUT,
        Number("0x" . SubStr(klid, 5, 4)),
        RabbitSystemInputProfiles.NULL_GUID,
        RabbitSystemInputProfiles.NULL_GUID,
        Number("0x" . klid),
        enabled ? RabbitSystemInputProfile.ENABLED : 0
    )
    profile.klid := klid
    return profile
}

JoinWorkflowCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitDeployerWorkflowProbe extends RabbitDeployerWorkflow {
    __New(rime_api, calls) {
        this.calls := calls
        super.__New(rime_api)
    }

    CreateFileIfNotExist(filename) {
    }

    CreateLevers() {
        this.calls.Push("levers")
        return 0
    }

    CreateMutex() {
        return RabbitDeployerWorkflowMutexProbe(this.calls)
    }
}

class RabbitDeployerWorkflowMutexProbe {
    __New(calls) {
        this.calls := calls
        this.lasterr := 0
    }

    Create() {
        this.calls.Push("mutex_create")
        return true
    }

    Close() {
        this.calls.Push("mutex_close")
    }
}

class RabbitDeployerWorkflowRimeProbe {
    __New(calls, fail_deploy := false) {
        this.calls := calls
        this.fail_deploy := fail_deploy
    }

    deploy() {
        this.calls.Push("deploy")
        if this.fail_deploy {
            throw Error("Injected deployment failure.")
        }
    }

    deploy_config_file(filename, version_key) {
        this.calls.Push("deploy_config")
    }

    sync_user_data() {
        this.calls.Push("sync")
        return true
    }

    join_maintenance_thread() {
        this.calls.Push("join")
    }
}

class RabbitSystemInputDeployerWorkflowProbe extends RabbitDeployerWorkflow {
    __New(calls, configured_klid, enabled_profiles, selection := 0) {
        this.calls := calls
        this.settings := RabbitSystemInputWorkflowSettingsProbe(calls, configured_klid)
        this.profiles := RabbitSystemInputWorkflowProfilesProbe(calls, enabled_profiles)
        this.selection := selection
        super.__New(0)
    }

    CreateFileIfNotExist(filename) {
    }

    CreateLevers() {
        return 0
    }

    CreateSystemInputProfiles() {
        return this.profiles
    }

    CreateSystemInputSettings(levers) {
        return this.settings
    }

    CreateSystemInputDialog(enabled, available, configured_klid) {
        return RabbitSystemInputWorkflowDialogProbe(this.selection)
    }

    ShowSystemInputDialog(dialog) {
        this.calls.Push("dialog")
        dialog.Accept()
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return 0
    }

    ShowSystemInputError(message) {
        this.calls.Push("error:" . message)
    }
}

class RabbitSystemInputWorkflowSettingsProbe {
    __New(calls, configured_klid) {
        this.calls := calls
        this.configured_klid := configured_klid
    }

    Load(&klid) {
        this.calls.Push("load")
        klid := this.configured_klid
        return true
    }

    Save(klid) {
        this.calls.Push("save:" . klid)
        return true
    }
}

class RabbitSystemInputWorkflowProfilesProbe {
    __New(calls, enabled_profiles) {
        this.calls := calls
        this.enabled_profiles := enabled_profiles
    }

    EnumerateProfiles() {
        this.calls.Push("enumerate")
        return this.enabled_profiles
    }

    EnumerateAvailableLayouts(enabled) {
        this.calls.Push("available")
        return []
    }

    IsRabbitCompatible(profile) {
        return RabbitSystemInputProfiles.COMPATIBLE_KLIDS.Has(StrUpper(profile.klid))
    }

    Activate(profile, enable := false, window := 0) {
        this.calls.Push("activate:" . (profile.klid ? profile.klid : "input") . ":" . enable)
        return true
    }
}

class RabbitSystemInputWorkflowDialogProbe {
    __New(selection) {
        this.selected_profile := selection
        this.accepted := false
        this.activation_attempted := false
        this.activation_succeeded := false
        this.accept_callback := 0
    }

    Accept() {
        this.accepted := true
        this.activation_attempted := true
        this.activation_succeeded := this.accept_callback.Call(this.selected_profile, 42)
    }

    Dispose() {
    }
}
