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

#Include RabbitCommon.ahk
#Include RabbitNativeListView.ahk

class RabbitInputTarget {
    static YES := "yes"
    static NO := "no"
    static TYPE_AHEAD := "type_ahead"
    static UNKNOWN := "unknown"

    static UIA_EDIT_CONTROL_TYPE_ID := 50004
    static UIA_BUTTON_CONTROL_TYPE_ID := 50000
    static UIA_COMBOBOX_CONTROL_TYPE_ID := 50003
    static UIA_LIST_ITEM_CONTROL_TYPE_ID := 50007
    static UIA_LIST_CONTROL_TYPE_ID := 50008
    static UIA_MENU_ITEM_CONTROL_TYPE_ID := 50010
    static UIA_TREE_CONTROL_TYPE_ID := 50023
    static UIA_TREE_ITEM_CONTROL_TYPE_ID := 50024
    static UIA_DATA_GRID_CONTROL_TYPE_ID := 50028
    static UIA_DATA_ITEM_CONTROL_TYPE_ID := 50029
    static UIA_DOCUMENT_CONTROL_TYPE_ID := 50030
    static UIA_VALUE_PATTERN_ID := 10002
    static UIA_TEXT_PATTERN_ID := 10014
    static UIA_IS_READONLY_ATTRIBUTE_ID := 40015
    static UIA_FRAMEWORK_ID_PROPERTY_ID := 30024
    static UIA_VALUE_IS_READONLY_PROPERTY_ID := 30046
    static UIA_EXPAND_COLLAPSE_STATE_PROPERTY_ID := 30070
    static VT_I4 := 3
    static VT_BSTR := 8
    static VT_BOOL := 11

    static native_list_view_detector := RabbitNativeListViewDetector()
    static mygo_combo := 0

    static Classify(foreground_hwnd, &editor := 0, &force_direct := false) {
        local result, is_browser, mygo_hwnd, is_explorer_xaml
        editor := 0
        force_direct := false
        if !(descriptor := this.Describe(foreground_hwnd)) {
            this.native_list_view_detector.Reset()
            this.mygo_combo := 0
            return this.UNKNOWN
        }
        is_browser := this.IsBrowserWindow(descriptor)
        mygo_hwnd := this.IsMyGoSurface(descriptor) ? descriptor.focus_hwnd : 0
        is_explorer_xaml := this.IsExplorerXamlHost(descriptor)
        if this.mygo_combo && this.mygo_combo.hwnd != mygo_hwnd {
            this.mygo_combo := 0
        }
        if this.IsWpfWindow(descriptor) || is_browser || mygo_hwnd || is_explorer_xaml {
            local uia_details := this.GetFocusedUIAutomationDetails(
                descriptor.process_id, is_browser, mygo_hwnd, is_explorer_xaml
            )
            descriptor.uia_control_types := uia_details.control_types
            descriptor.uia_text_editability := uia_details.text_editability
            descriptor.mygo_focus := uia_details.mygo_focus
            descriptor.explorer_editor := uia_details.explorer_editor
        }
        result := this.ClassifyDescriptor(descriptor)
        if mygo_hwnd {
            local focus := descriptor.mygo_focus
            editor := result = this.YES && focus ? focus.element : 0
            force_direct := !!editor
            this.mygo_combo := editor && focus.control_type = this.UIA_COMBOBOX_CONTROL_TYPE_ID
                ? { hwnd: mygo_hwnd, element: editor }
                : 0
        } else if is_explorer_xaml {
            editor := descriptor.explorer_editor
        }
        if result != this.UNKNOWN {
            this.native_list_view_detector.Reset()
            return result
        }
        return this.native_list_view_detector.IsCompatible(descriptor) ? this.TYPE_AHEAD : this.UNKNOWN
    }

