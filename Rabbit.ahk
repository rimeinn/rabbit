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
#Requires AutoHotkey v2.0
#SingleInstance Ignore

;@Ahk2Exe-SetInternalName rabbit
;@Ahk2Exe-SetProductName 玉兔毫
;@Ahk2Exe-SetOrigFilename Rabbit.ahk

#Include <RabbitCommon>
#Include <RabbitCandidateBoxFactory>
#Include <RabbitInput>
#Include <RabbitRuntimeState>
#Include <RabbitTrayMenu>
#Include <RabbitUIStyle>
#Include <RabbitConfig>

global IN_MAINTENANCE := false
global session_id := 0
global mutex := RabbitMutex()
global last_is_hide := false

RabbitMain(A_Args)

; args[1]: maintenance option
; args[2]: deployer result
; args[3]: keyboard layout
RabbitMain(args) {
    local layout, fail_count, status
    global box, rabbit_traits
    if args.Length >= 3 {
        layout := Number(args[3])
    }
    if !IsSet(layout) || layout == 0 {
        layout := DllCall("GetKeyboardLayout", "UInt", 0)
    }
    RabbitGlobals.keyboard_layout := layout
    SetDefaultKeyboard()

    fail_count := 0
    while !mutex.Create() {
        mutex.Close()
        fail_count++
        if fail_count > 500 {
            TrayTip()
            TrayTip("有其他进程正在使用 RIME，启动失败")
            Sleep(2000)
            ExitApp()
        }
    }

    ; TODO: better handling of first run
    local first_run := !FileExist(RabbitUserDataPath() . "\default.custom.yaml")
        || !FileExist(RabbitUserDataPath() . "\rabbit.custom.yaml")
        || !FileExist(RabbitUserDataPath() . "\user.yaml")
        || !FileExist(RabbitUserDataPath() . "\installation.yaml")
        || !FileExist(RabbitUserDataPath() . "\build\rabbit.yaml") ; in staging dir

    rabbit_traits := CreateTraits()
    global rime
    rime.setup(rabbit_traits)
    rime.set_notification_handler(OnRimeMessage, 0)
    rime.initialize(rabbit_traits)

    local m := (args.Length == 0) ? RABBIT_PARTIAL_MAINTENANCE : args[1]
    if m != RABBIT_NO_MAINTENANCE {
        global IN_MAINTENANCE := true
        UpdateTrayIcon()
        if first_run {
            RunDeployer("install", RabbitGlobals.keyboard_layout)
        } else if rime.start_maintenance(m == RABBIT_FULL_MAINTENANCE) {
            rime.join_maintenance_thread()
        }
    } else {
        TrayTip()
        TrayTip("维护完成", RABBIT_IME_NAME)
        SetTimer(TrayTip, -2000)
    }
    IN_MAINTENANCE := false

    global session_id := rime.create_session()
    if !session_id {
        SetDefaultKeyboard(RabbitGlobals.keyboard_layout)
        rime.finalize()
        throw Error("未能成功创建 RIME 会话。")
    }

    CleanOldLogs()
    CleanMisPlacedConfigs()
    RabbitConfig.load()
    box := RabbitCandidateBoxFactory().Create(RabbitConfig.use_legacy_candidate_box)
    RegisterHotKeys()
    UpdateStateLabels()
    if (status := rime.get_status(session_id)) {
        local schema_id := status.schema_id
        local schema_name := status.schema_name
        local ascii_mode := status.is_ascii_mode
        local full_shape := status.is_full_shape
        local ascii_punct := status.is_ascii_punct
        rime.free_status(status)

        UpdateTrayTip(schema_name, ascii_mode, full_shape, ascii_punct)

        if RabbitConfig.schema_icon.Has(schema_id) {
            if (RabbitGlobals.current_schema_icon := RabbitConfig.schema_icon[schema_id]) {
                UpdateTrayIcon()
            }
        }
    }
    SetupTrayMenu()
    box.UpdateStyle(UIStyle)
    OnMessage(AHK_NOTIFYICON, ClickHandler.Bind())
    OnMessage(WM_SETTINGCHANGE, OnColorChange.Bind())
    OnMessage(WM_DWMCOLORIZATIONCOLORCHANGED, OnColorChange.Bind())
    if !RabbitConfig.global_ascii {
        SetTimer(UpdateWinAscii)
    }
    OnExit(ExitRabbit.Bind(RabbitGlobals.keyboard_layout))
}

; https://www.autohotkey.com/boards/viewtopic.php?f=76&t=101183
SetDefaultKeyboard(locale_id := 0x0409) {
    local lang, WM_INPUTLANGCHANGEREQUEST, HWND_BROADCAST
    if FileExist(RabbitUserDataPath() . "\.lang") {
        return
    }
    local locale_id_hex := Format("{:08x}", locale_id & 0xffff)
    lang := DllCall("LoadKeyboardLayout", "Str", locale_id_hex, "Int", 0)
    PostMessage(WM_INPUTLANGCHANGEREQUEST := 0x0050, 0, lang, HWND_BROADCAST := 0xffff)
}

ExitRabbit(layout, reason, code) {
    if code == 0 {
        SetDefaultKeyboard(layout)
    }
    TrayTip()
    ToolTip(, , , STATUS_TOOLTIP)
    if box && HasMethod(box, "Dispose") {
        box.Dispose()
    }
    if session_id {
        rime.destroy_session(session_id)
        rime.finalize()
    }
    if mutex {
        mutex.Close()
    }
}
