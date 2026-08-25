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
#Include RabbitKeyTable.ahk
#Include RabbitInputHotkeys.ahk
#Include RabbitInputTarget.ahk
#Include RabbitPasswordField.ahk
#Include RabbitCaret.ahk
#Include RabbitMonitors.ahk
#Include RabbitPopupPlacement.ahk
#Include RabbitCandidateViewport.ahk
#Include RabbitConfigSnapshot.ahk
#Include RabbitRuntimeState.ahk
#Include RabbitTrayMenu.ahk

class RabbitInputController {
    static FOCUS_POLL_INTERVAL := 50
    static PASSWORD_POLL_INTERVAL := 250
    ; 6000 * FOCUS_POLL_INTERVAL (50 ms) = one resource sample every 5 minutes.
    static RESOURCE_SAMPLE_INTERVAL := 6000
    static EVENT_OBJECT_FOCUS := 0x8005
    static WINEVENT_OUTOFCONTEXT := 0x0000

    __New(
        rime_api,
        session_id,
        candidate_box,
        config,
        runtime_state,
        tray,
        input_target := 0,
        password_field_detector := 0
    ) {
        this.rime := rime_api
        this.session_id := session_id
        this.candidate_box := candidate_box
        this.config := config
        this.runtime_state := runtime_state
        this.tray := tray
        this.input_target := input_target ? input_target : RabbitInputTarget
        this.password_field_detector := config.bypass_password_fields
            ? (password_field_detector ? password_field_detector : RabbitPasswordFieldDetector())
            : 0
        this.suspend_hotkey_mask := 0
        this.suspend_hotkey := ""
        this.prev_show := false
        this.prev_x := 4
        this.prev_y := 4
        this.candidate_revision := 0
        this.candidate_viewport := RabbitCandidateViewport()
        this.composition_owner_hwnd := 0
        this.switcher_state := 0
        this.focus_timer_callback := this.CheckCompositionFocus.Bind(this)
        this.focus_timer_running := false
        this.focus_event_handler := this.OnFocusEvent.Bind(this)
        this.focus_event_callback := 0
        this.focus_event_hook := 0
        this.password_poll_ticks := 0
        this.password_bypass_active := false
        this.registered_hotkeys := []
        this.registered_hotkey_names := Map()
        this.registered_input_hotkeys := []
        this.resource_poll_ticks := 0
        this.replayed_down := Map()
    }

