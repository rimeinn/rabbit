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
#Include ..\..\Lib\RabbitMaintenanceIpc.ahk

RunTest("maintenance IPC validates and deduplicates requests", TestMaintenanceIpcValidation.Bind())
RunTest("maintenance IPC reports busy requests", TestMaintenanceIpcBusy.Bind())
RunTest("maintenance IPC guards standalone deployment from application startup", TestApplicationStartupGate.Bind())
RunTest("maintenance IPC creates unpredictable request tokens", TestMaintenanceIpcToken.Bind())

TestMaintenanceIpcValidation() {
    local calls := []
    local token := "00112233445566778899aabbccddeeff"
    local request_id := "ffeeddccbbaa99887766554433221100"
    local server := RabbitMaintenanceIpcServerProbe(
        token,
        (operation, plan := 0) => (calls.Push(operation . ":" . plan.Serialize()), true)
    )
    local payload := RabbitMaintenanceIpcClient.BuildPayload(
        42,
        request_id,
        token,
        "deploy",
        "v1|rabbit|schema:demo"
    )
    AssertEqual(
        RabbitMaintenanceIpcServer.ACCEPTED,
        server.HandleRequest(payload, 42),
        "A valid maintenance request was rejected."
    )
    AssertEqual(
        RabbitMaintenanceIpcServer.ACCEPTED,
        server.HandleRequest(payload, 42),
        "A duplicate request did not return its original result."
    )
    AssertEqual(1, calls.Length, "A duplicate maintenance request was submitted twice.")
    AssertEqual("deploy:v1|rabbit|schema:demo", calls[1], "The IPC request changed its deployment plan.")
    AssertEqual(
        RabbitMaintenanceIpcServer.INVALID,
        server.HandleRequest(payload, 43),
        "The IPC server accepted a mismatched sender PID."
    )
    AssertEqual(
        RabbitMaintenanceIpcServer.INVALID,
        server.HandleRequest(StrReplace(payload, token, "00000000000000000000000000000000"), 42),
        "The IPC server accepted a mismatched token."
    )
}

TestMaintenanceIpcBusy() {
    local token := "00112233445566778899aabbccddeeff"
    local server := RabbitMaintenanceIpcServerProbe(token, (*) => false)
    local payload := RabbitMaintenanceIpcClient.BuildPayload(
        42,
        "ffeeddccbbaa99887766554433221100",
        token,
        "sync",
        "v1"
    )
    AssertEqual(
        RabbitMaintenanceIpcServer.BUSY,
        server.HandleRequest(payload, 42),
        "The IPC server did not report a busy coordinator."
    )
}

TestApplicationStartupGate() {
    local application_mutex := RabbitApplicationMutex()
    try {
        AssertTrue(application_mutex.Create(), "The application mutex could not be created.")
        AssertEqual(
            0,
            RabbitAcquireApplicationStartupGate(),
            "Standalone deployment acquired the startup gate beside a resident application."
        )
    } finally {
        application_mutex.Close()
    }
    local startup_gate := RabbitAcquireApplicationStartupGate()
    AssertTrue(startup_gate is RabbitApplicationMutex, "Standalone deployment could not acquire the startup gate.")
    startup_gate.Close()
}

TestMaintenanceIpcToken() {
    local first_token := RabbitCreateIpcToken()
    local second_token := RabbitCreateIpcToken()
    AssertTrue(RegExMatch(first_token, "^[0-9a-f]{32}$"), "The first IPC token has an invalid format.")
    AssertTrue(RegExMatch(second_token, "^[0-9a-f]{32}$"), "The second IPC token has an invalid format.")
    AssertTrue(first_token != second_token, "Two IPC tokens unexpectedly matched.")
}

class RabbitMaintenanceIpcServerProbe extends RabbitMaintenanceIpcServer {
    __New(token, submit_callback) {
        this.token := token
        this.submit_callback := submit_callback
        this.requests := Map()
        this.disposed := false
    }
}
