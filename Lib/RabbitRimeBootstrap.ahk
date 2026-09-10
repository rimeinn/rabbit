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
 */

#Include RabbitCommon.ahk
#Include RabbitCompiledResourcePolicy.ahk
#Include librime-ahk\rime_api.ahk

/**
 * Selects a librime DLL before the RimeApi object is constructed.
 *
 * A selected module is assigned to RimeApi.rimeDll before RimeApi() runs. This
 * prevents the binding's legacy fallback search from selecting a different
 * DLL after a candidate has been validated.
 */
class RabbitRimeBootstrap {
    static Prepare() {
        if !A_IsCompiled {
            return A_ScriptDir . "\Lib\librime-ahk\rime.dll"
        }

        local required_version := RabbitRimeBootstrap.EmbeddedVersion()
        local expected_bits := RabbitRimeBootstrap.EmbeddedBits()
        local candidates := this.Candidates()
        local selected := this.SelectCandidate(candidates, required_version, expected_bits)
        if !selected {
            RabbitCompiledResourcePolicy.InstallEmbeddedRimeDll()
            selected := this.InspectCandidate(
                A_ScriptDir . "\rime.dll",
                required_version,
                expected_bits
            )
            if !selected {
                throw Error("The embedded librime DLL is missing or incompatible.")
            }
        }
        RimeApi.rimeDll := selected.handle
        return selected.path
    }

    static EmbeddedVersion() {
        global RABBIT_EMBEDDED_RIME_VERSION
        if !IsSet(RABBIT_EMBEDDED_RIME_VERSION) || !RABBIT_EMBEDDED_RIME_VERSION {
            throw Error("The compiled Rabbit binary has no embedded librime version.")
        }
        if !this.IsNumericVersion(RABBIT_EMBEDDED_RIME_VERSION) {
            throw Error("The embedded librime version is not numeric: " . RABBIT_EMBEDDED_RIME_VERSION)
        }
        return RABBIT_EMBEDDED_RIME_VERSION
    }

    static EmbeddedBits() {
        global RABBIT_EMBEDDED_RIME_BITS
        if !IsSet(RABBIT_EMBEDDED_RIME_BITS) || RABBIT_EMBEDDED_RIME_BITS != A_PtrSize * 8 {
            throw Error("The embedded librime architecture does not match the compiled Rabbit executable.")
        }
        return RABBIT_EMBEDDED_RIME_BITS
    }

    static Candidates() {
        local candidates := [], path, librime_lib_dir, weasel_root
        candidates.Push(A_ScriptDir . "\rime.dll")
        if (librime_lib_dir := EnvGet("LIBRIME_LIB_DIR")) {
            candidates.Push(librime_lib_dir . "\rime.dll")
        }
        try {
            weasel_root := RegRead("HKEY_LOCAL_MACHINE\Software\Rime\Weasel", "WeaselRoot", "")
        } catch {
            weasel_root := ""
        }
        if weasel_root {
            candidates.Push(weasel_root . "\rime.dll")
        }

        local unique := [], seen := Map()
        seen.CaseSense := "Off"
        for path in candidates {
            path := this.NormalizePath(path)
            if !path || seen.Has(path) {
                continue
            }
            seen[path] := true
            unique.Push(path)
        }
        return unique
    }

    static SelectCandidate(candidates, required_version, expected_bits, inspector := 0) {
        local candidate, result
        if !inspector {
            inspector := (candidate) => this.InspectCandidate(candidate, required_version, expected_bits)
        }
        for candidate in candidates {
            try {
                if (result := inspector.Call(candidate)) {
                    return result
                }
            } catch {
                ; A broken external candidate must not prevent the next source.
            }
        }
        return 0
    }

