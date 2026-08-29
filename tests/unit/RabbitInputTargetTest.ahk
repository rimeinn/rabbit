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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitInputTarget.ahk

RunTest("Explorer file view is a type-ahead target", TestExplorerFileViewIsTypeAhead.Bind())
RunTest("Explorer edit control remains a text target", TestExplorerEditControlIsYes.Bind())
RunTest("Process Explorer process list is a type-ahead target", TestProcessExplorerListIsTypeAhead.Bind())
RunTest("Process Explorer edit control remains a text target", TestProcessExplorerEditControlIsYes.Bind())
RunTest("WPF list is a type-ahead target", TestWpfListIsTypeAhead.Bind())
RunTest("WPF tree is a type-ahead target", TestWpfTreeIsTypeAhead.Bind())
RunTest("WPF file grid is a type-ahead target", TestWpfFileGridIsTypeAhead.Bind())
RunTest("WPF edit control is a text target", TestWpfEditControlIsYes.Bind())
RunTest("WPF document control is a text target", TestWpfDocumentControlIsYes.Bind())
RunTest("WPF nested editor takes priority over its list", TestWpfNestedEditorIsYes.Bind())
RunTest("WPF active window identifies a native child target", TestWpfActiveWindowIdentifiesNativeChild.Bind())
RunTest("WPF unrecognized control remains unknown", TestWpfUnknownControl.Bind())
RunTest("UIA list in a non-WPF window remains unknown", TestNonWpfUIAutomationListIsUnknown.Bind())
RunTest("Open With app list is a non-text target", TestOpenWithListIsNo.Bind())
RunTest("Open With edit control remains a text target", TestOpenWithEditControlIsYes.Bind())
RunTest("Open With class in another process remains unknown", TestOpenWithClassInAnotherProcessIsUnknown.Bind())
RunTest("Common file dialog view is a type-ahead target", TestCommonFileDialogViewIsTypeAhead.Bind())
RunTest("Common folder dialog tree is a type-ahead target", TestCommonFolderDialogTreeIsTypeAhead.Bind())
RunTest("Common file dialog edit control remains a text target", TestCommonFileDialogEditIsYes.Bind())
RunTest("Unrecognized common dialog remains unknown", TestUnknownCommonDialog.Bind())
RunTest("Desktop is a type-ahead target", TestDesktopIsTypeAhead.Bind())
RunTest("Taskbar button is a non-text target", TestTaskbarButtonIsNo.Bind())
RunTest("Chrome address bar is a text target", TestChromeAddressBarIsYes.Bind())
RunTest("Chrome native menu is a non-text target", TestChromeNativeMenuIsNo.Bind())
RunTest("Chrome page edit control is a text target", TestChromePageEditIsYes.Bind())
RunTest("Chrome generic contenteditable is a text target", TestChromeGenericContenteditableIsYes.Bind())
RunTest("Chrome generic page area is a non-text target", TestChromeGenericPageAreaIsNo.Bind())
RunTest("Chrome editable document is a text target", TestChromeEditableDocumentIsYes.Bind())
RunTest("Chrome read-only document is a non-text target", TestChromeReadOnlyDocumentIsNo.Bind())
RunTest("Chrome search combo box is a text target", TestChromeSearchComboboxIsYes.Bind())
RunTest("Chrome dropdown picker list item is a text target", TestChromeDropdownListItemIsYes.Bind())
RunTest("Chrome context menu item is a non-text target", TestChromeContextMenuItemIsNo.Bind())
RunTest("Chrome page without UIA focus remains unknown", TestChromePageWithoutUIAFocusIsUnknown.Bind())
RunTest("Edge non-editable page area is a non-text target", TestEdgePageAreaIsNo.Bind())
RunTest("Electron app keeps the previous behavior", TestElectronAppIsUnknown.Bind())
RunTest("Unrecognized target remains unknown", TestUnknownTarget.Bind())

TestExplorerFileViewIsTypeAhead() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "explorer.exe",
            ["directuihwnd", "shelldll_defview"]
        )),
        "The Explorer file view was not classified as a type-ahead target."
    )
}

TestExplorerEditControlIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "explorer.exe",
            ["edit", "directuihwnd", "cabinetwclass"]
        )),
        "An Explorer edit control was classified as a non-text target."
    )
}

TestProcessExplorerListIsTypeAhead() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "procexp64.exe",
            ["syslistview32", "procexplorer"],
            ["procexplorer"]
        )),
        "The Process Explorer process list was not classified as a type-ahead target."
    )
}

TestProcessExplorerEditControlIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "procexp64.exe",
            ["edit", "procexplorer"],
            ["procexplorer"]
        )),
        "A Process Explorer edit control was classified as a non-text target."
    )
}

