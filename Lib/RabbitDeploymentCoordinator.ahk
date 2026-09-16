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

#Include RabbitCommandLine.ahk
#Include RabbitCommon.ahk
#Include RabbitDeploymentPlan.ahk

RabbitLaunchDeployerWorker(operation, plan := 0, payload := 0) {
    local command_line := []
    if A_IsCompiled {
        command_line.Push(A_ScriptFullPath, "/force")
    } else {
        command_line.Push(A_AhkPath, "/force", A_ScriptFullPath)
    }
    command_line.Push("--deployer-worker", operation)
    if operation = "deploy" {
        if !(plan is RabbitDeploymentPlan) {
            throw TypeError("Expected a RabbitDeploymentPlan.")
        }
        command_line.Push("--plan", plan.Serialize())
    } else if operation = "dictionary" {
        command_line.Push("--action", payload.action)
        if payload.dictionary_name {
            command_line.Push("--dictionary", payload.dictionary_name)
        }
        if payload.path {
            command_line.Push("--path", payload.path)
        }
    }
    local pid := 0
    Run(RabbitBuildCommandLine(command_line), , "Hide", &pid)
    return RabbitWorkerProcess(pid)
}

class RabbitWorkerProcess {
    static STILL_ACTIVE := 259
    static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000

    __New(pid) {
        this.pid := pid
        this.handle := DllCall(
            "OpenProcess",
            "UInt",
            RabbitWorkerProcess.PROCESS_QUERY_LIMITED_INFORMATION,
            "Int",
            false,
            "UInt",
            pid,
            "Ptr"
        )
        if !this.handle {
            throw OSError(A_LastError, "OpenProcess")
        }
        this.closed := false
    }

    ExitCode() {
        if this.closed {
            throw Error("The worker process handle is closed.")
        }
        local exit_code := 0
        if !DllCall("GetExitCodeProcess", "Ptr", this.handle, "UInt*", &exit_code) {
            throw OSError(A_LastError, "GetExitCodeProcess")
        }
        return exit_code
    }

    IsRunning() {
        return this.ExitCode() = RabbitWorkerProcess.STILL_ACTIVE
    }

    Close() {
        if this.closed {
            return
        }
        this.closed := true
        if this.handle {
            DllCall("CloseHandle", "Ptr", this.handle)
            this.handle := 0
        }
    }
}

class RabbitDeploymentCoordinator {
    static IDLE := "idle"
    static PREPARING := "preparing"
    static STOPPING_RUNTIME := "stopping_runtime"
    static WORKER_RUNNING := "worker_running"
    static RESUMING_RUNTIME := "resuming_runtime"
    static REFRESHING_SETTINGS := "refreshing_settings"
    static FAILED_TO_RESUME := "failed_to_resume"

    __New(settings_controller, stop_runtime_callback, start_runtime_callback, result_callback := 0) {
        this.settings := settings_controller
        this.stop_runtime_callback := stop_runtime_callback
        this.start_runtime_callback := start_runtime_callback
        this.result_callback := result_callback
        this.state := RabbitDeploymentCoordinator.IDLE
        this.operation := ""
        this.plan := 0
        this.payload := 0
        this.completion_callback := 0
        this.process := 0
        this.runtime_stopped := false
        this.disposed := false
        this.begin_callback := this.BeginOperation.Bind(this)
        this.poll_callback := this.PollWorker.Bind(this)
    }

    Submit(plan, completion_callback := 0) {
        if !(plan is RabbitDeploymentPlan) {
            throw TypeError("Expected a RabbitDeploymentPlan.")
        }
        if plan.IsEmpty() {
            if completion_callback {
                completion_callback.Call(0, true)
            }
            return true
        }
        return this.SubmitOperation(
            "deploy",
            RabbitDeploymentPlan.Parse(plan.Serialize()),
            completion_callback
        )
    }

    SubmitSync(completion_callback := 0) {
        return this.SubmitOperation("sync", 0, completion_callback)
    }

    SubmitDictionary(action, dictionary_name := "", path := "", completion_callback := 0) {
        return this.SubmitOperation(
            "dictionary",
            0,
            completion_callback,
            {action: action, dictionary_name: dictionary_name, path: path}
        )
    }

