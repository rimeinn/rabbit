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
#Include ..\..\Lib\RabbitDeploymentCoordinator.ahk

RunTest("deployment coordinator supervises a worker", TestCoordinatorWorkerLifecycle.Bind())
RunTest("deployment coordinator restores after worker launch failure", TestCoordinatorLaunchFailure.Bind())
RunTest("deployment coordinator exposes runtime resume failure", TestCoordinatorResumeFailure.Bind())

TestCoordinatorWorkerLifecycle() {
    local calls := []
    local process := RabbitCoordinatorProcessProbe(calls, [true, false], 0)
    local settings := RabbitCoordinatorSettingsProbe(calls)
    local coordinator := RabbitDeploymentCoordinatorProbe(
        settings,
        (*) => calls.Push("stop"),
        (*) => (calls.Push("start"), true),
        (result, resumed) => calls.Push("result:" . result . ":" . resumed),
        process,
        calls
    )
    AssertTrue(coordinator.Submit(RabbitDeploymentPlan.RabbitConfig()), "The deployment was rejected.")
    AssertTrue(!coordinator.SubmitSync(), "A concurrent maintenance operation was accepted.")
    coordinator.BeginOperation()
    AssertEqual(
        RabbitDeploymentCoordinator.WORKER_RUNNING,
        coordinator.state,
        "The coordinator did not enter the worker state."
    )
    coordinator.PollWorker()
    AssertEqual(
        RabbitDeploymentCoordinator.WORKER_RUNNING,
        coordinator.state,
        "The coordinator treated a running worker as complete."
    )
    coordinator.PollWorker()
    AssertEqual(RabbitDeploymentCoordinator.IDLE, coordinator.state, "The coordinator did not return to idle.")
    AssertEqual(
        "begin:deploy,prepare,stop,launch:deploy:v1|rabbit,poll,poll,exit,close,start,resume:0,result:0:1",
        JoinCoordinatorCalls(calls),
        "The coordinator violated the maintenance ownership order."
    )
}

TestCoordinatorLaunchFailure() {
    local calls := []
    local coordinator := RabbitDeploymentCoordinatorProbe(
        RabbitCoordinatorSettingsProbe(calls),
        (*) => calls.Push("stop"),
        (*) => (calls.Push("start"), true),
        (result, resumed) => calls.Push("result:" . result . ":" . resumed),
        0,
        calls,
        true
    )
    AssertTrue(coordinator.SubmitSync(), "Synchronization was rejected.")
    coordinator.BeginOperation()
    AssertEqual(RabbitDeploymentCoordinator.IDLE, coordinator.state, "Launch failure left the coordinator busy.")
    AssertEqual(
        "begin:sync,prepare,stop,launch:sync:,start,resume:1,result:1:1",
        JoinCoordinatorCalls(calls),
        "Worker launch failure did not restore the frontend runtime."
    )
}

TestCoordinatorResumeFailure() {
    local calls := [], allow_start := false
    local coordinator := RabbitDeploymentCoordinatorProbe(
        RabbitCoordinatorSettingsProbe(calls),
        (*) => calls.Push("stop"),
        (*) => (calls.Push("start"), allow_start),
        (result, resumed) => calls.Push("result:" . result . ":" . resumed),
        RabbitCoordinatorProcessProbe(calls, [false], 5),
        calls
    )
    coordinator.Submit(RabbitDeploymentPlan.RabbitConfig())
    coordinator.BeginOperation()
    coordinator.PollWorker()
    AssertEqual(
        RabbitDeploymentCoordinator.FAILED_TO_RESUME,
        coordinator.state,
        "Runtime restart failure was not retained."
    )
    allow_start := true
    AssertTrue(coordinator.RetryResume(), "The coordinator could not retry runtime recovery.")
    AssertEqual(RabbitDeploymentCoordinator.IDLE, coordinator.state, "Recovery retry did not return to idle.")
    AssertEqual(2, CountCoordinatorCalls(calls, "start"), "Runtime recovery was not retried exactly once.")
    AssertEqual(1, CountCoordinatorCalls(calls, "resume_failed"), "The settings UI did not receive the failure.")
}

JoinCoordinatorCalls(calls) {
    local call, result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

CountCoordinatorCalls(calls, expected) {
    local call, count := 0
    for call in calls {
        if call = expected {
            count += 1
        }
    }
    return count
}

class RabbitDeploymentCoordinatorProbe extends RabbitDeploymentCoordinator {
    __New(settings, stop_callback, start_callback, result_callback, process, calls, fail_launch := false) {
        super.__New(settings, stop_callback, start_callback, result_callback)
        this.test_process := process
        this.calls := calls
        this.fail_launch := fail_launch
    }

    ScheduleBegin() {
    }

    SchedulePoll() {
    }

    CreateWorkerProcess(operation, plan, payload := 0) {
        this.calls.Push("launch:" . operation . ":" . (plan ? plan.Serialize() : ""))
        if this.fail_launch {
            throw Error("Injected worker launch failure.")
        }
        return this.test_process
    }
}

class RabbitCoordinatorSettingsProbe {
    __New(calls) {
        this.calls := calls
    }

    BeginMaintenance(operation) {
        this.calls.Push("begin:" . operation)
    }

    PrepareForMaintenance() {
        this.calls.Push("prepare")
        return true
    }

    ResumeAfterMaintenance(result) {
        this.calls.Push("resume:" . result)
    }

    RuntimeResumeFailed(*) {
        this.calls.Push("resume_failed")
    }
}

class RabbitCoordinatorProcessProbe {
    __New(calls, running_values, exit_code) {
        this.calls := calls
        this.running_values := running_values
        this.exit_code := exit_code
        this.index := 0
    }

    IsRunning() {
        this.calls.Push("poll")
        this.index += 1
        return this.running_values[this.index]
    }

    ExitCode() {
        this.calls.Push("exit")
        return this.exit_code
    }

    Close() {
        this.calls.Push("close")
    }
}
