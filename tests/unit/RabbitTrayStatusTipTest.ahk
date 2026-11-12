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

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitTrayMenu.ahk
#Include ..\..\Lib\RabbitRuntimeState.ahk

RunTest("status tip follows current tray icon", TestStatusTipFollowsTrayIcon.Bind())
RunTest("tray about opens a standalone window", TestTrayAboutOpensStandaloneWindow.Bind())

TestStatusTipFollowsTrayIcon() {
    local config := RabbitConfigSnapshot(Map("schema_icon", Map("custom", "custom.ico")))
    local tray := RabbitTrayStatusTipProbe(0, 0, 0, config, 0, (*) => 0, (*) => 0)

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
        this.format_tip_calls := 0
        super.__New(args*)
    }

    UpdateIcon() {
        this.update_icon_calls++
    }

    FormatTip(args*) {
        this.format_tip_calls++
        return super.FormatTip(args*)
    }
}

class RabbitTrayAboutProbe extends RabbitTrayController {
    __New() {
        this.about_created := false
        this.about_shown := false
        super.__New(0, 0, 0, 0, 0, (*) => 0, (*) => 0)
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
RunTest("tray tooltip updates only when the visible text changes", TestTrayTipUpdatesOnTextChange.Bind())
RunTest("tray tooltip reloads a catalog in the current language", TestTrayTipCatalogReload.Bind())

TestTranslatedTrayTip() {
    local directory := A_LineFile . "\..\..\..\Locales"
    local old_tip := A_IconTip, runtime, tray, rebound_runtime
    try {
        RabbitI18n.Initialize(directory, "en-US")
        runtime := RabbitRuntimeState(0, 0, RabbitConfigSnapshot())
        tray := RabbitTrayController(0, 0, 0, 0, runtime, (*) => 0, (*) => 0)
        tray.UpdateTip("Test", false, false, false)
        AssertTrue(InStr(A_IconTip, "Left-click"), "Tray instructions were not translated.")
        AssertTrue(InStr(A_IconTip, "Chinese | Half-width"), "Default status labels were not translated.")
        runtime.ascii_mode_false_label := "自定义"
        AssertTrue(tray.UpdateTip(), "Changing a schema label did not refresh the tooltip.")
        AssertTrue(InStr(A_IconTip, "自定义"), "Schema labels were replaced by translations.")
        runtime.full_shape_false_label := "Half"
        AssertTrue(tray.UpdateTip(), "Changing the shape label did not refresh the tooltip.")
        runtime.ascii_punct_false_label := "Symbols"
        AssertTrue(tray.UpdateTip(), "Changing the punctuation label did not refresh the tooltip.")
        AssertTrue(InStr(A_IconTip, "Half | Symbols"), "The updated shape and punctuation labels were not shown.")
        RabbitI18n.Initialize(directory, "ja-JP")
        AssertTrue(tray.UpdateTip(), "Changing the language did not refresh the tooltip.")
        AssertTrue(InStr(A_IconTip, "左クリック"), "Tray instructions retained the previous language.")

        rebound_runtime := RabbitRuntimeState(0, 0, RabbitConfigSnapshot())
        rebound_runtime.ascii_mode_false_label := "Rebound"
        tray.UnbindRuntime()
        tray.BindRuntime(0, 0, 0, 0, rebound_runtime)
        AssertTrue(tray.UpdateTip(), "Binding a new runtime did not refresh the tooltip.")
        AssertTrue(InStr(A_IconTip, "Rebound"), "The tooltip did not use the new runtime's labels.")
        AssertTrue(!tray.UpdateTip(), "The unchanged rebound tooltip was rewritten.")
    } finally {
        A_IconTip := old_tip
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}

TestTrayTipUpdatesOnTextChange() {
    local directory := A_LineFile . "\..\..\..\Locales"
    local old_tip := A_IconTip
    local was_suspended := A_IsSuspended
    local rendered_tip, formatted_count
    try {
        RabbitI18n.Initialize(directory, "en-US")
        local runtime := RabbitRuntimeState(0, 0, RabbitConfigSnapshot())
        local tray := RabbitTrayStatusTipProbe(0, 0, 0, 0, runtime, (*) => 0, (*) => 0)
        AssertTrue(tray.UpdateTip("Test"), "The initial tooltip was not written.")
        AssertTrue(!tray.UpdateTip(), "The unchanged tooltip was rewritten.")
        AssertEqual(1, tray.format_tip_calls, "The unchanged tooltip was reformatted.")
        AssertTrue(tray.UpdateTip("test"), "A case-only schema rename did not refresh the tooltip.")

        Suspend(!was_suspended)
        AssertTrue(tray.UpdateTip(), "A suspend state change did not refresh the tooltip.")
        AssertTrue(!tray.UpdateTip(), "The unchanged suspend state rewrote the tooltip.")

        local long_schema := Format("{:130}", "Long schema")
        AssertTrue(tray.UpdateTip(long_schema), "The long tooltip was not written.")
        AssertEqual(127, StrLen(A_IconTip), "The tooltip did not fit the tray buffer.")
        formatted_count := tray.format_tip_calls
        AssertTrue(!tray.UpdateTip(), "The truncated tooltip was rewritten.")

        rendered_tip := A_IconTip
        A_IconTip := "Maintenance"
        AssertTrue(tray.UpdateTip(), "The frontend tooltip was not restored after an external write.")
        AssertTrue(A_IconTip == rendered_tip, "The restored tooltip differed from the original.")
        AssertTrue(!tray.UpdateTip(), "The unchanged restored tooltip was rewritten.")
        AssertEqual(formatted_count, tray.format_tip_calls, "Restoring cached text repeated tooltip formatting.")
    } finally {
        Suspend(was_suspended)
        A_IconTip := old_tip
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}

TestTrayTipCatalogReload() {
    local directory := A_Temp . "\rabbit-tray-catalog-" . DllCall("GetCurrentProcessId") . "-" . A_TickCount
    local catalog := directory . "\en-US.ini"
    local old_tip := A_IconTip, runtime, tray
    DirCreate(directory)
    try {
        FileAppend("[frontend]`nicon_tip=Original {schema}: {ascii}`n", catalog, "UTF-8-RAW")
        RabbitI18n.Initialize(directory, "en-US")
        runtime := RabbitRuntimeState(0, 0, RabbitConfigSnapshot())
        tray := RabbitTrayController(0, 0, 0, 0, runtime, (*) => 0, (*) => 0)
        tray.UpdateTip("Test")
        AssertTrue(InStr(A_IconTip, "Original Test"), "The initial catalog template was not displayed.")

        FileDelete(catalog)
        FileAppend("[frontend]`nicon_tip=Updated {schema}: {ascii}`n", catalog, "UTF-8-RAW")
        RabbitI18n.Initialize(directory, "en-US")
        AssertTrue(tray.UpdateTip(), "Reloading a catalog in the same language did not refresh the tooltip.")
        AssertTrue(InStr(A_IconTip, "Updated Test"), "The tooltip retained the previous catalog template.")
        AssertTrue(!tray.UpdateTip(), "The unchanged reloaded tooltip was rewritten.")
    } finally {
        A_IconTip := old_tip
        RabbitI18n.Initialize(A_LineFile . "\..\..\..\Locales", "zh-CN")
        if FileExist(catalog) {
            FileDelete(catalog)
        }
        DirDelete(directory)
    }
}
