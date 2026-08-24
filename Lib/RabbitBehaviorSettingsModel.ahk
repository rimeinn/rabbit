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

class RabbitBehaviorSettingsModel {
    __New(levers_api, rime_api) {
        this.api := levers_api
        this.rime := rime_api
        this.settings := 0
        this.disposed := false

        try {
            this.settings := this.api.custom_settings_init("rabbit", "Rabbit.BehaviorSettings")
            if !this.settings || !this.Load() {
                throw Error("未能读取输入与行为设置。")
            }
        } catch {
            this.Dispose()
            throw
        }
    }

    Load() {
        local config
        if !this.api.load_settings(this.settings) {
            return false
        }
        if !(config := this.api.settings_get_config(this.settings)) {
            return false
        }
        this.show_tips := this.GetBool(config, "show_tips", true)
        this.show_tips_time := this.GetInt(config, "show_tips_time", 1200)
        this.global_ascii := this.GetBool(config, "global_ascii", false)
        this.fix_candidate_box := this.GetBool(config, "fix_candidate_box", false)
        this.use_legacy_candidate_box := this.GetBool(config, "use_legacy_candidate_box", false)
        this.bypass_password_fields := this.GetBool(config, "bypass_password_fields", true)
        return true
    }

    GetBool(config, key, fallback) {
        local value
        return this.rime.config_test_get_bool(config, key, &value) ? !!value : fallback
    }

    GetInt(config, key, fallback) {
        local value
        return this.rime.config_test_get_int(config, key, &value) ? value : fallback
    }

    Save(values) {
        if !this.api.load_settings(this.settings) {
            return false
        }
        if !this.api.customize_bool(this.settings, "show_tips", values.show_tips) {
            return false
        }
        if !this.api.customize_int(this.settings, "show_tips_time", values.show_tips_time) {
            return false
        }
        if !this.api.customize_bool(this.settings, "global_ascii", values.global_ascii) {
            return false
        }
        if !this.api.customize_bool(this.settings, "fix_candidate_box", values.fix_candidate_box) {
            return false
        }
        if !this.api.customize_bool(
            this.settings,
            "use_legacy_candidate_box",
            values.use_legacy_candidate_box
        ) {
            return false
        }
        if !this.api.customize_bool(
            this.settings,
            "bypass_password_fields",
            values.bypass_password_fields
        ) {
            return false
        }
        return !!this.api.save_settings(this.settings)
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
    }

    __Delete() {
        this.Dispose()
    }
}