    RegisterHotKeys() {
        local key, registration, k
        local shift := KeyDef.mask["Shift"]
        local ctrl := KeyDef.mask["Ctrl"]
        local alt := KeyDef.mask["Alt"]
        local up := KeyDef.mask["Up"]

        this.RegisterSuspendHotKey(shift, ctrl, alt, up)

        ; Register only modifier-containing keys found in the effective default
        ; and enabled-schema configurations. This snapshot is intentionally
        ; static: schema changes do not repeatedly install and remove hotkeys.
        if this.config.input_hotkeys {
            for registration in this.config.input_hotkeys.GetRegistrations() {
                this.RegisterInputHotKey(
                    (registration.pass_through ? "$~" : "$") . registration.hotkey,
                    this.ProcessConfiguredKey.Bind(
                        this,
                        registration.key,
                        registration.mask,
                        registration.pass_through
                    ),
                    "S0"
                )
            }
        }

        ; Plain keys are always needed for ordinary text input.
        ; Key-up variants forward key release events to librime, matching TSF
        ; frontends such as Weasel. Processors that act on key release (for
        ; example ascii_composer switches) rely on receiving the release event;
        ; without it a key that librime reports as handled on release would
        ; stay swallowed and never reach the application.
        Loop 2 {
            local key_map := A_Index = 1 ? KeyDef.plain_keycode : KeyDef.other_keycode
            for key, _ in key_map {
                this.RegisterInputHotKey(
                    "$" . key,
                    this.ProcessTextKey.Bind(this, key, 0),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$" . key . " Up",
                    this.ProcessTextKey.Bind(this, key, up),
                    "S0"
                )
            }
        }

        local has_lshift := this.registered_hotkey_names.Has("$LShift")
            || this.registered_hotkey_names.Has("$~LShift")
        local has_rshift := this.registered_hotkey_names.Has("$RShift")
            || this.registered_hotkey_names.Has("$~RShift")

        ; Shifted letters and symbols must remain registered even when no
        ; schema binding mentions them: they are required for normal text input.
        for key, _ in KeyDef.shifted_keycode {
            this.RegisterInputHotKey(
                "$<+" . key,
                this.ProcessTextKey.Bind(this, key, shift),
                "S0"
            )
            this.RegisterInputHotKey(
                "$>+" . key,
                this.ProcessTextKey.Bind(this, key, shift),
                "S0"
            )
            this.RegisterInputHotKey(
                "$<+" . key . " Up",
                this.ProcessTextKey.Bind(this, key, shift | up),
                "S0"
            )
            this.RegisterInputHotKey(
                "$>+" . key . " Up",
                this.ProcessTextKey.Bind(this, key, shift | up),
                "S0"
            )
            if has_lshift {
                this.RegisterInputHotKey(
                    "$<+^" . key,
                    this.ProcessTextKey.Bind(this, key, shift | ctrl),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$<+^" . key . " Up",
                    this.ProcessTextKey.Bind(this, key, shift | ctrl | up),
                    "S0"
                )
            }
            if has_rshift {
                this.RegisterInputHotKey(
                    "$>+^" . key,
                    this.ProcessTextKey.Bind(this, key, shift | ctrl),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$>+^" . key . " Up",
                    this.ProcessTextKey.Bind(this, key, shift | ctrl | up),
                    "S0"
                )
            }
        }

        ; Other keys only need shifted variants when the corresponding
        ; standalone Shift key is intercepted by Rabbit. Otherwise the target
        ; application can handle the native combination itself.
        for key, _ in KeyDef.other_keycode {
            if has_lshift {
                this.RegisterInputHotKey(
                    "$<+" . key,
                    this.ProcessTextKey.Bind(this, key, shift),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$<+^" . key,
                    this.ProcessTextKey.Bind(this, key, shift | ctrl),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$<+" . key . " Up",
                    this.ProcessTextKey.Bind(this, key, shift | up),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$<+^" . key . " Up",
                    this.ProcessTextKey.Bind(this, key, shift | ctrl | up),
                    "S0"
                )
            }
            if has_rshift {
                this.RegisterInputHotKey(
                    "$>+" . key,
                    this.ProcessTextKey.Bind(this, key, shift),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$>+^" . key,
                    this.ProcessTextKey.Bind(this, key, shift | ctrl),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$>+" . key . " Up",
                    this.ProcessTextKey.Bind(this, key, shift | up),
                    "S0"
                )
                this.RegisterInputHotKey(
                    "$>+^" . key . " Up",
                    this.ProcessTextKey.Bind(this, key, shift | ctrl | up),
                    "S0"
                )
            }
        }

        ; Alt+Shift and Ctrl+Alt+Shift variants are intentionally not
        ; registered yet: they are uncommon and would broaden interception.

        ; Special handling
        this.RegisterInputHotKey(
            "$Space Up",
            this.ProcessTextKey.Bind(this, "Space", up),
            "S0"
        )

    }

    RegisterSuspendHotKey(shift, ctrl, alt, up) {
        if !this.config.suspend_hotkey {
            return
        }
        local keys := StrSplit(this.config.suspend_hotkey, "+", " ", 4)
        local mask := 0
        local target_key := ""
        local num_modifiers := 0
        local k
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

        local callback, m
        if target_key {
            if KeyDef.rime_to_ahk.Has(target_key) {
                target_key := KeyDef.rime_to_ahk[target_key]
            }
            callback := this.ProcessConfiguredKey.Bind(this, target_key, mask, false)
            if num_modifiers = 1 {
                if mask & ctrl {
                    this.RegisterHotKey("$<^" . target_key, callback, "S", true)
                    this.RegisterHotKey("$>^" . target_key, callback, "S", true)
                    this.suspend_hotkey_mask := mask
                    this.suspend_hotkey := target_key
                }
            } else if num_modifiers > 1 {
                m := "$" . (mask & shift ? "+" : "") .
                                (mask & ctrl ? "^" : "") .
                                (mask & alt ? "!" : "")
                this.RegisterHotKey(m . target_key, callback, "S", true)
                this.suspend_hotkey_mask := mask
                this.suspend_hotkey := target_key
            }
        } else if keys.Length == 1 && keys[1] = "Shift" {
            ; A standalone Shift key is intentionally unsupported for now.
            callback := this.ProcessConfiguredKey.Bind(this, "LShift", shift, false)
            this.RegisterHotKey("$LShift", callback, "S", true)
            callback := this.ProcessConfiguredKey.Bind(this, "RShift", shift, false)
            this.RegisterHotKey("$RShift", callback, "S", true)
            callback := this.ProcessConfiguredKey.Bind(this, "LShift", shift | up, false)
            this.RegisterHotKey("$LShift Up", callback, "S", true)
            callback := this.ProcessConfiguredKey.Bind(this, "RShift", shift | up, false)
            this.RegisterHotKey("$RShift Up", callback, "S", true)
            this.suspend_hotkey_mask := shift | up
            this.suspend_hotkey := "Shift"
        }
    }

