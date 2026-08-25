/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
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
#Include ..\..\Lib\RabbitNativeListView.ahk

RunTest("Native ListView protocol is detected", TestNativeListViewIsDetected.Bind())
RunTest("Standard ListView HWND passes the native probe", TestStandardListViewHwndIsDetected.Bind())
RunTest("Headerless controls skip ListView messages", TestHeaderlessControlSkipsQuery.Bind())
RunTest("Mismatched ListView headers are rejected", TestMismatchedListViewHeaderIsRejected.Bind())
RunTest("Native ListView matches avoid repeated messages", TestNativeListViewMatchIsCached.Bind())
RunTest("Native ListView timeouts use a retry cooldown", TestNativeListViewTimeoutUsesCooldown.Bind())
RunTest("Native ListView cache is scoped to the focused target", TestNativeListViewCacheIsTargetScoped.Bind())

TestNativeListViewIsDetected() {
    local detector := RabbitNativeListViewDetectorProbe()
    detector.header_hwnd := 200
    detector.actual_header_hwnd := 200
    AssertEqual(
        true,
        detector.IsCompatible(CreateNativeListViewDescriptor()),
        "A compatible native ListView was not detected."
    )
}

TestStandardListViewHwndIsDetected() {
    local test_gui := Gui()
    try {
        local list_view := test_gui.Add("ListView", "w200 h100", ["Name"])
        list_view.Add("", "file.txt")
        local descriptor := {
            active_hwnd: list_view.Hwnd,
            focus_hwnd: list_view.Hwnd,
            process_id: DllCall("GetCurrentProcessId", "UInt"),
            focus_classes: [StrLower(WinGetClass("ahk_id " . list_view.Hwnd))]
        }
        AssertEqual(
            true,
            RabbitNativeListViewDetector().IsCompatible(descriptor),
            "A standard ListView HWND did not pass the native protocol probe."
        )
    } finally {
        test_gui.Destroy()
    }
}

TestHeaderlessControlSkipsQuery() {
    local detector := RabbitNativeListViewDetectorProbe()
    AssertEqual(
        false,
        detector.IsCompatible(CreateNativeListViewDescriptor()),
        "A control without a direct header was classified as a native ListView."
    )
    AssertEqual(0, detector.query_count, "A headerless control received a ListView message.")
}

TestMismatchedListViewHeaderIsRejected() {
    local detector := RabbitNativeListViewDetectorProbe()
    detector.header_hwnd := 200
    detector.actual_header_hwnd := 201
    AssertEqual(
        false,
        detector.IsCompatible(CreateNativeListViewDescriptor()),
        "A mismatched ListView header was accepted."
    )
}

TestNativeListViewMatchIsCached() {
    local detector := RabbitNativeListViewDetectorProbe()
    local descriptor := CreateNativeListViewDescriptor()
    detector.header_hwnd := 200
    detector.actual_header_hwnd := 200
    AssertEqual(true, detector.IsCompatible(descriptor), "The initial native ListView probe failed.")
    AssertEqual(true, detector.IsCompatible(descriptor), "The cached native ListView match was lost.")
    AssertEqual(2, detector.find_count, "A cached match did not cheaply revalidate its header.")
    AssertEqual(1, detector.query_count, "A cached match repeated the cross-window ListView message.")
}

TestNativeListViewTimeoutUsesCooldown() {
    local detector := RabbitNativeListViewDetectorProbe()
    local descriptor := CreateNativeListViewDescriptor()
    detector.header_hwnd := 200
    detector.query_succeeds := false
    AssertEqual(false, detector.IsCompatible(descriptor), "A timed-out ListView probe was accepted.")
    detector.now := 1600
    AssertEqual(false, detector.IsCompatible(descriptor), "A timed-out ListView probe changed during cooldown.")
    AssertEqual(1, detector.query_count, "A ListView timeout was retried during its cooldown.")
    detector.now := 1800
    AssertEqual(false, detector.IsCompatible(descriptor), "A repeated ListView timeout was accepted.")
    AssertEqual(2, detector.query_count, "A ListView timeout was not retried after its cooldown.")
}

TestNativeListViewCacheIsTargetScoped() {
    local detector := RabbitNativeListViewDetectorProbe()
    detector.header_hwnd := 200
    detector.actual_header_hwnd := 200
    AssertEqual(
        true,
        detector.IsCompatible(CreateNativeListViewDescriptor(100)),
        "The first native ListView target was not detected."
    )
    AssertEqual(
        true,
        detector.IsCompatible(CreateNativeListViewDescriptor(101)),
        "A second native ListView target reused an incompatible cache entry."
    )
    AssertEqual(2, detector.query_count, "A native ListView cache entry leaked across focused targets.")
}

CreateNativeListViewDescriptor(hwnd := 100, process_id := 10, class_name := "customlistview") {
    return {
        active_hwnd: hwnd,
        focus_hwnd: hwnd,
        process_id: process_id,
        focus_classes: [class_name]
    }
}

class RabbitNativeListViewDetectorProbe extends RabbitNativeListViewDetector {
    __New() {
        super.__New()
        this.now := 1000
        this.header_hwnd := 0
        this.actual_header_hwnd := 0
        this.query_succeeds := true
        this.find_count := 0
        this.query_count := 0
    }

    FindHeader(hwnd) {
        this.find_count++
        return this.header_hwnd
    }

    QueryHeader(hwnd, &actual_header_hwnd) {
        this.query_count++
        actual_header_hwnd := this.actual_header_hwnd
        return this.query_succeeds
    }

    GetTickCount() {
        return this.now
    }
}
