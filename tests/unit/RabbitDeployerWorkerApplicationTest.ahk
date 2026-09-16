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
#Include ..\..\Lib\RabbitDeployerWorkerApplication.ahk

RunTest("deployer worker owns its complete lifecycle", TestWorkerLifecycle.Bind())
RunTest("deployer worker reports synchronization failure", TestWorkerFailureResult.Bind())

TestWorkerLifecycle() {
    local calls := []
    local application := RabbitWorkerApplicationProbe(calls, 0)
    local plan := RabbitDeploymentPlan.RabbitConfig().Merge(RabbitDeploymentPlan.SchemaConfig("demo"))
    AssertEqual(
        0,
        application.Run(["deploy", "--plan", plan.Serialize()]),
        "The deployment worker returned the wrong result."
    )
    AssertEqual(
        "initialize,workflow,deploy:" . plan.Serialize() . ",dispose,exit:0",
        JoinWorkerCalls(calls),
        "The worker did not finalize before publishing its exit code."
    )
}

TestWorkerFailureResult() {
    local calls := []
    local application := RabbitWorkerApplicationProbe(calls, 7)
    AssertEqual(7, application.Run(["sync"]), "The worker swallowed a maintenance failure.")
    AssertEqual(
        "initialize,workflow,sync,dispose,exit:7",
        JoinWorkerCalls(calls),
        "The failed worker did not release its deployment context."
    )
}

JoinWorkerCalls(calls) {
    local call, result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitWorkerApplicationProbe extends RabbitDeployerWorkerApplication {
    __New(calls, result) {
        super.__New(0)
        this.calls := calls
        this.result := result
        this.context := RabbitWorkerContextProbe(calls)
    }

    CreateWorkflow() {
        this.calls.Push("workflow")
        return RabbitWorkerWorkflowProbe(this.calls, this.result)
    }

    ExitApplication(code) {
        this.calls.Push("exit:" . code)
    }
}

class RabbitWorkerContextProbe {
    __New(calls) {
        this.calls := calls
        this.rime := 0
    }

    Initialize() {
        this.calls.Push("initialize")
    }

    Dispose() {
        this.calls.Push("dispose")
    }
}

class RabbitWorkerWorkflowProbe {
    __New(calls, result) {
        this.calls := calls
        this.result := result
    }

    Deploy(plan) {
        this.calls.Push("deploy:" . plan.Serialize())
        return this.result
    }

    SyncUserData() {
        this.calls.Push("sync")
        return this.result
    }
}
