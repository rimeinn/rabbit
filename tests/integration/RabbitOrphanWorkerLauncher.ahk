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

#Include ..\..\Lib\RabbitDeploymentCoordinator.ahk

try {
    SetWorkingDir(A_ScriptDir . "\..\..")
    if A_Args.Length != 1 {
        throw ValueError("The orphan worker launcher requires an output path.")
    }
    worker_command := RabbitBuildCommandLine([
        A_AhkPath,
        "/force",
        "/ErrorStdOut",
        A_ScriptDir . "\..\..\Rabbit.ahk",
        "--deployer-worker",
        "deploy",
        "--plan",
        RabbitDeploymentPlan.FullRedeploy().Serialize()
    ])
    worker_pid := 0
    Run(worker_command, A_ScriptDir . "\..\..", "Hide", &worker_pid)
    FileAppend(worker_pid, A_Args[1])
    ExitApp(0)
} catch as err {
    FileAppend(
        "Uncaught exception: " . err.Message . "`n  at " . err.What . "`n  " . err.Line
            . "`nStack:`n" . err.Stack . "`n",
        "*"
    )
    ExitApp(1)
}
