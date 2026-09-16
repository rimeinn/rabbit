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

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\..\Lib\RabbitApplication.ahk
#Include ..\support\RabbitTestCommon.ahk

global runtime_maintenance_application := 0
global runtime_maintenance_hwnd := 0
global runtime_maintenance_started := false
global runtime_maintenance_observed := false
global runtime_maintenance_client := 0
global runtime_maintenance_deadline := 0

try {
    SetWorkingDir(A_ScriptDir . "\..\..")
    RunRuntimeMaintenanceIntegration()
} catch as err {
    ReportRuntimeMaintenanceFailure(err)
}

RunRuntimeMaintenanceIntegration() {
    global runtime_maintenance_application
    global runtime_maintenance_deadline
    local rime_path := A_ScriptDir . "\..\..\Lib\librime-ahk\rime.dll"
    runtime_maintenance_application := RabbitRuntimeMaintenanceApplication(RimeApi(rime_path))
    runtime_maintenance_application.Run(["--maintenance", "none"])
    runtime_maintenance_deadline := A_TickCount + 30000
    SetTimer(StartRuntimeMaintenanceRequest, -100)
    SetTimer(CheckRuntimeMaintenanceTimeout, 250)
}

StartRuntimeMaintenanceRequest() {
    global runtime_maintenance_application
    global runtime_maintenance_hwnd
    global runtime_maintenance_started
    global runtime_maintenance_client
    try {
        if !runtime_maintenance_application.runtime || !runtime_maintenance_application.runtime.started {
            throw Error("The initial frontend runtime did not start.")
        }
        runtime_maintenance_application.settings.Show("maintenance")
        runtime_maintenance_hwnd := runtime_maintenance_application.settings.window.Hwnd
        local command_line := RabbitBuildCommandLine([
            A_AhkPath,
            "/force",
            A_ScriptDir . "\RabbitExternalMaintenanceClient.ahk"
        ])
        local client_pid := 0
        Run(command_line, A_ScriptDir . "\..\..", "Hide", &client_pid)
        runtime_maintenance_client := RabbitWorkerProcess(client_pid)
        if !runtime_maintenance_client.handle {
            throw Error("The external maintenance client did not start.")
        }
        runtime_maintenance_started := true
        SetTimer(CheckRuntimeMaintenanceComplete, 100)
    } catch as err {
        ReportRuntimeMaintenanceFailure(err)
    }
}

CheckRuntimeMaintenanceComplete() {
    global runtime_maintenance_application
    global runtime_maintenance_hwnd
    global runtime_maintenance_started
    global runtime_maintenance_observed
    global runtime_maintenance_client
    if !runtime_maintenance_started
        return
    try {
        if runtime_maintenance_application.coordinator.state != RabbitDeploymentCoordinator.IDLE {
            runtime_maintenance_observed := true
        }
        if runtime_maintenance_client {
            if runtime_maintenance_client.IsRunning() {
                return
            }
            local client_result := runtime_maintenance_client.ExitCode()
            runtime_maintenance_client.Close()
            runtime_maintenance_client := 0
            if client_result != 0 {
                throw Error("The external deployer command was not accepted by the resident application.")
            }
        }
        if runtime_maintenance_application.coordinator.state != RabbitDeploymentCoordinator.IDLE {
            return
        }
        SetTimer(CheckRuntimeMaintenanceComplete, 0)
        SetTimer(CheckRuntimeMaintenanceTimeout, 0)
        if !runtime_maintenance_application.runtime || !runtime_maintenance_application.runtime.started {
            throw Error("The frontend runtime did not recover after deployment.")
        }
        if !runtime_maintenance_observed {
            throw Error("The external deployer command did not start resident maintenance.")
        }
        if !runtime_maintenance_application.settings.window
            || runtime_maintenance_application.settings.window.Hwnd != runtime_maintenance_hwnd {
            throw Error("Deployment replaced the top-level settings window.")
        }
        FileAppend("PASS: resident runtime maintenance lifecycle`n", "*")
        runtime_maintenance_application.Shutdown()
        ExitApp(0)
    } catch as err {
        ReportRuntimeMaintenanceFailure(err)
    }
}

CheckRuntimeMaintenanceTimeout() {
    global runtime_maintenance_deadline
    if A_TickCount <= runtime_maintenance_deadline {
        return
    }
    ReportRuntimeMaintenanceFailure(Error("Runtime maintenance integration timed out."))
}

ReportRuntimeMaintenanceFailure(err) {
    global runtime_maintenance_application
    global runtime_maintenance_client
    SetTimer(StartRuntimeMaintenanceRequest, 0)
    SetTimer(CheckRuntimeMaintenanceComplete, 0)
    SetTimer(CheckRuntimeMaintenanceTimeout, 0)
    FileAppend(
        "FAIL: resident runtime maintenance lifecycle`n  Error: " . err.Message
            . "`n  at " . err.What . "`n  " . err.Line . "`nStack:`n" . err.Stack . "`n",
        "*"
    )
    if runtime_maintenance_application {
        try runtime_maintenance_application.Shutdown(1)
    }
    if runtime_maintenance_client {
        try runtime_maintenance_client.Close()
    }
    ExitApp(1)
}

class RabbitRuntimeMaintenanceApplication extends RabbitApplication {
    CreateDeploymentCoordinator() {
        return RabbitRuntimeMaintenanceCoordinator(
            this.settings,
            this.StopFrontendRuntime.Bind(this),
            this.StartFrontendRuntime.Bind(this),
            this.OnMaintenanceComplete.Bind(this)
        )
    }
}

class RabbitRuntimeMaintenanceCoordinator extends RabbitDeploymentCoordinator {
    CreateWorkerProcess(operation, plan, payload := 0) {
        if operation != "deploy" {
            throw ValueError("The runtime maintenance integration only supports deployment.")
        }
        local command_line := RabbitBuildCommandLine([
            A_AhkPath,
            "/force",
            "/ErrorStdOut",
            A_ScriptDir . "\..\..\Rabbit.ahk",
            "--deployer-worker",
            "deploy",
            "--plan",
            plan.Serialize()
        ])
        local worker_pid := 0
        Run(command_line, A_ScriptDir . "\..\..", "Hide", &worker_pid)
        return RabbitWorkerProcess(worker_pid)
    }
}
