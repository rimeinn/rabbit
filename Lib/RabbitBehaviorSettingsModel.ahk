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
    static SWITCH_KEYS := ["Shift_L", "Shift_R", "Control_L", "Control_R", "Caps_Lock", "Eisu_toggle"]
    static SWITCH_KEY_DEFAULTS := Map(
        "Shift_L", "inline_ascii",
        "Shift_R", "commit_text",
        "Control_L", "noop",
        "Control_R", "noop",
        "Caps_Lock", "clear",
        "Eisu_toggle", "clear"
    )

    __New(levers_api, rime_api) {
        this.api := levers_api
        this.rime := rime_api
        this.settings := 0
        this.default_settings := 0
        this.disposed := false

        try {
            this.settings := this.api.custom_settings_init("rabbit", "Rabbit.BehaviorSettings")
            this.default_settings := this.api.custom_settings_init("default", "Rabbit.DefaultBehaviorSettings")
            if !this.settings || !this.default_settings || !this.Load() {
                throw Error("未能读取输入与行为设置。")
            }
        } catch {
            this.Dispose()
            throw
        }
    }

    Load() {
        local config, default_config
        if !this.api.load_settings(this.settings) || !this.api.load_settings(this.default_settings) {
            return false
        }
        if !(config := this.api.settings_get_config(this.settings)) {
            return false
        }
        if !(default_config := this.api.settings_get_config(this.default_settings)) {
            return false
        }

        this.show_tips := this.GetBool(config, "show_tips", true)
        this.show_tips_time := this.GetInt(config, "show_tips_time", 1200)
        this.suspend_hotkey := this.GetString(config, "suspend_hotkey", "")
        this.send_by_clipboard_length := this.GetInt(config, "send_by_clipboard_length", 8)
        this.global_ascii := this.GetBool(config, "global_ascii", false)
        this.fix_candidate_box := this.GetBool(config, "fix_candidate_box", false)
        this.use_legacy_candidate_box := this.GetBool(config, "use_legacy_candidate_box", false)
        this.bypass_password_fields := this.GetBool(config, "bypass_password_fields", true)
        this.switch_key := this.LoadSwitchKeys(default_config)
        this.page_size := this.GetInt(default_config, "menu/page_size", 5)
        this.alternative_select_labels := this.LoadStringList(default_config, "menu/alternative_select_labels")
        this.bindings := this.LoadBindings(default_config)
        this.original_values := this.GetCurrentValues()
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

    GetString(config, key, fallback) {
        local value
        return this.rime.config_test_get_string(config, key, &value) ? value : fallback
    }

    LoadSwitchKeys(config) {
        local action, key
        local result := Map()
        for key in RabbitBehaviorSettingsModel.SWITCH_KEYS {
            if !this.rime.config_test_get_string(config, "ascii_composer/switch_key/" . key, &action) {
                action := RabbitBehaviorSettingsModel.SWITCH_KEY_DEFAULTS[key]
            }
            result[key] := action
        }
        return result
    }

    LoadStringList(config, path) {
        local iter, value
        local result := []
        if !(iter := this.rime.config_begin_list(config, path)) {
            return result
        }
        try {
            while this.rime.config_next(iter) {
                if this.rime.config_test_get_string(config, iter.path, &value) {
                    result.Push(value)
                }
            }
        } finally {
            this.rime.config_end(iter)
        }
        return result
    }

    LoadBindings(config) {
        local binding, iter
        local result := []
        if !(iter := this.rime.config_begin_list(config, "key_binder/bindings")) {
            return result
        }
        try {
            while this.rime.config_next(iter) {
                if (binding := this.ReadConfigMap(config, iter.path)) {
                    result.Push(binding)
                }
            }
        } finally {
            this.rime.config_end(iter)
        }
        return result
    }

    ReadConfigMap(config, path) {
        local iter, value
        local result := Map()
        if !(iter := this.rime.config_begin_map(config, path)) {
            return 0
        }
        try {
            while this.rime.config_next(iter) {
                if this.TryReadConfigValue(config, iter.path, &value) {
                    result[iter.key] := value
                }
            }
        } finally {
            this.rime.config_end(iter)
        }
        return result
    }

    ReadConfigList(config, path) {
        local iter, value
        local result := []
        if !(iter := this.rime.config_begin_list(config, path)) {
            return 0
        }
        try {
            while this.rime.config_next(iter) {
                if this.TryReadConfigValue(config, iter.path, &value) {
                    result.Push(value)
                }
            }
        } finally {
            this.rime.config_end(iter)
        }
        return result
    }

    TryReadConfigValue(config, path, &value) {
        local nested
        if (nested := this.ReadConfigMap(config, path)) {
            value := nested
            return true
        }
        if (nested := this.ReadConfigList(config, path)) {
            value := nested
            return true
        }
        if this.rime.config_test_get_bool(config, path, &value) {
            value := !!value
            return true
        }
        if this.rime.config_test_get_int(config, path, &value) {
            return true
        }
        if this.rime.config_test_get_double(config, path, &value) {
            return true
        }
        return !!this.rime.config_test_get_string(config, path, &value)
    }

    GetCurrentValues() {
        return {
            show_tips: this.show_tips,
            show_tips_time: this.show_tips_time,
            suspend_hotkey: this.suspend_hotkey,
            send_by_clipboard_length: this.send_by_clipboard_length,
            global_ascii: this.global_ascii,
            fix_candidate_box: this.fix_candidate_box,
            use_legacy_candidate_box: this.use_legacy_candidate_box,
            bypass_password_fields: this.bypass_password_fields,
            switch_key: RabbitBehaviorSettingsModel.CloneValue(this.switch_key),
            page_size: this.page_size,
            alternative_select_labels: RabbitBehaviorSettingsModel.CloneValue(this.alternative_select_labels),
            bindings: RabbitBehaviorSettingsModel.CloneValue(this.bindings),
        }
    }

    GetBindings() {
        return RabbitBehaviorSettingsModel.CloneValue(this.bindings)
    }

    Save(values) {
        local default_changed := this.HasDefaultChanges(values)
        local rabbit_changed := this.HasRabbitChanges(values)
        if !rabbit_changed && !default_changed {
            return true
        }
        if rabbit_changed && !this.SaveRabbitSettings(values) {
            return false
        }
        if default_changed && !this.SaveDefaultSettings(values) {
            return false
        }
        this.SetCurrentValues(values)
        this.original_values := this.GetCurrentValues()
        return true
    }

    HasRabbitChanges(values) {
        local original := this.original_values
        return values.show_tips != original.show_tips
            || values.show_tips_time != original.show_tips_time
            || values.suspend_hotkey != original.suspend_hotkey
            || values.send_by_clipboard_length != original.send_by_clipboard_length
            || values.global_ascii != original.global_ascii
            || values.fix_candidate_box != original.fix_candidate_box
            || values.use_legacy_candidate_box != original.use_legacy_candidate_box
            || values.bypass_password_fields != original.bypass_password_fields
    }

    HasDefaultChanges(values) {
        local original := this.original_values
        return !RabbitBehaviorSettingsModel.ValuesEqual(values.switch_key, original.switch_key)
            || values.page_size != original.page_size
            || !RabbitBehaviorSettingsModel.ValuesEqual(
                values.alternative_select_labels,
                original.alternative_select_labels
            )
            || !RabbitBehaviorSettingsModel.ValuesEqual(values.bindings, original.bindings)
    }

    SaveRabbitSettings(values) {
        if !this.api.load_settings(this.settings) {
            return false
        }
        if !this.api.customize_bool(this.settings, "show_tips", values.show_tips) {
            return false
        }
        if !this.api.customize_int(this.settings, "show_tips_time", values.show_tips_time) {
            return false
        }
        if values.suspend_hotkey != this.original_values.suspend_hotkey {
            if values.suspend_hotkey {
                if !this.api.customize_string(this.settings, "suspend_hotkey", values.suspend_hotkey) {
                    return false
                }
            } else if !this.api.customize_item(this.settings, "suspend_hotkey", 0) {
                return false
            }
        }
        if !this.api.customize_int(
            this.settings,
            "send_by_clipboard_length",
            values.send_by_clipboard_length
        ) {
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

    SaveDefaultSettings(values) {
        local key
        local original := this.original_values
        if !this.api.load_settings(this.default_settings) {
            return false
        }
        for key in RabbitBehaviorSettingsModel.SWITCH_KEYS {
            if values.switch_key[key] != original.switch_key[key]
                && !this.api.customize_string(
                    this.default_settings,
                    "ascii_composer/switch_key/" . key,
                    values.switch_key[key]
                ) {
                return false
            }
        }
        if values.page_size != original.page_size
            && !this.api.customize_int(this.default_settings, "menu/page_size", values.page_size) {
            return false
        }
        if !RabbitBehaviorSettingsModel.ValuesEqual(
            values.alternative_select_labels,
            original.alternative_select_labels
        ) && !this.CustomizeYamlItem(
            this.default_settings,
            "menu/alternative_select_labels",
            values.alternative_select_labels
        ) {
            return false
        }
        if !RabbitBehaviorSettingsModel.ValuesEqual(values.bindings, original.bindings)
            && !this.CustomizeBindings(values.bindings, original.bindings.Length) {
            return false
        }
        return !!this.api.save_settings(this.default_settings)
    }

    CustomizeBindings(bindings, original_length) {
        local index, key
        ; A full-list edit owns this path. Remove common incremental patch forms before writing it.
        for key in ["key_binder/bindings/+", "key_binder/bindings/-"] {
            this.api.customize_item(this.default_settings, key, 0)
        }
        Loop Max(original_length, bindings.Length) {
            index := A_Index - 1
            this.api.customize_item(this.default_settings, "key_binder/bindings/@" . index, 0)
        }
        return this.CustomizeYamlItem(this.default_settings, "key_binder/bindings", bindings)
    }

    CustomizeYamlItem(settings, key, value) {
        local config := 0
        if !(config := this.rime.config_load_string(RabbitBehaviorSettingsModel.ToYaml(value))) {
            return false
        }
        try {
            return !!this.api.customize_item(settings, key, config)
        } finally {
            this.rime.config_close(config)
        }
    }

    SetCurrentValues(values) {
        this.show_tips := values.show_tips
        this.show_tips_time := values.show_tips_time
        this.suspend_hotkey := values.suspend_hotkey
        this.send_by_clipboard_length := values.send_by_clipboard_length
        this.global_ascii := values.global_ascii
        this.fix_candidate_box := values.fix_candidate_box
        this.use_legacy_candidate_box := values.use_legacy_candidate_box
        this.bypass_password_fields := values.bypass_password_fields
        this.switch_key := RabbitBehaviorSettingsModel.CloneValue(values.switch_key)
        this.page_size := values.page_size
        this.alternative_select_labels := RabbitBehaviorSettingsModel.CloneValue(values.alternative_select_labels)
        this.bindings := RabbitBehaviorSettingsModel.CloneValue(values.bindings)
    }

    static CloneValue(value) {
        local copy, item, key
        if value is Map {
            copy := Map()
            for key, item in value {
                copy[key] := RabbitBehaviorSettingsModel.CloneValue(item)
            }
            return copy
        }
        if value is Array {
            copy := []
            for item in value {
                copy.Push(RabbitBehaviorSettingsModel.CloneValue(item))
            }
            return copy
        }
        return value
    }

    static ValuesEqual(left, right) {
        local key, value
        if left is Map {
            if !(right is Map) || left.Count != right.Count {
                return false
            }
            for key, value in left {
                if !right.Has(key) || !RabbitBehaviorSettingsModel.ValuesEqual(value, right[key]) {
                    return false
                }
            }
            return true
        }
        if left is Array {
            if !(right is Array) || left.Length != right.Length {
                return false
            }
            Loop left.Length {
                if !RabbitBehaviorSettingsModel.ValuesEqual(left[A_Index], right[A_Index]) {
                    return false
                }
            }
            return true
        }
        return !(right is Map) && !(right is Array) && left == right && Type(left) = Type(right)
    }

    static ToYaml(value) {
        local parts, item, key
        if value is Map {
            parts := []
            for key, item in value {
                parts.Push(RabbitBehaviorSettingsModel.QuoteYaml(key) . ": " . RabbitBehaviorSettingsModel.ToYaml(item))
            }
            return "{" . RabbitBehaviorSettingsModel.Join(parts, ", ") . "}"
        }
        if value is Array {
            parts := []
            for item in value {
                parts.Push(RabbitBehaviorSettingsModel.ToYaml(item))
            }
            return "[" . RabbitBehaviorSettingsModel.Join(parts, ", ") . "]"
        }
        if Type(value) = "Integer" || Type(value) = "Float" {
            return String(value)
        }
        return RabbitBehaviorSettingsModel.QuoteYaml(value)
    }

    static QuoteYaml(value) {
        local escaped := StrReplace(String(value), "\", "\\")
        escaped := StrReplace(escaped, '"', '\"')
        escaped := StrReplace(escaped, "`r", "\r")
        escaped := StrReplace(escaped, "`n", "\n")
        return '"' . escaped . '"'
    }

    static Join(items, separator) {
        local result := ""
        for item in items {
            result .= (result ? separator : "") . item
        }
        return result
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        if this.default_settings {
            this.api.custom_settings_destroy(this.default_settings)
            this.default_settings := 0
        }
        if this.settings {
            this.api.custom_settings_destroy(this.settings)
            this.settings := 0
        }
    }

    __Delete() {
        this.Dispose()
    }
}
