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
#Include ..\..\Lib\RabbitDeployerApplication.ahk

RunTest("interactive deployer rejects modern settings", TestDeployerRejectsModernSettings.Bind())
RunTest("interactive deployer retains legacy settings", TestDeployerRetainsLegacySettings.Bind())
RunTest("standalone deployer releases the application startup gate", TestDeployerReleasesStartupGate.Bind())

TestDeployerRejectsModernSettings() {
    local application := RabbitDeployerApplication(0)
    AssertThrows(
        application.ParseOptions.Bind(application, []),
        "The default deployer invocation still opened modern settings."
    )
    AssertThrows(
        application.ParseOptions.Bind(application, ["settings", "input-schemes", "--install"]),
        "The deployer retained the modern bootstrap settings window."
    )
}

TestDeployerRetainsLegacySettings() {
    local application := RabbitDeployerApplication(0)
    local options := application.ParseOptions(["legacy-settings", "dictionary"])
    AssertEqual("legacy-settings", options.command, "The legacy settings command was rejected.")
    AssertEqual("dictionary", options.target, "The legacy dictionary target was changed.")
}

TestDeployerReleasesStartupGate() {
    local calls := []
    local application := RabbitDeployerApplication(0)
    application.context := RabbitDeployerDisposeProbe(calls, "context")
    application.application_gate := RabbitDeployerDisposeProbe(calls, "gate")
    application.Shutdown()
    application.Shutdown()
    AssertEqual("context,gate", JoinDeployerCalls(calls), "The startup gate was not released after the context.")
}

JoinDeployerCalls(calls) {
    local call, result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitDeployerDisposeProbe {
    __New(calls, label) {
        this.calls := calls
        this.label := label
    }

    Dispose() {
        this.calls.Push(this.label)
    }

    Close() {
        this.calls.Push(this.label)
    }
}