    RegisterHotKey(name, callback, options, update_existing := false) {
        if this.registered_hotkey_names.Has(name) {
            if update_existing {
                Hotkey(name, callback, options)
            }
            return false
        }
        Hotkey(name, callback, options)
        this.registered_hotkeys.Push(name)
        this.registered_hotkey_names[name] := true
        return true
    }

    RegisterInputHotKey(name, callback, options) {
        if this.RegisterHotKey(name, callback, options) {
            this.registered_input_hotkeys.Push(name)
            if this.password_bypass_active {
                this.SetInputHotKeyEnabled(name, false)
            }
        }
    }

    StartFocusMonitor() {
        if !this.focus_timer_running {
            this.RegisterFocusEventHook()
            this.UpdatePasswordBypass()
            SetTimer(
                this.focus_timer_callback,
                RabbitInputController.FOCUS_POLL_INTERVAL
            )
            this.focus_timer_running := true
        }
    }

    RegisterFocusEventHook() {
        if !this.password_field_detector || this.focus_event_hook {
            return false
        }

        this.focus_event_callback := CallbackCreate(this.focus_event_handler, , 7)
        this.focus_event_hook := DllCall(
            "User32\SetWinEventHook",
            "UInt",
            RabbitInputController.EVENT_OBJECT_FOCUS,
            "UInt",
            RabbitInputController.EVENT_OBJECT_FOCUS,
            "Ptr",
            0,
            "Ptr",
            this.focus_event_callback,
            "UInt",
            0,
            "UInt",
            0,
            "UInt",
            RabbitInputController.WINEVENT_OUTOFCONTEXT,
            "Ptr"
        )
        if !this.focus_event_hook {
            CallbackFree(this.focus_event_callback)
            this.focus_event_callback := 0
            return false
        }
        return true
    }

    UnregisterFocusEventHook() {
        if this.focus_event_hook {
            DllCall("User32\UnhookWinEvent", "Ptr", this.focus_event_hook)
            this.focus_event_hook := 0
        }
        if this.focus_event_callback {
            CallbackFree(this.focus_event_callback)
            this.focus_event_callback := 0
        }
    }

    OnFocusEvent(*) {
        try {
            this.password_poll_ticks := 0
            this.UpdatePasswordBypass()
        }
    }

    UpdatePasswordBypass() {
        if !this.password_field_detector {
            return false
        }
        return this.SetPasswordBypass(
            this.password_field_detector.IsFocusedPasswordField()
        )
    }

    SetPasswordBypass(enabled) {
        enabled := !!enabled
        if enabled = this.password_bypass_active {
            return false
        }

        local previous_critical := Critical()
        try {
            this.password_bypass_active := enabled
            local name
            for name in this.registered_input_hotkeys {
                this.SetInputHotKeyEnabled(name, !enabled)
            }
            if enabled {
                this.ClearCompositionIfActive()
            }
            return true
        } finally {
            Critical(previous_critical)
        }
    }

    SetInputHotKeyEnabled(name, enabled) {
        Hotkey(name, , enabled ? "On" : "Off")
    }

    Dispose() {
        local name
        if this.focus_timer_running {
            SetTimer(this.focus_timer_callback, 0)
            this.focus_timer_running := false
        }
        this.UnregisterFocusEventHook()
        for name in this.registered_hotkeys {
            try {
                Hotkey(name, , "Off")
            }
        }
        this.registered_hotkeys := []
        this.registered_hotkey_names := Map()
        this.registered_input_hotkeys := []
        this.password_bypass_active := false
        this.replayed_down := Map()
    }

