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
 */

#Include RabbitCommon.ahk

/**
 * Rabbit-owned settings for the RimeDepot integration.
 *
 * Reading deliberately uses the merged Rime configuration and closes the
 * returned handle immediately.  Saving goes through Rime Levers so the only
 * persistent user override remains rabbit.custom.yaml.
 */
class RabbitRimeDepotSettings {
    static DEFAULT_RPPI_URL := "https://raw.githubusercontent.com/rime/rppi/HEAD/index.json"
    static RPPI_URL_KEY := "rime_depot/rppi_url"
    static PROXY_KEY := "rime_depot/proxy"
    static USE_GIT_KEY := "rime_depot/use_git"
    static GIT_PATH_KEY := "rime_depot/git_path"

    __New(values := 0) {
        this.rppi_url := RabbitRimeDepotSettings.DEFAULT_RPPI_URL
        this.proxy := ""
        this.use_git := false
        this.git_path := ""
        if values {
            this.Apply(values)
        }
    }

    static Load(rime_api) {
        local settings := this(), config := 0, value
        if !rime_api {
            return settings
        }
        if !(config := rime_api.config_open("rabbit")) {
            throw Error("The merged Rabbit configuration could not be opened.")
        }
        try {
            if rime_api.config_test_get_string(config, this.RPPI_URL_KEY, &value) && value != "" {
                settings.rppi_url := value
            }
            if rime_api.config_test_get_string(config, this.PROXY_KEY, &value) {
                settings.proxy := value
            }
            if rime_api.config_test_get_bool(config, this.USE_GIT_KEY, &value) {
                settings.use_git := !!value
            }
            if rime_api.config_test_get_string(config, this.GIT_PATH_KEY, &value) {
                settings.git_path := value
            }
        } finally {
            rime_api.config_close(config)
        }
        return settings
    }

    /** Save all four keys through the Rabbit Levers custom-settings writer. */
    static Save(rime_api, values, levers_api := 0) {
        local api, custom_settings := 0, settings
        if !rime_api {
            return false
        }
        api := levers_api ? levers_api : RimeLeversApi(rime_api)
        try {
            custom_settings := api.custom_settings_init("rabbit", RABBIT_CUSTOMIZATION_GENERATOR_ID)
            if !custom_settings || !api.load_settings(custom_settings) {
                return false
            }
            settings := this(values)
            if !api.customize_string(custom_settings, this.RPPI_URL_KEY, settings.rppi_url)
                || !api.customize_string(custom_settings, this.PROXY_KEY, settings.proxy)
                || !api.customize_bool(custom_settings, this.USE_GIT_KEY, settings.use_git)
                || !api.customize_string(custom_settings, this.GIT_PATH_KEY, settings.git_path) {
                return false
            }
            return !!api.save_settings(custom_settings)
        } finally {
            if custom_settings {
                api.custom_settings_destroy(custom_settings)
            }
        }
    }

    Apply(values) {
        local value
        if !IsObject(values) {
            return
        }
        value := this.GetValue(values, ["rppi_url", "RppiIndexUrl", "rppi_index_url"], "")
        if value != "" {
            this.rppi_url := Trim(String(value))
        }
        this.proxy := Trim(String(this.GetValue(values, ["proxy", "Proxy"], this.proxy)))
        value := this.GetValue(values, ["use_git", "UseGit"], this.use_git)
        this.use_git := value is String
            ? RabbitRimeDepotSettings.ParseBoolean(value, this.use_git)
            : !!value
        this.git_path := Trim(String(this.GetValue(values, ["git_path", "GitPath"], this.git_path)))
    }

    ToMap() {
        return Map(
            "rppi_url", this.rppi_url,
            "proxy", this.proxy,
            "use_git", this.use_git,
            "git_path", this.git_path
        )
    }

    /** Options use the names expected by RimeDepotConfig. */
    ToServiceOptions(cache_path, rime_directory) {
        return Map(
            "CachePath", cache_path,
            "RimeDirectory", rime_directory,
            "RppiIndexUrl", this.rppi_url,
            "Proxy", this.proxy,
            "UseGit", this.use_git,
            "GitPath", this.git_path
        )
    }

    GetValue(values, keys, fallback := "") {
        local key
        for key in keys {
            if values is Map {
                if values.Has(key) {
                    return values[key]
                }
            } else if HasProp(values, key) {
                return values.%key%
            }
        }
        return fallback
    }

    static ParseBoolean(value, fallback := false) {
        value := StrLower(Trim(String(value)))
        if value = "true" || value = "yes" || value = "on" || value = "1" {
            return true
        }
        if value = "false" || value = "no" || value = "off" || value = "0" {
            return false
        }
        return fallback
    }
}
