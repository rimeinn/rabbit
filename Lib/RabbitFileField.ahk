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

class RabbitFileField {
    static IsValidValue(value) {
        local part
        if Type(value) != "String" {
            return false
        }
        if !value {
            return true
        }
        if SubStr(value, 1, 1) = "/" || SubStr(value, -1) = "/" || InStr(value, "\")
            || InStr(value, ":") || RegExMatch(value, "[\r\n]") {
            return false
        }
        for part in StrSplit(value, "/") {
            if !part || part = "." || part = ".." {
                return false
            }
        }
        return true
    }

    static TryParseExtensions(value, &extensions) {
        local extension, seen := Map()
        extensions := []
        seen.CaseSense := "Off"
        for extension in StrSplit(value, "|") {
            extension := Trim(extension)
            if !RegExMatch(extension, "^[A-Za-z0-9][A-Za-z0-9_+-]*(?:\.[A-Za-z0-9][A-Za-z0-9_+-]*)*$")
                || seen.Has(extension) {
                return false
            }
            seen[extension] := true
            extensions.Push(extension)
        }
        return true
    }

    static SelectionToValue(user_data_dir, selected_path) {
        local prefix, relative
        user_data_dir := this.FullPath(user_data_dir)
        selected_path := this.FullPath(selected_path)
        if !user_data_dir || !selected_path {
            throw ValueError("A file path is required.")
        }
        prefix := SubStr(user_data_dir, -1) = "\" ? user_data_dir : user_data_dir . "\"
        if StrLower(SubStr(selected_path, 1, StrLen(prefix))) != StrLower(prefix) {
            throw ValueError("The selected file is outside the Rime user data directory.")
        }
        relative := StrReplace(SubStr(selected_path, StrLen(prefix) + 1), "\", "/")
        if !this.IsValidValue(relative) || !relative {
            throw ValueError("The selected file path is invalid.")
        }
        return relative
    }

    static ResolveExisting(value, roots) {
        local attributes, path, root
        if !this.IsValidValue(value) || !value {
            return ""
        }
        for root in roots {
            path := RTrim(root, "\/") . "\" . StrReplace(value, "/", "\")
            attributes := FileExist(path)
            if attributes && !InStr(attributes, "D") {
                return path
            }
        }
        return ""
    }

    static FullPath(value) {
        local capacity := 32768, length, path := Buffer(capacity * 2, 0)
        if !value {
            return ""
        }
        length := DllCall(
            "Kernel32\GetFullPathNameW",
            "Str",
            value,
            "UInt",
            capacity,
            "Ptr",
            path.Ptr,
            "Ptr",
            0,
            "UInt"
        )
        return length > 0 && length < capacity ? StrGet(path, length, "UTF-16") : ""
    }
}
