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
