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
RunTest("deploy workflow checks librime results", TestDeployWorkflowChecksLibrimeResults.Bind())
RunTest("settings workflow reads candidate labels without a behavior model", TestWorkflowReadsCandidateLabels.Bind())

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

TestDeployWorkflowChecksLibrimeResults() {
    local calls := []
    local workflow := RabbitDeployerWorkflowProbe(
        RabbitDeployerWorkflowRimeProbe(calls, false, true, false),
        calls
    )

    AssertEqual(1, workflow.UpdateWorkspace(), "The deploy workflow ignored a failed config deployment.")
    AssertEqual(
        "mutex_create,deploy,deploy_config,mutex_close",
        JoinWorkflowCalls(calls),
        "A reported config deployment failure skipped mutex cleanup."
    )
}

TestWorkflowReadsCandidateLabels() {
    local calls := []
    local workflow := RabbitCandidateLabelWorkflowProbe(RabbitCandidateLabelRimeProbe(calls), calls)
    local labels := workflow.ReadCandidateLabels()
    AssertEqual(2, labels.Length, "The workflow loaded the wrong candidate label count.")
    AssertEqual("①", labels[1], "The workflow loaded the wrong first candidate label.")
    AssertEqual("②", labels[2], "The workflow loaded the wrong second candidate label.")
    AssertTrue(WorkflowCallsHave(calls, "destroy:default"), "The workflow leaked its candidate label settings.")
}

JoinWorkflowCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

WorkflowCallsHave(calls, expected) {
    for call in calls {
        if call = expected {
            return true
        }
    }
    return false
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

class RabbitCandidateLabelWorkflowProbe extends RabbitDeployerWorkflowProbe {
    __New(rime_api, calls) {
        this.label_api := RabbitCandidateLabelLeversProbe(calls)
        super.__New(rime_api, calls)
    }

    CreateLevers() {
        this.calls.Push("levers")
        return this.label_api
    }
}

class RabbitCandidateLabelLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    custom_settings_init(config_id, generator_id) {
        this.calls.Push("init:" . config_id)
        return config_id
    }

    load_settings(settings) {
        this.calls.Push("load:" . settings)
        return true
    }

    settings_get_config(settings) {
        this.calls.Push("config:" . settings)
        return settings
    }

    custom_settings_destroy(settings) {
        this.calls.Push("destroy:" . settings)
    }
}

class RabbitCandidateLabelRimeProbe {
    __New(calls) {
        this.calls := calls
        this.labels := ["①", "②"]
    }

    config_begin_list(config, path) {
        this.calls.Push("begin:" . path)
        return { index: 0, path: "" }
    }

    config_next(iter) {
        iter.index += 1
        if iter.index > this.labels.Length {
            return false
        }
        iter.path := "menu/alternative_select_labels/@" . (iter.index - 1)
        return true
    }

    config_test_get_string(config, path, &value) {
        local index := Integer(SubStr(path, InStr(path, "@") + 1)) + 1
        value := this.labels[index]
        return true
    }

    config_end(iter) {
        this.calls.Push("end")
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
    __New(calls, fail_deploy := false, deploy_result := true, config_result := true) {
        this.calls := calls
        this.fail_deploy := fail_deploy
        this.deploy_result := deploy_result
        this.config_result := config_result
    }

    deploy() {
        this.calls.Push("deploy")
        if this.fail_deploy {
            throw Error("Injected deployment failure.")
        }
        return this.deploy_result
    }

    deploy_config_file(filename, version_key) {
        this.calls.Push("deploy_config")
        return this.config_result
    }

    sync_user_data() {
        this.calls.Push("sync")
        return true
    }

    join_maintenance_thread() {
        this.calls.Push("join")
    }
}