    static InspectCandidate(path, required_version, expected_bits) {
        local file_version := this.ReadFileVersion(path)
        if !file_version || this.CompareNumericVersions(file_version, required_version) < 0 {
            return 0
        }
        if this.ReadPeBits(path) != expected_bits {
            return 0
        }

        local handle := this.LoadLibrary(path)
        if !handle {
            return 0
        }
        local accepted := false
        try {
            local api_version := this.ReadApiVersion(handle)
            if !api_version || VerCompare(api_version, RimeApi.min_version) < 0 {
                return 0
            }
            accepted := true
            return {path: path, handle: handle, file_version: file_version, api_version: api_version}
        } finally {
            if !accepted {
                DllCall("FreeLibrary", "Ptr", handle)
            }
        }
    }

    static ReadFileVersion(path) {
        if !FileExist(path) {
            return ""
        }
        local version := ""
        try {
            version := FileGetVersion(path)
        } catch {
            return ""
        }
        return this.IsNumericVersion(version) ? version : ""
    }

    static ReadPeBits(path) {
        local file, data, pe_offset, optional_magic, machine
        try {
            file := FileOpen(path, "r")
            data := Buffer(0x40)
            if file.RawRead(data) != data.Size || NumGet(data, 0, "UShort") != 0x5a4d {
                return 0
            }
            pe_offset := NumGet(data, 0x3c, "UInt")
            if pe_offset < 0x40 || pe_offset + 0x1a > file.Length {
                return 0
            }
            file.Pos := pe_offset
            data := Buffer(0x1a)
            if file.RawRead(data) != data.Size || NumGet(data, 0, "UInt") != 0x00004550 {
                return 0
            }
        } catch {
            return 0
        } finally {
            if IsSet(file) && file {
                file.Close()
            }
        }
        machine := NumGet(data, 4, "UShort")
        optional_magic := NumGet(data, 0x18, "UShort")
        if machine = 0x14c && optional_magic = 0x10b {
            return 32
        }
        if machine = 0x8664 && optional_magic = 0x20b {
            return 64
        }
        return 0
    }

    static LoadLibrary(path) {
        ; Missing dependencies must return failure rather than show a loader dialog.
        local previous_mode := DllCall("SetErrorMode", "UInt", 0x8001, "UInt")
        try {
            return DllCall("LoadLibraryW", "WStr", path, "Ptr")
        } catch {
            return 0
        } finally {
            DllCall("SetErrorMode", "UInt", previous_mode)
        }
    }

    static ReadApiVersion(handle) {
        local get_api, api, data_size, real_size, version_ptr
        get_api := DllCall("GetProcAddress", "Ptr", handle, "AStr", "rime_get_api", "Ptr")
        if !get_api {
            return ""
        }
        try {
            api := DllCall(get_api, "CDecl Ptr")
        } catch {
            return ""
        }
        if !api {
            return ""
        }
        data_size := NumGet(api, RimeApi.data_size_offset, "Int")
        real_size := A_IntSize + data_size
        if real_size < RimeApi.get_version_offset + A_PtrSize {
            return ""
        }
        version_ptr := NumGet(api, RimeApi.get_version_offset, "Ptr")
        if !version_ptr {
            return ""
        }
        local version_string := DllCall(version_ptr, "CDecl Ptr")
        return version_string ? StrGet(version_string, "UTF-8") : ""
    }

    static IsNumericVersion(version) {
        return !!version && RegExMatch(version, "^\d+(?:\.\d+){0,3}$")
    }

    static CompareNumericVersions(left, right) {
        local left_parts := StrSplit(left, "."), right_parts := StrSplit(right, ".")
        local count := Max(left_parts.Length, right_parts.Length), index, left_part, right_part
        Loop count {
            index := A_Index
            left_part := index <= left_parts.Length ? Integer(left_parts[index]) : 0
            right_part := index <= right_parts.Length ? Integer(right_parts[index]) : 0
            if left_part < right_part {
                return -1
            }
            if left_part > right_part {
                return 1
            }
        }
        return 0
    }

    static NormalizePath(path) {
        if !path {
            return ""
        }
        return StrReplace(path, "/", "\")
    }
}
