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
#Include RabbitPunctuatorMap.ahk

#Include RabbitI18n.ahk

class RabbitSchemaSettingsManifest {
    static FALLBACK_FILE := "schema.rabbit-fallback.ini"
    static DEFAULT_LIST_ROWS := 3
    static MIN_LIST_ROWS := 1
    static MAX_LIST_ROWS := 10

    static Load(schema_id, user_data_dir := "", shared_data_dir := "") {
        local path
        this.ValidateSchemaId(schema_id)
        user_data_dir := user_data_dir ? user_data_dir : RabbitUserDataPath()
        shared_data_dir := shared_data_dir ? shared_data_dir : RabbitSharedDataPath()
        for path in [
            user_data_dir . "\" . schema_id . ".rabbit.ini",
            shared_data_dir . "\" . schema_id . ".rabbit.ini",
            shared_data_dir . "\" . this.FALLBACK_FILE,
        ] {
            if FileExist(path) {
                return this.Parse(path)
            }
        }
        throw Error(RabbitI18n.Text("models.schema_settings_manifest_missing"))
    }

    static Parse(path) {
        local fields := []
        local groups := [], groups_by_id := Map()
        local sections := Map()
        local section_order := []
        local current_section := ""
        local field_id, group_id, match, name, properties, line, key, value
        local has_explicit_groups := false
        local source
        try {
            source := FileRead(path, "UTF-8")
        } catch as err {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        for line in StrSplit(source, "`n", "`r") {
            line := Trim(line)
            if !line || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#" {
                continue
            }
            if RegExMatch(line, "^\[([^]]+)\]$", &match) {
                current_section := Trim(match[1])
                if !current_section || sections.Has(current_section) {
                    throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
                }
                sections[current_section] := Map()
                section_order.Push(current_section)
                continue
            }
            if !current_section || !RegExMatch(line, "^([^=]+)=(.*)$", &match) {
                throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
            }
            key := Trim(match[1])
            value := Trim(match[2])
            if !key || sections[current_section].Has(key) {
                throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
            }
            sections[current_section][key] := value
        }
        if !sections.Has("meta") || sections["meta"].Get("format", "") != "1" {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        for name in section_order {
            if !RegExMatch(name, "^group\.([A-Za-z0-9_-]+)$", &match) {
                continue
            }
            group_id := match[1]
            groups.Push(this.ParseGroup(group_id, sections[name], path))
            groups_by_id[group_id] := groups[groups.Length]
            has_explicit_groups := true
        }
        if !has_explicit_groups {
            group_id := "general"
            groups.Push({
                id: group_id,
                label: RabbitI18n.Text("controls.scheme_settings"),
                description: "",
            })
            groups_by_id[group_id] := groups[groups.Length]
        }
        for name in section_order {
            if !RegExMatch(name, "^field\.([A-Za-z0-9_-]+)$", &match) {
                continue
            }
            field_id := match[1]
            properties := sections[name]
            group_id := properties.Get("group", "")
            if !group_id && !has_explicit_groups {
                group_id := "general"
            }
            if !groups_by_id.Has(group_id) {
                throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
            }
            fields.Push(this.ParseField(field_id, group_id, properties, path))
        }
        if !fields.Length {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        return {
            file_path: path,
            title: sections["meta"].Get("title", RabbitI18n.Text("controls.scheme_settings")),
            description: sections["meta"].Get("description", ""),
            groups: groups,
            fields: fields,
        }
    }

    static ParseGroup(group_id, properties, path) {
        if !properties.Has("label") || !properties["label"] {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        return {
            id: group_id,
            label: properties["label"],
            description: properties.Get("description", ""),
        }
    }

    static ParseField(field_id, group_id, properties, path) {
        local type := StrLower(properties.Get("type", ""))
        local minimum := "", maximum := "", options := []
        local rows := ""
        local option, seen := Map()
        local has_default := properties.Has("default"), default_value := ""
        if !properties.Has("path") || !properties.Has("label") || !type
            || !this.IsSafeConfigPath(properties["path"]) {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        if type != "boolean" && type != "integer" && type != "number" && type != "string" && type != "enum"
            && type != "list" && type != "key_binding_list" && type != "punctuator_map" {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        if type = "key_binding_list" && properties["path"] != "key_binder/bindings" {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        if type = "punctuator_map" && !RabbitPunctuatorMap.IsEditablePath(properties["path"]) {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        if type = "list" || type = "key_binding_list" {
            rows := this.ParseListRows(properties)
        }
        if type = "integer" || type = "number" {
            minimum := this.ParseNumber(properties, "min", path)
            maximum := this.ParseNumber(properties, "max", path)
            if minimum != "" && maximum != "" && minimum > maximum {
                throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
            }
        }
        if type = "enum" {
            if !properties.Has("options") {
                throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
            }
            for option in StrSplit(properties["options"], "|") {
                option := Trim(option)
                if !option || seen.Has(option) {
                    throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
                }
                seen[option] := true
                options.Push(option)
            }
        }
        if has_default {
            default_value := this.ParseDefault(properties["default"], type, options, path)
        }
        return {
            id: field_id,
            group: group_id,
            path: properties["path"],
            type: type,
            label: properties["label"],
            description: properties.Get("description", ""),
            min: minimum,
            max: maximum,
            options: options,
            rows: rows,
            has_default: has_default,
            default: default_value,
        }
    }

    static ParseDefault(value, type, options, path) {
        local option
        switch type {
            case "boolean":
                if value != "true" && value != "false" {
                    throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
                }
                return value = "true"
            case "integer":
                if !RegExMatch(value, "^-?\d+$") {
                    throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
                }
                return Integer(value)
            case "number":
                if !RegExMatch(value, "^-?(?:\d+(?:\.\d*)?|\.\d+)$") {
                    throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
                }
                return Number(value)
            case "enum":
                for option in options {
                    if option = value {
                        return value
                    }
                }
            case "string":
                return value
        }
        throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
    }

    static ParseListRows(properties) {
        local rows, value
        if !properties.Has("rows") {
            return this.DEFAULT_LIST_ROWS
        }
        value := Trim(properties["rows"])
        if !RegExMatch(value, "^\d+$") {
            return this.DEFAULT_LIST_ROWS
        }
        try {
            rows := Integer(value)
        } catch {
            return this.DEFAULT_LIST_ROWS
        }
        return rows >= this.MIN_LIST_ROWS && rows <= this.MAX_LIST_ROWS ? rows : this.DEFAULT_LIST_ROWS
    }

    static ParseNumber(properties, key, path) {
        local value
        if !properties.Has(key) {
            return ""
        }
        value := properties[key]
        if !RegExMatch(value, "^-?(?:\d+(?:\.\d*)?|\.\d+)$") {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map("file", path)))
        }
        return Number(value)
    }

    static IsSafeConfigPath(path) {
        return RegExMatch(path, "^[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*$")
    }

    static ValidateSchemaId(schema_id) {
        if !RegExMatch(schema_id, "^[A-Za-z0-9][A-Za-z0-9_.-]*$") {
            throw ValueError(RabbitI18n.Text("models.schema_settings_invalid_id"))
        }
    }
}
