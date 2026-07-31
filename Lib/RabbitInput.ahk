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
#Include <RabbitConfigSnapshot>
#Include <RabbitRuntimeState>
#Include <RabbitTrayMenu>

class RabbitInputController {
    static FOCUS_POLL_INTERVAL := 50

    __New(rime_api, session_id, candidate_box, config, runtime_state, tray) {
        this.rime := rime_api
        this.session_id := session_id
        this.candidate_box := candidate_box
        this.config := config
        this.runtime_state := runtime_state
        this.tray := tray
        this.suspend_hotkey_mask := 0
        this.suspend_hotkey := ""
        this.prev_show := false
        this.prev_x := 4
        this.prev_y := 4
        this.candidate_revision := 0
        this.composition_owner_hwnd := 0
        this.focus_timer_callback := this.CheckCompositionFocus.Bind(this)
        this.focus_timer_running := false
        this.registered_hotkeys := []
    }

    RegisterHotKeys() {
        local modifier, _, key, k
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
            this.RegisterHotKey("$" . modifier, this.ProcessKey.Bind(this, modifier, mask), "S0")
            this.RegisterHotKey(
                "$" . modifier . " Up",
                this.ProcessKey.Bind(this, modifier, mask | up),
                "S0"
            )
        }

        ; Plain
        Loop 2 {
            local key_map := A_Index = 1 ? KeyDef.plain_keycode : KeyDef.other_keycode
            for key, _ in key_map {
                this.RegisterHotKey("$" . key, this.ProcessKey.Bind(this, key, 0), "S0")
                ; Specify left/right to prevent fallback to modifier down/up hotkeys.
                this.RegisterHotKey("$<^" . key, this.ProcessKey.Bind(this, key, ctrl), "S0")
                ; Alt plus a single key is intentionally unsupported for now.
                ; if key != "Tab" {
                ;     Hotkey("$<!" . key, ProcessKey.Bind(key, alt), "S0")
                ;     Hotkey("$>!" . key, ProcessKey.Bind(key, alt), "S0")
                ; }
                this.RegisterHotKey("$>^" . key, this.ProcessKey.Bind(this, key, ctrl), "S0")
                this.RegisterHotKey(
                    "$^!" . key,
                    this.ProcessKey.Bind(this, key, ctrl | alt),
                    "S0"
                )
                this.RegisterHotKey(
                    "$!#" . key,
                    this.ProcessKey.Bind(this, key, alt | win),
                    "S0"
                )

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
                this.RegisterHotKey("$<+" . key, this.ProcessKey.Bind(this, key, shift), "S0")
                this.RegisterHotKey("$>+" . key, this.ProcessKey.Bind(this, key, shift), "S0")
                this.RegisterHotKey(
                    "$+^" . key,
                    this.ProcessKey.Bind(this, key, shift | ctrl),
                    "S0"
                )
                if !key == "Tab" {
                    this.RegisterHotKey(
                        "$+!" . key,
                        this.ProcessKey.Bind(this, key, shift | alt),
                        "S0"
                    )
                }
                this.RegisterHotKey(
                    "$+^!" . key,
                    this.ProcessKey.Bind(this, key, shift | ctrl | alt),
                    "S0"
                )

                ; Win-key combinations are intentionally unsupported for now.
                ; Hotkey("$+#" . key, ProcessKey.Bind(key, shift | win), "S0")
                ; Hotkey("$+^#" . key, ProcessKey.Bind(key, shift | ctrl | win), "S0")
                ; Hotkey("$+!#" . key, ProcessKey.Bind(key, shift | alt | win), "S0")
                ; Hotkey("$+^!#" . key, ProcessKey.Bind(key, shift | ctrl | alt | win), "S0")
            }
        }

        ; Special handling
        this.RegisterHotKey(
            "$Space Up",
            this.ProcessKey.Bind(this, "Space", up),
            "S0"
        )

