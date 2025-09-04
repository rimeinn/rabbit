/*
 * Copyright (c) 2025 Xuesong Peng <pengxuesong.cn@gmail.com>
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
#Include <RabbitUIStyle>

class RabbitConfig {
    static suspend_hotkey := ""
    static show_tips := true
    static show_tips_time := 1200
    static global_ascii := false
    static preset_process_ascii := Map()
    static schema_icon := Map()
    static fix_candidate_box := false
    static use_legacy_candidate_box := false

    static load() {
        global rime, IS_DARK_MODE
        if !rime || !config := rime.config_open("rabbit")
            return

        RabbitConfig.suspend_hotkey := rime.config_get_string(config, "suspend_hotkey")
        if rime.config_test_get_bool(config, "show_tips", &result)
            RabbitConfig.show_tips := !!result
        if rime.config_test_get_int(config, "show_tips_time", &result) {
            RabbitConfig.show_tips_time := Abs(result)
            if result == 0
                RabbitConfig.show_tips := false
        }

        if rime.config_test_get_bool(config, "global_ascii", &result)
            RabbitConfig.global_ascii := !!result

        if iter := rime.config_begin_map(config, "app_options") {
            while rime.config_next(iter) {
                proc_name := StrLower(iter.key)
                if rime.config_test_get_bool(config, "app_options/" . proc_name . "/ascii_mode", &result) {
                    RabbitConfig.preset_process_ascii[proc_name] := !!result
                    RabbitGlobals.process_ascii[proc_name] := !!result
                }
            }
            rime.config_end(iter)
        }

        if rime.config_test_get_bool(config, "fix_candidate_box", &result)
            RabbitConfig.fix_candidate_box := !!result
        if rime.config_test_get_bool(config, "use_legacy_candidate_box", &result)
            RabbitConfig.use_legacy_candidate_box := !!result

        UIStyle.Update(config, true)
        if IS_DARK_MODE := RabbitIsUserDarkMode() {
            if color_name := rime.config_get_string(config, "style/color_scheme_dark")
                UIStyle.use_dark := UIStyle.UpdateColor(config, color_name)
            DarkMode.set(IS_DARK_MODE)
        }

        rime.config_close(config)

        if !schema_list := rime.get_schema_list()
            return

        Loop schema_list.size {
            local item := schema_list.list[A_Index]
            if !schema := rime.schema_open(item.schema_id)
                continue

            if rime.config_test_get_string(schema, "schema/icon", &icon) {
                icon_path := RabbitUserDataPath() . "\" . LTrim(icon, "\")
                if !FileExist(icon_path)
                    icon_path := RabbitSharedDataPath() . "\" . LTrim(icon, "\")
                RabbitConfig.schema_icon[item.schema_id] := FileExist(icon_path) ? icon_path : ""
            } else
                RabbitConfig.schema_icon[item.schema_id] := ""

            rime.config_close(schema)
        }

        rime.free_schema_list(schema_list)
    }
}