    ProcessTextKey(key, mask, this_hotkey := "") {
        return this.ProcessKey(key, mask, false, this_hotkey, true)
    }

    ProcessConfiguredKey(key, mask, pass_through := false, this_hotkey := "") {
        return this.ProcessKey(key, mask, pass_through, this_hotkey, false)
    }

    ProcessKey(key, mask, pass_through := false, this_hotkey := "", requires_text_target := false) {
        local check_key, check_code, caps, status, processed, commit, context
        local candidate_revision, foreground_hwnd, hide_candidate := false
        local input_target
        local code := 0
        local previous_critical, commit_text := ""
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
        input_target := this.input_target.Classify(foreground_hwnd)
        if input_target = RabbitInputTarget.NO {
            ; Serialize the Rime cleanup against other key sequences; the
            ; replay itself stays outside the critical section.
            previous_critical := Critical()
            try {
                this.ClearCompositionIfActive()
            } finally {
                Critical(previous_critical)
            }
            if requires_text_target {
                this.ReplayInput(key, mask, pass_through)
                if mask & KeyDef.mask["Up"] {
                    ; The key-down may have been handled by Rime in a text
                    ; target while the release arrives here: no mark exists.
                    if this.replayed_down.Has(key) {
                        this.replayed_down.Delete(key)
                    }
                } else {
                    this.replayed_down[key] := true
                }
                return
            }
            if pass_through {
                return
            }
        }
        ; Serialize the whole Rime key sequence so concurrent hotkey threads
        ; cannot interleave librime calls on the same session (librime is not
        ; thread-safe). State updates stay inside; text sending and replay
        ; happen outside the critical section because they block.
        previous_critical := Critical()
        try {
            this.CancelCompositionIfFocusChanged(foreground_hwnd)
            candidate_revision := ++this.candidate_revision
            if (caps := GetKeyState("CapsLock", "T")) {
                if StrLen(key) == 1 && Ord(key) >= Ord("a") && Ord(key) <= Ord("z") { ; small case letters
                    code += (Ord("A") - Ord("a"))
                }
            }

            if (status := this.rime.get_status(this.session_id)) {
                try {
                    local old_schema_id := status.schema_id
                    local old_ascii_mode := status.is_ascii_mode
                    local old_full_shape := status.is_full_shape
                    local old_ascii_punct := status.is_ascii_punct
                } finally {
                    this.rime.free_status(status)
                }
            }

            processed := this.rime.process_key(this.session_id, code, mask)

            status := this.rime.get_status(this.session_id)
            if status {
                try {
                    local new_schema_id := status.schema_id
                    local new_schema_name := status.schema_name
                    local new_ascii_mode := status.is_ascii_mode
                    local new_full_shape := status.is_full_shape
                    local new_ascii_punct := status.is_ascii_punct
                } finally {
                    this.rime.free_status(status)
                }
            } else {
                RabbitWarn(
                    "get_status returned 0 after process_key",
                    Format("RabbitInput.ahk:{}", A_LineNumber),
                    1
                )
            }

            local switcher_status := this.ResolveSwitcherStatus(
                old_schema_id,
                old_ascii_mode,
                old_full_shape,
                old_ascii_punct,
                new_schema_id
            )
            local processing_switcher := switcher_status.processing_switcher
            old_schema_id := switcher_status.schema_id
            old_ascii_mode := switcher_status.ascii_mode
            old_full_shape := switcher_status.full_shape
            old_ascii_punct := switcher_status.ascii_punct
            local schema_changed := !processing_switcher && old_schema_id !== new_schema_id
            local status_text := ""
            local status_changed := false
            local ascii_changed := false
            if !processing_switcher && schema_changed {
                this.runtime_state.UpdateStateLabels()
            }
            if !processing_switcher {
                this.tray.UpdateTip(new_schema_name, new_ascii_mode, new_full_shape, new_ascii_punct)
                if schema_changed {
                    this.tray.UpdateSchemaIcon(new_schema_id)
                }
            }
            if !processing_switcher && old_ascii_mode != new_ascii_mode {
                ascii_changed := true
                this.runtime_state.UpdateWinAscii(new_ascii_mode, true)
                status_text := new_ascii_mode
                    ? this.runtime_state.ascii_mode_true_label_abbr
                    : this.runtime_state.ascii_mode_false_label_abbr
            } else if !processing_switcher && old_full_shape != new_full_shape {
                status_changed := true
                status_text := new_full_shape
                    ? this.runtime_state.full_shape_true_label_abbr
                    : this.runtime_state.full_shape_false_label_abbr
            } else if !processing_switcher && old_ascii_punct != new_ascii_punct {
                status_changed := true
                status_text := new_ascii_punct
                    ? this.runtime_state.ascii_punct_true_label_abbr
                    : this.runtime_state.ascii_punct_false_label_abbr
            }

            if this.config.show_tips && schema_changed {
                this.tray.ShowStatusTip(new_schema_name, true)
            } else if this.config.show_tips && (status_changed || ascii_changed) {
                this.tray.ShowStatusTip(status_text, ascii_changed)
            }

            if (commit := this.rime.get_commit(this.session_id)) {
                try {
                    if ascii_changed {
                        hide_candidate := true
                    }
                    commit_text := commit.text
                    this.RunCandidateUpdate(
                        candidate_revision,
                        () => this.HideCandidate()
                    )
                } finally {
                    this.rime.free_commit(commit)
                }
            }
        } finally {
            Critical(previous_critical)
        }

        ; Send committed text outside the critical section: SendText and the
        ; clipboard path block (ClipWait) and would hold up all input.
        if commit_text != "" {
            this.SendCommittedText(commit_text, input_target)
        }
        if this.suspend_hotkey && this.suspend_hotkey_mask
            && (key = this.suspend_hotkey || SubStr(key, 2) = this.suspend_hotkey)
            && (mask = this.suspend_hotkey_mask) {
            this.tray.ToggleSuspend()
            return
        }

        ; The context snapshot is rendered inside the same serialization:
        ; its internal pointers are only valid until free_context, and the
        ; candidate update reads them.
        previous_critical := Critical()
        try {
            if (context := this.rime.get_context(this.session_id)) {
                try {
                    this.UpdateCompositionOwner(context, foreground_hwnd)
                    if !this.CancelCompositionIfFocusChanged(this.GetForegroundWindow()) {
                        this.UpdateCandidate(context, candidate_revision, hide_candidate)
                    }
                } finally {
                    this.rime.free_context(context)
                }
            }
        } finally {
            Critical(previous_critical)
        }

        ; Replay an unhandled key outside the critical section. A key-up is
        ; replayed only when its key-down was replayed, so the application
        ; never receives an orphaned release; a key-down that Rime swallowed
        ; is invisible to the application, and so is its release.
        if !processed && !pass_through {
            if mask & KeyDef.mask["Up"] {
                if this.replayed_down.Has(key) && this.replayed_down[key] {
                    this.replayed_down.Delete(key)
                    this.ReplayInput(key, mask)
                }
            } else {
                this.replayed_down[key] := true
                this.ReplayInput(key, mask)
            }
        }
    }

