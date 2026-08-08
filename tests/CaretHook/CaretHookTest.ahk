#Requires AutoHotkey v2.0
#SingleInstance Off

#Include %A_ScriptDir%\generated\CaretHookPayloadX64.ahk
#Include %A_ScriptDir%\generated\CaretHookPayloadX86.ahk

test_log_path := A_Temp . "\RabbitCaretHookTest-" . ProcessExist() . ".log"
try FileDelete(test_log_path)
FileAppend("before-log`n", test_log_path, "UTF-8")
Log("start args=" . (A_Args.Length ? A_Args[1] : ""))
FileAppend("after-log`n", test_log_path, "UTF-8")

try {
    RunTest()
    ExitApp(0)
} catch as caught_error {
    Log("failed: " . caught_error.Message . " what=" . caught_error.What . " line=" . caught_error.Line)
    ExitApp(1)
}

RunTest() {
    Log("controller starting target")
    payload := A_PtrSize = 8 ? CaretHookPayloadX64 : CaretHookPayloadX86
    target_pid := 0
    target_hwnd := 0

    try {
        target_script := A_ScriptDir . "\CaretHookTarget.ahk"
        Run('"' . A_AhkPath . '" "' . target_script . '"',, , &target_pid)
        Log("target pid=" . target_pid)
        target_hwnd := WinWait("ahk_pid " . target_pid,, 5)
        Log("target hwnd=" . target_hwnd)
        if !target_hwnd {
            throw Error("Target window was not created")
        }

        WinActivate("ahk_id " . target_hwnd)
        if !WinWaitActive("ahk_id " . target_hwnd,, 5) {
            throw Error("Target window could not be activated")
        }

        edit_hwnd := ControlGetFocus("ahk_id " . target_hwnd)
        Log("edit hwnd=" . edit_hwnd)
        if !edit_hwnd {
            throw Error("Target edit control is not focused")
        }

        ControlSend("{Home}",, "ahk_id " . target_hwnd)
        Sleep(200)
        Log("invoking hook at home")
        home_rect := InvokeCaretHook(payload, edit_hwnd, target_pid)
        Log("home rect=" . FormatRect(home_rect))

        ControlSend("{End}",, "ahk_id " . target_hwnd)
        Sleep(200)
        Log("invoking hook at end")
        end_rect := InvokeCaretHook(payload, edit_hwnd, target_pid)
        Log("end rect=" . FormatRect(end_rect))

        AssertHookMarker("home", home_rect)
        AssertHookMarker("end", end_rect)

        Log("passed ptr=" . A_PtrSize . ", home=" . FormatRect(home_rect) . ", end=" . FormatRect(end_rect))
    } finally {
        if target_pid {
            ProcessClose(target_pid)
        }
    }
}

