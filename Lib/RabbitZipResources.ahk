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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

class RabbitZipResources {
    static Install(installer, files, destination) {
        local temporary := this.CreateTemporaryDirectory()
        local archive := temporary . "\resources.zip", unpacked := temporary . "\unpacked"
        local entry, source, target, parent
        try {
            installer.Call(archive)
            DirCreate(unpacked)
            this.Extract(archive, unpacked)
            ; Verify every expected file before overwriting any installed resource.
            for entry in files {
                source := unpacked . "\" . entry[1]
                if !FileExist(source) || DirExist(source) || FileGetSize(source) != entry[2]
                    || this.HashFile(source) != entry[3] {
                    throw Error("Invalid extracted resource: " . entry[1])
                }
            }
            for entry in files {
                target := destination . "\" . entry[1]
                if DirExist(target) {
                    throw Error("A directory occupies the resource path: " . target)
                }
                SplitPath(target, , &parent)
                DirCreate(parent)
                FileCopy(unpacked . "\" . entry[1], target, true)
            }
        } finally {
            DirDelete(temporary, true)
        }
    }

    static Extract(archive, destination) {
        local shell := ComObject("Shell.Application"), folder := shell.NameSpace(archive)
        if !folder {
            throw Error("Cannot open the embedded resource ZIP.")
        }
        local operation := ComObject("{3ad05575-8857-4850-9277-11b85bdb8e09}",
            "{947aab5f-0a5c-4c13-b4d6-4bf7836fc9f8}")
        local target := this.ShellItem(destination), entry, source, aborted := 0
        ; IFileOperation is synchronous, unlike Folder.CopyHere. Suppress shell UI;
        ; HRESULT and GetAnyOperationsAborted must both indicate success.
        ComCall(5, operation, "UInt", 0x614) ; FOF_SILENT | NOCONFIRMATION | NOCONFIRMMKDIR | NOERRORUI
        for entry in folder.Items() {
            source := this.ShellItem(entry.Path)
            ComCall(16, operation, "Ptr", source, "Ptr", target, "Ptr", 0, "Ptr", 0)
        }
        ComCall(21, operation)
        ComCall(22, operation, "Int*", &aborted)
        if aborted {
            throw Error("Resource ZIP extraction was aborted.")
        }
    }

    static ShellItem(path) {
        local iid := Buffer(16), pointer := 0
        DllCall("ole32\IIDFromString", "Str", "{43826d1e-e718-42ee-bc55-a1e261c37bfe}",
            "Ptr", iid, "HRESULT")
        DllCall("shell32\SHCreateItemFromParsingName", "Str", path, "Ptr", 0, "Ptr", iid,
            "Ptr*", &pointer, "HRESULT")
        return ComValue(13, pointer, 1)
    }

    static CreateTemporaryDirectory() {
        local guid := Buffer(16), text := Buffer(78), path
        DllCall("ole32\CoCreateGuid", "Ptr", guid, "HRESULT")
        DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", text, "Int", 39)
        path := A_Temp . "\rabbit-resources-" . StrGet(text)
        DirCreate(path)
        return path
    }

    static HashFile(path) {
        local provider := 0, hash := 0, data := FileRead(path, "RAW")
        local digest := Buffer(32), size := digest.Size, result := ""
        try {
            if !DllCall("advapi32\CryptAcquireContextW", "Ptr*", &provider, "Ptr", 0, "Ptr", 0,
                "UInt", 24, "UInt", 0xf0000000) {
                throw OSError()
            }
            if !DllCall("advapi32\CryptCreateHash", "Ptr", provider, "UInt", 0x800c, "Ptr", 0,
                "UInt", 0, "Ptr*", &hash) {
                throw OSError()
            }
            if !DllCall("advapi32\CryptHashData", "Ptr", hash, "Ptr", data, "UInt", data.Size, "UInt", 0) {
                throw OSError()
            }
            if !DllCall("advapi32\CryptGetHashParam", "Ptr", hash, "UInt", 2, "Ptr", digest,
                "UInt*", &size, "UInt", 0) {
                throw OSError()
            }
            loop size {
                result .= Format("{:02x}", NumGet(digest, A_Index - 1, "UChar"))
            }
            return result
        } finally {
            if hash {
                DllCall("advapi32\CryptDestroyHash", "Ptr", hash)
            }
            if provider {
                DllCall("advapi32\CryptReleaseContext", "Ptr", provider, "UInt", 0)
            }
        }
    }
}
