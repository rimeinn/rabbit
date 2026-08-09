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

global test_failure_count := 0

OnError(TestUnhandledError)
OnExit(TestExit)

RunTest(name, test, failure_reporter := 0) {
    global test_failure_count
    try {
        test.Call()
    } catch as error {
        test_failure_count += 1
        if failure_reporter {
            failure_reporter.Call(name, error)
        } else {
            TestReportFailure(name, error)
        }
        return false
    }
    TestWrite("PASS: " . name . "`n")
    return true
}

TestUnhandledError(error, *) {
    global test_failure_count
    test_failure_count += 1
    TestReportFailure("unhandled test error", error)
    ExitApp(1)
    return true
}

TestExit(exit_reason, exit_code) {
    global test_failure_count
    if test_failure_count && exit_code = 0 {
        ExitApp(1)
    }
}

TestReportFailure(name, error) {
    local message := "FAIL: " . name . "`n"
    if !IsObject(error) {
        TestWrite(message . "  Error: " . error . "`n")
        return
    }
    if HasProp(error, "Message") {
        message .= "  Error: " . error.Message . "`n"
    } else {
        message .= "  Error: " . Type(error) . "`n"
    }
    if HasProp(error, "What") && error.What {
        message .= "  What: " . error.What . "`n"
    }
    if HasProp(error, "File") && error.File {
        message .= "  Location: " . error.File
        if HasProp(error, "Line") && error.Line {
            message .= ":" . error.Line
        }
        message .= "`n"
    }
    if HasProp(error, "Stack") && error.Stack {
        message .= "  Stack:`n" . error.Stack . "`n"
    }
    TestWrite(message)
}

TestWrite(message) {
    try {
        FileAppend(message, "*")
    } catch as error {
        ; A GUI-launched test has no inherited stdout handle.  Preserve the
        ; original test outcome and leave its report available to a debugger.
        OutputDebug(message)
    }
}

AssertTrue(condition, message) {
    if !condition {
        throw Error(message)
    }
}

AssertEqual(expected, actual, message) {
    if expected != actual {
        throw Error(Format("{} Expected: {}. Actual: {}.", message, expected, actual))
    }
}

AssertThrows(callback, message) {
    try {
        callback.Call()
    } catch {
        return
    }
    throw Error(message)
}