TestWpfListIsTypeAhead() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "wpf_app.exe",
            ["hwndwrapper[wpf_app.exe;;window-id]"],
            [],
            [
                RabbitInputTarget.UIA_LIST_ITEM_CONTROL_TYPE_ID,
                RabbitInputTarget.UIA_LIST_CONTROL_TYPE_ID
            ]
        )),
        "A WPF list was not classified as a type-ahead target."
    )
}

TestWpfTreeIsTypeAhead() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "wpf_app.exe",
            ["hwndwrapper[wpf_app.exe;;window-id]"],
            [],
            [
                RabbitInputTarget.UIA_TREE_ITEM_CONTROL_TYPE_ID,
                RabbitInputTarget.UIA_TREE_CONTROL_TYPE_ID
            ]
        )),
        "A WPF tree was not classified as a type-ahead target."
    )
}

TestWpfFileGridIsTypeAhead() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "wpf_app.exe",
            ["hwndwrapper[wpf_app.exe;;window-id]"],
            [],
            [
                RabbitInputTarget.UIA_DATA_ITEM_CONTROL_TYPE_ID,
                RabbitInputTarget.UIA_DATA_GRID_CONTROL_TYPE_ID
            ]
        )),
        "A WPF file grid was not classified as a type-ahead target."
    )
}

TestWpfEditControlIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "wpf_app.exe",
            ["hwndwrapper[wpf_app.exe;;window-id]"],
            [],
            [RabbitInputTarget.UIA_EDIT_CONTROL_TYPE_ID]
        )),
        "A WPF edit control was not classified as a text target."
    )
}

TestWpfDocumentControlIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "wpf_app.exe",
            ["hwndwrapper[wpf_app.exe;;window-id]"],
            [],
            [RabbitInputTarget.UIA_DOCUMENT_CONTROL_TYPE_ID]
        )),
        "A WPF document control was not classified as a text target."
    )
}

TestWpfNestedEditorIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "wpf_app.exe",
            ["hwndwrapper[wpf_app.exe;;window-id]"],
            [],
            [
                RabbitInputTarget.UIA_EDIT_CONTROL_TYPE_ID,
                RabbitInputTarget.UIA_DATA_GRID_CONTROL_TYPE_ID
            ]
        )),
        "A WPF editor nested in a list did not take priority over the list."
    )
}

TestWpfActiveWindowIdentifiesNativeChild() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "hybrid_wpf_app.exe",
            ["windowsforms10.window.8.app"],
            ["hwndwrapper[hybrid_wpf_app.exe;;window-id]"],
            [RabbitInputTarget.UIA_LIST_CONTROL_TYPE_ID]
        )),
        "A native child of an active WPF window was not classified using UIA."
    )
}

TestWpfUnknownControl() {
    AssertEqual(
        RabbitInputTarget.UNKNOWN,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "wpf_app.exe",
            ["hwndwrapper[wpf_app.exe;;window-id]"],
            [],
            [50000]
        )),
        "An unrecognized WPF control did not remain unknown."
    )
}

TestNonWpfUIAutomationListIsUnknown() {
    AssertEqual(
        RabbitInputTarget.UNKNOWN,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "non_wpf_app.exe",
            ["customwindow"],
            [],
            [RabbitInputTarget.UIA_LIST_CONTROL_TYPE_ID]
        )),
        "A UIA list in a non-WPF window was classified as a non-text target."
    )
}

TestOpenWithListIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "openwith.exe",
            ["open with"],
            ["open with"]
        )),
        "The Open With app list was not classified as a non-text target."
    )
}

TestOpenWithEditControlIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "openwith.exe",
            ["edit", "open with"],
            ["open with"]
        )),
        "An Open With edit control was classified as a non-text target."
    )
}

TestOpenWithClassInAnotherProcessIsUnknown() {
    AssertEqual(
        RabbitInputTarget.UNKNOWN,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "other.exe",
            ["open with"],
            ["open with"]
        )),
        "An Open With class owned by another process was classified as a non-text target."
    )
}

TestCommonFileDialogViewIsTypeAhead() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "node.exe",
            ["directuihwnd", "shelldll_defview", "duiviewwndclassname", "#32770"],
            ["#32770"]
        )),
        "A common file dialog view was not classified as a type-ahead target."
    )
}

TestCommonFolderDialogTreeIsTypeAhead() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "node.exe",
            ["systreeview32", "#32770"],
            ["#32770"]
        )),
        "A common folder dialog tree was not classified as a type-ahead target."
    )
}

TestCommonFileDialogEditIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "node.exe",
            ["edit", "combobox", "#32770"],
            ["#32770"]
        )),
        "A common file dialog edit control was classified as a non-text target."
    )
}

TestUnknownCommonDialog() {
    AssertEqual(
        RabbitInputTarget.UNKNOWN,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "node.exe",
            ["button", "#32770"],
            ["#32770"]
        )),
        "An unrecognized common dialog was classified as a non-text target."
    )
}

TestDesktopIsTypeAhead() {
    AssertEqual(
        RabbitInputTarget.TYPE_AHEAD,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "explorer.exe",
            ["workerw"]
        )),
        "The desktop was not classified as a type-ahead target."
    )
}

TestTaskbarButtonIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "explorer.exe",
            ["mstasklistwclass", "shell_traywnd"]
        )),
        "The taskbar button area was not classified as a non-text target."
    )
}

TestChromeAddressBarIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "chrome.exe",
            ["edit", "chrome_widgetwin_1"]
        )),
        "A Chrome address bar edit control was classified as a non-text target."
    )
}

TestChromeNativeMenuIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "msedge.exe",
            ["#32768", "chrome_widgetwin_1"]
        )),
        "A Chrome native popup menu was not passed through to the browser."
    )
}

TestChromePageEditIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "chrome.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [RabbitInputTarget.UIA_EDIT_CONTROL_TYPE_ID]
        )),
        "A Chrome page edit control was classified as a non-text target."
    )
}

TestChromeGenericContenteditableIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "msedge.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [50026], ; UIA_GROUP_CONTROL_TYPE_ID
            RabbitInputTarget.YES
        )),
        "A Chrome generic contenteditable control was classified as a non-text target."
    )
}

TestChromeGenericPageAreaIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "msedge.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [50026] ; UIA_GROUP_CONTROL_TYPE_ID
        )),
        "A Chrome generic page area was classified as a text target."
    )
}

TestChromeEditableDocumentIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "chrome.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [RabbitInputTarget.UIA_DOCUMENT_CONTROL_TYPE_ID],
            RabbitInputTarget.YES
        )),
        "An editable Chrome document was classified as a non-text target."
    )
}

TestChromeReadOnlyDocumentIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "chrome.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [RabbitInputTarget.UIA_DOCUMENT_CONTROL_TYPE_ID],
            RabbitInputTarget.NO
        )),
        "A read-only Chrome document was classified as a text target."
    )
}

TestChromeSearchComboboxIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "chrome.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [RabbitInputTarget.UIA_COMBOBOX_CONTROL_TYPE_ID]
        )),
        "A Chrome search combo box was classified as a non-text target."
    )
}

TestChromeDropdownListItemIsYes() {
    AssertEqual(
        RabbitInputTarget.YES,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "chrome.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [RabbitInputTarget.UIA_LIST_ITEM_CONTROL_TYPE_ID]
        )),
        "A Chrome dropdown picker list item was classified as a non-text target."
    )
}

TestChromeContextMenuItemIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "chrome.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [RabbitInputTarget.UIA_MENU_ITEM_CONTROL_TYPE_ID]
        )),
        "A Chrome context menu item was not passed through to the browser."
    )
}

TestChromePageWithoutUIAFocusIsUnknown() {
    AssertEqual(
        RabbitInputTarget.UNKNOWN,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "chrome.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"]
        )),
        "A Chrome page without UIA focus did not keep the previous behavior."
    )
}

TestEdgePageAreaIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "msedge.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [50033] ; UIA_PANE_CONTROL_TYPE_ID
        )),
        "An Edge non-editable page area was not passed through to the browser."
    )
}

TestElectronAppIsUnknown() {
    AssertEqual(
        RabbitInputTarget.UNKNOWN,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "Code.exe",
            ["chrome_renderwidgethosthwnd", "chrome_widgetwin_1"],
            [],
            [RabbitInputTarget.UIA_EDIT_CONTROL_TYPE_ID]
        )),
        "An Electron app using Chrome_WidgetWin_1 did not keep the previous behavior."
    )
}

TestUnknownTarget() {
    AssertEqual(
        RabbitInputTarget.UNKNOWN,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "custom_editor.exe",
            ["customtextsurface"]
        )),
        "An unrecognized target was not kept in the unknown state."
    )
}

CreateTargetDescriptor(
    process_name,
    focus_classes,
    active_classes := [],
    uia_control_types := [],
    uia_text_editability := RabbitInputTarget.UNKNOWN
) {
    return {
        process_name: process_name,
        focus_classes: focus_classes,
        active_classes: active_classes,
        uia_control_types: uia_control_types,
        uia_text_editability: uia_text_editability
    }
}