    ResolveSwitcherStatus(old_schema_id, old_ascii_mode, old_full_shape, old_ascii_punct, new_schema_id) {
        local state
        if new_schema_id = ".default" {
            if old_schema_id != ".default" {
                this.switcher_state := {
                    schema_id: old_schema_id,
                    ascii_mode: old_ascii_mode,
                    full_shape: old_full_shape,
                    ascii_punct: old_ascii_punct
                }
            }
            return {
                processing_switcher: true,
                schema_id: old_schema_id,
                ascii_mode: old_ascii_mode,
                full_shape: old_full_shape,
                ascii_punct: old_ascii_punct
            }
        }
        if (state := this.switcher_state) {
            this.switcher_state := 0
            return {
                processing_switcher: false,
                schema_id: state.schema_id,
                ascii_mode: state.ascii_mode,
                full_shape: state.full_shape,
                ascii_punct: state.ascii_punct
            }
        }
        return {
            processing_switcher: false,
            schema_id: old_schema_id,
            ascii_mode: old_ascii_mode,
            full_shape: old_full_shape,
            ascii_punct: old_ascii_punct
        }
    }

    ReplayInput(key, mask, pass_through := false) {
        if pass_through {
            return
        }
        local has_modifier := mask & (
            KeyDef.mask["Shift"] | KeyDef.mask["Ctrl"] | KeyDef.mask["Alt"] | KeyDef.mask["Win"]
        )
        local fallback := this.BuildFallbackInput(key, mask)
        if key == "Space" && !has_modifier {
            Send(fallback)
        } else {
            SendInput(fallback)
        }
    }

