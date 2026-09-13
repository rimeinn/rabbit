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
#Include RabbitSchemaSettingsManifest.ahk

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
            default:
                if this.rime.config_test_get_string(config, field.path, &value) {
                    return value
                }
        }
        throw Error(RabbitI18n.Text("models.schema_settings_read", Map("schema", this.schema_id)))
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
        local normalized
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
                if !this.HasOption(field.options, normalized) {
                    throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
                }
            default:
                normalized := String(value)
        }
        if field.min != "" && normalized < field.min || field.max != "" && normalized > field.max {
            throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map("field", field.label)))
        }
        return normalized
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

    Save(values) {
        local field, normalized := this.NormalizeValues(values), settings := 0
        this.EnsureCustomFile()
        try {
            settings := this.api.custom_settings_init(this.schema_id . ".schema", RABBIT_CUSTOMIZATION_GENERATOR_ID)
            if !settings || !this.api.load_settings(settings) {
                return false
            }
            for field in this.manifest.fields {
                if !this.CustomizeField(settings, field, normalized[field.id]) {
                    return false
                }
            }
            if !this.api.save_settings(settings) {
                return false
            }
            this.values := normalized
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
            default: return !!this.api.customize_string(settings, field.path, value)
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
