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

class RabbitSystemInputSettings {
    __New(rime_api, levers_api := 0) {
        this.rime := rime_api
        this.api := levers_api ? levers_api : RimeLeversApi(rime_api)
    }

    Load(&klid) {
        klid := ""
        local config := this.rime.user_config_open("rabbit.custom")
        if !config {
            return false
        }
        try {
            klid := this.rime.config_get_string(config, "patch/system_input_layout")
            return true
        } finally {
            this.rime.config_close(config)
        }
    }

    Save(klid) {
        local settings := this.api.custom_settings_init(
            "rabbit",
            "Rabbit.SystemInputSettings"
        )
        if !settings {
            return false
        }
        try {
            if !this.api.load_settings(settings) {
                return false
            }
            if !this.api.customize_string(settings, "system_input_layout", klid) {
                return false
            }
            return !!this.api.save_settings(settings)
        } finally {
            this.api.custom_settings_destroy(settings)
        }
    }
}
