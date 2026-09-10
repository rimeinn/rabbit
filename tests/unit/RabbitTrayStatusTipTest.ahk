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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitTrayMenu.ahk
#Include ..\..\Lib\RabbitRuntimeState.ahk

RunTest("status tip follows current tray icon", TestStatusTipFollowsTrayIcon.Bind())
RunTest("tray about opens a standalone window", TestTrayAboutOpensStandaloneWindow.Bind())

TestStatusTipFollowsTrayIcon() {
    local config := RabbitConfigSnapshot(Map("schema_icon", Map("custom", "custom.ico")))
    local tray := RabbitTrayStatusTipProbe(0, 0, 0, config, 0, 0, (*) => 0)

    tray.UpdateSchemaIcon("custom")
    AssertEqual("custom.ico", tray.GetStatusIconPath(), "The schema status tip lost its configured icon.")

    tray.UpdateSchemaIcon("default")
    AssertEqual("Lib\rabbit.ico", tray.GetStatusIconPath(), "The schema status tip retained an old schema icon.")

    tray.ascii_mode := true
    AssertEqual("Lib\rabbit-ascii.ico", tray.GetStatusIconPath(), "ASCII status did not override the schema icon.")
    AssertEqual(2, tray.update_icon_calls, "Schema changes did not refresh the tray icon.")
}

TestTrayAboutOpensStandaloneWindow() {
    local tray := RabbitTrayAboutProbe()
    AssertTrue(tray.StartAbout(), "The tray about action did not report success.")
    AssertTrue(tray.about_created, "The tray about action did not create a standalone about window.")
    AssertTrue(tray.about_shown, "The tray about action did not show the standalone about window.")
}

class RabbitTrayStatusTipProbe extends RabbitTrayController {
    __New(args*) {
        this.update_icon_calls := 0
        super.__New(args*)
    }

    UpdateIcon() {
        this.update_icon_calls++
    }
}

class RabbitTrayAboutProbe extends RabbitTrayController {
    __New() {
        this.about_created := false
        this.about_shown := false
        super.__New(0, 0, 0, 0, 0, 0, (*) => 0)
    }

    UseLegacySettings() {
        return false
    }

    CreateAboutDialog() {
        this.about_created := true
        return RabbitTrayAboutDialogProbe(this)
    }
}

class RabbitTrayAboutDialogProbe {
    __New(owner) {
        this.owner := owner
        this.disposed := false
        this.Hwnd := 0
    }

    Show(options := "") {
        this.owner.about_shown := true
    }
}

RunTest("tray tooltip localizes defaults and preserves schema labels", TestTranslatedTrayTip.Bind())

TestTranslatedTrayTip() {
    local directory := A_LineFile . "\..\..\..\Locales"
    local old_tip := A_IconTip, runtime, tray
    try {
        RabbitI18n.Initialize(directory, "en-US")
        runtime := RabbitRuntimeState(0, 0, RabbitConfigSnapshot())
        tray := RabbitTrayController(0, 0, 0, 0, runtime, 0, (*) => 0)
        tray.UpdateTip("Test", false, false, false)
        AssertTrue(InStr(A_IconTip, "Left-click"), "Tray instructions were not translated.")
        AssertTrue(InStr(A_IconTip, "Chinese | Half-width"), "Default status labels were not translated.")
        runtime.ascii_mode_false_label := "自定义"
        tray.UpdateTip()
        AssertTrue(InStr(A_IconTip, "自定义"), "Schema labels were replaced by translations.")
        RabbitI18n.Initialize(directory, "ja-JP")
        tray.UpdateTip()
        AssertTrue(InStr(A_IconTip, "左クリック"), "Tray instructions retained the previous language.")
    } finally {
        A_IconTip := old_tip
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}
