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

global worker_recovery_launcher := 0
global worker_recovery_worker := 0
global worker_recovery_application := 0
global worker_recovery_pid_path := A_Temp . "\rabbit-worker-recovery-" . ProcessExist() . ".pid"
global worker_recovery_stage := "launcher"
global worker_recovery_deadline := 0

try {
    SetWorkingDir(A_ScriptDir . "\..\..")
    StartWorkerRecoveryIntegration()
} catch as err {
    ReportWorkerRecoveryFailure(err)
}

StartWorkerRecoveryIntegration() {
    global worker_recovery_launcher
    global worker_recovery_pid_path
    global worker_recovery_deadline
    if FileExist(worker_recovery_pid_path) {
        FileDelete(worker_recovery_pid_path)
    }
    local command_line := RabbitBuildCommandLine([
        A_AhkPath,
        "/force",
        A_ScriptDir . "\RabbitOrphanWorkerLauncher.ahk",
        worker_recovery_pid_path
    ])
    local launcher_pid := 0
    Run(command_line, A_ScriptDir . "\..\..", "Hide", &launcher_pid)
    worker_recovery_launcher := RabbitWorkerProcess(launcher_pid)
    worker_recovery_deadline := A_TickCount + 30000
    SetTimer(PollWorkerRecovery, 100)
    SetTimer(CheckWorkerRecoveryTimeout, 250)
}

PollWorkerRecovery() {
    global worker_recovery_launcher
    global worker_recovery_worker
    global worker_recovery_application
    global worker_recovery_pid_path
    global worker_recovery_stage
    try {
        if worker_recovery_stage = "launcher" {
            if worker_recovery_launcher.IsRunning() {
                return
            }
            local launcher_result := worker_recovery_launcher.ExitCode()
            worker_recovery_launcher.Close()
            worker_recovery_launcher := 0
            if launcher_result != 0 || !FileExist(worker_recovery_pid_path) {
                throw Error("The orphan worker launcher failed.")
            }
            local worker_pid := Integer(Trim(FileRead(worker_recovery_pid_path)))
            worker_recovery_worker := RabbitWorkerProcess(worker_pid)
            if !worker_recovery_worker.IsRunning() {
                throw Error(
                    "The maintenance worker exited with its launcher (exit code "
                        . worker_recovery_worker.ExitCode() . ")."
                )
            }
            worker_recovery_stage := "worker"
            return
        }
        if worker_recovery_worker.IsRunning() {
            return
        }
        local worker_result := worker_recovery_worker.ExitCode()
        worker_recovery_worker.Close()
        worker_recovery_worker := 0
        if worker_result != 0 {
            throw Error("The orphaned maintenance worker failed.")
        }
        worker_recovery_application := RabbitApplication(
            RimeApi(A_ScriptDir . "\..\..\Lib\librime-ahk\rime.dll")
        )
        worker_recovery_application.Run(["--maintenance", "none"])
        if !worker_recovery_application.runtime || !worker_recovery_application.runtime.started {
            throw Error("Rabbit did not restart after the orphaned worker completed.")
        }
        SetTimer(PollWorkerRecovery, 0)
        SetTimer(CheckWorkerRecoveryTimeout, 0)
        FileAppend("PASS: orphan worker completion and application recovery`n", "*")
        CleanupWorkerRecovery()
        ExitApp(0)
    } catch as err {
        ReportWorkerRecoveryFailure(err)
    }
}

CheckWorkerRecoveryTimeout() {
    global worker_recovery_deadline
    if A_TickCount <= worker_recovery_deadline {
        return
    }
    ReportWorkerRecoveryFailure(Error("Worker recovery integration timed out."))
}

CleanupWorkerRecovery() {
    global worker_recovery_launcher
    global worker_recovery_worker
    global worker_recovery_application
    global worker_recovery_pid_path
    if worker_recovery_application {
        try worker_recovery_application.Shutdown(1)
        worker_recovery_application := 0
    }
    if worker_recovery_launcher {
        try worker_recovery_launcher.Close()
        worker_recovery_launcher := 0
    }
    if worker_recovery_worker {
        try worker_recovery_worker.Close()
        worker_recovery_worker := 0
    }
    if FileExist(worker_recovery_pid_path) {
        try FileDelete(worker_recovery_pid_path)
    }
}

ReportWorkerRecoveryFailure(err) {
    SetTimer(PollWorkerRecovery, 0)
    SetTimer(CheckWorkerRecoveryTimeout, 0)
    FileAppend(
        "FAIL: orphan worker completion and application recovery`n  Error: " . err.Message
            . "`n  at " . err.What . "`n  " . err.Line . "`nStack:`n" . err.Stack . "`n",
        "*"
    )
    CleanupWorkerRecovery()
    ExitApp(1)
}
