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
#Include ..\..\Lib\RabbitCommon.ahk

RunTest("application and deployment mutexes are independent", TestIndependentMutexes.Bind())

TestIndependentMutexes() {
    local application := RabbitApplicationMutex()
    local duplicate_application := RabbitApplicationMutex()
    local deployment := RabbitDeploymentMutex()
    try {
        AssertTrue(application.Create(), "The application mutex could not be created.")
        AssertEqual(0, application.lasterr, "The application mutex already existed before the test.")
        AssertTrue(deployment.Create(), "The deployment mutex could not be created beside the application mutex.")
        AssertEqual(0, deployment.lasterr, "The application mutex blocked the deployment mutex.")
        AssertTrue(duplicate_application.Create(), "The duplicate application mutex did not return a handle.")
        AssertEqual(
            ERROR_ALREADY_EXISTS,
            duplicate_application.lasterr,
            "A second application mutex was not reported as an existing instance."
        )
    } finally {
        duplicate_application.Close()
        deployment.Close()
        application.Close()
    }
}
