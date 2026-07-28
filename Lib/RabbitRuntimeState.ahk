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

#Include <RabbitConfigSnapshot>

class RabbitRuntimeState {
    __New(rime_api, session_id, config) {
        this.rime := rime_api
        this.session_id := session_id
        this.config := config
        this.tray := 0
        this.process_ascii := config.GetPresetProcessAscii()
        this.on_tray_icon_click := false
        this.active_win := ""
        this.timer_callback := this.UpdateWinAscii.Bind(this)
        this.timer_running := false

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
        if this.timer_running {
            SetTimer(this.timer_callback, 0)
            this.timer_running := false
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
        if this.tray {
            this.tray.UpdateTip(, target)
            this.tray.UpdateIcon()
        }
    }
}
