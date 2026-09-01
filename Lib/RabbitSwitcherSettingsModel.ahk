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

class RabbitSwitcherSettingsModel {
    __New(levers_api, rime_api) {
        this.api := levers_api
        this.rime := rime_api
        this.settings := 0
        this.items := []
        this.hotkeys := ""
        this.caption := ":-)"
        this.save_options := []
        this.fold_options := false
        this.abbreviate_options := false
        this.option_list_prefix := ""
        this.option_list_suffix := ""
        this.option_list_separator := " "
        this.fix_schema_list_order := false
        this.original_values := 0
        this.disposed := false

        try {
            this.settings := this.api.switcher_settings_init()
            if !this.settings || !this.Load() {
                throw Error("未能读取输入方案与方案选单设置。")
            }
        } catch {
            this.Dispose()
            throw
        }
    }

    Load() {
        local available := 0
        local selected := 0
        local available_items := Map()
        local available_info, config, info, schema_id, selected_item
        local selected_ids := Map()
        if !this.api.load_settings(this.settings) {
            return false
        }
        if !(config := this.api.settings_get_config(this.settings)) {
            return false
        }

        try {
            available := this.api.get_available_schema_list(this.settings)
            selected := this.api.get_selected_schema_list(this.settings)
            if !available || !selected {
                return false
            }

            Loop available.size {
                info := this.CopySchemaInfo(available.list[A_Index])
                available_items[info.id] := info
            }

            this.items := []
            Loop selected.size {
                selected_item := selected.list[A_Index]
                schema_id := selected_item.schema_id
                if selected_ids.Has(schema_id) {
                    continue
                }
                selected_ids[schema_id] := true
                if available_items.Has(schema_id) {
                    info := available_items[schema_id]
                } else {
                    info := {
                        id: schema_id,
                        name: selected_item.name,
                        author: "",
                        description: "",
                        file_path: "",
                    }
                }
                this.items.Push(this.MakeSchemaItem(info, true))
            }

            for schema_id, available_info in available_items {
                if !selected_ids.Has(schema_id) {
                    this.items.Push(this.MakeSchemaItem(available_info, false))
                }
            }
            this.hotkeys := this.api.get_hotkeys(this.settings)
            this.caption := this.GetString(config, "switcher/caption", ":-)")
            this.save_options := this.ReadStringList(config, "switcher/save_options")
            this.fold_options := this.GetBool(config, "switcher/fold_options", false)
            this.abbreviate_options := this.GetBool(config, "switcher/abbreviate_options", false)
            this.option_list_prefix := this.GetString(config, "switcher/option_list_prefix", "")
            this.option_list_suffix := this.GetString(config, "switcher/option_list_suffix", "")
            this.option_list_separator := this.GetString(config, "switcher/option_list_separator", " ")
            this.fix_schema_list_order := this.GetBool(config, "switcher/fix_schema_list_order", false)
            this.original_values := this.GetCurrentValues()
            return true
        } finally {
            if selected {
                this.api.schema_list_destroy(selected)
            }
            if available {
                this.api.schema_list_destroy(available)
            }
        }
    }

    MakeSchemaItem(info, selected) {
        return {
            id: info.id,
            name: info.name,
            author: info.author,
            description: info.description,
            file_path: HasProp(info, "file_path") ? info.file_path : "",
            selected: selected,
        }
    }

    CopySchemaInfo(item) {
        local info := RimeSchemaInfo(item)
        return {
            id: this.api.get_schema_id(info),
            name: this.api.get_schema_name(info),
            author: this.api.get_schema_author(info),
            description: this.api.get_schema_description(info),
            file_path: this.api.get_schema_file_path(info),
        }
    }

    GetBool(config, key, fallback) {
        local value
        return this.rime.config_test_get_bool(config, key, &value) ? !!value : fallback
    }

    GetString(config, key, fallback) {
        local value
        return this.rime.config_test_get_string(config, key, &value) ? value : fallback
    }

