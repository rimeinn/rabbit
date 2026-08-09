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

OnError(TestUnhandledError)

RunTest(name, test) {
    test.Call()
    FileAppend("PASS: " . name . "`n", "*")
}

TestUnhandledError(error, *) {
    local message := "FAIL: " . error.Message
    if error.File {
        message .= " (" . error.File . ":" . error.Line . ")"
    }
    FileAppend(message . "`n", "*")
    ExitApp(1)
    return true
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