    static Describe(foreground_hwnd) {
        local thread_id, active_hwnd, focus_hwnd, target_hwnd
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

        local windows := this.GetThreadWindows(thread_id)
        if !windows {
            return 0
        }

        active_hwnd := windows.active_hwnd
        focus_hwnd := windows.focus_hwnd
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

        local focus_classes := this.GetClassChain(target_hwnd)
        return {
            active_hwnd: active_hwnd,
            focus_hwnd: focus_hwnd,
            process_id: process_id,
            process_name: StrLower(process_name),
            focus_classes: focus_classes,
            active_classes: active_hwnd == target_hwnd
                ? focus_classes
                : (active_hwnd ? this.GetClassChain(active_hwnd) : [])
        }
    }

    static GetThreadWindows(thread_id) {
        local buffer_size := 8 + A_PtrSize * 6 + 16
        local gui_info := Buffer(buffer_size, 0)
        NumPut("UInt", buffer_size, gui_info, 0)
        if !DllCall("GetGUIThreadInfo", "UInt", thread_id, "Ptr", gui_info, "Int") {
            return 0
        }
        return {
            active_hwnd: NumGet(gui_info, 8, "Ptr"),
            focus_hwnd: NumGet(gui_info, 8 + A_PtrSize, "Ptr")
        }
    }

