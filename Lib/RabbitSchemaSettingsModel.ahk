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
#Include RabbitConfigValue.ahk
#Include RabbitEngineLists.ahk
#Include RabbitFileField.ahk
#Include RabbitMenuSettings.ahk
#Include RabbitPunctuatorMap.ahk
#Include RabbitRecognizerPatterns.ahk
#Include RabbitSchemaSettingsManifest.ahk
#Include RabbitSwitchList.ahk

#Include RabbitI18n.ahk

class RabbitSchemaSettingsModel {
    __New(rime_api, levers_api, schema_id, manifest := 0) {
        if !rime_api || !levers_api {
            throw Error(RabbitI18n.Text("frontend.settings_api"))
        }
        RabbitSchemaSettingsManifest.ValidateSchemaId(schema_id)
        this.rime := rime_api
        this.api := levers_api
        this.schema_id := schema_id
        this.manifest := manifest ? manifest : RabbitSchemaSettingsManifest.Load(schema_id)
        this.values := Map()
        this.last_save_changed := false
    }

    Load() {
        local config := this.rime.schema_open(this.schema_id)
        if !config {
            return false
        }
        try {
            this.values := Map()
            for field in this.manifest.fields {
                this.values[field.id] := this.ReadField(config, field)
            }
            this.values := RabbitConfigValue.Clone(this.values)
            return true
        } finally {
            this.rime.config_close(config)
        }
    }

    ReadField(config, field) {
        local value
        switch field.type {
            case "boolean":
                if this.rime.config_test_get_bool(config, field.path, &value) {
                    return !!value
                }
            case "integer":
                if this.rime.config_test_get_int(config, field.path, &value) {
                    return value
                }
            case "number":
                if this.rime.config_test_get_double(config, field.path, &value) {
                    return value
                }
            case "file":
                if this.rime.config_test_get_string(config, field.path, &value) {
                    if RabbitFileField.IsValidValue(value) {
                        return value
                    }
                    throw Error(RabbitI18n.Text("models.schema_settings_read", Map("schema", this.schema_id)))
                }
            case "enum":
                if this.rime.config_test_get_string(config, field.path, &value) {
                    return field.path = RabbitPunctuatorMap.DIGIT_SEPARATOR_ACTION_PATH
                        ? RabbitPunctuatorMap.NormalizeDigitSeparatorAction(value) : value
                }
            case "list", "key_binding_list":
                return this.ReadListField(config, field)
            case "punctuator_map":
                return RabbitPunctuatorMap.Read(this.rime, config, field.path)
            case "recognizer_patterns":
                return RabbitRecognizerPatterns.Read(this.rime, config, field.path)
            case "switch_list":
                return RabbitSwitchList.Read(this.rime, config, field.path)
            case "engine_lists":
                return this.ReadEngineLists(config)
            default:
                if this.rime.config_test_get_string(config, field.path, &value) {
                    return value
                }
        }
        if HasProp(field, "has_default") && field.has_default {
            return RabbitConfigValue.Clone(field.default)
        }
        throw Error(RabbitI18n.Text("models.schema_settings_read", Map("schema", this.schema_id)))
    }

    ReadListField(config, field) {
        local item_config, item_value, iter
        local result := []
        if !(iter := this.rime.config_begin_list(config, field.path)) {
            if HasProp(field, "has_default") && field.has_default {
                return RabbitConfigValue.Clone(field.default)
            }
            throw Error(RabbitI18n.Text("models.schema_settings_read", Map("schema", this.schema_id)))
        }
        try {
            while this.rime.config_next(iter) {
                if !(item_config := this.rime.config_get_item(config, iter.path)) {
                    throw Error(RabbitI18n.Text("models.schema_settings_read", Map("schema", this.schema_id)))
                }
                try {
                    if !RabbitConfigValue.Read(this.rime, item_config, "/", &item_value) {
                        throw Error(RabbitI18n.Text("models.schema_settings_read", Map("schema", this.schema_id)))
                    }
                    result.Push(this.NormalizeListItem(field, item_value))
                } finally {
                    this.rime.config_close(item_config)
                }
            }
        } finally {
            this.rime.config_end(iter)
        }
        return result
    }

    NormalizeValues(values) {
        local normalized := Map(), field
        if !(values is Map) {
            throw TypeError("Expected a map of schema setting values.")
        }
        for field in this.manifest.fields {
            if !values.Has(field.id) {
                throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
            }
            normalized[field.id] := this.NormalizeFieldValue(field, values[field.id])
        }
        return normalized
    }

