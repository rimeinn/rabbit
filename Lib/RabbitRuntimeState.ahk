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
#Include <RabbitConfig>
#Include <RabbitTrayMenu>

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
