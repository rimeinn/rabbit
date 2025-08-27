/*
 * Copyright (c) 2023 - 2025 Xuesong Peng <pengxuesong.cn@gmail.com>
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
#Include <RabbitKeyTable>
#Include <RabbitCandidateBox>
#Include <RabbitCaret>
#Include <RabbitTrayMenu>
#Include <RabbitMonitors>
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
    global box, rabbit_traits
    if args.Length >= 3
        layout := Number(args[3])
    if !IsSet(layout) || layout == 0 {
        layout := DllCall("GetKeyboardLayout", "UInt", 0)
    }
    RabbitGlobals.keyboard_layout := layout
    SetDefaultKeyboard()

    fail_count := 0
    while not mutex.Create() {
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
        } else if rime.start_maintenance(m == RABBIT_FULL_MAINTENANCE)
            rime.join_maintenance_thread()
    } else {
        TrayTip()
        TrayTip("维护完成", RABBIT_IME_NAME)
        SetTimer(TrayTip, -2000)
    }
    IN_MAINTENANCE := false

    global session_id := rime.create_session()
    if not session_id {
        SetDefaultKeyboard(RabbitGlobals.keyboard_layout)
        rime.finalize()
        throw Error("未能成功创建 RIME 会话。")
    }

    CleanOldLogs()
    RabbitConfig.load()
    box := CandidateBox()
    RegisterHotKeys()
    UpdateStateLabels()
    if status := rime.get_status(session_id) {
        local schema_id := status.schema_id
        local schema_name := status.schema_name
        local ascii_mode := status.is_ascii_mode
        local full_shape := status.is_full_shape
        local ascii_punct := status.is_ascii_punct
        rime.free_status(status)

        UpdateTrayTip(schema_name, ascii_mode, full_shape, ascii_punct)

        if RabbitConfig.schema_icon.Has(schema_id)
            if RabbitGlobals.current_schema_icon := RabbitConfig.schema_icon[schema_id]
                UpdateTrayIcon()
    }
    SetupTrayMenu()
    box.UpdateUIStyle()
    OnMessage(AHK_NOTIFYICON, ClickHandler.Bind())
    OnMessage(WM_SETTINGCHANGE, OnColorChange.Bind())
    OnMessage(WM_DWMCOLORIZATIONCOLORCHANGED, OnColorChange.Bind())
    if !RabbitConfig.global_ascii
        SetTimer(UpdateWinAscii)

    OnExit(ExitRabbit.Bind(RabbitGlobals.keyboard_layout))
}

; https://www.autohotkey.com/boards/viewtopic.php?f=76&t=101183
SetDefaultKeyboard(locale_id := 0x0409) {
    if FileExist(RabbitUserDataPath() . "\.lang")
        return
    local locale_id_hex := Format("{:08x}", locale_id & 0xffff)
    lang := DllCall("LoadKeyboardLayout", "Str", locale_id_hex, "Int", 0)
    PostMessage(WM_INPUTLANGCHANGEREQUEST := 0x0050, 0, lang, HWND_BROADCAST := 0xffff)
}

ExitRabbit(layout, reason, code) {
    if code == 0
        SetDefaultKeyboard(layout)
    TrayTip()
    ToolTip(, , , STATUS_TOOLTIP)
    if session_id {
        rime.destroy_session(session_id)
        rime.finalize()
    }
    if mutex
        mutex.Close()
}

RegisterHotKeys() {
    global rime
    global suspend_hotkey_mask := 0
    global suspend_hotkey := ""
    local shift := KeyDef.mask["Shift"]
    local ctrl := KeyDef.mask["Ctrl"]
    local alt := KeyDef.mask["Alt"]
    local win := KeyDef.mask["Win"]
    local up := KeyDef.mask["Up"]

    ; Modifiers
    for modifier, _ in KeyDef.modifier_code {
        if modifier == "LWin" or modifier == "RWin" or modifier == "LAlt" or modifier == "RAlt"
            continue ; do not register Win / Alt keys for now
        local mask := KeyDef.mask[modifier]
        Hotkey("$" . modifier, ProcessKey.Bind(modifier, mask), "S0")
        Hotkey("$" . modifier . " Up", ProcessKey.Bind(modifier, mask | up), "S0")
    }

    ; Plain
    Loop 2 {
        local key_map := A_Index = 1 ? KeyDef.plain_keycode : KeyDef.other_keycode
        for key, _ in key_map {
            Hotkey("$" . key, ProcessKey.Bind(key, 0), "S0")
            ; need specify left/right to prevent fallback to modifier down/up hotkeys
            Hotkey("$<^" . key, ProcessKey.Bind(key, ctrl), "S0")
            ; do not register Alt + single key now
            ; if not key = "Tab" {
            ;     Hotkey("$<!" . key, ProcessKey.Bind(key, alt), "S0")
            ;     Hotkey("$>!" . key, ProcessKey.Bind(key, alt), "S0")
            ; }
            Hotkey("$>^" . key, ProcessKey.Bind(key, ctrl), "S0")
            Hotkey("$^!" . key, ProcessKey.Bind(key, ctrl | alt), "S0")
            Hotkey("$!#" . key, ProcessKey.Bind(key, alt | win), "S0")

            ; Do not register Win keys for now
            ; Hotkey("$<#" . key, ProcessKey.Bind(key, win), "S0")
            ; Hotkey("$>#" . key, ProcessKey.Bind(key, win), "S0")
            ; Hotkey("$^#" . key, ProcessKey.Bind(key, ctrl | win), "S0")
            ; Hotkey("$^!#" . key, ProcessKey.Bind(key, ctrl | alt | win), "S0")
        }
    }

    ; Shifted
    Loop 2 {
        local key_map := A_Index = 1 ? KeyDef.shifted_keycode : KeyDef.other_keycode
        for key, _ in key_map {
            Hotkey("$<+" . key, ProcessKey.Bind(key, shift), "S0")
            Hotkey("$>+" . key, ProcessKey.Bind(key, shift), "S0")
            Hotkey("$+^" . key, ProcessKey.Bind(key, shift | ctrl), "S0")
            if not key == "Tab"
                Hotkey("$+!" . key, ProcessKey.Bind(key, shift | alt), "S0")
            Hotkey("$+^!" . key, ProcessKey.Bind(key, shift | ctrl | alt), "S0")

            ; Do not register Win keys for now
            ; Hotkey("$+#" . key, ProcessKey.Bind(key, shift | win), "S0")
            ; Hotkey("$+^#" . key, ProcessKey.Bind(key, shift | ctrl | win), "S0")
            ; Hotkey("$+!#" . key, ProcessKey.Bind(key, shift | alt | win), "S0")
            ; Hotkey("$+^!#" . key, ProcessKey.Bind(key, shift | ctrl | alt | win), "S0")
        }
    }

    ; Special handling
    Hotkey("$Space Up", ProcessKey.Bind("Space", up), "S0")

    ; Read the hotkey to suspend / resume Rabbit
    if !RabbitConfig.suspend_hotkey
        return
    local keys := StrSplit(RabbitConfig.suspend_hotkey, "+", " ", 4)
    local mask := 0
    local target_key := ""
    local num_modifiers := 0
    for k in keys {
        if k = "Control" {
            num_modifiers += !(mask & ctrl)
            mask |= ctrl
        } else if k = "Alt" {
            num_modifiers += !(mask & alt)
            mask |= alt
        } else if k = "Shift" {
            num_modifiers += !(mask & shift)
            mask |= shift
        } else if not target_key {
            target_key := k
        }
    }

    if target_key {
        if KeyDef.rime_to_ahk.Has(target_key)
            target_key := KeyDef.rime_to_ahk[target_key]
        if num_modifiers = 1 {
            if mask & ctrl {
                Hotkey("$<^" . target_key, , "S")
                Hotkey("$>^" . target_key, , "S")
                suspend_hotkey_mask := mask
                suspend_hotkey := target_key
            }
        } else if num_modifiers > 1 {
            local m := "$" . (mask & shift ? "+" : "") .
                                (mask & ctrl ? "^" : "") .
                                (mask & alt ? "!" : "")
            Hotkey(m . target_key, , "S")
            suspend_hotkey_mask := mask
            suspend_hotkey := target_key
        }
    } else if keys.Length == 1 {
        if keys[1] = "Shift" {
            ; do not support now
            Hotkey("$LShift", , "S")
            Hotkey("$RShift", , "S")
            Hotkey("$LShift Up", , "S")
            Hotkey("$RShift Up", , "S")
            suspend_hotkey_mask := mask | up
            suspend_hotkey := "Shift"
        }
    }
}

ProcessKey(key, mask, this_hotkey) {
    global suspend_hotkey_mask, suspend_hotkey
    global last_is_hide
    local code := 0
    Loop 4 {
        local key_map
        switch A_Index {
            case 1:
                key_map := KeyDef.modifier_code
            case 2:
                key_map := KeyDef.plain_keycode
            case 3:
                key_map := KeyDef.shifted_keycode
            case 4:
                key_map := KeyDef.other_keycode
            default:
                return
        }
        for check_key, check_code in key_map {
            if key == check_key {
                code := check_code
                break
            }
        }
        if code
            break
    }
    if not code
        return

    if caps := GetKeyState("CapsLock", "T") {
        if StrLen(key) == 1 and Ord(key) >= Ord("a") and Ord(key) <= Ord("z") ; small case letters
            code += (Ord("A") - Ord("a"))
    }

    if status := rime.get_status(session_id) {
        local old_schema_id := status.schema_id
        local old_ascii_mode := status.is_ascii_mode
        local old_full_shape := status.is_full_shape
        local old_ascii_punct := status.is_ascii_punct
        rime.free_status(status)
    }

    processed := rime.process_key(session_id, code, mask)

    status := rime.get_status(session_id)
    local new_schema_id := status.schema_id
    local new_schema_name := status.schema_name
    local new_ascii_mode := status.is_ascii_mode
    local new_full_shape := status.is_full_shape
    local new_ascii_punct := status.is_ascii_punct
    rime.free_status(status)

    if old_schema_id !== new_schema_id {
        UpdateStateLabels()
    }

    UpdateTrayTip(new_schema_name, new_ascii_mode, new_full_shape, new_ascii_punct)
    if old_schema_id !== new_schema_id && RabbitConfig.schema_icon.Has(new_schema_id) {
        if RabbitGlobals.current_schema_icon := RabbitConfig.schema_icon[new_schema_id]
            UpdateTrayIcon()
    }

    local status_text := ""
    local status_changed := false
    local ascii_changed := false
    if old_ascii_mode != new_ascii_mode {
        ascii_changed := true
        UpdateWinAscii(new_ascii_mode, true)
        status_text := new_ascii_mode ? ASCII_MODE_TRUE_LABEL_ABBR : ASCII_MODE_FALSE_LABEL_ABBR
    } else if old_full_shape != new_full_shape {
        status_changed := true
        status_text := new_full_shape ? FULL_SHAPE_TRUE_LABEL_ABBR : FULL_SHAPE_FALSE_LABEL_ABBR
    } else if old_ascii_punct != new_ascii_punct {
        status_changed := true
        status_text := new_ascii_punct ? ASCII_PUNCT_TRUE_LABEL_ABBR : ASCII_PUNCT_FALSE_LABEL_ABBR
    }

    if RabbitConfig.show_tips && (status_changed || ascii_changed) {
        ToolTip(status_text, , , STATUS_TOOLTIP)
        SetTimer(() => ToolTip(, , , STATUS_TOOLTIP), -RabbitConfig.show_tips_time)
    }

    if commit := rime.get_commit(session_id) {
        if ascii_changed
            last_is_hide := true
        else
            last_is_hide := false
        SendText(commit.text)
        box.Hide()
        rime.free_commit(commit)
    } else
        last_is_hide := false

    if (suspend_hotkey and suspend_hotkey_mask)
            and (key = suspend_hotkey or SubStr(key, 2) = suspend_hotkey)
            and (mask = suspend_hotkey_mask) {
        ToggleSuspend()
        return
    }

    if context := rime.get_context(session_id) {
        static prev_show := false
        static prev_x := 4
        static prev_y := 4
        if context.composition.length > 0 {
            DetectHiddenWindows True
            local start_menu := WinActive("ahk_class Windows.UI.Core.CoreWindow ahk_exe StartMenuExperienceHost.exe")
                             || WinActive("ahk_class Windows.UI.Core.CoreWindow ahk_exe SearchHost.exe")
                             || WinActive("ahk_class Windows.UI.Core.CoreWindow ahk_exe SearchApp.exe")
            DetectHiddenWindows False
            local show_at_left_top := false
            if start_menu {
                hMon := MonitorManage.MonitorFromWindow(start_menu)
                info := MonitorManage.GetMonitorInfo(hMon)
                show_at_left_top := !!info
                if show_at_left_top && !last_is_hide {
                    box.Build(context, &box_width, &box_height)
                    box.Show(info.work.left + 4, info.work.top + 4)
                }
            }
            if !show_at_left_top && GetCaretPos(&caret_x, &caret_y, &caret_w, &caret_h) {
                box.Build(context, &box_width, &box_height)
                if RabbitConfig.fix_candidate_box && prev_show {
                    new_x := prev_x
                    new_y := prev_y
                } else {
                    new_x := caret_x + caret_w
                    new_y := caret_y + caret_h + 4

                    hWnd := WinExist("A")
                    hMon := MonitorManage.MonitorFromWindow(hWnd)
                    info := MonitorManage.GetMonitorInfo(hMon)
                    if info {
                        if new_x + box_width > info.work.right
                            new_x := info.work.right - box_width
                        if new_y + box_height > info.work.bottom
                            new_y := caret_y - 4 - box_height
                    } else {
                        workspace_width := SysGet(16) ; SM_CXFULLSCREEN
                        workspace_height := SysGet(17) ; SM_CYFULLSCREEN
                        if new_x + box_width > workspace_width
                            new_x := workspace_width - box_width
                        if new_y + box_height > workspace_height
                            new_y := caret_y - 4 - box_height
                    }
                }
                if !last_is_hide
                    box.Show(new_x, new_y)
                prev_x := new_x
                prev_y := new_y
            } else if !show_at_left_top {
                backup_mouse_ref := A_CoordModeMouse
                CoordMode("Mouse", "Screen")
                MouseGetPos(&mouse_x, &mouse_y)
                CoordMode("Mouse", backup_mouse_ref)
                box.Build(context, &box_width, &box_height)
                box.Show(mouse_x, mouse_y)
            }
            prev_show := true
        } else {
            box.Hide()
            prev_show := false
        }
        rime.free_context(context)
    }

    if not processed {
        local shift := (mask & KeyDef.mask["Shift"]) ? "+" : ""
        local ctrl := (mask & KeyDef.mask["Ctrl"]) ? "^" : ""
        local alt := (mask & KeyDef.mask["Alt"]) ? "!" : ""
        local win := (mask & KeyDef.mask["Win"]) ? "#" : ""

        local isUp := mask & KeyDef.mask["Up"]
        local hasModifier := mask & (KeyDef.mask["Shift"] | KeyDef.mask["Ctrl"] | KeyDef.mask["Alt"] | KeyDef.mask["Win"])

        if key == "Space" and not hasModifier {
            Send("{Blind}{" . key . (isUp ? " Up" : " Down") . "}")
        } else {
            SendInput(shift . ctrl . alt . win . "{" . key . "}")
        }
    }
}

UpdateStateLabels() {
    global rime, session_id, ASCII_MODE_FALSE_LABEL, ASCII_MODE_TRUE_LABEL, ASCII_MODE_FALSE_LABEL_ABBR, ASCII_MODE_TRUE_LABEL_ABBR, FULL_SHAPE_FALSE_LABEL, FULL_SHAPE_TRUE_LABEL, FULL_SHAPE_FALSE_LABEL_ABBR, FULL_SHAPE_TRUE_LABEL_ABBR, ASCII_PUNCT_FALSE_LABEL, ASCII_PUNCT_TRUE_LABEL, ASCII_PUNCT_FALSE_LABEL_ABBR, ASCII_PUNCT_TRUE_LABEL_ABBR
    if not rime
        return

    str := rime.get_state_label(session_id, "ascii_mode", false)
    ASCII_MODE_FALSE_LABEL := str ? str : "中文"
    str := rime.get_state_label(session_id, "ascii_mode", true)
    ASCII_MODE_TRUE_LABEL := str ? str : "西文"
    slice := rime.get_state_label_abbreviated(session_id, "ascii_mode", false, true)
    ASCII_MODE_FALSE_LABEL_ABBR := (slice and slice.slice !== "") ? slice.slice : "中"
    slice := rime.get_state_label_abbreviated(session_id, "ascii_mode", true, true)
    ASCII_MODE_TRUE_LABEL_ABBR := (slice and slice.slice !== "") ? slice.slice : "西"
    str := rime.get_state_label(session_id, "full_shape", false)
    FULL_SHAPE_FALSE_LABEL := str ? str : "半角"
    str := rime.get_state_label(session_id, "full_shape", true)
    FULL_SHAPE_TRUE_LABEL := str ? str : "全角"
    slice := rime.get_state_label_abbreviated(session_id, "full_shape", false, true)
    FULL_SHAPE_FALSE_LABEL_ABBR := (slice and slice.slice !== "") ? slice.slice : "半"
    slice := rime.get_state_label_abbreviated(session_id, "full_shape", true, true)
    FULL_SHAPE_TRUE_LABEL_ABBR := (slice and slice.slice !== "") ? slice.slice : "全"
    str := rime.get_state_label(session_id, "ascii_punct", false)
    ASCII_PUNCT_FALSE_LABEL := str ? str : "。，"
    str := rime.get_state_label(session_id, "ascii_punct", true)
    ASCII_PUNCT_TRUE_LABEL := str ? str : ". ,"
    slice := rime.get_state_label_abbreviated(session_id, "ascii_punct", false, true)
    ASCII_PUNCT_FALSE_LABEL_ABBR := (slice and slice.slice !== "") ? slice.slice : "。"
    slice := rime.get_state_label_abbreviated(session_id, "ascii_punct", true, true)
    ASCII_PUNCT_TRUE_LABEL_ABBR := (slice and slice.slice !== "") ? slice.slice : "."
}

UpdateWinAscii(target := false, use_target := false, proc_name := "", by_tray_icon := false) {
    if A_IsSuspended
        return
    if RabbitGlobals.on_tray_icon_click && !by_tray_icon
        return
    global rime, session_id
    if !rime || !session_id
        return
    if not proc_name {
        if not act := WinExist("A")
            return
        try {
            proc_name := StrLower(WinGetProcessName())
        }
        if not proc_name
            return
    }
    RabbitGlobals.active_win := proc_name
    ; TODO: current state might not be accurate due to non-atomic
    current := !!rime.get_option(session_id, "ascii_mode")
    if use_target {
        ; force to use passed target
        RabbitGlobals.process_ascii[proc_name] := !!target
    } else if RabbitGlobals.process_ascii.Has(proc_name) {
        ; not first time to active window, restore the ascii_mode
        target := RabbitGlobals.process_ascii[proc_name]
        if current !== target
            rime.set_option(session_id, "ascii_mode", target)
    } else if RabbitConfig.preset_process_ascii.Has(proc_name) {
        ; in preset, set ascii_mode as preset
        target := RabbitConfig.preset_process_ascii[proc_name]
        RabbitGlobals.process_ascii[proc_name] := !!target
        if current !== target
            rime.set_option(session_id, "ascii_mode", target)
    } else {
        ; not in preset, set ascii_mode to false
        target := false
        RabbitGlobals.process_ascii[proc_name] := !!target
        if current !== target
            rime.set_option(session_id, "ascii_mode", target)
    }
    UpdateTrayTip(, target)
    UpdateTrayIcon()
}
