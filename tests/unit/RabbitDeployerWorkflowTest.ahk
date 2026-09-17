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

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitDeployerWorkflow.ahk

RunTest("deploy workflow ownership", TestDeployWorkflowOwnership.Bind())
RunTest("deploy workflow honors granular plans", TestDeployWorkflowGranularity.Bind())
RunTest("deploy workflow deploys requested schemas", TestDeployWorkflowSchemaConfig.Bind())
RunTest("sync workflow ownership", TestSyncWorkflowOwnership.Bind())
RunTest("deploy workflow failure cleanup", TestDeployWorkflowFailureCleanup.Bind())
RunTest("deploy workflow checks librime results", TestDeployWorkflowChecksLibrimeResults.Bind())
RunTest("deployer dictionary workflow reuses outer mutex ownership", TestDictionaryWorkflowMutexOwnership.Bind())
RunTest("settings workflow reads candidate labels without a behavior model", TestWorkflowReadsCandidateLabels.Bind())

TestDeployWorkflowOwnership() {
    local calls := []
    local workflow := RabbitDeployerWorkflowProbe(
        RabbitDeployerWorkflowRimeProbe(calls),
        calls
    )

    AssertEqual(0, workflow.UpdateWorkspace(), "The deploy workflow failed.")
    AssertEqual(
        "mutex_create,deploy,deploy_config:rabbit.yaml,mutex_close",
        JoinWorkflowCalls(calls),
        "The deploy workflow created unrelated services or released its mutex out of order."
    )
}

TestDeployWorkflowGranularity() {
    local calls := []
    local workflow := RabbitDeployerWorkflowProbe(
        RabbitDeployerWorkflowRimeProbe(calls),
        calls
    )

    AssertEqual(0, workflow.Deploy(RabbitDeploymentPlan()), "An empty deployment plan failed.")
    AssertEqual("", JoinWorkflowCalls(calls), "An empty deployment plan acquired the deployment mutex.")

    AssertEqual(0, workflow.Deploy(RabbitDeploymentPlan.RabbitConfig()), "Rabbit config deployment failed.")
    AssertEqual(
        "mutex_create,deploy_config:rabbit.yaml,mutex_close",
        JoinWorkflowCalls(calls),
        "A Rabbit-only change triggered unrelated deployment work."
    )

    calls.Length := 0
    AssertEqual(0, workflow.Deploy(RabbitDeploymentPlan.DefaultConfig()), "Default config deployment failed.")
    AssertEqual(
        "mutex_create,deploy_config:default.yaml,mutex_close",
        JoinWorkflowCalls(calls),
        "A default-only change triggered unrelated deployment work."
    )

    calls.Length := 0
    local plan := RabbitDeploymentPlan.DefaultConfig().Merge(RabbitDeploymentPlan.RabbitConfig())
    AssertEqual(0, workflow.Deploy(plan), "Merged config deployment failed.")
    AssertEqual(
        "mutex_create,deploy_config:default.yaml,deploy_config:rabbit.yaml,mutex_close",
        JoinWorkflowCalls(calls),
        "Merged config changes were not deployed in dependency order."
    )

    calls.Length := 0
    plan.RequireWorkspace()
    AssertEqual(0, workflow.Deploy(plan), "Workspace deployment failed.")
    AssertEqual(
        "mutex_create,deploy,deploy_config:rabbit.yaml,mutex_close",
        JoinWorkflowCalls(calls),
        "A workspace deployment redundantly deployed default.yaml."
    )
}

TestDeployWorkflowSchemaConfig() {
    local calls := []
    local workflow := RabbitDeployerWorkflowProbe(
        RabbitDeployerWorkflowRimeProbe(calls),
        calls
    )
    local plan := RabbitDeploymentPlan.SchemaConfig("demo")
        .Merge(RabbitDeploymentPlan.SchemaConfig("other"))
    AssertEqual(0, workflow.Deploy(plan), "Schema config deployment failed.")
    AssertEqual(
        "mutex_create,deploy_config:demo.schema.yaml,deploy_config:other.schema.yaml,mutex_close",
        JoinWorkflowCalls(calls),
        "The deploy workflow did not target each requested schema."
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
        "mutex_create,deploy,deploy_config:rabbit.yaml,mutex_close",
        JoinWorkflowCalls(calls),
        "A reported config deployment failure skipped mutex cleanup."
    )
}

TestDictionaryWorkflowMutexOwnership() {
    local calls := []
    local workflow := RabbitDeployerWorkflowProbe(
        RabbitDeployerWorkflowRimeProbe(calls),
        calls,
        false,
        ERROR_ALREADY_EXISTS
    )
    workflow.settings_workflow := RabbitDictionarySettingsWorkflowProbe(calls)

    local model := workflow.CreateDictionarySettingsModel()
    try {
        AssertEqual(
            "dictionary_load",
            JoinWorkflowCalls(calls),
            "The deployer tried to reacquire the deployment mutex already owned by its context."
        )
    } finally {
        model.Dispose()
    }

    calls.Length := 0
    workflow := RabbitDeployerWorkflowProbe(RabbitDeployerWorkflowRimeProbe(calls), calls)
    workflow.settings_workflow := RabbitDictionarySettingsWorkflowProbe(calls)
    model := workflow.CreateDictionarySettingsModel()
    try {
        AssertEqual(
            "mutex_create,dictionary_load,mutex_close",
            JoinWorkflowCalls(calls),
            "A standalone dictionary workflow stopped acquiring the deployment mutex."
        )
    } finally {
        model.Dispose()
    }
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
    __New(rime_api, calls, lock_operations := true, mutex_lasterr := 0) {
        this.calls := calls
        this.mutex_lasterr := mutex_lasterr
        super.__New(rime_api, lock_operations)
    }

    CreateFileIfNotExist(filename) {
    }

    CreateLevers() {
        this.calls.Push("levers")
        return 0
    }

    CreateMutex() {
        return RabbitDeployerWorkflowMutexProbe(this.calls, this.mutex_lasterr)
    }
}

class RabbitDictionarySettingsWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    CreateDictionarySettingsModel(mutex_factory) {
        return RabbitDictionarySettingsModel(
            RabbitDictionaryWorkflowRimeProbe(),
            RabbitDictionaryWorkflowLeversProbe(this.calls),
            mutex_factory
        )
    }
}

class RabbitDictionaryWorkflowRimeProbe {
    api_available(name) {
        return false
    }
}

class RabbitDictionaryWorkflowLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    user_dict_iterator_init() {
        this.calls.Push("dictionary_load")
        return 0
    }
}

class RabbitCandidateLabelWorkflowProbe extends RabbitSettingsWorkflow {
    __New(rime_api, calls) {
        this.rime := rime_api
        this.calls := calls
        this.label_api := RabbitCandidateLabelLeversProbe(calls)
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
    __New(calls, lasterr := 0) {
        this.calls := calls
        this.lasterr := lasterr
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
        this.calls.Push("deploy_config:" . filename)
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
