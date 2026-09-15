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
#Include RabbitConfigValue.ahk
#Include RabbitDeploymentPlan.ahk
#Include RabbitMenuSettings.ahk
#Include RabbitPunctuatorMap.ahk
#Include RabbitRecognizerPatterns.ahk

#Include RabbitI18n.ahk

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
            this.settings := this.api.custom_settings_init("rabbit", RABBIT_CUSTOMIZATION_GENERATOR_ID)
            this.default_settings := this.api.custom_settings_init("default", RABBIT_CUSTOMIZATION_GENERATOR_ID)
            if !this.settings || !this.default_settings || !this.Load() {
                throw Error(RabbitI18n.Text("models.behavior_read"))
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

        this.language := this.GetString(config, "language", "auto")
        this.show_tips := this.GetBool(config, "show_tips", true)
        this.show_tips_time := this.GetInt(config, "show_tips_time", 1200)
        this.suspend_hotkey := this.GetString(config, "suspend_hotkey", "")
        this.send_by_clipboard_length := this.GetInt(config, "send_by_clipboard_length", 8)
        this.global_ascii := this.GetBool(config, "global_ascii", false)
        this.fix_candidate_box := this.GetBool(config, "fix_candidate_box", false)
        this.use_legacy_candidate_box := this.GetBool(config, "use_legacy_candidate_box", false)
        this.bypass_password_fields := this.GetBool(config, "bypass_password_fields", true)
        this.good_old_caps_lock := this.GetBool(
            default_config,
            "ascii_composer/good_old_caps_lock",
            true
        )
        this.switch_key := this.LoadSwitchKeys(default_config)
        this.page_size := this.GetInt(default_config, RabbitMenuSettings.PAGE_SIZE_PATH, 5)
        this.alternative_select_labels := this.LoadStringList(
            default_config,
            RabbitMenuSettings.ALTERNATIVE_SELECT_LABELS_PATH
        )
        this.alternative_select_keys := this.GetString(
            default_config,
            RabbitMenuSettings.ALTERNATIVE_SELECT_KEYS_PATH,
            RabbitMenuSettings.ALTERNATIVE_SELECT_KEYS_DEFAULT
        )
        this.page_down_cycle := this.GetBool(
            default_config,
            RabbitMenuSettings.PAGE_DOWN_CYCLE_PATH,
            RabbitMenuSettings.PAGE_DOWN_CYCLE_DEFAULT
        )
        this.bindings := this.LoadBindings(default_config)
        this.punctuator_maps := this.LoadPunctuatorMaps(default_config)
        this.punctuator_use_space := this.GetBool(
            default_config,
            RabbitPunctuatorMap.USE_SPACE_PATH,
            false
        )
        this.punctuator_digit_separators := this.GetString(
            default_config,
            RabbitPunctuatorMap.DIGIT_SEPARATORS_PATH,
            RabbitPunctuatorMap.DIGIT_SEPARATORS_DEFAULT
        )
        this.punctuator_digit_separator_action := RabbitPunctuatorMap.NormalizeDigitSeparatorAction(
            this.GetString(
                default_config,
                RabbitPunctuatorMap.DIGIT_SEPARATOR_ACTION_PATH,
                RabbitPunctuatorMap.DIGIT_SEPARATOR_ACTION_DEFAULT
            )
        )
        this.recognizer_use_space := this.GetBool(
            default_config,
            RabbitRecognizerPatterns.USE_SPACE_PATH,
            false
        )
        this.recognizer_patterns := this.LoadRecognizerPatterns(default_config)
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
        return RabbitBehaviorSettingsModel.ReadStringList(this.rime, config, path)
    }

    static ReadStringList(rime_api, config, path) {
        local iter, value
        local result := []
        if !(iter := rime_api.config_begin_list(config, path)) {
            return result
        }
        try {
            while rime_api.config_next(iter) {
                if rime_api.config_test_get_string(config, iter.path, &value) {
                    result.Push(value)
                }
            }
        } finally {
            rime_api.config_end(iter)
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

    LoadPunctuatorMaps(config) {
        local path, value, result := Map()
        for path in RabbitPunctuatorMap.PATHS {
            if RabbitConfigValue.Read(this.rime, config, path, &value) && value is Map {
                try {
                    result[path] := RabbitPunctuatorMap.Validate(value, path)
                    continue
                }
            }
            result[path] := Map()
        }
        return result
    }

    LoadRecognizerPatterns(config) {
        local value
        if !RabbitConfigValue.Read(this.rime, config, RabbitRecognizerPatterns.PATH, &value)
            || !(value is Map) {
            return Map()
        }
        try {
            return RabbitRecognizerPatterns.Validate(value)
        } catch {
            return Map()
        }
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
            language: this.language,
            show_tips: this.show_tips,
            show_tips_time: this.show_tips_time,
            suspend_hotkey: this.suspend_hotkey,
            send_by_clipboard_length: this.send_by_clipboard_length,
            global_ascii: this.global_ascii,
            fix_candidate_box: this.fix_candidate_box,
            use_legacy_candidate_box: this.use_legacy_candidate_box,
            bypass_password_fields: this.bypass_password_fields,
            good_old_caps_lock: this.good_old_caps_lock,
            switch_key: RabbitBehaviorSettingsModel.CloneValue(this.switch_key),
            page_size: this.page_size,
            alternative_select_labels: RabbitBehaviorSettingsModel.CloneValue(this.alternative_select_labels),
            alternative_select_keys: this.alternative_select_keys,
            page_down_cycle: this.page_down_cycle,
            bindings: RabbitBehaviorSettingsModel.CloneValue(this.bindings),
            punctuator_maps: RabbitBehaviorSettingsModel.CloneValue(this.punctuator_maps),
            punctuator_use_space: this.punctuator_use_space,
            punctuator_digit_separators: this.punctuator_digit_separators,
            punctuator_digit_separator_action: this.punctuator_digit_separator_action,
            recognizer_use_space: this.recognizer_use_space,
            recognizer_patterns: RabbitBehaviorSettingsModel.CloneValue(this.recognizer_patterns),
        }
    }

    GetBindings() {
        return RabbitBehaviorSettingsModel.CloneValue(this.bindings)
    }

    GetPunctuatorMaps() {
        return RabbitBehaviorSettingsModel.CloneValue(this.punctuator_maps)
    }

    GetRecognizerPatterns() {
        return RabbitBehaviorSettingsModel.CloneValue(this.recognizer_patterns)
    }

    Save(values) {
        local default_changed := this.HasDefaultChanges(values)
        local rabbit_changed := this.HasRabbitChanges(values)
        this.ValidateMenuValues(values)
        this.ValidatePunctuatorValues(values)
        this.ValidateRecognizerValues(values)
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

    GetDeploymentPlan(values) {
        local plan := RabbitDeploymentPlan()
        if this.HasRabbitChanges(values) {
            plan.RequireRabbitConfig()
        }
        if this.HasAsciiComposerChanges(values) {
            plan.RequireDefaultConfig()
        }
        if this.HasSchemaAffectingDefaultChanges(values) {
            plan.RequireWorkspace()
        }
        return plan
    }

    HasRabbitChanges(values) {
        local original := this.original_values
        return values.language != original.language
            || values.show_tips != original.show_tips
            || values.show_tips_time != original.show_tips_time
            || values.suspend_hotkey != original.suspend_hotkey
            || values.send_by_clipboard_length != original.send_by_clipboard_length
            || values.global_ascii != original.global_ascii
            || values.fix_candidate_box != original.fix_candidate_box
            || values.use_legacy_candidate_box != original.use_legacy_candidate_box
            || values.bypass_password_fields != original.bypass_password_fields
    }

    HasDefaultChanges(values) {
        return this.HasAsciiComposerChanges(values) || this.HasSchemaAffectingDefaultChanges(values)
    }

    HasAsciiComposerChanges(values) {
        local original := this.original_values
        return !RabbitBehaviorSettingsModel.ValuesEqual(values.switch_key, original.switch_key)
            || values.good_old_caps_lock != original.good_old_caps_lock
    }

    HasSchemaAffectingDefaultChanges(values) {
        local original := this.original_values
        return values.page_size != original.page_size
            || HasProp(values, "alternative_select_labels_reset") && values.alternative_select_labels_reset
            || !RabbitBehaviorSettingsModel.ValuesEqual(
                values.alternative_select_labels,
                original.alternative_select_labels
            )
            || values.alternative_select_keys != original.alternative_select_keys
            || values.page_down_cycle != original.page_down_cycle
            || !RabbitBehaviorSettingsModel.ValuesEqual(values.bindings, original.bindings)
            || this.HasPunctuatorChanges(values)
            || this.HasRecognizerChanges(values)
    }

    HasPunctuatorChanges(values) {
        local path, maps
        if values.punctuator_use_space != this.original_values.punctuator_use_space
            || values.punctuator_digit_separators != this.original_values.punctuator_digit_separators
            || values.punctuator_digit_separator_action != this.original_values.punctuator_digit_separator_action {
            return true
        }
        if !HasProp(values, "punctuator_maps") {
            return false
        }
        maps := values.punctuator_maps
        if !(maps is Map) {
            return true
        }
        if HasProp(values, "punctuator_reset_fields") && values.punctuator_reset_fields.Count {
            return true
        }
        for path in RabbitPunctuatorMap.PATHS {
            if !maps.Has(path) || !RabbitBehaviorSettingsModel.ValuesEqual(
                maps[path],
                this.original_values.punctuator_maps[path]
            ) {
                return true
            }
        }
        return false
    }

    HasRecognizerChanges(values) {
        if values.recognizer_use_space != this.original_values.recognizer_use_space {
            return true
        }
        if !HasProp(values, "recognizer_patterns") {
            return false
        }
        if !(values.recognizer_patterns is Map) {
            return true
        }
        if HasProp(values, "recognizer_reset_fields") && values.recognizer_reset_fields.Count {
            return true
        }
        return !RabbitBehaviorSettingsModel.ValuesEqual(
            values.recognizer_patterns,
            this.original_values.recognizer_patterns
        )
    }

    ValidatePunctuatorValues(values) {
        RabbitPunctuatorMap.ValidateDigitSeparators(values.punctuator_digit_separators)
        RabbitPunctuatorMap.ValidateDigitSeparatorAction(values.punctuator_digit_separator_action)
    }

    ValidateMenuValues(values) {
        RabbitMenuSettings.ValidateAlternativeSelectKeys(values.alternative_select_keys)
    }

    ValidateRecognizerValues(values) {
        if HasProp(values, "recognizer_patterns") {
            RabbitRecognizerPatterns.Validate(values.recognizer_patterns)
        }
    }

    SaveRabbitSettings(values) {
        if !this.api.load_settings(this.settings) {
            return false
        }
        if values.language != this.original_values.language
            && !this.api.customize_string(this.settings, "language", values.language) {
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
        if values.good_old_caps_lock != original.good_old_caps_lock
            && !this.api.customize_bool(
                this.default_settings,
                "ascii_composer/good_old_caps_lock",
                values.good_old_caps_lock
            ) {
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
            && !this.api.customize_int(this.default_settings, RabbitMenuSettings.PAGE_SIZE_PATH, values.page_size) {
            return false
        }
        if HasProp(values, "alternative_select_labels_reset") && values.alternative_select_labels_reset {
            if !this.ClearAlternativeSelectLabelsPatch() {
                return false
            }
        } else if !RabbitBehaviorSettingsModel.ValuesEqual(
                values.alternative_select_labels,
                original.alternative_select_labels
            ) && !this.CustomizeAlternativeSelectLabels(values.alternative_select_labels) {
            return false
        }
        if values.alternative_select_keys != original.alternative_select_keys
            && !this.api.customize_string(
                this.default_settings,
                RabbitMenuSettings.ALTERNATIVE_SELECT_KEYS_PATH,
                values.alternative_select_keys
            ) {
            return false
        }
        if values.page_down_cycle != original.page_down_cycle
            && !this.api.customize_bool(
                this.default_settings,
                RabbitMenuSettings.PAGE_DOWN_CYCLE_PATH,
                values.page_down_cycle
            ) {
            return false
        }
        if !RabbitBehaviorSettingsModel.ValuesEqual(values.bindings, original.bindings)
            && !this.CustomizeBindings(values.bindings, original.bindings.Length) {
            return false
        }
        if values.punctuator_use_space != original.punctuator_use_space
            && !this.api.customize_bool(
                this.default_settings,
                RabbitPunctuatorMap.USE_SPACE_PATH,
                values.punctuator_use_space
            ) {
            return false
        }
        if values.punctuator_digit_separators != original.punctuator_digit_separators
            && !this.api.customize_string(
                this.default_settings,
                RabbitPunctuatorMap.DIGIT_SEPARATORS_PATH,
                values.punctuator_digit_separators
            ) {
            return false
        }
        if values.punctuator_digit_separator_action != original.punctuator_digit_separator_action
            && !this.api.customize_string(
                this.default_settings,
                RabbitPunctuatorMap.DIGIT_SEPARATOR_ACTION_PATH,
                values.punctuator_digit_separator_action
            ) {
            return false
        }
        if HasProp(values, "punctuator_maps") && this.HasPunctuatorChanges(values) {
            for path in RabbitPunctuatorMap.PATHS {
                if HasProp(values, "punctuator_reset_fields") && values.punctuator_reset_fields.Has(path) {
                    if !this.ClearPunctuatorMapPatch(path) {
                        return false
                    }
                } else if !RabbitBehaviorSettingsModel.ValuesEqual(
                    values.punctuator_maps[path],
                    original.punctuator_maps[path]
                ) && !this.CustomizePunctuatorMap(path, values.punctuator_maps[path]) {
                    return false
                }
            }
        }
        if values.recognizer_use_space != original.recognizer_use_space
            && !this.api.customize_bool(
                this.default_settings,
                RabbitRecognizerPatterns.USE_SPACE_PATH,
                values.recognizer_use_space
            ) {
            return false
        }
        if HasProp(values, "recognizer_patterns") && this.HasRecognizerChanges(values) {
            if HasProp(values, "recognizer_reset_fields") && values.recognizer_reset_fields.Has(
                RabbitRecognizerPatterns.PATH
            ) {
                if !this.ClearRecognizerPatternsPatch() {
                    return false
                }
            } else if !RabbitBehaviorSettingsModel.ValuesEqual(
                values.recognizer_patterns,
                original.recognizer_patterns
            ) && !this.CustomizeRecognizerPatterns(values.recognizer_patterns) {
                return false
            }
        }
        return !!this.api.save_settings(this.default_settings)
    }

    CustomizePunctuatorMap(path, value) {
        if !this.ClearPunctuatorMapPatch(path) {
            return false
        }
        return this.CustomizeYamlItem(this.default_settings, path, value)
    }

    CustomizeAlternativeSelectLabels(value) {
        if !this.ClearAlternativeSelectLabelsPatch() {
            return false
        }
        return this.CustomizeYamlItem(
            this.default_settings,
            RabbitMenuSettings.ALTERNATIVE_SELECT_LABELS_PATH,
            value
        )
    }

    ClearAlternativeSelectLabelsPatch() {
        local key, keys := Map(RabbitMenuSettings.ALTERNATIVE_SELECT_LABELS_PATH, true)
        for key in this.GetExistingAlternativeSelectLabelsPatchKeys() {
            keys[key] := true
        }
        for key in keys {
            if !this.api.customize_item(this.default_settings, key, 0) {
                return false
            }
        }
        return true
    }

    GetExistingAlternativeSelectLabelsPatchKeys() {
        local config := 0, iter := 0, key, result := []
        if !HasMethod(this.rime, "user_config_open")
            || !(config := this.rime.user_config_open("default.custom")) {
            return result
        }
        try {
            if !(iter := this.rime.config_begin_map(config, "patch")) {
                return result
            }
            try {
                while this.rime.config_next(iter) {
                    key := iter.key
                    if key = RabbitMenuSettings.ALTERNATIVE_SELECT_LABELS_PATH
                        || SubStr(key, 1, StrLen(RabbitMenuSettings.ALTERNATIVE_SELECT_LABELS_PATH) + 1)
                            = RabbitMenuSettings.ALTERNATIVE_SELECT_LABELS_PATH . "/" {
                        result.Push(key)
                    }
                }
            } finally {
                this.rime.config_end(iter)
            }
        } finally {
            this.rime.config_close(config)
        }
        return result
    }

    ClearPunctuatorMapPatch(path) {
        local key, keys := Map(path, true)
        for key in this.GetExistingPunctuatorMapPatchKeys(path) {
            keys[key] := true
        }
        for key in keys {
            if !this.api.customize_item(this.default_settings, key, 0) {
                return false
            }
        }
        return true
    }

    GetExistingPunctuatorMapPatchKeys(path) {
        local config := 0, iter := 0, key, result := []
        if !HasMethod(this.rime, "user_config_open")
            || !(config := this.rime.user_config_open("default.custom")) {
            return result
        }
        try {
            if !(iter := this.rime.config_begin_map(config, "patch")) {
                return result
            }
            try {
                while this.rime.config_next(iter) {
                    key := iter.key
                    if key = path || SubStr(key, 1, StrLen(path) + 1) = path . "/" {
                        result.Push(key)
                    }
                }
            } finally {
                this.rime.config_end(iter)
            }
        } finally {
            this.rime.config_close(config)
        }
        return result
    }

    CustomizeRecognizerPatterns(value) {
        if !this.ClearRecognizerPatternsPatch() {
            return false
        }
        return this.CustomizeYamlItem(this.default_settings, RabbitRecognizerPatterns.PATH, value)
    }

    ClearRecognizerPatternsPatch() {
        local key, keys := Map(RabbitRecognizerPatterns.PATH, true)
        for key in this.GetExistingRecognizerPatternsPatchKeys() {
            keys[key] := true
        }
        for key in keys {
            if !this.api.customize_item(this.default_settings, key, 0) {
                return false
            }
        }
        return true
    }

    GetExistingRecognizerPatternsPatchKeys() {
        local config := 0, iter := 0, key, result := []
        if !HasMethod(this.rime, "user_config_open")
            || !(config := this.rime.user_config_open("default.custom")) {
            return result
        }
        try {
            if !(iter := this.rime.config_begin_map(config, "patch")) {
                return result
            }
            try {
                while this.rime.config_next(iter) {
                    key := iter.key
                    if key = RabbitRecognizerPatterns.PATH
                        || SubStr(key, 1, StrLen(RabbitRecognizerPatterns.PATH) + 1)
                            = RabbitRecognizerPatterns.PATH . "/" {
                        result.Push(key)
                    }
                }
            } finally {
                this.rime.config_end(iter)
            }
        } finally {
            this.rime.config_close(config)
        }
        return result
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
        this.language := values.language
        this.show_tips := values.show_tips
        this.show_tips_time := values.show_tips_time
        this.suspend_hotkey := values.suspend_hotkey
        this.send_by_clipboard_length := values.send_by_clipboard_length
        this.global_ascii := values.global_ascii
        this.fix_candidate_box := values.fix_candidate_box
        this.use_legacy_candidate_box := values.use_legacy_candidate_box
        this.bypass_password_fields := values.bypass_password_fields
        this.good_old_caps_lock := values.good_old_caps_lock
        this.switch_key := RabbitBehaviorSettingsModel.CloneValue(values.switch_key)
        this.page_size := values.page_size
        this.alternative_select_labels := RabbitBehaviorSettingsModel.CloneValue(values.alternative_select_labels)
        this.alternative_select_keys := values.alternative_select_keys
        this.page_down_cycle := values.page_down_cycle
        this.bindings := RabbitBehaviorSettingsModel.CloneValue(values.bindings)
        if HasProp(values, "punctuator_maps") {
            this.punctuator_maps := RabbitBehaviorSettingsModel.CloneValue(values.punctuator_maps)
        }
        this.punctuator_use_space := values.punctuator_use_space
        this.punctuator_digit_separators := values.punctuator_digit_separators
        this.punctuator_digit_separator_action := values.punctuator_digit_separator_action
        this.recognizer_use_space := values.recognizer_use_space
        if HasProp(values, "recognizer_patterns") {
            this.recognizer_patterns := RabbitBehaviorSettingsModel.CloneValue(values.recognizer_patterns)
        }
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
