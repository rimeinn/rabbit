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
#Include RabbitConfigSnapshot.ahk

class RabbitRuntimeState {
    __New(rime_api, session_id, config) {
        this.rime := rime_api
        this.session_id := session_id
        this.config := config
        this.tray := 0
        this.process_ascii := config.GetPresetProcessAscii()
        this.on_tray_icon_click := false
        this.tray_click_window := 0
        this.tray_click_process := ""
        this.tray_click_timeout_callback := this.EndTrayIconClick.Bind(this)
        this.active_win := ""
        this.active_window := 0
        this.timer_callback := this.UpdateWinAscii.Bind(this)
        this.timer_running := false
        ; Last (process, ascii) pair the tray tip and icon were refreshed for.
        ; UpdateWinAscii runs on the runtime state timer (SetTimer without a
        ; period, i.e. the default 250 ms), so refreshing the tray on every
        ; tick would reload the tray icon file about four times per second.
        this.tray_tip_process := ""
        this.tray_tip_ascii := false

        this.ascii_mode_false_label := "中文"
        this.ascii_mode_true_label := "西文"
        this.ascii_mode_false_label_abbr := "中"
        this.ascii_mode_true_label_abbr := "西"
        this.full_shape_false_label := "半角"
        this.full_shape_true_label := "全角"
        this.full_shape_false_label_abbr := "半"
        this.full_shape_true_label_abbr := "全"
        this.ascii_punct_false_label := "。，"
        this.ascii_punct_true_label := ". ,"
        this.ascii_punct_false_label_abbr := "。"
        this.ascii_punct_true_label_abbr := "."
    }

    SetTray(tray) {
        this.tray := tray
    }

    StartTimer() {
        if !this.config.global_ascii && !this.timer_running {
            SetTimer(this.timer_callback)
            this.timer_running := true
        }
    }

    Dispose() {
        SetTimer(this.tray_click_timeout_callback, 0)
        this.EndTrayIconClick()
        if this.timer_running {
            SetTimer(this.timer_callback, 0)
            this.timer_running := false
        }
    }

    BeginTrayIconClick() {
        this.on_tray_icon_click := true
        ; The notification area becomes the active window before this callback runs.
        ; Keep using the window and process cached by the focus monitor instead.
        this.tray_click_window := this.active_window
        this.tray_click_process := this.active_win
        ; A mouse-up outside the notification area may not produce a callback.
        SetTimer(this.tray_click_timeout_callback, -5000)
    }

    EndTrayIconClick() {
        SetTimer(this.tray_click_timeout_callback, 0)
        this.on_tray_icon_click := false
        this.tray_click_window := 0
        this.tray_click_process := ""
    }

    ApplyTrayAscii(target) {
        if !this.config.global_ascii && this.tray_click_process {
            this.UpdateWinAscii(target, true, this.tray_click_process, true)
        } else if this.tray {
            this.tray.UpdateTip(, target)
            this.tray.UpdateIcon()
        }
    }

    RestoreTrayClickWindow() {
        if this.tray_click_window && WinExist("ahk_id " . this.tray_click_window) {
            WinActivate("ahk_id " . this.tray_click_window)
        }
    }

    UpdateStateLabels() {
        local str, slice
        if !this.rime {
            return
        }
        str := this.rime.get_state_label(this.session_id, "ascii_mode", false)
        this.ascii_mode_false_label := str ? str : "中文"
        str := this.rime.get_state_label(this.session_id, "ascii_mode", true)
        this.ascii_mode_true_label := str ? str : "西文"
        slice := this.rime.get_state_label_abbreviated(this.session_id, "ascii_mode", false, true)
        this.ascii_mode_false_label_abbr := (slice && slice.slice !== "") ? slice.slice : "中"
        slice := this.rime.get_state_label_abbreviated(this.session_id, "ascii_mode", true, true)
        this.ascii_mode_true_label_abbr := (slice && slice.slice !== "") ? slice.slice : "西"
        str := this.rime.get_state_label(this.session_id, "full_shape", false)
        this.full_shape_false_label := str ? str : "半角"
        str := this.rime.get_state_label(this.session_id, "full_shape", true)
        this.full_shape_true_label := str ? str : "全角"
        slice := this.rime.get_state_label_abbreviated(this.session_id, "full_shape", false, true)
        this.full_shape_false_label_abbr := (slice && slice.slice !== "") ? slice.slice : "半"
        slice := this.rime.get_state_label_abbreviated(this.session_id, "full_shape", true, true)
        this.full_shape_true_label_abbr := (slice && slice.slice !== "") ? slice.slice : "全"
        str := this.rime.get_state_label(this.session_id, "ascii_punct", false)
        this.ascii_punct_false_label := str ? str : "。，"
        str := this.rime.get_state_label(this.session_id, "ascii_punct", true)
        this.ascii_punct_true_label := str ? str : ". ,"
        slice := this.rime.get_state_label_abbreviated(this.session_id, "ascii_punct", false, true)
        this.ascii_punct_false_label_abbr := (slice && slice.slice !== "") ? slice.slice : "。"
        slice := this.rime.get_state_label_abbreviated(this.session_id, "ascii_punct", true, true)
        this.ascii_punct_true_label_abbr := (slice && slice.slice !== "") ? slice.slice : "."
    }

    UpdateWinAscii(target := false, use_target := false, proc_name := "", by_tray_icon := false) {
        local active_window, current
        if A_IsSuspended {
            return
        }
        if this.on_tray_icon_click && !by_tray_icon {
            return
        }
        if !this.rime || !this.session_id {
            return
        }
        if !proc_name {
            if !(active_window := WinExist("A")) {
                return
            }
            try {
                proc_name := StrLower(WinGetProcessName())
            }
            if !proc_name {
                return
            }
            this.active_window := active_window
        }
        this.active_win := proc_name
        ; TODO: The cached state may be inaccurate because this update is not atomic.
        current := !!this.rime.get_option(this.session_id, "ascii_mode")
        if use_target {
            this.process_ascii[proc_name] := !!target
        } else if this.process_ascii.Has(proc_name) {
            target := this.process_ascii[proc_name]
            if current !== target {
                this.rime.set_option(this.session_id, "ascii_mode", target)
            }
        } else if this.config.TryGetPresetProcessAscii(proc_name, &target) {
            this.process_ascii[proc_name] := !!target
            if current !== target {
                this.rime.set_option(this.session_id, "ascii_mode", target)
            }
        } else {
            target := false
            this.process_ascii[proc_name] := !!target
            if current !== target {
                this.rime.set_option(this.session_id, "ascii_mode", target)
            }
        }
        if this.tray
            && (this.tray_tip_process != proc_name || this.tray_tip_ascii != !!target) {
            this.tray_tip_process := proc_name
            this.tray_tip_ascii := !!target
            this.tray.UpdateTip(, target)
            this.tray.UpdateIcon()
        }
    }
}