    ClearCompositionIfActive() {
        if !this.composition_owner_hwnd && !this.prev_show {
            return false
        }
        this.ClearComposition()
        return true
    }

    BuildFallbackInput(key, mask) {
        local is_up := mask & KeyDef.mask["Up"]
        if is_up {
            ; A Release binding must replay the physical key-up event, not a
            ; new key press. Blind preserves the modifier state already held
            ; by the target application.
            return "{Blind}{" . key . " Up}"
        }
        local shift := (mask & KeyDef.mask["Shift"]) ? "+" : ""
        local ctrl := (mask & KeyDef.mask["Ctrl"]) ? "^" : ""
        local alt := (mask & KeyDef.mask["Alt"]) ? "!" : ""
        local win := (mask & KeyDef.mask["Win"]) ? "#" : ""
        if key == "Space" && !(mask & (
            KeyDef.mask["Shift"] | KeyDef.mask["Ctrl"] | KeyDef.mask["Alt"] | KeyDef.mask["Win"]
        )) {
            return "{Blind}{" . key . " Down}"
        }
        return shift . ctrl . alt . win . "{" . key . "}"
    }

    GetForegroundWindow() {
        return DllCall("GetForegroundWindow", "Ptr")
    }

    CheckCompositionFocus() {
        ; Serialize the Rime calls so the focus poll cannot interleave with a
        ; key's Rime sequence.
        local previous_critical := Critical()
        try {
            this.CancelCompositionIfFocusChanged(this.GetForegroundWindow())
            if this.password_field_detector {
                this.password_poll_ticks++
                if this.password_poll_ticks * RabbitInputController.FOCUS_POLL_INTERVAL
                    >= RabbitInputController.PASSWORD_POLL_INTERVAL {
                    this.password_poll_ticks := 0
                    this.UpdatePasswordBypass()
                }
            }
        } finally {
            Critical(previous_critical)
        }
        this.resource_poll_ticks++
        if this.resource_poll_ticks >= RabbitInputController.RESOURCE_SAMPLE_INTERVAL {
            this.resource_poll_ticks := 0
            this.LogResourceSample()
        }
    }

