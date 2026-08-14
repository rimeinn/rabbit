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

class RabbitInputTarget {
    static YES := "yes"
    static NO := "no"
    static UNKNOWN := "unknown"

    static Classify(foreground_hwnd) {
        if !(descriptor := this.Describe(foreground_hwnd)) {
            return this.UNKNOWN
        }
        return this.ClassifyDescriptor(descriptor)
    }

    static Describe(foreground_hwnd) {
        local thread_id, gui_info, active_hwnd, focus_hwnd, target_hwnd
        if !foreground_hwnd {
            return 0
        }
        if !(thread_id := DllCall("GetWindowThreadProcessId", "Ptr", foreground_hwnd, "Ptr", 0, "UInt")) {
            return 0
        }

        local buffer_size := 8 + A_PtrSize * 6 + 16
        gui_info := Buffer(buffer_size, 0)
        NumPut("UInt", buffer_size, gui_info, 0)
        if !DllCall("GetGUIThreadInfo", "UInt", thread_id, "Ptr", gui_info.Ptr, "Int") {
            return 0
        }

        active_hwnd := NumGet(gui_info, 8, "Ptr")
        focus_hwnd := NumGet(gui_info, 8 + A_PtrSize, "Ptr")
        target_hwnd := focus_hwnd ? focus_hwnd : active_hwnd
        if !target_hwnd {
            return 0
        }

        local process_name := ""
        try {
            process_name := WinGetProcessName("ahk_id " . target_hwnd)
        }
        if !process_name {
            return 0
        }

        return {
            active_hwnd: active_hwnd,
            focus_hwnd: focus_hwnd,
            process_name: StrLower(process_name),
            focus_classes: this.GetClassChain(target_hwnd),
            active_classes: active_hwnd ? this.GetClassChain(active_hwnd) : []
        }
    }

    static ClassifyDescriptor(descriptor) {
        if this.ContainsEditableClass(descriptor.focus_classes) {
            return this.YES
        }
        if this.IsDesktop(descriptor) {
            return this.NO
        }
        if this.IsProcessExplorer(descriptor) {
            return this.NO
        }
        if this.IsOpenWithDialog(descriptor) {
            return this.NO
        }
        if this.IsCommonFileDialogView(descriptor) {
            return this.NO
        }
        if descriptor.process_name != "explorer.exe" {
            return this.UNKNOWN
        }
        if this.IsExplorerFileView(descriptor) || this.IsTaskbarControl(descriptor) {
            return this.NO
        }
        return this.UNKNOWN
    }

    static GetClassChain(hwnd) {
        local classes := []
        local current := hwnd
        local class_name
        Loop 16 {
            if !current {
                break
            }
            try {
                class_name := WinGetClass("ahk_id " . current)
            } catch {
                break
            }
            if !class_name {
                break
            }
            classes.Push(StrLower(class_name))
            local parent := DllCall("GetParent", "Ptr", current, "Ptr")
            if !parent || parent == current {
                break
            }
            current := parent
        }
        return classes
    }

    static ContainsEditableClass(classes) {
        local class_name
        for class_name in classes {
            if class_name = "edit" || InStr(class_name, "richedit") = 1 {
                return true
            }
        }
        return false
    }

    static IsDesktop(descriptor) {
        return descriptor.process_name = "explorer.exe"
            && (this.ContainsClass(descriptor.focus_classes, "progman")
                || this.ContainsClass(descriptor.focus_classes, "workerw")
                || this.ContainsClass(descriptor.active_classes, "progman")
                || this.ContainsClass(descriptor.active_classes, "workerw"))
    }

    static IsExplorerFileView(descriptor) {
        return this.ContainsClass(descriptor.focus_classes, "shelldll_defview")
            || this.ContainsClass(descriptor.focus_classes, "syslistview32")
    }

    static IsProcessExplorer(descriptor) {
        local process_name := descriptor.process_name
        return (process_name = "procexp.exe"
                || process_name = "procexp64.exe"
                || process_name = "procexp64a.exe")
            && (this.ContainsClass(descriptor.focus_classes, "procexplorer")
                || this.ContainsClass(descriptor.active_classes, "procexplorer"))
    }

    static IsOpenWithDialog(descriptor) {
        return descriptor.process_name = "openwith.exe"
            && (this.ContainsClass(descriptor.focus_classes, "open with")
                || this.ContainsClass(descriptor.active_classes, "open with"))
    }

    static IsCommonFileDialogView(descriptor) {
        local focus_classes := descriptor.focus_classes
        return (this.ContainsClass(focus_classes, "#32770")
                || this.ContainsClass(descriptor.active_classes, "#32770"))
            && (this.IsExplorerFileView(descriptor)
                || this.ContainsClass(focus_classes, "systreeview32")
                || this.ContainsClass(focus_classes, "namespacetreecontrol"))
    }

    static IsTaskbarControl(descriptor) {
        local classes := descriptor.focus_classes
        return this.ContainsClass(classes, "mstasklistwclass")
            || this.ContainsClass(classes, "traynotifywnd")
            || this.ContainsClass(classes, "toolbarwindow32")
    }

    static ContainsClass(classes, expected) {
        local class_name
        for class_name in classes {
            if class_name = expected {
                return true
            }
        }
        return false
    }
}
