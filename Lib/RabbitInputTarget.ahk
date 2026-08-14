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

    static UIA_EDIT_CONTROL_TYPE_ID := 50004
    static UIA_LIST_ITEM_CONTROL_TYPE_ID := 50007
    static UIA_LIST_CONTROL_TYPE_ID := 50008
    static UIA_TREE_CONTROL_TYPE_ID := 50023
    static UIA_TREE_ITEM_CONTROL_TYPE_ID := 50024
    static UIA_DATA_GRID_CONTROL_TYPE_ID := 50028
    static UIA_DATA_ITEM_CONTROL_TYPE_ID := 50029
    static UIA_DOCUMENT_CONTROL_TYPE_ID := 50030

    static Classify(foreground_hwnd) {
        if !(descriptor := this.Describe(foreground_hwnd)) {
            return this.UNKNOWN
        }
        if this.IsWpfWindow(descriptor) {
            descriptor.uia_control_types := this.GetFocusedUIAutomationControlTypes(descriptor.process_id)
        }
        return this.ClassifyDescriptor(descriptor)
    }

    static Describe(foreground_hwnd) {
        local thread_id, gui_info, active_hwnd, focus_hwnd, target_hwnd
        local process_id := 0
        if !foreground_hwnd {
            return 0
        }
        if !(thread_id := DllCall(
            "GetWindowThreadProcessId",
            "Ptr",
            foreground_hwnd,
            "UInt*",
            &process_id,
            "UInt"
        )) {
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
            process_id: process_id,
            process_name: StrLower(process_name),
            focus_classes: this.GetClassChain(target_hwnd),
            active_classes: active_hwnd ? this.GetClassChain(active_hwnd) : []
        }
    }

    static ClassifyDescriptor(descriptor) {
        if this.ContainsEditableClass(descriptor.focus_classes) {
            return this.YES
        }
        if this.IsWpfTextTarget(descriptor) {
            return this.YES
        }
        if this.IsDesktop(descriptor) {
            return this.NO
        }
        if this.IsProcessExplorer(descriptor) {
            return this.NO
        }
        if this.IsWpfSelectionTarget(descriptor) {
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

    static IsWpfWindow(descriptor) {
        return this.ContainsClassPrefix(descriptor.focus_classes, "hwndwrapper[")
            || this.ContainsClassPrefix(descriptor.active_classes, "hwndwrapper[")
    }

    static IsWpfTextTarget(descriptor) {
        if !this.IsWpfWindow(descriptor) {
            return false
        }
        local control_types := this.GetDescriptorUIAutomationControlTypes(descriptor)
        return this.ContainsControlType(control_types, this.UIA_EDIT_CONTROL_TYPE_ID)
            || this.ContainsControlType(control_types, this.UIA_DOCUMENT_CONTROL_TYPE_ID)
    }

    static IsWpfSelectionTarget(descriptor) {
        if !this.IsWpfWindow(descriptor) {
            return false
        }
        local control_types := this.GetDescriptorUIAutomationControlTypes(descriptor)
        return this.ContainsControlType(control_types, this.UIA_LIST_ITEM_CONTROL_TYPE_ID)
            || this.ContainsControlType(control_types, this.UIA_LIST_CONTROL_TYPE_ID)
            || this.ContainsControlType(control_types, this.UIA_TREE_CONTROL_TYPE_ID)
            || this.ContainsControlType(control_types, this.UIA_TREE_ITEM_CONTROL_TYPE_ID)
            || this.ContainsControlType(control_types, this.UIA_DATA_GRID_CONTROL_TYPE_ID)
            || this.ContainsControlType(control_types, this.UIA_DATA_ITEM_CONTROL_TYPE_ID)
    }

    static GetDescriptorUIAutomationControlTypes(descriptor) {
        return descriptor.HasOwnProp("uia_control_types") ? descriptor.uia_control_types : []
    }

    static GetFocusedUIAutomationControlTypes(expected_process_id) {
        local control_types := []
        local uia := this.GetUIAutomation()
        local focused_element, walker, current_element, parent_element
        local process_id, control_type
        if !uia {
            return control_types
        }

        try {
            focused_element := ComValue(13, 0)
            ComCall(8, uia, "Ptr*", focused_element)
            if !focused_element.Ptr {
                return control_types
            }

            walker := ComValue(13, 0)
            ComCall(14, uia, "Ptr*", walker)
            if !walker.Ptr {
                return control_types
            }

            current_element := focused_element
            Loop 16 {
                process_id := 0
                ComCall(20, current_element, "Int*", &process_id)
                if process_id != expected_process_id {
                    return control_types.Length ? control_types : []
                }

                control_type := 0
                ComCall(21, current_element, "Int*", &control_type)
                control_types.Push(control_type)
                if this.IsUIAutomationTextControlType(control_type)
                    || this.IsUIAutomationSelectionControlType(control_type) {
                    break
                }

                parent_element := ComValue(13, 0)
                ComCall(3, walker, "Ptr", current_element, "Ptr*", parent_element)
                if !parent_element.Ptr {
                    break
                }
                current_element := parent_element
            }
        } catch {
            return []
        }
        return control_types
    }

    static GetUIAutomation() {
        static uia := 0
        static uia_unavailable := false
        if uia || uia_unavailable {
            return uia
        }
        try {
            uia := ComObject(
                "{E22AD333-B25F-460C-83D0-0581107395C9}",
                "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
            )
        } catch {
            uia_unavailable := true
        }
        return uia
    }

    static IsUIAutomationTextControlType(control_type) {
        return control_type = this.UIA_EDIT_CONTROL_TYPE_ID
            || control_type = this.UIA_DOCUMENT_CONTROL_TYPE_ID
    }

    static IsUIAutomationSelectionControlType(control_type) {
        return control_type = this.UIA_LIST_ITEM_CONTROL_TYPE_ID
            || control_type = this.UIA_LIST_CONTROL_TYPE_ID
            || control_type = this.UIA_TREE_CONTROL_TYPE_ID
            || control_type = this.UIA_TREE_ITEM_CONTROL_TYPE_ID
            || control_type = this.UIA_DATA_GRID_CONTROL_TYPE_ID
            || control_type = this.UIA_DATA_ITEM_CONTROL_TYPE_ID
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

    static ContainsClassPrefix(classes, expected_prefix) {
        local class_name
        for class_name in classes {
            if InStr(class_name, expected_prefix) = 1 {
                return true
            }
        }
        return false
    }

    static ContainsControlType(control_types, expected) {
        local control_type
        for control_type in control_types {
            if control_type = expected {
                return true
            }
        }
        return false
    }
}
