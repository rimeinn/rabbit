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

#Include <RabbitCommon>
#Include <RabbitKeyTable>
#Include <RabbitCaret>
#Include <RabbitMonitors>
#Include <RabbitConfig>
#Include <RabbitRuntimeState>
#Include <RabbitTrayMenu>

RegisterHotKeys() {
    local modifier, _, key, k
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
        if modifier == "LWin" || modifier == "RWin" || modifier == "LAlt" || modifier == "RAlt" {
            ; Win and Alt modifiers are intentionally unsupported for now.
            continue
        }
        local mask := KeyDef.mask[modifier]
        Hotkey("$" . modifier, ProcessKey.Bind(modifier, mask), "S0")
        Hotkey("$" . modifier . " Up", ProcessKey.Bind(modifier, mask | up), "S0")
    }

    ; Plain
    Loop 2 {
        local key_map := A_Index = 1 ? KeyDef.plain_keycode : KeyDef.other_keycode
        for key, _ in key_map {
            Hotkey("$" . key, ProcessKey.Bind(key, 0), "S0")
            ; Specify left/right to prevent fallback to modifier down/up hotkeys.
            Hotkey("$<^" . key, ProcessKey.Bind(key, ctrl), "S0")
            ; Alt plus a single key is intentionally unsupported for now.
            ; if key != "Tab" {
            ;     Hotkey("$<!" . key, ProcessKey.Bind(key, alt), "S0")
            ;     Hotkey("$>!" . key, ProcessKey.Bind(key, alt), "S0")
            ; }
            Hotkey("$>^" . key, ProcessKey.Bind(key, ctrl), "S0")
            Hotkey("$^!" . key, ProcessKey.Bind(key, ctrl | alt), "S0")
            Hotkey("$!#" . key, ProcessKey.Bind(key, alt | win), "S0")

            ; Win-key combinations are intentionally unsupported for now.
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
            if !key == "Tab" {
                Hotkey("$+!" . key, ProcessKey.Bind(key, shift | alt), "S0")
            }
            Hotkey("$+^!" . key, ProcessKey.Bind(key, shift | ctrl | alt), "S0")

            ; Win-key combinations are intentionally unsupported for now.
            ; Hotkey("$+#" . key, ProcessKey.Bind(key, shift | win), "S0")
            ; Hotkey("$+^#" . key, ProcessKey.Bind(key, shift | ctrl | win), "S0")
            ; Hotkey("$+!#" . key, ProcessKey.Bind(key, shift | alt | win), "S0")
            ; Hotkey("$+^!#" . key, ProcessKey.Bind(key, shift | ctrl | alt | win), "S0")
        }
    }

    ; Special handling
    Hotkey("$Space Up", ProcessKey.Bind("Space", up), "S0")

    ; Read the hotkey to suspend / resume Rabbit
    if !RabbitConfig.suspend_hotkey {
        return
    }
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
        } else if !target_key {
            target_key := k
        }
    }

    if target_key {
        if KeyDef.rime_to_ahk.Has(target_key) {
            target_key := KeyDef.rime_to_ahk[target_key]
        }
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
            ; A standalone Shift key is intentionally unsupported for now.
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
    local check_key, check_code, caps, status, processed, commit, context, hmon, info, box_width, box_height
    local caret_x, caret_y, caret_w, caret_h, new_x, new_y, hwnd, workspace_width, workspace_height
    local backup_mouse_ref, mouse_x, mouse_y
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
        if code {
            break
        }
    }
    if !code {
        return
    }
    if (caps := GetKeyState("CapsLock", "T")) {
        if StrLen(key) == 1 && Ord(key) >= Ord("a") && Ord(key) <= Ord("z") { ; small case letters
            code += (Ord("A") - Ord("a"))
        }
    }

    if (status := rime.get_status(session_id)) {
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
        if (RabbitGlobals.current_schema_icon := RabbitConfig.schema_icon[new_schema_id]) {
            UpdateTrayIcon()
        }
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

    if (commit := rime.get_commit(session_id)) {
        if ascii_changed {
            last_is_hide := true
        } else {
            last_is_hide := false
        }
        if StrLen(commit.text) >= RabbitConfig.send_by_clipboard_length {
            SendTextByClipboard(commit.text)
        } else {
            SendText(commit.text)
        }
        box.Hide()
        rime.free_commit(commit)
    } else {
        last_is_hide := false
    }
    if suspend_hotkey && suspend_hotkey_mask
        && (key = suspend_hotkey || SubStr(key, 2) = suspend_hotkey)
        && (mask = suspend_hotkey_mask) {
        ToggleSuspend()
        return
    }

    if (context := rime.get_context(session_id)) {
        static prev_show := false
        static prev_x := 4
        static prev_y := 4
        if context.composition.length > 0 || context.menu.num_candidates > 0 {
            DetectHiddenWindows True
            local start_menu := WinActive("ahk_class Windows.UI.Core.CoreWindow ahk_exe StartMenuExperienceHost.exe")
                || WinActive("ahk_class Windows.UI.Core.CoreWindow ahk_exe SearchHost.exe")
                || WinActive("ahk_class Windows.UI.Core.CoreWindow ahk_exe SearchApp.exe")
            DetectHiddenWindows False
            local show_at_left_top := false
            if start_menu {
                hmon := MonitorManage.MonitorFromWindow(start_menu)
                info := MonitorManage.GetMonitorInfo(hmon)
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

                    hwnd := WinExist("A")
                    hmon := MonitorManage.MonitorFromWindow(hwnd)
                    info := MonitorManage.GetMonitorInfo(hmon)
                    if info {
                        if new_x + box_width > info.work.right {
                            new_x := info.work.right - box_width
                        }
                        if new_y + box_height > info.work.bottom {
                            new_y := caret_y - 4 - box_height
                        }
                    } else {
                        workspace_width := SysGet(16) ; SM_CXFULLSCREEN
                        workspace_height := SysGet(17) ; SM_CYFULLSCREEN
                        if new_x + box_width > workspace_width {
                            new_x := workspace_width - box_width
                        }
                        if new_y + box_height > workspace_height {
                            new_y := caret_y - 4 - box_height
                        }
                    }
                }
                if !last_is_hide {
                    box.Show(new_x, new_y)
                }
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

    if !processed {
        local shift := (mask & KeyDef.mask["Shift"]) ? "+" : ""
        local ctrl := (mask & KeyDef.mask["Ctrl"]) ? "^" : ""
        local alt := (mask & KeyDef.mask["Alt"]) ? "!" : ""
        local win := (mask & KeyDef.mask["Win"]) ? "#" : ""

        local is_up := mask & KeyDef.mask["Up"]
        local has_modifier := mask & (KeyDef.mask["Shift"] | KeyDef.mask["Ctrl"] | KeyDef.mask["Alt"] | KeyDef.mask["Win"])

        if key == "Space" && !has_modifier {
            Send("{Blind}{" . key . (is_up ? " Up" : " Down") . "}")
        } else {
            SendInput(shift . ctrl . alt . win . "{" . key . "}")
        }
    }
}

; by rawbx (https://github.com/rimeinn/rabbit/issues/13#issuecomment-3072554342)
SendTextByClipboard(text) {
    local clip_prev
    clip_prev := A_Clipboard
    A_Clipboard := text

    if ClipWait(0.5, 0) {
        Send("+{Insert}") ; Alternatively, Send("^v").

    ; Restore clipboard
    }
    SetTimer(() => A_Clipboard := clip_prev, -50)
}