    static ClassifyDescriptor(descriptor) {
        if this.ContainsEditableClass(descriptor.focus_classes) {
            return this.YES
        }
        if this.IsMyGoSurface(descriptor) {
            return this.ClassifyMyGo(descriptor)
        }
        if descriptor.HasOwnProp("explorer_editor") && descriptor.explorer_editor {
            return this.YES
        }
        if this.IsWpfTextTarget(descriptor) {
            return this.YES
        }
        if this.IsDesktop(descriptor) {
            return this.TYPE_AHEAD
        }
        if this.IsProcessExplorer(descriptor) {
            return this.TYPE_AHEAD
        }
        if this.IsWpfSelectionTarget(descriptor) {
            return this.TYPE_AHEAD
        }
        if this.IsOpenWithDialog(descriptor) {
            return this.NO
        }
        if this.IsCommonFileDialogView(descriptor) {
            return this.TYPE_AHEAD
        }
        if this.IsBrowserWindow(descriptor) {
            return this.ClassifyBrowser(descriptor)
        }
        if descriptor.process_name != "explorer.exe" {
            return this.UNKNOWN
        }
        if this.IsExplorerFileView(descriptor) {
            return this.TYPE_AHEAD
        }
        if this.IsTaskbarControl(descriptor) {
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

    static IsExplorerXamlHost(descriptor) {
        return descriptor.process_name = "explorer.exe"
            && this.ContainsClass(descriptor.active_classes, "cabinetwclass")
            && this.ContainsClass(descriptor.focus_classes, "microsoft.ui.content.desktopchildsitebridge")
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

    static IsMyGoSurface(descriptor) {
        return this.ContainsClass(descriptor.focus_classes, "mygosurface")
    }

    static ClassifyMyGo(descriptor) {
        if !descriptor.HasOwnProp("mygo_focus") || !descriptor.mygo_focus {
            return this.UNKNOWN
        }
        local focus := descriptor.mygo_focus
        switch focus.control_type {
            case this.UIA_EDIT_CONTROL_TYPE_ID, this.UIA_COMBOBOX_CONTROL_TYPE_ID:
                return focus.text_editability
            case this.UIA_BUTTON_CONTROL_TYPE_ID, this.UIA_MENU_ITEM_CONTROL_TYPE_ID:
                return this.NO
        }
        return this.UNKNOWN
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

    static GetFocusedUIAutomationDetails(
        expected_process_id, inspect_text_editability := false, mygo_hwnd := 0, is_explorer_xaml := false
    ) {
        local details := {
            control_types: [],
            text_editability: this.UNKNOWN,
            mygo_focus: 0,
            explorer_editor: 0
        }
        local uia := this.GetUIAutomation()
        local focused_element, walker, current_element, parent_element
        local process_id, control_type
        if !uia {
            return details
        }

        try {
            focused_element := ComValue(13, 0)
            ComCall(8, uia, "Ptr*", focused_element)
            if !focused_element.Ptr {
                return details
            }
            process_id := 0
            ComCall(20, focused_element, "Int*", &process_id)
            if process_id != expected_process_id {
                return details
            }
            if mygo_hwnd {
                details.mygo_focus := this.GetMyGoFocus(focused_element, uia)
                return details
            }
            if is_explorer_xaml {
                details.explorer_editor := this.GetExplorerEditor(focused_element)
                return details
            }
            walker := ComValue(13, 0)
            ComCall(14, uia, "Ptr*", walker)
            if !walker.Ptr {
                return details
            }

            current_element := focused_element
            Loop 16 {
                process_id := 0
                ComCall(20, current_element, "Int*", &process_id)
                if process_id != expected_process_id {
                    return details
                }

                control_type := 0
                ComCall(21, current_element, "Int*", &control_type)
                details.control_types.Push(control_type)
                if A_Index = 1 && inspect_text_editability && !this.IsBrowserTextTargetType(control_type) {
                    details.text_editability := this.GetUIAutomationTextEditability(focused_element)
                }
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
            details.control_types := []
            details.text_editability := this.UNKNOWN
            return details
        }
        return details
    }

    static GetExplorerEditor(element) {
        local control_type := 0
        local has_focus := 0
        ComCall(21, element, "Int*", &control_type) ; CurrentControlType
        if control_type != this.UIA_EDIT_CONTROL_TYPE_ID {
            return 0
        }
        ComCall(26, element, "Int*", &has_focus) ; CurrentHasKeyboardFocus
        return has_focus && this.GetEnabledValueEditability(element) = this.YES ? element : 0
    }

    static GetMyGoFocus(element, uia) {
        local has_focus := 0
        local control_type := 0
        local text_editability := this.UNKNOWN
        local framework_id := Buffer(24, 0)
        try {
            ComCall(10, element, "Int", this.UIA_FRAMEWORK_ID_PROPERTY_ID, "Ptr", framework_id)
            if NumGet(framework_id, 0, "UShort") != this.VT_BSTR
                || StrGet(NumGet(framework_id, 8, "Ptr"), "UTF-16") != "MyGo" {
                return 0
            }
        } finally {
            DllCall("OleAut32\VariantClear", "Ptr", framework_id)
        }
        ComCall(26, element, "Int*", &has_focus) ; CurrentHasKeyboardFocus
        if !has_focus {
            return 0
        }
        ComCall(21, element, "Int*", &control_type) ; CurrentControlType
        if control_type = this.UIA_LIST_ITEM_CONTROL_TYPE_ID && this.IsMyGoComboSuggestion(element, uia) {
            element := this.mygo_combo.element
            control_type := this.UIA_COMBOBOX_CONTROL_TYPE_ID
        }
        ; MyGo also exposes selection-only dropdowns as ComboBox. ValuePattern
        ; distinguishes those from comboboxes backed by a text editor.
        if control_type = this.UIA_EDIT_CONTROL_TYPE_ID || control_type = this.UIA_COMBOBOX_CONTROL_TYPE_ID {
            text_editability := this.GetEnabledValueEditability(element)
        }
        return { control_type: control_type, text_editability: text_editability, element: element }
    }

    static GetEnabledValueEditability(element) {
        local enabled := 0
        ComCall(28, element, "Int*", &enabled) ; CurrentIsEnabled
        return enabled ? this.GetUIAutomationValueEditability(element) : this.NO
    }

    static IsMyGoComboSuggestion(element, uia) {
        ; MyGo moves UIA focus to the highlighted option while keyboard input
        ; stays in the combo. Its provider does not expose an owner relation.
        if !this.mygo_combo {
            return false
        }
        local state := Buffer(24, 0)
        try {
            ComCall(11, this.mygo_combo.element, "Int", this.UIA_EXPAND_COLLAPSE_STATE_PROPERTY_ID,
                "Int", true, "Ptr", state)
            if NumGet(state, 0, "UShort") != this.VT_I4 || NumGet(state, 8, "Int") != 1 {
                return false
            }
        } finally {
            DllCall("OleAut32\VariantClear", "Ptr", state)
        }
        local walker := ComValue(13, 0)
        local parent := ComValue(13, 0)
        local control_type := 0
        ComCall(16, uia, "Ptr*", walker) ; RawViewWalker
        if walker.Ptr {
            ComCall(3, walker, "Ptr", element, "Ptr*", parent)
        }
        if parent.Ptr {
            ComCall(21, parent, "Int*", &control_type)
        }
        return control_type = this.UIA_LIST_CONTROL_TYPE_ID
    }

    static GetUIAutomationValueEditability(element) {
        static iid := 0
        if !iid {
            iid := Buffer(16, 0)
            DllCall(
                "Ole32\CLSIDFromString",
                "WStr",
                "{A94CD8B1-0844-4CD6-9D2D-640537AB39E9}",
                "Ptr",
                iid
            )
        }
        local value_pattern := ComValue(13, 0)
        local read_only := 0
        ComCall(14, element, "Int", this.UIA_VALUE_PATTERN_ID, "Ptr", iid, "Ptr*", value_pattern)
        if !value_pattern.Ptr {
            return this.UNKNOWN
        }
        ComCall(5, value_pattern, "Int*", &read_only) ; CurrentIsReadOnly
        return read_only ? this.NO : this.YES
    }

    static GetUIAutomationTextEditability(element) {
        local text_pattern := ComValue(13, 0)
        local document_range := ComValue(13, 0)
        local property_value := Buffer(24, 0)
        try {
            ComCall(
                14,
                element,
                "Int",
                this.UIA_TEXT_PATTERN_ID,
                "Ptr",
                this.GetIUIAutomationTextPatternIID(),
                "Ptr*",
                text_pattern
            )
            if !text_pattern.Ptr {
                return this.UNKNOWN
            }
            ComCall(7, text_pattern, "Ptr*", document_range)
            if !document_range.Ptr {
                return this.UNKNOWN
            }
            ComCall(9, document_range, "Int", this.UIA_IS_READONLY_ATTRIBUTE_ID, "Ptr", property_value)
            if NumGet(property_value, 0, "UShort") != this.VT_BOOL {
                return this.UNKNOWN
            }
            return NumGet(property_value, 8, "Short") = 0 ? this.YES : this.NO
        } catch {
            return this.UNKNOWN
        } finally {
            DllCall("OleAut32\VariantClear", "Ptr", property_value)
        }
    }

    static GetIUIAutomationTextPatternIID() {
        static iid := 0
        if !iid {
            iid := Buffer(16, 0)
            DllCall(
                "Ole32\CLSIDFromString",
                "WStr",
                "{32EBA289-3583-42C9-9C59-3B6D9A1E9B6A}",
                "Ptr",
                iid
            )
        }
        return iid
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

    ; Chrome, Edge, Brave and other Chromium browsers use the Chrome_WidgetWin_1
    ; top-level class. Without a text control, letter keys must pass through so
    ; the browser keeps its shortcuts (e.g. pressing S on a right-click menu
    ; searches the selected text).
    ;
    ; Electron apps also use Chrome_WidgetWin_1 but are deliberately excluded:
    ; their editable areas are not guaranteed to surface as UIA text controls,
    ; so they keep the previous unknown behavior instead of risking a missed
    ; input field.
    static IsBrowserWindow(descriptor) {
        return this.IsBrowserProcess(descriptor.process_name)
            && (this.ContainsClass(descriptor.focus_classes, "chrome_widgetwin_1")
                || this.ContainsClass(descriptor.active_classes, "chrome_widgetwin_1"))
    }

    static IsBrowserProcess(process_name) {
        switch process_name {
            case "brave.exe", "chrome.exe", "chromium.exe", "msedge.exe", "opera.exe", "vivaldi.exe":
                return true
        }
        return false
    }

    static IsBrowserTextTargetType(control_type) {
        ; Chrome reports IsReadOnly unreliably for combo boxes such as search
        ; fields with suggestions. A dropdown can also keep UIA focus on the
        ; highlighted list item (aria-activedescendant) while its filter accepts keys.
        return control_type = this.UIA_EDIT_CONTROL_TYPE_ID
            || control_type = this.UIA_COMBOBOX_CONTROL_TYPE_ID
            || control_type = this.UIA_LIST_ITEM_CONTROL_TYPE_ID
    }

    static ClassifyBrowser(descriptor) {
        local control_types := []
        local control_type, result, focus_text, uia_text
        if this.ContainsEditableClass(descriptor.focus_classes) {
            return this.YES
        }
        ; A native popup menu (#32768) must receive its letter shortcuts.
        if this.ContainsClass(descriptor.focus_classes, "#32768")
            || this.ContainsClass(descriptor.active_classes, "#32768") {
            return this.NO
        }
        control_types := this.GetDescriptorUIAutomationControlTypes(descriptor)
        if !control_types.Length {
            ; UIA is unavailable or reports no focused element; keep the
            ; previous behavior so a real input field is never missed.
            result := this.UNKNOWN
        } else if descriptor.HasOwnProp("uia_text_editability")
            && descriptor.uia_text_editability = this.YES {
            ; Chromium can expose a contenteditable element as a generic UIA
            ; control instead of Edit or Document. The TextPattern range's
            ; IsReadOnly attribute distinguishes it from ordinary page text.
            result := this.YES
        } else {
            ; The first entry is the focused element itself.
            control_type := control_types[1]
            if this.IsBrowserTextTargetType(control_type) {
                result := this.YES
            } else if control_type = this.UIA_DOCUMENT_CONTROL_TYPE_ID {
                if descriptor.HasOwnProp("uia_text_editability")
                    && descriptor.uia_text_editability != this.UNKNOWN {
                    result := descriptor.uia_text_editability
                } else {
                    result := this.IsFocusedDocumentEditable(descriptor.process_id)
                }
            } else {
                ; Menu items, buttons, panes and other non-text elements pass keys
                ; through to the browser.
                result := this.NO
            }
        }
        focus_text := RabbitJoinList(descriptor.focus_classes)
        uia_text := RabbitJoinList(control_types)
        RabbitDebug(
            Format(
                "browser target {} -> {} focus=[{}] uia=[{}]",
                descriptor.process_name,
                result,
                focus_text,
                uia_text
            ),
            Format("RabbitInputTarget.ahk:{}", A_LineNumber),
            1
        )
        return result
    }

    ; A web document (contenteditable) is a text target only when it is not
    ; read-only. Failure to read the property keeps the previous behavior.
    static IsFocusedDocumentEditable(expected_process_id) {
        local uia := this.GetUIAutomation()
        local property_value
        if !uia {
            return this.UNKNOWN
        }
        try {
            local focused_element := ComValue(13, 0)
            ComCall(8, uia, "Ptr*", focused_element)
            if !focused_element.Ptr {
                return this.UNKNOWN
            }
            local process_id := 0
            ComCall(20, focused_element, "Int*", &process_id)
            if process_id != expected_process_id {
                return this.UNKNOWN
            }
            property_value := Buffer(24, 0)
            ComCall(
                10,
                focused_element,
                "Int",
                this.UIA_VALUE_IS_READONLY_PROPERTY_ID,
                "Ptr",
                property_value
            )
            if NumGet(property_value, 0, "UShort") != this.VT_BOOL {
                return this.UNKNOWN
            }
            return NumGet(property_value, 8, "Short") = 0 ? this.YES : this.NO
        } catch {
            return this.UNKNOWN
        } finally {
            if IsSet(property_value) {
                DllCall("OleAut32\VariantClear", "Ptr", property_value)
            }
        }
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

RabbitJoinList(list) {
    local text := ""
    local first := true
    for item in list {
        if first {
            text := item
            first := false
        } else {
            text .= ", " . item
        }
    }
    return text
}