    LogResourceSample() {
        local process := DllCall("GetCurrentProcess", "ptr")
        local gdi := DllCall("GetGuiResources", "ptr", process, "uint", 0, "uint") ; GR_GDIOBJECTS
        local user := DllCall("GetGuiResources", "ptr", process, "uint", 1, "uint") ; GR_USEROBJECTS
        local handle_count := 0
        local working_set := 0
        DllCall("GetProcessHandleCount", "ptr", process, "uint*", &handle_count)
        ; PROCESS_MEMORY_COUNTERS: cb + PageFaultCount + PeakWorkingSetSize + WorkingSetSize.
        local pmc := Buffer(A_PtrSize = 8 ? 72 : 40, 0)
        NumPut("uint", pmc.Size, pmc, 0)
        if DllCall("psapi\GetProcessMemoryInfo", "ptr", process, "ptr", pmc, "uint", pmc.Size) {
            working_set := NumGet(pmc, A_PtrSize = 8 ? 16 : 12, "uptr")
        }
        RabbitDebug(
            Format(
                "resource sample: gdi={} user={} handles={} working_set={} KiB",
                gdi,
                user,
                handle_count,
                working_set // 1024
            ),
            Format("RabbitInput.ahk:{}", A_LineNumber)
        )
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
        this.candidate_viewport.Reset()
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
        local info, caret_x, caret_y, caret_w, caret_h
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
                    y: info.work.top + 4,
                    monitor_info: info
                }
            } else if RabbitGetCaretPos(
                &caret_x,
                &caret_y,
                &caret_w,
                &caret_h,
                this.config.use_caret_hook
            ) {
                info := RabbitPopupPlacement.GetWorkAreaAt(caret_x, caret_y)
                placement := {
                    mode: "caret",
                    caret_x: caret_x,
                    caret_y: caret_y,
                    caret_w: caret_w,
                    caret_h: caret_h,
                    monitor_info: info
                }
            } else {
                backup_mouse_ref := A_CoordModeMouse
                CoordMode("Mouse", "Screen")
                MouseGetPos(&mouse_x, &mouse_y)
                CoordMode("Mouse", backup_mouse_ref)
                placement := {
                    mode: "mouse",
                    x: mouse_x,
                    y: mouse_y,
                    monitor_info: RabbitPopupPlacement.GetWorkAreaAt(mouse_x, mouse_y)
                }
            }
        }

        return this.RunCandidateUpdate(
            candidate_revision,
            () => this.ApplyCandidateUpdate(context, placement, hide_candidate)
        )
    }

    ApplyCandidateUpdate(context, placement, hide_candidate) {
        local box_width, box_height, new_x, new_y, info, position, content_bottom
        switch placement.mode {
            case "hide":
                this.HideCandidate()
                return
            case "top_left":
                if !hide_candidate {
                    this.BuildCandidate(context, &box_width, &box_height, placement.monitor_info)
                    this.candidate_box.Show(placement.x, placement.y)
                }
                this.prev_x := placement.x
                this.prev_y := placement.y
            case "caret":
                info := placement.monitor_info
                this.BuildCandidate(context, &box_width, &box_height, info, placement)
                if this.config.fix_candidate_box && this.prev_show {
                    info := RabbitPopupPlacement.GetWorkAreaAt(this.prev_x, this.prev_y)
                    position := RabbitPopupPlacement.PlaceAtPoint(
                        this.prev_x,
                        this.prev_y,
                        box_width,
                        box_height,
                        info
                    )
                    new_x := position.x
                    new_y := position.y
                } else {
                    content_bottom := placement.caret_y + placement.caret_h
                    if HasMethod(this.candidate_box, "GetPopupAnchorBottom") {
                        content_bottom := this.candidate_box.GetPopupAnchorBottom(content_bottom)
                    }
                    position := RabbitPopupPlacement.PlaceBelowCaret(
                        placement.caret_x,
                        placement.caret_y,
                        placement.caret_w,
                        placement.caret_h,
                        box_width,
                        box_height,
                        info,
                        content_bottom
                    )
                    new_x := position.x
                    new_y := position.y
                }
                if !hide_candidate {
                    if HasMethod(this.candidate_box, "SetFlowAnimationAnchor") {
                        this.candidate_box.SetFlowAnimationAnchor(HasProp(position, "above") && position.above)
                    }
                    this.candidate_box.Show(new_x, new_y)
                }
                this.prev_x := new_x
                this.prev_y := new_y
            case "mouse":
                this.BuildCandidate(context, &box_width, &box_height, placement.monitor_info)
                position := RabbitPopupPlacement.PlaceAtPoint(
                    placement.x,
                    placement.y,
                    box_width,
                    box_height,
                    placement.monitor_info
                )
                this.candidate_box.Show(position.x, position.y)
                this.prev_x := position.x
                this.prev_y := position.y
            default:
                throw Error("Unknown candidate placement mode: " . placement.mode)
        }
        this.prev_show := true
    }

    BuildCandidate(context, &box_width, &box_height, monitor_info := 0, caret := 0) {
        local style, presentation, max_width := 0
        if !HasMethod(this.candidate_box, "BuildPresentation") || !HasProp(this.candidate_box, "style") {
            this.candidate_box.Build(context, &box_width, &box_height)
            return
        }
        style := this.candidate_box.style
        if monitor_info {
            max_width := monitor_info.work.right - monitor_info.work.left
        }
        presentation := this.candidate_viewport.Build(
            context,
            style.label_format,
            style.layout_type,
            style.flow_rows,
            this.rime,
            this.session_id
        )
        if caret && caret.caret_h > 0 && HasMethod(this.candidate_box, "BuildFloatingPresentation") {
            this.candidate_box.BuildFloatingPresentation(
                presentation,
                caret.caret_x,
                caret.caret_y,
                caret.caret_w,
                caret.caret_h,
                &box_width,
                &box_height,
                max_width
            )
            return
        }
        this.candidate_box.BuildPresentation(presentation, &box_width, &box_height, max_width)
    }

    SendCommittedText(text, input_target) {
        ; Type-ahead controls interpret text input, not paste.
        if input_target = RabbitInputTarget.TYPE_AHEAD {
            this.SendTextDirect(text)
        } else if StrLen(text) >= this.config.send_by_clipboard_length {
            this.SendTextByClipboard(text)
        } else {
            this.SendTextDirect(text)
        }
    }

    SendTextDirect(text) {
        SendText(text)
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
