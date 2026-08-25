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

class RabbitNativeListViewDetector {
    static PROBE_NOT_COMPATIBLE := 0
    static PROBE_COMPATIBLE := 1
    static PROBE_RETRY := 2

    static LVM_GETHEADER := 0x101F
    static SMTO_BLOCK := 0x0001
    static SMTO_ABORTIFHUNG := 0x0002
    static SMTO_ERRORONEXIT := 0x0020

    static DEFAULT_TIMEOUT_MS := 15
    static DEFAULT_NEGATIVE_CACHE_MS := 1000
    static DEFAULT_TIMEOUT_COOLDOWN_MS := 750

    __New(
        timeout_ms := RabbitNativeListViewDetector.DEFAULT_TIMEOUT_MS,
        negative_cache_ms := RabbitNativeListViewDetector.DEFAULT_NEGATIVE_CACHE_MS,
        timeout_cooldown_ms := RabbitNativeListViewDetector.DEFAULT_TIMEOUT_COOLDOWN_MS
    ) {
        this.timeout_ms := timeout_ms
        this.negative_cache_ms := negative_cache_ms
        this.timeout_cooldown_ms := timeout_cooldown_ms
        this.Reset()
    }

    Reset() {
        this.cached_process_id := 0
        this.cached_hwnd := 0
        this.cached_class_name := ""
        this.cached_header_hwnd := 0
        this.cached_result := false
        this.retry_at := 0
    }

    IsCompatible(descriptor) {
        local hwnd := descriptor.focus_hwnd ? descriptor.focus_hwnd : descriptor.active_hwnd
        local process_id := descriptor.process_id
        local class_name := descriptor.focus_classes.Length ? descriptor.focus_classes[1] : ""
        local now := this.GetTickCount()
        local header_hwnd := 0
        local status
        if !hwnd {
            this.Reset()
            return false
        }

        if this.IsSameTarget(process_id, hwnd, class_name) {
            if this.cached_result {
                ; Revalidating the direct header is a cheap server-side lookup
                ; and protects the cache against a destroyed or reused HWND.
                header_hwnd := this.FindHeader(hwnd)
                if header_hwnd && header_hwnd == this.cached_header_hwnd {
                    return true
                }
            } else if now < this.retry_at {
                return false
            }
        }

        status := this.Probe(hwnd, &header_hwnd)
        this.cached_process_id := process_id
        this.cached_hwnd := hwnd
        this.cached_class_name := class_name
        this.cached_header_hwnd := header_hwnd
        this.cached_result := status = RabbitNativeListViewDetector.PROBE_COMPATIBLE
        if status = RabbitNativeListViewDetector.PROBE_RETRY {
            this.retry_at := now + this.timeout_cooldown_ms
        } else if status = RabbitNativeListViewDetector.PROBE_NOT_COMPATIBLE {
            this.retry_at := now + this.negative_cache_ms
        } else {
            this.retry_at := 0
        }
        return this.cached_result
    }

    IsSameTarget(process_id, hwnd, class_name) {
        return process_id = this.cached_process_id
            && hwnd = this.cached_hwnd
            && class_name = this.cached_class_name
    }

    Probe(hwnd, &header_hwnd) {
        header_hwnd := this.FindHeader(hwnd)
        if !header_hwnd {
            return RabbitNativeListViewDetector.PROBE_NOT_COMPATIBLE
        }

        local actual_header_hwnd := 0
        if !this.QueryHeader(hwnd, &actual_header_hwnd) {
            return RabbitNativeListViewDetector.PROBE_RETRY
        }
        return actual_header_hwnd = header_hwnd
            ? RabbitNativeListViewDetector.PROBE_COMPATIBLE
            : RabbitNativeListViewDetector.PROBE_NOT_COMPATIBLE
    }

    FindHeader(hwnd) {
        ; FindWindowExW only searches direct children and does not enter the
        ; target window procedure, so non-list controls are rejected cheaply.
        return DllCall(
            "FindWindowExW",
            "Ptr",
            hwnd,
            "Ptr",
            0,
            "Str",
            "SysHeader32",
            "Ptr",
            0,
            "Ptr"
        )
    }

    QueryHeader(hwnd, &actual_header_hwnd) {
        actual_header_hwnd := 0
        return DllCall(
            "SendMessageTimeoutW",
            "Ptr",
            hwnd,
            "UInt",
            RabbitNativeListViewDetector.LVM_GETHEADER,
            "Ptr",
            0,
            "Ptr",
            0,
            "UInt",
            RabbitNativeListViewDetector.SMTO_BLOCK
                | RabbitNativeListViewDetector.SMTO_ABORTIFHUNG
                | RabbitNativeListViewDetector.SMTO_ERRORONEXIT,
            "UInt",
            this.timeout_ms,
            "Ptr*",
            &actual_header_hwnd,
            "Ptr"
        ) != 0
    }

    GetTickCount() {
        return DllCall("GetTickCount64", "UInt64")
    }
}
