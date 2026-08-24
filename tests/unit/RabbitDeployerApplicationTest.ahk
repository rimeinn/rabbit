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

TestSettingsWindowOwnership() {
    local calls := []
    local application := RabbitDeployerApplicationProbe(calls)

    AssertEqual(0, application.ShowSettings(), "The settings window returned a failure result.")
    AssertEqual(
        "create,show,wait,dispose",
        JoinSettingsWindowCalls(calls),
        "The deployer application did not own the settings window for its complete lifetime."
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

    CreateSettingsWindow() {
        this.calls.Push("create")
        return RabbitSettingsWindowProbe(this.calls)
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
