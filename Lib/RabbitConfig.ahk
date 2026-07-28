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
#Include <RabbitConfigSnapshot>
#Include <RabbitUIStyle>
#Include <RabbitUIStyleSnapshot>

class RabbitConfigLoader {
    static Load(rime_api) {
        local config, result, iter, proc_name, schema_list, schema, icon, icon_path
        local values := Map(
            "preset_process_ascii", Map(),
            "schema_icon", Map()
        )
        local ui_style := RabbitUIStyleSnapshot()
        local dark_mode := false

        if !rime_api || !(config := rime_api.config_open("rabbit")) {
            return {
                config: RabbitConfigSnapshot(values),
                style: ui_style,
                dark_mode: dark_mode
            }
        }

        values["suspend_hotkey"] := rime_api.config_get_string(config, "suspend_hotkey")
        if rime_api.config_test_get_bool(config, "show_tips", &result) {
            values["show_tips"] := !!result
        }
        if rime_api.config_test_get_int(config, "show_tips_time", &result) {
            values["show_tips_time"] := Abs(result)
            if result == 0 {
                values["show_tips"] := false
            }
        }
        if rime_api.config_test_get_int(config, "send_by_clipboard_length", &result) {
            ; 0: always send by clipboard
            ; >0: send by clipboard if length >= value
            ; <0: never send by clipboard (65535 is large enough for candidates)
            values["send_by_clipboard_length"] := result >= 0 ? result : 65535
        }
        if rime_api.config_test_get_bool(config, "global_ascii", &result) {
            values["global_ascii"] := !!result
        }
        if (iter := rime_api.config_begin_map(config, "app_options")) {
            while rime_api.config_next(iter) {
                proc_name := StrLower(iter.key)
                if rime_api.config_test_get_bool(
                    config, "app_options/" . proc_name . "/ascii_mode", &result) {
                    values["preset_process_ascii"][proc_name] := !!result
                }
            }
            rime_api.config_end(iter)
        }
        if rime_api.config_test_get_bool(config, "fix_candidate_box", &result) {
            values["fix_candidate_box"] := !!result
        }
        if rime_api.config_test_get_bool(config, "use_legacy_candidate_box", &result) {
            values["use_legacy_candidate_box"] := !!result
        }
        if rime_api.config_test_get_bool(config, "use_caret_hook", &result) {
            values["use_caret_hook"] := !!result
        }

        dark_mode := RabbitIsUserDarkMode()
        ui_style := RabbitUIStyleSnapshot.FromConfig(rime_api, config, dark_mode)
        rime_api.config_close(config)

        if (schema_list := rime_api.get_schema_list()) {
            Loop schema_list.size {
                local item := schema_list.list[A_Index]
                if !(schema := rime_api.schema_open(item.schema_id)) {
                    continue
                }
                if rime_api.config_test_get_string(schema, "schema/icon", &icon) {
                    icon_path := RabbitUserDataPath() . "\" . LTrim(icon, "\")
                    if !FileExist(icon_path) {
                        icon_path := RabbitSharedDataPath() . "\" . LTrim(icon, "\")
                    }
                    values["schema_icon"][item.schema_id] := FileExist(icon_path) ? icon_path : ""
                } else {
                    values["schema_icon"][item.schema_id] := ""
                }
                rime_api.config_close(schema)
            }
            rime_api.free_schema_list(schema_list)
        }

        return {
            config: RabbitConfigSnapshot(values),
            style: ui_style,
            dark_mode: dark_mode
        }
    }
}
