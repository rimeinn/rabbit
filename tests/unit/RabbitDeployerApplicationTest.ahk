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
 *
 */

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitDeployerApplication.ahk

RunTest("settings window ownership", TestSettingsWindowOwnership.Bind())
RunTest("old Windows uses legacy deployer", TestOldWindowsUsesLegacyDeployer.Bind())
RunTest("deployer validates settings page IDs", TestDeployerValidatesSettingsPageIds.Bind())
RunTest("old Windows redirects dictionary settings", TestOldWindowsRedirectsDictionarySettings.Bind())

TestSettingsWindowOwnership() {
    local calls := []
    local application := RabbitDeployerApplicationProbe(calls)

    AssertEqual(0, application.ShowSettings("input-schemes", true), "The settings window returned a failure result.")
    AssertEqual(
        "create:input-schemes:1,show,wait,dispose",
        JoinSettingsWindowCalls(calls),
        "The deployer application did not own the settings window for its complete lifetime."
    )
}

TestDeployerValidatesSettingsPageIds() {
    local application := RabbitDeployerApplicationProbe([])
    local options := application.ParseOptions([])
    AssertEqual("settings", options.command, "No arguments did not select unified settings.")
    AssertEqual("", options.target, "No arguments were mapped to a named page.")

    options := application.ParseOptions(["settings", "about"])
    AssertEqual("about", options.target, "A stable settings page ID was rejected.")
    AssertThrows(
        application.ParseOptions.Bind(application, ["settings", "missing-page"]),
        "The deployer accepted an unknown settings page."
    )
}

TestOldWindowsRedirectsDictionarySettings() {
    local calls := []
    local application := RabbitLegacyDeployerApplicationProbe(calls)

    AssertEqual(8, application.ShowSettings("dictionary"), "The legacy dictionary result was not returned.")
    AssertEqual(
        "dictionary",
        JoinSettingsWindowCalls(calls),
        "Old Windows did not redirect unified dictionary settings to the legacy dialog."
    )
}

TestOldWindowsUsesLegacyDeployer() {
    local calls := []
    local application := RabbitLegacyDeployerApplicationProbe(calls)

    AssertEqual(7, application.ShowSettings(), "The legacy deployer result was not returned.")
    AssertEqual(
        "legacy:0",
        JoinSettingsWindowCalls(calls),
        "The old-Windows settings path constructed the new settings window."
    )
}

JoinSettingsWindowCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitDeployerApplicationProbe extends RabbitDeployerApplication {
    __New(calls) {
        this.calls := calls
        super.__New(0)
    }

    CreateSettingsWindow(page_id := "", installing := false) {
        this.calls.Push("create:" . page_id . ":" . installing)
        return RabbitSettingsWindowProbe(this.calls)
    }

    UseLegacySettings() {
        return false
    }
}

class RabbitLegacyDeployerApplicationProbe extends RabbitDeployerApplication {
    __New(calls) {
        this.calls := calls
        super.__New(0)
        this.workflow := RabbitLegacySettingsWorkflowProbe(calls)
    }

    CreateSettingsWindow() {
        this.calls.Push("create")
        throw Error("The new settings window must not be created on old Windows.")
    }

    UseLegacySettings() {
        return true
    }
}

class RabbitLegacySettingsWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    Run(installing) {
        this.calls.Push("legacy:" . installing)
        return 7
    }

    DictManagement() {
        this.calls.Push("dictionary")
        return 8
    }
}

class RabbitSettingsWindowProbe {
    __New(calls) {
        this.calls := calls
    }

    Show(options) {
        this.calls.Push("show")
    }

    WaitClose() {
        this.calls.Push("wait")
    }

    Dispose() {
        this.calls.Push("dispose")
    }
}
