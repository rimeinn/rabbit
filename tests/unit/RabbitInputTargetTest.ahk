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

RunTest("Explorer file view is a non-text target", TestExplorerFileViewIsNo.Bind())
RunTest("Explorer edit control remains a text target", TestExplorerEditControlIsYes.Bind())
RunTest("Process Explorer process list is a non-text target", TestProcessExplorerListIsNo.Bind())
RunTest("Process Explorer edit control remains a text target", TestProcessExplorerEditControlIsYes.Bind())
RunTest("Desktop is a non-text target", TestDesktopIsNo.Bind())
RunTest("Taskbar button is a non-text target", TestTaskbarButtonIsNo.Bind())
RunTest("Unrecognized target remains unknown", TestUnknownTarget.Bind())

TestExplorerFileViewIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "explorer.exe",
            ["directuihwnd", "shelldll_defview"]
        )),
        "The Explorer file view was not classified as a non-text target."
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

TestProcessExplorerListIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "procexp64.exe",
            ["syslistview32", "procexplorer"],
            ["procexplorer"]
        )),
        "The Process Explorer process list was not classified as a non-text target."
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

TestDesktopIsNo() {
    AssertEqual(
        RabbitInputTarget.NO,
        RabbitInputTarget.ClassifyDescriptor(CreateTargetDescriptor(
            "explorer.exe",
            ["workerw"]
        )),
        "The desktop was not classified as a non-text target."
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

CreateTargetDescriptor(process_name, focus_classes, active_classes := []) {
    return {
        process_name: process_name,
        focus_classes: focus_classes,
        active_classes: active_classes
    }
}