        ; Read the hotkey to suspend / resume Rabbit
        if !this.config.suspend_hotkey {
            return
        }
        local keys := StrSplit(this.config.suspend_hotkey, "+", " ", 4)
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
                    this.suspend_hotkey_mask := mask
                    this.suspend_hotkey := target_key
                }
            } else if num_modifiers > 1 {
                local m := "$" . (mask & shift ? "+" : "") .
                                    (mask & ctrl ? "^" : "") .
                                    (mask & alt ? "!" : "")
                Hotkey(m . target_key, , "S")
                this.suspend_hotkey_mask := mask
                this.suspend_hotkey := target_key
            }
        } else if keys.Length == 1 {
            if keys[1] = "Shift" {
                ; A standalone Shift key is intentionally unsupported for now.
                Hotkey("$LShift", , "S")
                Hotkey("$RShift", , "S")
                Hotkey("$LShift Up", , "S")
                Hotkey("$RShift Up", , "S")
                this.suspend_hotkey_mask := mask | up
                this.suspend_hotkey := "Shift"
            }
        }
    }

    RegisterHotKey(name, callback, options) {
        Hotkey(name, callback, options)
        this.registered_hotkeys.Push(name)
    }

    StartFocusMonitor() {
        if !this.focus_timer_running {
            SetTimer(
                this.focus_timer_callback,
                RabbitInputController.FOCUS_POLL_INTERVAL
            )
            this.focus_timer_running := true
        }
    }

    Dispose() {
        local name
        if this.focus_timer_running {
            SetTimer(this.focus_timer_callback, 0)
            this.focus_timer_running := false
        }
        for name in this.registered_hotkeys {
            try {
                Hotkey(name, , "Off")
            }
        }
        this.registered_hotkeys := []
    }

    ProcessKey(key, mask, this_hotkey) {
        local check_key, check_code, caps, status, processed, commit, context
        local candidate_revision, foreground_hwnd, hide_candidate := false
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
        foreground_hwnd := this.GetForegroundWindow()
        this.CancelCompositionIfFocusChanged(foreground_hwnd)
        candidate_revision := ++this.candidate_revision
        if (caps := GetKeyState("CapsLock", "T")) {
            if StrLen(key) == 1 && Ord(key) >= Ord("a") && Ord(key) <= Ord("z") { ; small case letters
                code += (Ord("A") - Ord("a"))
            }
        }

        if (status := this.rime.get_status(this.session_id)) {
            local old_schema_id := status.schema_id
            local old_ascii_mode := status.is_ascii_mode
            local old_full_shape := status.is_full_shape
            local old_ascii_punct := status.is_ascii_punct
            this.rime.free_status(status)
        }

        processed := this.rime.process_key(this.session_id, code, mask)

        status := this.rime.get_status(this.session_id)
        local new_schema_id := status.schema_id
        local new_schema_name := status.schema_name
        local new_ascii_mode := status.is_ascii_mode
        local new_full_shape := status.is_full_shape
        local new_ascii_punct := status.is_ascii_punct
        this.rime.free_status(status)

        if old_schema_id !== new_schema_id {
            this.runtime_state.UpdateStateLabels()
        }

        this.tray.UpdateTip(new_schema_name, new_ascii_mode, new_full_shape, new_ascii_punct)
        if old_schema_id !== new_schema_id {
            this.tray.UpdateSchemaIcon(new_schema_id)
        }

        local status_text := ""
        local status_changed := false
        local ascii_changed := false
        if old_ascii_mode != new_ascii_mode {
            ascii_changed := true
            this.runtime_state.UpdateWinAscii(new_ascii_mode, true)
            status_text := new_ascii_mode
                ? this.runtime_state.ascii_mode_true_label_abbr
                : this.runtime_state.ascii_mode_false_label_abbr
        } else if old_full_shape != new_full_shape {
            status_changed := true
            status_text := new_full_shape
                ? this.runtime_state.full_shape_true_label_abbr
                : this.runtime_state.full_shape_false_label_abbr
        } else if old_ascii_punct != new_ascii_punct {
            status_changed := true
            status_text := new_ascii_punct
                ? this.runtime_state.ascii_punct_true_label_abbr
                : this.runtime_state.ascii_punct_false_label_abbr
        }

        if this.config.show_tips && (status_changed || ascii_changed) {
            ToolTip(status_text, , , STATUS_TOOLTIP)
            SetTimer(() => ToolTip(, , , STATUS_TOOLTIP), -this.config.show_tips_time)
        }

        if (commit := this.rime.get_commit(this.session_id)) {
            if ascii_changed {
                hide_candidate := true
            }
            if StrLen(commit.text) >= this.config.send_by_clipboard_length {
                this.SendTextByClipboard(commit.text)
            } else {
                SendText(commit.text)
            }
            this.RunCandidateUpdate(
                candidate_revision,
                () => this.candidate_box.Hide()
            )
            this.rime.free_commit(commit)
        }
        if this.suspend_hotkey && this.suspend_hotkey_mask
            && (key = this.suspend_hotkey || SubStr(key, 2) = this.suspend_hotkey)
            && (mask = this.suspend_hotkey_mask) {
            this.tray.ToggleSuspend()
            return
        }

        if (context := this.rime.get_context(this.session_id)) {
            this.UpdateCompositionOwner(context, foreground_hwnd)
            if !this.CancelCompositionIfFocusChanged(this.GetForegroundWindow()) {
                this.UpdateCandidate(context, candidate_revision, hide_candidate)
            }
            this.rime.free_context(context)
        }

        if !processed {
            local shift := (mask & KeyDef.mask["Shift"]) ? "+" : ""
            local ctrl := (mask & KeyDef.mask["Ctrl"]) ? "^" : ""
            local alt := (mask & KeyDef.mask["Alt"]) ? "!" : ""
            local win := (mask & KeyDef.mask["Win"]) ? "#" : ""

            local is_up := mask & KeyDef.mask["Up"]
            local has_modifier := mask & (
                KeyDef.mask["Shift"] | KeyDef.mask["Ctrl"] | KeyDef.mask["Alt"] | KeyDef.mask["Win"]
            )

            if key == "Space" && !has_modifier {
                Send("{Blind}{" . key . (is_up ? " Up" : " Down") . "}")
            } else {
                SendInput(shift . ctrl . alt . win . "{" . key . "}")
            }
        }
    }

    GetForegroundWindow() {
        return DllCall("GetForegroundWindow", "Ptr")
    }

    CheckCompositionFocus() {
        this.CancelCompositionIfFocusChanged(this.GetForegroundWindow())
    }

    CancelCompositionIfFocusChanged(foreground_hwnd) {
        if !this.composition_owner_hwnd || !foreground_hwnd
            || foreground_hwnd == this.composition_owner_hwnd {
            return false
        }
        this.ClearComposition()
        return true
    }

    ClearComposition() {
        local candidate_revision := ++this.candidate_revision
        this.composition_owner_hwnd := 0
        this.rime.clear_composition(this.session_id)
        this.RunCandidateUpdate(
            candidate_revision,
            () => this.HideCandidate()
        )
    }

    UpdateCompositionOwner(context, foreground_hwnd) {
        if context.composition.length > 0 || context.menu.num_candidates > 0 {
            if foreground_hwnd {
                this.composition_owner_hwnd := foreground_hwnd
            }
        } else {
            this.composition_owner_hwnd := 0
        }
    }

    HideCandidate() {
        this.candidate_box.Hide()
        this.prev_show := false
    }

    RunCandidateUpdate(candidate_revision, update_callback) {
        local previous_critical := Critical()
        try {
            if candidate_revision != this.candidate_revision {
                return false
            }
            update_callback.Call()
            return true
        } finally {
            Critical(previous_critical)
        }
    }

    UpdateCandidate(context, candidate_revision, hide_candidate) {
        local hmon, info, caret_x, caret_y, caret_w, caret_h, hwnd
        local backup_mouse_ref, mouse_x, mouse_y, placement
        if context.composition.length <= 0 && context.menu.num_candidates <= 0 {
            placement := { mode: "hide" }
        } else {
            DetectHiddenWindows True
            local start_menu := WinActive(
                "ahk_class Windows.UI.Core.CoreWindow ahk_exe StartMenuExperienceHost.exe"
            )
                || WinActive("ahk_class Windows.UI.Core.CoreWindow ahk_exe SearchHost.exe")
                || WinActive("ahk_class Windows.UI.Core.CoreWindow ahk_exe SearchApp.exe")
            DetectHiddenWindows False
            if start_menu
                && (hmon := MonitorManage.MonitorFromWindow(start_menu))
                && (info := MonitorManage.GetMonitorInfo(hmon)) {
                placement := {
                    mode: "top_left",
                    x: info.work.left + 4,
                    y: info.work.top + 4
                }
            } else if RabbitGetCaretPos(
                &caret_x,
                &caret_y,
                &caret_w,
                &caret_h,
                this.config.use_caret_hook
            ) {
                hwnd := WinExist("A")
                hmon := MonitorManage.MonitorFromWindow(hwnd)
                info := MonitorManage.GetMonitorInfo(hmon)
                placement := {
                    mode: "caret",
                    caret_x: caret_x,
                    caret_y: caret_y,
                    caret_w: caret_w,
                    caret_h: caret_h,
                    monitor_info: info,
                    workspace_width: info ? 0 : SysGet(16), ; SM_CXFULLSCREEN
                    workspace_height: info ? 0 : SysGet(17) ; SM_CYFULLSCREEN
                }
            } else {
                backup_mouse_ref := A_CoordModeMouse
                CoordMode("Mouse", "Screen")
                MouseGetPos(&mouse_x, &mouse_y)
                CoordMode("Mouse", backup_mouse_ref)
                placement := { mode: "mouse", x: mouse_x, y: mouse_y }
            }
        }

        return this.RunCandidateUpdate(
            candidate_revision,
            () => this.ApplyCandidateUpdate(context, placement, hide_candidate)
        )
    }

    ApplyCandidateUpdate(context, placement, hide_candidate) {
        local box_width, box_height, new_x, new_y, info
        switch placement.mode {
            case "hide":
                this.candidate_box.Hide()
                this.prev_show := false
                return
            case "top_left":
                if !hide_candidate {
                    this.candidate_box.Build(context, &box_width, &box_height)
                    this.candidate_box.Show(placement.x, placement.y)
                }
            case "caret":
                this.candidate_box.Build(context, &box_width, &box_height)
                if this.config.fix_candidate_box && this.prev_show {
                    new_x := this.prev_x
                    new_y := this.prev_y
                } else {
                    new_x := placement.caret_x + placement.caret_w
                    new_y := placement.caret_y + placement.caret_h + 4
                    info := placement.monitor_info
                    if info {
                        if new_x + box_width > info.work.right {
                            new_x := info.work.right - box_width
                        }
                        if new_y + box_height > info.work.bottom {
                            new_y := placement.caret_y - 4 - box_height
                        }
                    } else {
                        if new_x + box_width > placement.workspace_width {
                            new_x := placement.workspace_width - box_width
                        }
                        if new_y + box_height > placement.workspace_height {
                            new_y := placement.caret_y - 4 - box_height
                        }
                    }
                }
                if !hide_candidate {
                    this.candidate_box.Show(new_x, new_y)
                }
                this.prev_x := new_x
                this.prev_y := new_y
            case "mouse":
                this.candidate_box.Build(context, &box_width, &box_height)
                this.candidate_box.Show(placement.x, placement.y)
            default:
                throw Error("Unknown candidate placement mode: " . placement.mode)
        }
        this.prev_show := true
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
}
