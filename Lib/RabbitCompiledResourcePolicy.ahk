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

/**
 * Owns the on-disk policy for resources embedded in a compiled Rabbit binary.
 *
 * The generated resource include supplies the literal FileInstall statements.
 * Keeping the marker and commit policy here means generated files cannot
 * accidentally change the source-run behavior or publish a partial update.
 */
global rabbit_compiled_resource_extractor := 0
global rabbit_compiled_legacy_installer := 0
global rabbit_compiled_rime_installer := 0

class RabbitCompiledResourcePolicy {
    static MARKER_NAME := ".rabbit"

    static ShouldExtract(root, version) {
        local marker_path := root . "\" . this.MARKER_NAME, marker_value
        if !version || !FileExist(marker_path) {
            return true
        }
        try {
            marker_value := FileRead(marker_path, "UTF-8-RAW")
        } catch {
            return true
        }
        return !(marker_value == version && marker_value != "")
    }

    static EnsureDirectory(path) {
        if DirExist(path) {
            return
        }
        DirCreate(path)
        if !DirExist(path) {
            throw Error("Failed to create compiled resource directory: " . path)
        }
    }

    static VerifyFile(path) {
        if !FileExist(path) || DirExist(path) {
            throw Error("Compiled resource was not installed: " . path)
        }
    }

    static Commit(root, version) {
        local marker_path := root . "\" . this.MARKER_NAME
        local temp_path := marker_path . ".tmp-" . ProcessExist() . "-" . A_TickCount
        local marker_file := 0
        try {
            marker_file := FileOpen(temp_path, "w", "UTF-8-RAW")
            marker_file.Write(version)
            marker_file.Close()
            marker_file := 0
            FileSetAttrib("+H", temp_path)
            ; Replace only the marker after every resource write has succeeded.
            if !DllCall("MoveFileExW", "Str", temp_path, "Str", marker_path, "UInt", 9) {
                throw OSError(A_LastError, "MoveFileExW", marker_path)
            }
        } finally {
            if marker_file {
                marker_file.Close()
            }
            if FileExist(temp_path) {
                try FileDelete(temp_path)
            }
        }
    }

    static ExtractIfCompiled() {
        global rabbit_compiled_resource_extractor
        if !A_IsCompiled {
            return
        }
        if !IsObject(rabbit_compiled_resource_extractor) {
            throw Error("The compiled resource extractor was not generated.")
        }
        rabbit_compiled_resource_extractor.Call()
    }

    static EnsureLegacyInstaller() {
        global rabbit_compiled_legacy_installer
        if !A_IsCompiled {
            return
        }
        local path := A_ScriptDir . "\rime-install.bat"
        if FileExist(path) {
            return
        }
        if !IsObject(rabbit_compiled_legacy_installer) {
            throw Error("The compiled legacy installer was not generated.")
        }
        rabbit_compiled_legacy_installer.Call()
        this.VerifyFile(path)
    }

    static InstallEmbeddedRimeDll() {
        global rabbit_compiled_rime_installer
        if !A_IsCompiled {
            throw Error("The embedded librime installer is only available in compiled Rabbit.")
        }
        if !IsObject(rabbit_compiled_rime_installer) {
            throw Error("The compiled librime installer was not generated.")
        }
        rabbit_compiled_rime_installer.Call()
        this.VerifyFile(A_ScriptDir . "\rime.dll")
    }
}