    ReadStringList(config, path) {
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

    GetCurrentValues() {
        local item
        local schema_ids := []
        for item in this.items {
            if item.selected {
                schema_ids.Push(item.id)
            }
        }
        return {
            schema_ids: schema_ids,
            hotkeys: this.hotkeys,
            caption: this.caption,
            save_options: this.save_options.Clone(),
            fold_options: this.fold_options,
            abbreviate_options: this.abbreviate_options,
            option_list_prefix: this.option_list_prefix,
            option_list_suffix: this.option_list_suffix,
            option_list_separator: this.option_list_separator,
            fix_schema_list_order: this.fix_schema_list_order,
        }
    }

    GetOptionItems(schema_ids) {
        local configured := Map()
        local discovered := Map()
        local result := []
        local item, option_name
        for option_name in this.save_options {
            configured[option_name] := true
        }
        for item in this.items {
            if RabbitSwitcherSettingsModel.ArrayContains(schema_ids, item.id) {
                try {
                    this.DiscoverSchemaOptions(item.id, item.name, discovered, result)
                } catch {
                    ; A stale or not-yet-deployed schema must not prevent editing explicit option names.
                }
            }
        }
        for option_name in this.save_options {
            if !discovered.Has(option_name) {
                item := {
                    name: option_name,
                    source: "当前配置",
                    custom: true,
                    selected: true,
                }
                discovered[option_name] := item
                result.Push(item)
            }
        }
        for item in result {
            item.selected := configured.Has(item.name)
        }
        return result
    }

    DiscoverSchemaOptions(schema_id, schema_name, discovered, result) {
        local config := 0
        local iter, name, options
        try {
            if !(config := this.rime.schema_open(schema_id)) {
                return
            }
            if !(iter := this.rime.config_begin_list(config, "switches")) {
                return
            }
            try {
                while this.rime.config_next(iter) {
                    if this.rime.config_test_get_string(config, iter.path . "/name", &name) {
                        this.AddDiscoveredOption(name, schema_name, discovered, result)
                        continue
                    }
                    options := this.ReadStringList(config, iter.path . "/options")
                    for name in options {
                        this.AddDiscoveredOption(name, schema_name, discovered, result)
                    }
                }
            } finally {
                this.rime.config_end(iter)
            }
        } finally {
            if config {
                this.rime.config_close(config)
            }
        }
    }

    AddDiscoveredOption(name, schema_name, discovered, result) {
        local item
        if !name {
            return
        }
        if discovered.Has(name) {
            item := discovered[name]
            if !InStr("、" . item.source . "、", "、" . schema_name . "、") {
                item.source .= "、" . schema_name
            }
            return
        }
        item := {
            name: name,
            source: schema_name,
            custom: false,
            selected: false,
        }
        discovered[name] := item
        result.Push(item)
    }

    Save(values) {
        local key, name
        local original := this.original_values
        if values.schema_ids.Length = 0 || !Trim(values.caption) {
            return false
        }
        if !this.api.load_settings(this.settings) {
            return false
        }
        if !RabbitSwitcherSettingsModel.ValuesEqual(values.schema_ids, original.schema_ids)
            && !this.api.select_schemas(this.settings, values.schema_ids) {
            return false
        }
        if values.hotkeys != original.hotkeys && !this.CustomizeHotkeys(values.hotkeys, original.hotkeys) {
            return false
        }
        for name, key in Map(
            "caption", "switcher/caption",
            "option_list_prefix", "switcher/option_list_prefix",
            "option_list_suffix", "switcher/option_list_suffix",
            "option_list_separator", "switcher/option_list_separator"
        ) {
            if values.%name% != original.%name%
                && !this.api.customize_string(this.settings, key, values.%name%) {
                return false
            }
        }
        for name, key in Map(
            "fold_options", "switcher/fold_options",
            "abbreviate_options", "switcher/abbreviate_options",
            "fix_schema_list_order", "switcher/fix_schema_list_order"
        ) {
            if values.%name% != original.%name%
                && !this.api.customize_bool(this.settings, key, values.%name%) {
                return false
            }
        }
        if !RabbitSwitcherSettingsModel.StringSetsEqual(values.save_options, original.save_options)
            && !this.CustomizeStringList("switcher/save_options", values.save_options, original.save_options.Length) {
            return false
        }
        if !this.api.save_settings(this.settings) {
            return false
        }
        this.SetCurrentValues(values)
        this.original_values := this.GetCurrentValues()
        return true
    }

    CustomizeHotkeys(hotkeys, original_hotkeys := "") {
        local values := RabbitSwitcherSettingsModel.ParseCommaList(hotkeys)
        local original_values := RabbitSwitcherSettingsModel.ParseCommaList(original_hotkeys)
        return this.CustomizeStringList("switcher/hotkeys", values, original_values.Length)
    }

    CustomizeStringList(path, values, original_length) {
        local index, key
        for key in [path . "/+", path . "/-"] {
            this.api.customize_item(this.settings, key, 0)
        }
        Loop Max(original_length, values.Length) {
            index := A_Index - 1
            this.api.customize_item(this.settings, path . "/@" . index, 0)
        }
        return this.CustomizeYamlItem(path, values)
    }

    CustomizeYamlItem(path, values) {
        local config := 0
        if !(config := this.rime.config_load_string(RabbitSwitcherSettingsModel.ToYamlStringList(values))) {
            return false
        }
        try {
            return !!this.api.customize_item(this.settings, path, config)
        } finally {
            this.rime.config_close(config)
        }
    }

    SetCurrentValues(values) {
        local item, schema_id
        local items_by_id := Map()
        local ordered_items := []
        local selected := Map()
        for item in this.items {
            items_by_id[item.id] := item
        }
        for schema_id in values.schema_ids {
            selected[schema_id] := true
            if items_by_id.Has(schema_id) {
                item := items_by_id[schema_id]
                item.selected := true
                ordered_items.Push(item)
            }
        }
        for item in this.items {
            if !selected.Has(item.id) {
                item.selected := false
                ordered_items.Push(item)
            }
        }
        this.items := ordered_items
        this.hotkeys := values.hotkeys
        this.caption := values.caption
        this.save_options := values.save_options.Clone()
        this.fold_options := !!values.fold_options
        this.abbreviate_options := !!values.abbreviate_options
        this.option_list_prefix := values.option_list_prefix
        this.option_list_suffix := values.option_list_suffix
        this.option_list_separator := values.option_list_separator
        this.fix_schema_list_order := !!values.fix_schema_list_order
    }

    static ParseCommaList(value) {
        local item
        local result := []
        Loop Parse value, "," {
            if (item := Trim(A_LoopField)) {
                result.Push(item)
            }
        }
        return result
    }

    static ToYamlStringList(values) {
        local escaped, value
        local yaml := "["
        for value in values {
            escaped := StrReplace(StrReplace(value, "\", "\\"), '"', '\"')
            yaml .= (A_Index > 1 ? ", " : "") . '"' . escaped . '"'
        }
        return yaml . "]"
    }

    static ArrayContains(values, expected) {
        local value
        for value in values {
            if value = expected {
                return true
            }
        }
        return false
    }

    static ValuesEqual(left, right) {
        if !(left is Array) || !(right is Array) || left.Length != right.Length {
            return false
        }
        Loop left.Length {
            if left[A_Index] != right[A_Index] {
                return false
            }
        }
        return true
    }

    static StringSetsEqual(left, right) {
        local item
        local left_items := Map()
        local right_items := Map()
        for item in left {
            left_items[item] := true
        }
        for item in right {
            right_items[item] := true
        }
        if left_items.Count != right_items.Count {
            return false
        }
        for item in left_items {
            if !right_items.Has(item) {
                return false
            }
        }
        return true
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
        this.items := []
    }

    __Delete() {
        this.Dispose()
    }
}