    SubmitOperation(operation, plan, completion_callback, payload := 0) {
        if this.disposed || this.state != RabbitDeploymentCoordinator.IDLE {
            return false
        }
        this.operation := operation
        this.plan := plan
        this.payload := payload
        this.completion_callback := completion_callback
        this.runtime_stopped := false
        this.state := RabbitDeploymentCoordinator.PREPARING
        if this.settings && HasMethod(this.settings, "BeginMaintenance") {
            this.settings.BeginMaintenance(operation)
        }
        this.ScheduleBegin()
        return true
    }

    ScheduleBegin() {
        SetTimer(this.begin_callback, -50)
    }

    BeginOperation() {
        if this.disposed || this.state != RabbitDeploymentCoordinator.PREPARING {
            return
        }
        try {
            if this.settings && HasMethod(this.settings, "PrepareForMaintenance")
                && !this.settings.PrepareForMaintenance() {
                this.FinishWithoutWorker(1)
                return
            }
            this.state := RabbitDeploymentCoordinator.STOPPING_RUNTIME
            ; Stop may finish shutting the runtime down before a cleanup error
            ; escapes.  Recovery must still attempt to restart that runtime.
            this.runtime_stopped := true
            this.stop_runtime_callback.Call()
            this.process := this.CreateWorkerProcess(this.operation, this.plan, this.payload)
            this.state := RabbitDeploymentCoordinator.WORKER_RUNNING
            this.SchedulePoll()
        } catch as err {
            RabbitError(err.Message, Format("RabbitDeploymentCoordinator.ahk:{}", A_LineNumber))
            this.ResumeRuntime(1)
        }
    }

    CreateWorkerProcess(operation, plan, payload := 0) {
        return RabbitLaunchDeployerWorker(operation, plan, payload)
    }

    SchedulePoll() {
        SetTimer(this.poll_callback, 100)
    }

    PollWorker() {
        if this.disposed || this.state != RabbitDeploymentCoordinator.WORKER_RUNNING || !this.process {
            return
        }
        try {
            if this.process.IsRunning() {
                return
            }
            local result := this.process.ExitCode()
            SetTimer(this.poll_callback, 0)
            this.process.Close()
            this.process := 0
            this.ResumeRuntime(result)
        } catch as err {
            RabbitError(err.Message, Format("RabbitDeploymentCoordinator.ahk:{}", A_LineNumber))
            SetTimer(this.poll_callback, 0)
            if this.process {
                this.process.Close()
                this.process := 0
            }
            this.ResumeRuntime(1)
        }
    }

    FinishWithoutWorker(result) {
        if this.settings && HasMethod(this.settings, "ResumeAfterMaintenance") {
            this.settings.ResumeAfterMaintenance(result)
        }
        this.Finish(result, true)
    }

    ResumeRuntime(result) {
        this.state := RabbitDeploymentCoordinator.RESUMING_RUNTIME
        try {
            if this.runtime_stopped && !this.start_runtime_callback.Call() {
                throw Error("The frontend runtime did not restart.")
            }
            this.runtime_stopped := false
            this.state := RabbitDeploymentCoordinator.REFRESHING_SETTINGS
            if this.settings && HasMethod(this.settings, "ResumeAfterMaintenance") {
                this.settings.ResumeAfterMaintenance(result)
            }
            this.Finish(result, true)
        } catch as err {
            RabbitError(err.Message, Format("RabbitDeploymentCoordinator.ahk:{}", A_LineNumber))
            this.state := RabbitDeploymentCoordinator.FAILED_TO_RESUME
            if this.settings && HasMethod(this.settings, "RuntimeResumeFailed") {
                this.settings.RuntimeResumeFailed(err)
            }
            this.NotifyCompletion(result, false)
        }
    }

    RetryResume() {
        if this.state != RabbitDeploymentCoordinator.FAILED_TO_RESUME {
            return false
        }
        this.runtime_stopped := true
        this.ResumeRuntime(1)
        return this.state = RabbitDeploymentCoordinator.IDLE
    }

    Finish(result, resumed) {
        this.NotifyCompletion(result, resumed)
        this.operation := ""
        this.plan := 0
        this.payload := 0
        this.completion_callback := 0
        this.state := RabbitDeploymentCoordinator.IDLE
    }

    NotifyCompletion(result, resumed) {
        if this.completion_callback {
            this.completion_callback.Call(result, resumed)
        }
        if this.result_callback {
            this.result_callback.Call(result, resumed)
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        SetTimer(this.begin_callback, 0)
        SetTimer(this.poll_callback, 0)
        if this.process {
            this.process.Close()
            this.process := 0
        }
    }
}
