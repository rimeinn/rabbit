/*
 * Copyright (c) 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
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

class RabbitApplicationSettingsModel {
    __New(levers_api, rime_api) {
        this.api := levers_api
        this.rime := rime_api
        this.settings := 0
        this.rules := Map()
        this.disposed := false

        try {
            this.settings := this.api.custom_settings_init("rabbit", "Rabbit.ApplicationSettings")
            if !this.settings || !this.Load() {
                throw Error("未能读取应用适配设置。")
            }
        } catch {
            this.Dispose()
            throw
        }
    }

    Load() {
        local config, iter, process_name, value
        if !this.api.load_settings(this.settings) {
            return false
        }
        if !(config := this.api.settings_get_config(this.settings)) {
            return false
        }

        this.rules := Map()
        if !(iter := this.rime.config_begin_map(config, "app_options")) {
            return true
        }
        try {
            while this.rime.config_next(iter) {
                process_name := StrLower(iter.key)
                if this.rime.config_test_get_bool(
                    config,
                    "app_options/" . process_name . "/ascii_mode",
                    &value
                ) {
                    this.rules[process_name] := !!value
                }
            }
        } finally {
            this.rime.config_end(iter)
        }
        return true
    }

    Save(changes) {
        local change, key, process_name
        if changes.Count = 0 {
            return false
        }
        if !this.api.load_settings(this.settings) {
            return false
        }
        for process_name, change in changes {
            key := "app_options/" . process_name . "/ascii_mode"
            if change.reset {
                if !this.api.customize_item(this.settings, key, 0) {
                    return false
                }
            } else if !this.api.customize_bool(this.settings, key, change.ascii_mode) {
                return false
            }
        }
        return !!this.api.save_settings(this.settings)
    }

    static NormalizeProcessName(process_name) {
        return StrLower(Trim(process_name))
    }

    static IsValidProcessName(process_name) {
        return process_name != "." && process_name != ".." && SubStr(process_name, -1) != "." &&
            RegExMatch(process_name, '^[^\\/:*?"<>|]+$')
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        if this.settings {
            this.api.custom_settings_destroy(this.settings)
            this.settings := 0
        }
        this.rules := Map()
    }

    __Delete() {
        this.Dispose()
    }
}
