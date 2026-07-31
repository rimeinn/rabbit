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

class RabbitConfigSnapshot {
    __New(values := 0) {
        this.suspend_hotkey := this.GetValue(values, "suspend_hotkey", "")
        this.show_tips := this.GetValue(values, "show_tips", true)
        this.show_tips_time := this.GetValue(values, "show_tips_time", 1200)
        this.global_ascii := this.GetValue(values, "global_ascii", false)
        this.fix_candidate_box := this.GetValue(values, "fix_candidate_box", false)
        this.use_legacy_candidate_box := this.GetValue(values, "use_legacy_candidate_box", false)
        this.use_caret_hook := this.GetValue(values, "use_caret_hook", false)
        this.send_by_clipboard_length := this.GetValue(values, "send_by_clipboard_length", 8)
        this._preset_process_ascii := this.CopyMap(
            this.GetValue(values, "preset_process_ascii", Map()))
        this._schema_icon := this.CopyMap(this.GetValue(values, "schema_icon", Map()))
    }

    GetPresetProcessAscii() {
        return this.CopyMap(this._preset_process_ascii)
    }

    TryGetPresetProcessAscii(process_name, &ascii_mode) {
        if !this._preset_process_ascii.Has(process_name) {
            return false
        }
        ascii_mode := this._preset_process_ascii[process_name]
        return true
    }

    TryGetSchemaIcon(schema_id, &icon_path) {
        if !this._schema_icon.Has(schema_id) {
            return false
        }
        icon_path := this._schema_icon[schema_id]
        return true
    }

    GetValue(values, name, fallback) {
        if !values {
            return fallback
        }
        if values is Map {
            return values.Has(name) ? values[name] : fallback
        }
        return HasProp(values, name) ? values.%name% : fallback
    }

    CopyMap(source) {
        local result := Map()
        for key, value in source {
            result[key] := value
        }
        return result
    }
}
