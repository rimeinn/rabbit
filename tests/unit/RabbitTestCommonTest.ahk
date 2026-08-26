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

RunTest("test runner captures callback exceptions", TestRunTestCapturesCallbackExceptions.Bind())

TestRunTestCapturesCallbackExceptions() {
    global test_failure_count
    local failure_count := test_failure_count
    local reported := []
    try {
        local passed := RunTest(
            "intentional callback exception",
            TestThrowCallbackException,
            TestCaptureFailure.Bind(reported)
        )
        AssertTrue(!passed, "RunTest did not report a callback exception as a failed test.")
        AssertEqual(
            "intentional callback exception: callback exception",
            reported[1],
            "RunTest did not send the callback exception to its failure reporter."
        )
    } finally {
        test_failure_count := failure_count
    }
}

TestThrowCallbackException() {
    throw Error("callback exception")
}

TestCaptureFailure(reported, name, err) {
    reported.Push(name . ": " . err.Message)
}
