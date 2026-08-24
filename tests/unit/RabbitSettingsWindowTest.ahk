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
#Include ..\..\Lib\RabbitSettingsWindow.ahk

RunTest("settings window navigation", TestSettingsWindowNavigation.Bind())
RunTest("settings window rejects invalid page", TestSettingsWindowRejectsInvalidPage.Bind())
RunTest("settings window maintenance actions", TestSettingsWindowMaintenanceActions.Bind())

TestSettingsWindowNavigation() {
    local window := RabbitSettingsWindow()
    try {
        AssertEqual(1, window.selected_page, "The settings window did not select its first page.")
        AssertEqual("外观", window.page_title.Value, "The settings window showed the wrong first page.")
        AssertTrue(window.SelectPage(4), "The settings window rejected a valid page.")
        AssertEqual(4, window.selected_page, "The settings window did not update its selected page.")
        AssertEqual("应用适配", window.page_title.Value, "The settings window showed the wrong selected page.")
    } finally {
        window.Dispose()
    }
}

TestSettingsWindowRejectsInvalidPage() {
    local window := RabbitSettingsWindow()
    try {
        AssertTrue(!window.SelectPage(0), "The settings window accepted an invalid page.")
        AssertEqual(1, window.selected_page, "An invalid page changed the settings selection.")
    } finally {
        window.Dispose()
        window.Dispose()
    }
}

TestSettingsWindowMaintenanceActions() {
    local calls := []
    local window := RabbitSettingsWindow(RabbitSettingsWorkflowProbe(calls))
    try {
        AssertTrue(window.RunDeploy(), "The settings window reported a deployment failure.")
        AssertTrue(window.RunSync(), "The settings window reported a synchronization failure.")
        AssertTrue(window.RunDictionaryManagement(), "The settings window reported a dictionary failure.")
        AssertEqual(
            "deploy,sync,dict",
            JoinSettingsWorkflowCalls(calls),
            "The settings window invoked the wrong maintenance actions."
        )
    } finally {
        window.Dispose()
    }
}

JoinSettingsWorkflowCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitSettingsWorkflowProbe {
    __New(calls) {
        this.calls := calls
    }

    UpdateWorkspace(report_errors := false) {
        this.calls.Push("deploy")
        return 0
    }

    SyncUserData() {
        this.calls.Push("sync")
        return 0
    }

    DictManagement() {
        this.calls.Push("dict")
        return 0
    }
}
