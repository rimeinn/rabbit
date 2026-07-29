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

#Include <RabbitDeployerWorkflow>

RunTest("deploy workflow ownership", TestDeployWorkflowOwnership.Bind())
RunTest("sync workflow ownership", TestSyncWorkflowOwnership.Bind())
RunTest("deploy workflow failure cleanup", TestDeployWorkflowFailureCleanup.Bind())

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