    NormalizeFieldValue(field, value) {
        local item, normalized
        switch field.type {
            case "boolean":
                return !!value
            case "integer":
                value := Trim(String(value))
                if !RegExMatch(value, "^-?\d+$") {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
                normalized := Integer(value)
            case "number":
                value := Trim(String(value))
                if !RegExMatch(value, "^-?(?:\d+(?:\.\d*)?|\.\d+)$") {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
                normalized := Number(value)
            case "enum":
                normalized := Trim(String(value))
                if field.path = RabbitPunctuatorMap.DIGIT_SEPARATOR_ACTION_PATH {
                    normalized := RabbitPunctuatorMap.ValidateDigitSeparatorAction(normalized)
                }
                if !this.HasOption(field.options, normalized) {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
            case "list", "key_binding_list":
                if !(value is Array) {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
                normalized := []
                for item in value {
                    normalized.Push(this.NormalizeListItem(field, item))
                }
            case "punctuator_map":
                try {
                    normalized := RabbitPunctuatorMap.Validate(value, field.path)
                } catch {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
            case "recognizer_patterns":
                try {
                    normalized := RabbitRecognizerPatterns.Validate(value)
                } catch {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
            case "switch_list":
                try {
                    normalized := RabbitSwitchList.Validate(value)
                } catch {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
            case "engine_lists":
                try {
                    normalized := RabbitEngineLists.Validate(value)
                } catch {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
            case "file":
                normalized := String(value)
                if !RabbitFileField.IsValidValue(normalized) {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
            case "string":
                normalized := field.path = RabbitMenuSettings.ALTERNATIVE_SELECT_KEYS_PATH
                    ? RabbitMenuSettings.ValidateAlternativeSelectKeys(String(value))
                    : Trim(String(value))
                if field.path = RabbitPunctuatorMap.DIGIT_SEPARATORS_PATH {
                    normalized := RabbitPunctuatorMap.ValidateDigitSeparators(normalized)
                }
            default:
                normalized := String(value)
        }
        if field.min != "" && normalized < field.min || field.max != "" && normalized > field.max {
            throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
        }
        return normalized
    }

    NormalizeListItem(field, value) {
        if field.type = "list" {
            if value is Map || value is Array || Type(value) != "String" {
                throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
            }
            return value
        }
        if !(value is Map) {
            throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
        }
        return RabbitConfigValue.Clone(value)
    }

    HasOption(options, value) {
        local option
        for option in options {
            if option = value {
                return true
            }
        }
        return false
    }

    HasChanges(values, reset_fields := 0) {
        local normalized := this.NormalizeValues(values)
        local resets := this.NormalizeResetFields(reset_fields)
        return this.HasNormalizedChanges(normalized, resets)
    }

    HasNormalizedChanges(normalized, reset_fields := 0) {
        local field
        for field in this.manifest.fields {
            if reset_fields.Has(field.id) || !this.values.Has(field.id)
                || !RabbitConfigValue.ValuesEqual(normalized[field.id], this.values[field.id]) {
                return true
            }
        }
        return false
    }

    NormalizeResetFields(reset_fields) {
        local field, matched, reset_id, reset_lists, resets := Map()
        if !reset_fields {
            return resets
        }
        if !(reset_fields is Map) {
            throw TypeError("Expected a map of schema setting resets.")
        }
        for reset_id, value in reset_fields {
            if !value {
                continue
            }
            matched := 0
            for field in this.manifest.fields {
                if field.id = reset_id {
                    matched := field
                    break
                }
            }
            if !matched || matched.type != "list" && matched.type != "key_binding_list"
                && matched.type != "punctuator_map" && matched.type != "recognizer_patterns"
                && matched.type != "switch_list" && matched.type != "engine_lists" {
                throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", reset_id)))
            }
            if matched.type = "engine_lists" {
                reset_lists := this.NormalizeEngineListResets(value)
                if reset_lists.Count {
                    resets[reset_id] := reset_lists
                }
                continue
            }
            resets[reset_id] := true
        }
        return resets
    }

    NormalizeEngineListResets(value) {
        local name, reset, resets := Map()
        if !(value is Map) {
            if value = true {
                for name in RabbitEngineLists.NAMES {
                    resets[name] := true
                }
                return resets
            }
            throw TypeError("Expected a map of engine-list resets.")
        }
        for name, reset in value {
            if !reset {
                continue
            }
            RabbitEngineLists.ListPath(name)
            resets[name] := true
        }
        return resets
    }

    Save(values, reset_fields := 0) {
        local field, field_resets, normalized := this.NormalizeValues(values)
        local resets := this.NormalizeResetFields(reset_fields)
        local settings := 0
        this.last_save_changed := this.HasNormalizedChanges(normalized, resets)
        if !this.last_save_changed {
            return true
        }
        this.EnsureCustomFile()
        try {
            settings := this.api.custom_settings_init(this.schema_id . ".schema", RABBIT_CUSTOMIZATION_GENERATOR_ID)
            if !settings || !this.api.load_settings(settings) {
                return false
            }
            for field in this.manifest.fields {
                if field.type = "engine_lists" {
                    field_resets := resets.Has(field.id) ? resets[field.id] : 0
                    if !this.SaveEngineListsField(settings, field, normalized[field.id], field_resets) {
                        return false
                    }
                    continue
                }
                if resets.Has(field.id) {
                    if !this.ResetField(settings, field) {
                        return false
                    }
                } else if !RabbitConfigValue.ValuesEqual(normalized[field.id], this.values[field.id])
                    && !this.CustomizeField(settings, field, normalized[field.id]) {
                    return false
                }
            }
            if !this.api.save_settings(settings) {
                return false
            }
            this.values := RabbitConfigValue.Clone(normalized)
            return true
        } finally {
            if settings {
                this.api.custom_settings_destroy(settings)
            }
        }
    }

    CustomizeField(settings, field, value) {
        switch field.type {
            case "boolean": return !!this.api.customize_bool(settings, field.path, value)
            case "integer": return !!this.api.customize_int(settings, field.path, value)
            case "number": return !!this.api.customize_double(settings, field.path, value)
            case "list", "key_binding_list": return this.CustomizeListField(settings, field, value)
            case "punctuator_map": return this.CustomizePunctuatorMapField(settings, field, value)
            case "recognizer_patterns": return this.CustomizeRecognizerPatternsField(settings, field, value)
            case "switch_list": return this.CustomizeListField(settings, field, value)
            case "engine_lists": return this.CustomizeEngineListsField(settings, value)
            default: return !!this.api.customize_string(settings, field.path, value)
        }
    }

    CustomizeListField(settings, field, value) {
        if !this.ClearListPatchOperations(settings, field.path) {
            return false
        }
        return this.CustomizeYamlItem(settings, field.path, value)
    }

    ResetListField(settings, field) {
        return this.ClearListPatchOperations(settings, field.path, true)
    }

    CustomizeEngineListsField(settings, value) {
        local name
        for name in RabbitEngineLists.NAMES {
            if !this.CustomizeEngineListField(settings, name, value[name]) {
                return false
            }
        }
        return true
    }

    CustomizeEngineListField(settings, name, value) {
        local path := RabbitEngineLists.ListPath(name)
        return this.ClearListPatchOperations(settings, path) && this.CustomizeYamlItem(settings, path, value)
    }

    ResetEngineListsField(settings, reset_lists := 0) {
        local name
        for name in RabbitEngineLists.NAMES {
            if reset_lists is Map && !reset_lists.Has(name) {
                continue
            }
            if !this.ClearListPatchOperations(settings, RabbitEngineLists.ListPath(name), true) {
                return false
            }
        }
        return true
    }

    SaveEngineListsField(settings, field, value, reset_lists := 0) {
        local current := this.values.Has(field.id) ? this.values[field.id] : 0
        local name
        for name in RabbitEngineLists.NAMES {
            if reset_lists is Map && reset_lists.Has(name) {
                if !this.ClearListPatchOperations(settings, RabbitEngineLists.ListPath(name), true) {
                    return false
                }
            } else if !current || !RabbitConfigValue.ValuesEqual(value[name], current[name]) {
                if !this.CustomizeEngineListField(settings, name, value[name]) {
                    return false
                }
            }
        }
        return true
    }

    ResetField(settings, field) {
        return field.type = "punctuator_map" ? this.ResetPunctuatorMapField(settings, field)
            : field.type = "recognizer_patterns" ? this.ResetRecognizerPatternsField(settings, field)
            : field.type = "engine_lists" ? this.ResetEngineListsField(settings)
            : this.ResetListField(settings, field)
    }

    CustomizePunctuatorMapField(settings, field, value) {
        if !this.ClearPunctuatorMapPatchOperations(settings, field.path) {
            return false
        }
        return this.CustomizeYamlItem(settings, field.path, value)
    }

    ResetPunctuatorMapField(settings, field) {
        return this.ClearPunctuatorMapPatchOperations(settings, field.path, true)
    }

    CustomizeRecognizerPatternsField(settings, field, value) {
        if !this.ClearRecognizerPatternsPatchOperations(settings, field.path) {
            return false
        }
        return this.CustomizeYamlItem(settings, field.path, value)
    }

    ResetRecognizerPatternsField(settings, field) {
        return this.ClearRecognizerPatternsPatchOperations(settings, field.path, true)
    }

    ClearRecognizerPatternsPatchOperations(settings, path, reset_value := false) {
        local key, keys := Map(path, true)
        if !reset_value {
            ; Writing the whole map still owns the exact path and all nested patches.
            keys[path] := true
        }
        for key in this.GetExistingRecognizerPatternsPatchOperations(path) {
            keys[key] := true
        }
        for key in keys {
            if !this.api.customize_item(settings, key, 0) {
                return false
            }
        }
        return true
    }

    GetExistingRecognizerPatternsPatchOperations(path) {
        local config := 0, iter := 0, key
        local result := []
        if !HasMethod(this.rime, "user_config_open")
            || !(config := this.rime.user_config_open(this.schema_id . ".custom")) {
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

    ReadEngineLists(config) {
        local field, name, result := Map()
        for name in RabbitEngineLists.NAMES {
            field := {
                type: "list",
                path: RabbitEngineLists.ListPath(name),
                label: name,
                has_default: false,
            }
            result[name] := this.ReadListField(config, field)
        }
        return RabbitEngineLists.Validate(result)
    }

    ClearPunctuatorMapPatchOperations(settings, path, reset_value := false) {
        local key, keys := Map(path, true)
        if !reset_value {
            ; Writing the whole map still owns the exact path and all nested patches.
            keys[path] := true
        }
        for key in this.GetExistingPunctuatorMapPatchOperations(path) {
            keys[key] := true
        }
        for key in keys {
            if !this.api.customize_item(settings, key, 0) {
                return false
            }
        }
        return true
    }

    GetExistingPunctuatorMapPatchOperations(path) {
        local config := 0, iter := 0, key
        local result := []
        if !HasMethod(this.rime, "user_config_open")
            || !(config := this.rime.user_config_open(this.schema_id . ".custom")) {
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

    ClearListPatchOperations(settings, path, reset_value := false) {
        local key, keys := Map(path . "/+", true, path . "/-", true)
        if reset_value {
            keys[path] := true
        }
        for key in this.GetExistingListPatchOperations(path) {
            keys[key] := true
        }
        for key in keys {
            if !this.api.customize_item(settings, key, 0) {
                return false
            }
        }
        return true
    }

    GetExistingListPatchOperations(path) {
        local config := 0, iter := 0, key
        local result := []
        if !HasMethod(this.rime, "user_config_open")
            || !(config := this.rime.user_config_open(this.schema_id . ".custom")) {
            return result
        }
        try {
            if !(iter := this.rime.config_begin_map(config, "patch")) {
                return result
            }
            try {
                while this.rime.config_next(iter) {
                    key := iter.key
                    if this.IsListPatchOperation(key, path) {
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

    IsListPatchOperation(key, path) {
        local operation
        if SubStr(key, 1, StrLen(path) + 1) != path . "/" {
            return false
        }
        operation := SubStr(key, StrLen(path) + 2)
        return operation = "+" || operation = "-" || SubStr(operation, 1, 1) = "@"
    }

    CustomizeYamlItem(settings, key, value) {
        local config := 0
        if !(config := this.rime.config_load_string(RabbitConfigValue.ToYaml(value))) {
            return false
        }
        try {
            return !!this.api.customize_item(settings, key, config)
        } finally {
            this.rime.config_close(config)
        }
    }

    EnsureCustomFile() {
        local directory := RabbitUserDataPath(), path
        if !DirExist(directory) {
            DirCreate(directory)
        }
        path := directory . "\" . this.schema_id . ".custom.yaml"
        if !FileExist(path) {
            FileAppend("patch: {}`n", path, "UTF-8")
        }
    }
}
