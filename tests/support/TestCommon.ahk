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
    } catch as err {
        test_failure_count += 1
        if failure_reporter {
            failure_reporter.Call(name, err)
        } else {
            TestReportFailure(name, err)
        }
        return false
    }
    TestWrite("PASS: " . name . "`n")
    return true
}

TestUnhandledError(err, *) {
    global test_failure_count
    test_failure_count += 1
    TestReportFailure("unhandled test error", err)
    ExitApp(1)
    return true
}

TestExit(exit_reason, exit_code) {
    global test_failure_count
    if test_failure_count && exit_code = 0 {
        ExitApp(1)
    }
}

TestReportFailure(name, err) {
    local message := "FAIL: " . name . "`n"
    if !IsObject(err) {
        TestWrite(message . "  Error: " . err . "`n")
        return
    }
    if HasProp(err, "Message") {
        message .= "  Error: " . err.Message . "`n"
    } else {
        message .= "  Error: " . Type(err) . "`n"
    }
    if HasProp(err, "What") && err.What {
        message .= "  What: " . err.What . "`n"
    }
    if HasProp(err, "File") && err.File {
        message .= "  Location: " . err.File
        if HasProp(err, "Line") && err.Line {
            message .= ":" . err.Line
        }
        message .= "`n"
    }
    if HasProp(err, "Stack") && err.Stack {
        message .= "  Stack:`n" . err.Stack . "`n"
    }
    TestWrite(message)
}

TestWrite(message) {
    try {
        FileAppend(message, "*")
    } catch as err {
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