InvokeCaretHook(payload, hwnd, pid) {
    Log("decoding payload")
    shellcode := DecodeBase64(payload.shellcode_base64)
    Log("opening target process")
    process := DllCall("OpenProcess", "uint", 0x043A, "int", false, "uint", pid, "ptr")
    if !process {
        throw Error("OpenProcess failed: " . A_LastError)
    }

    try {
        user32_base := GetModuleBase(process, "user32.dll")
        Log("module user32=" . user32_base)
        if !user32_base {
            throw Error("Required target module was not found")
        }

        msg := DllCall("RegisterWindowMessageW", "str", "Rabbit.CaretHookTest", "uint")
        if !msg {
            throw Error("RegisterWindowMessageW failed")
        }

        if payload.pointer_size = 8 {
            NumPut("uint64", user32_base, shellcode, 0)
            NumPut("uint64", 0, shellcode, 8)
            NumPut("uint64", hwnd, shellcode, 16)
            NumPut("uint", DllCall("GetWindowThreadProcessId", "ptr", hwnd, "ptr", 0, "uint"), shellcode, 24)
            NumPut("uint", msg, shellcode, 28)
        } else {
            NumPut("uint", user32_base, shellcode, 0)
            NumPut("uint", 0, shellcode, 4)
            NumPut("uint", hwnd, shellcode, 8)
            NumPut("uint", DllCall("GetWindowThreadProcessId", "ptr", hwnd, "ptr", 0, "uint"), shellcode, 12)
            NumPut("uint", msg, shellcode, 16)
        }

        remote := DllCall(
            "VirtualAllocEx",
            "ptr", process,
            "ptr", 0,
            "uptr", shellcode.Size,
            "uint", 0x3000,
            "uint", 0x40,
            "ptr"
        )
        if !remote {
            throw Error("VirtualAllocEx failed: " . A_LastError)
        }

        try {
            if !DllCall("WriteProcessMemory", "ptr", process, "ptr", remote, "ptr", shellcode, "uptr", shellcode.Size, "ptr", 0) {
                throw Error("WriteProcessMemory failed: " . A_LastError)
            }
            DllCall("FlushInstructionCache", "ptr", process, "ptr", remote, "uptr", shellcode.Size)

            thread := DllCall(
                "CreateRemoteThread",
                "ptr", process,
                "ptr", 0,
                "uptr", 0,
                "ptr", remote + payload.entry_offset,
                "ptr", remote,
                "uint", 0,
                "uint*", 0,
                "ptr"
            )
            if !thread {
                throw Error("CreateRemoteThread failed: " . A_LastError)
            }
            Log("remote thread=" . thread)

            try {
                wait_result := DllCall("WaitForSingleObject", "ptr", thread, "uint", 2000, "uint")
                if (wait_result != 0) {
                    timeout_rect := Buffer(16, 0)
                    if DllCall("ReadProcessMemory", "ptr", process, "ptr", remote + payload.rect_offset, "ptr", timeout_rect, "uptr", timeout_rect.Size, "ptr", 0) {
                        Log("remote thread timeout rect=" . FormatRect({
                            left: NumGet(timeout_rect, 0, "int"),
                            top: NumGet(timeout_rect, 4, "int"),
                            right: NumGet(timeout_rect, 8, "int"),
                            bottom: NumGet(timeout_rect, 12, "int")
                        }))
                    }
                    DllCall("TerminateThread", "ptr", thread, "uint", 1)
                    throw Error("Remote thread timed out or failed to wait: " . wait_result)
                }
                Log("remote thread completed")

                exit_code := 0
                if !DllCall("GetExitCodeThread", "ptr", thread, "uint*", &exit_code) {
                    throw Error("GetExitCodeThread failed: " . A_LastError)
                }
                if exit_code {
                    throw Error("Hook returned error code: " . exit_code)
                }
            } finally {
                DllCall("CloseHandle", "ptr", thread)
            }

            rect := Buffer(16, 0)
            if !DllCall("ReadProcessMemory", "ptr", process, "ptr", remote + payload.rect_offset, "ptr", rect, "uptr", rect.Size, "ptr", 0) {
                throw Error("ReadProcessMemory failed: " . A_LastError)
            }
            Log("rect read")
            return {
                left: NumGet(rect, 0, "int"),
                top: NumGet(rect, 4, "int"),
                right: NumGet(rect, 8, "int"),
                bottom: NumGet(rect, 12, "int")
            }
        } finally {
            DllCall("VirtualFreeEx", "ptr", process, "ptr", remote, "uptr", 0, "uint", 0x8000)
        }
    } finally {
        DllCall("CloseHandle", "ptr", process)
    }
}

GetModuleBase(process, wanted_name) {
    modules := Buffer(A_PtrSize * 1024)
    needed := 0
    if !DllCall("K32EnumProcessModules", "ptr", process, "ptr", modules, "uint", modules.Size, "uint*", &needed) {
        throw Error("K32EnumProcessModules failed: " . A_LastError)
    }

    name_buffer := Buffer(520, 0)
    count := Integer(needed / A_PtrSize)
    Loop count {
        module := NumGet(modules, (A_Index - 1) * A_PtrSize, "ptr")
        length := DllCall("K32GetModuleBaseNameW", "ptr", process, "ptr", module, "ptr", name_buffer, "uint", 260, "uint")
        if !length {
            continue
        }
        name := StrGet(name_buffer, length, "UTF-16")
        if (StrLower(name) != wanted_name) {
            continue
        }

        module_info := Buffer(24, 0)
        if !DllCall("K32GetModuleInformation", "ptr", process, "ptr", module, "ptr", module_info, "uint", module_info.Size) {
            throw Error("K32GetModuleInformation failed: " . A_LastError)
        }
        return NumGet(module_info, 0, "ptr")
    }
    return 0
}

DecodeBase64(text) {
    length := StrLen(text)
    size := 0
    if !DllCall("Crypt32\CryptStringToBinaryW", "str", text, "uint", length, "uint", 1, "ptr", 0, "uint*", &size, "ptr", 0, "ptr", 0) {
        throw Error("CryptStringToBinary size query failed")
    }
    decoded_buffer := Buffer(size, 0)
    if !DllCall("Crypt32\CryptStringToBinaryW", "str", text, "uint", length, "uint", 1, "ptr", decoded_buffer, "uint*", &size, "ptr", 0, "ptr", 0) {
        throw Error("CryptStringToBinary failed")
    }
    return decoded_buffer
}

AssertHookMarker(label, rect) {
    if (rect.left != 0x13579BDF || rect.top != 0x2468ACE0 || rect.right != 0x0BADF00D || rect.bottom != 0x00C0FFEE) {
        throw Error(label . " hook marker mismatch: " . FormatRect(rect))
    }
}

FormatRect(rect) {
    return "[" . rect.left . "," . rect.top . "," . rect.right . "," . rect.bottom . "]"
}

Log(message) {
    global test_log_path
    FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss.fff") . " " . message . "`n", test_log_path, "UTF-8")
}
