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

#Include RabbitCommon.ahk
#Include RabbitDeploymentPlan.ahk

class RabbitMaintenanceIpcServer {
    static WM_COPYDATA := 0x004A
    static TITLE_PREFIX := "RabbitMaintenanceIPC-v1-"
    static ACCEPTED := 1
    static BUSY := 2
    static INVALID := 3

    __New(submit_callback) {
        this.submit_callback := submit_callback
        this.token := RabbitCreateIpcToken()
        this.requests := Map()
        this.message_callback := this.OnCopyData.Bind(this)
        this.window := Gui("+ToolWindow -Caption", RabbitMaintenanceIpcServer.TITLE_PREFIX . this.token)
        this.window.Show("Hide")
        OnMessage(RabbitMaintenanceIpcServer.WM_COPYDATA, this.message_callback)
        this.disposed := false
    }

    OnCopyData(sender_hwnd, copy_data_ptr, message, target_hwnd) {
        if this.disposed || target_hwnd != this.window.Hwnd || !sender_hwnd || !copy_data_ptr {
            return RabbitMaintenanceIpcServer.INVALID
        }
        local sender_pid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", sender_hwnd, "UInt*", &sender_pid)
        local byte_count := NumGet(copy_data_ptr, A_PtrSize, "UInt")
        local payload_ptr := NumGet(copy_data_ptr, A_PtrSize * 2, "Ptr")
        if !sender_pid || !payload_ptr || byte_count < 2 || byte_count > 32768 || Mod(byte_count, 2) {
            return RabbitMaintenanceIpcServer.INVALID
        }
        local payload := StrGet(payload_ptr, byte_count // 2 - 1, "UTF-16")
        return this.HandleRequest(payload, sender_pid)
    }

    HandleRequest(payload, actual_sender_pid) {
        local fields := StrSplit(payload, "`n")
        if fields.Length != 6 || fields[1] != "v1" || fields[2] != String(actual_sender_pid)
            || fields[4] != this.token || !RegExMatch(fields[3], "^[0-9A-Fa-f]{32}$") {
            return RabbitMaintenanceIpcServer.INVALID
        }
        local request_id := StrLower(fields[3])
        if this.requests.Has(request_id) {
            return this.requests[request_id]
        }
        local result := RabbitMaintenanceIpcServer.INVALID
        try {
            switch fields[5] {
                case "deploy":
                    local plan := RabbitDeploymentPlan.Parse(fields[6])
                    result := this.submit_callback.Call("deploy", plan)
                        ? RabbitMaintenanceIpcServer.ACCEPTED
                        : RabbitMaintenanceIpcServer.BUSY
                case "sync":
                    if fields[6] != "v1" {
                        throw ValueError("Synchronization payload must not contain a plan.")
                    }
                    result := this.submit_callback.Call("sync")
                        ? RabbitMaintenanceIpcServer.ACCEPTED
                        : RabbitMaintenanceIpcServer.BUSY
            }
        }
        this.requests[request_id] := result
        if this.requests.Count > 128 {
            for oldest_id in this.requests {
                this.requests.Delete(oldest_id)
                break
            }
        }
        return result
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        OnMessage(RabbitMaintenanceIpcServer.WM_COPYDATA, this.message_callback, 0)
        if this.window {
            this.window.Destroy()
            this.window := 0
        }
    }
}

class RabbitMaintenanceIpcClient {
    static Submit(operation, plan := 0) {
        local endpoint := this.FindEndpoint()
        if !endpoint {
            return {found: false, result: 0}
        }
        local sender := Gui("+ToolWindow -Caption", "RabbitMaintenanceIPCClient")
        sender.Show("Hide")
        try {
            local payload := this.BuildPayload(
                ProcessExist(),
                RabbitCreateIpcToken(),
                endpoint.token,
                operation,
                operation = "deploy" ? plan.Serialize() : "v1"
            )
            local payload_buffer := Buffer((StrLen(payload) + 1) * 2, 0)
            StrPut(payload, payload_buffer, "UTF-16")
            local copy_data := Buffer(A_PtrSize * 3, 0)
            NumPut("UPtr", 1, copy_data, 0)
            NumPut("UInt", payload_buffer.Size, copy_data, A_PtrSize)
            NumPut("Ptr", payload_buffer.Ptr, copy_data, A_PtrSize * 2)
            local response := 0
            local sent := DllCall(
                "SendMessageTimeout",
                "Ptr",
                endpoint.hwnd,
                "UInt",
                RabbitMaintenanceIpcServer.WM_COPYDATA,
                "Ptr",
                sender.Hwnd,
                "Ptr",
                copy_data.Ptr,
                "UInt",
                0x2,
                "UInt",
                2000,
                "UPtr*",
                &response
            )
            return {found: true, result: sent ? response : RabbitMaintenanceIpcServer.BUSY}
        } finally {
            sender.Destroy()
        }
    }

    static BuildPayload(sender_pid, request_id, token, operation, plan) {
        return "v1`n" . sender_pid . "`n" . request_id . "`n" . token . "`n" . operation . "`n" . plan
    }

    static FindEndpoint() {
        local old_hidden := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        try {
            for hwnd in WinGetList("ahk_class AutoHotkeyGUI") {
                local title := WinGetTitle("ahk_id " . hwnd)
                if SubStr(title, 1, StrLen(RabbitMaintenanceIpcServer.TITLE_PREFIX))
                    = RabbitMaintenanceIpcServer.TITLE_PREFIX {
                    local token := SubStr(title, StrLen(RabbitMaintenanceIpcServer.TITLE_PREFIX) + 1)
                    if RegExMatch(token, "^[0-9A-Fa-f]{32}$") {
                        return {hwnd: hwnd, token: token}
                    }
                }
            }
        } finally {
            DetectHiddenWindows(old_hidden)
        }
        return 0
    }
}

RabbitAcquireApplicationStartupGate() {
    local mutex := RabbitApplicationMutex()
    if !mutex.Create() || mutex.lasterr == ERROR_ALREADY_EXISTS {
        mutex.Close()
        return 0
    }
    return mutex
}

RabbitCreateIpcToken() {
    local token_bytes := Buffer(16, 0)
    if DllCall("bcrypt\BCryptGenRandom", "Ptr", 0, "Ptr", token_bytes.Ptr, "UInt", token_bytes.Size, "UInt", 2) != 0 {
        throw OSError(A_LastError, "BCryptGenRandom")
    }
    local index, token := ""
    Loop token_bytes.Size {
        index := A_Index - 1
        token .= Format("{:02x}", NumGet(token_bytes, index, "UChar"))
    }
    return token
}
