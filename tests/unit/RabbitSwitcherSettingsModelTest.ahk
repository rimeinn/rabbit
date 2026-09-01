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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitSwitcherSettingsModel.ahk

RunTest("switcher settings model loads, discovers, and saves all fields", TestSwitcherSettingsModel.Bind())

TestSwitcherSettingsModel() {
    local calls := []
    local api := RabbitSwitcherModelLeversProbe(calls)
    local model := RabbitSwitcherSettingsModelProbe(api, RabbitSwitcherModelRimeProbe(calls))
    local options, values

    try {
        AssertEqual(2, model.items.Length, "The switcher model loaded the wrong number of schemas.")
        AssertEqual("schema_b", model.items[1].id, "The switcher model lost the selected schema order.")
        AssertEqual("Control+grave", model.hotkeys, "The switcher model loaded the wrong hotkeys.")
        AssertEqual("〔方案选单〕", model.caption, "The switcher model loaded the wrong caption.")
        AssertTrue(model.fold_options, "The switcher model lost fold_options.")
        AssertTrue(model.abbreviate_options, "The switcher model lost abbreviate_options.")
        AssertEqual("〔", model.option_list_prefix, "The switcher model lost the option prefix.")
        AssertEqual("〕", model.option_list_suffix, "The switcher model lost the option suffix.")
        AssertEqual("／", model.option_list_separator, "The switcher model lost the option separator.")
        AssertTrue(model.fix_schema_list_order, "The switcher model lost fix_schema_list_order.")
        AssertEqual(2, model.save_options.Length, "The switcher model loaded the wrong saved options.")

        options := model.GetOptionItems(["schema_b"])
        AssertEqual(4, options.Length, "The switcher model discovered the wrong number of options.")
        AssertEqual("ascii_mode", options[1].name, "The switcher model lost a toggle option.")
        AssertEqual("simplification", options[2].name, "The switcher model lost a radio option.")
        AssertEqual("custom_option", options[4].name, "The switcher model dropped an unknown configured option.")
        AssertTrue(options[4].custom, "The switcher model did not mark an unknown option as custom.")
        AssertTrue(
            RabbitSwitcherSettingsModel.StringSetsEqual(
                ["ascii_mode", "custom_option"],
                ["custom_option", "ascii_mode"]
            ),
            "Saved options treated list ordering as a semantic change."
        )

        values := model.GetCurrentValues()
        values.schema_ids := ["schema_a"]
        values.hotkeys := "F4, Control+grave"
        values.caption := "方案"
        values.save_options := ["ascii_mode"]
        values.fold_options := false
        values.abbreviate_options := false
        values.option_list_prefix := "["
        values.option_list_suffix := "]"
        values.option_list_separator := " | "
        values.fix_schema_list_order := false
        AssertTrue(model.Save(values), "The switcher model failed to save valid settings.")

        AssertTrue(HasSwitcherModelCall(calls, "select:schema_a"), "The model did not save schema selection.")
        AssertTrue(HasSwitcherModelCall(calls, "string:switcher/caption:方案"), "The model did not save caption.")
        AssertTrue(HasSwitcherModelCall(calls, "bool:switcher/fold_options:0"), "The model did not save folding.")
        AssertTrue(
            HasSwitcherModelCall(calls, "reset:switcher/save_options/+"),
            "The model did not remove the incremental save_options patch."
        )
        AssertTrue(
            HasSwitcherModelCall(calls, 'item:switcher/save_options:["ascii_mode"]'),
            "The model did not save the full option list."
        )
        AssertEqual("schema_a", model.items[1].id, "The model did not retain the saved schema order.")
    } finally {
        model.Dispose()
        model.Dispose()
    }
    AssertTrue(HasSwitcherModelCall(calls, "settings_destroy"), "The switcher settings leaked.")
}

HasSwitcherModelCall(calls, expected) {
    for call in calls {
        if call = expected {
            return true
        }
    }
    return false
}

class RabbitSwitcherSettingsModelProbe extends RabbitSwitcherSettingsModel {
    CopySchemaInfo(item) {
        return item
    }
}

class RabbitSwitcherModelLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    switcher_settings_init() {
        this.calls.Push("init")
        return 42
    }

    load_settings(settings) {
        this.calls.Push("load")
        return true
    }

    settings_get_config(settings) {
        return "default"
    }

    get_available_schema_list(settings) {
        return {
            size: 2,
            list: [
                { id: "schema_a", name: "方案 A", author: "", description: "A", file_path: "a.yaml" },
                { id: "schema_b", name: "方案 B", author: "", description: "B", file_path: "b.yaml" },
            ],
        }
    }

    get_selected_schema_list(settings) {
        return { size: 1, list: [{ schema_id: "schema_b", name: "方案 B" }] }
    }

    schema_list_destroy(list) {
        this.calls.Push("destroy")
    }

    get_hotkeys(settings) {
        return "Control+grave"
    }

    select_schemas(settings, schema_ids) {
        this.calls.Push("select:" . schema_ids[1])
        return true
    }

    customize_string(settings, key, value) {
        this.calls.Push("string:" . key . ":" . value)
        return true
    }

    customize_bool(settings, key, value) {
        this.calls.Push("bool:" . key . ":" . value)
        return true
    }

    customize_item(settings, key, value) {
        this.calls.Push((value ? "item:" : "reset:") . key . (value ? ":" . value.yaml : ""))
        return true
    }

    save_settings(settings) {
        this.calls.Push("save")
        return true
    }

    custom_settings_destroy(settings) {
        this.calls.Push("settings_destroy")
    }
}

class RabbitSwitcherModelRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    config_test_get_string(config, key, &value) {
        local values := Map(
            "switcher/caption", "〔方案选单〕",
            "switcher/option_list_prefix", "〔",
            "switcher/option_list_suffix", "〕",
            "switcher/option_list_separator", "／",
            "switches/@0/name", "ascii_mode"
        )
        if config = "schema_b" && values.Has(key) {
            value := values[key]
            return true
        }
        if config = "default" && values.Has(key) {
            value := values[key]
            return true
        }
        if config = "default" && key = "switcher/save_options/@0" {
            value := "ascii_mode"
            return true
        }
        if config = "default" && key = "switcher/save_options/@1" {
            value := "custom_option"
            return true
        }
        if config = "schema_b" && key = "switches/@1/options/@0" {
            value := "simplification"
            return true
        }
        if config = "schema_b" && key = "switches/@1/options/@1" {
            value := "traditionalization"
            return true
        }
        return false
    }

    config_test_get_bool(config, key, &value) {
        local values := Map(
            "switcher/fold_options", true,
            "switcher/abbreviate_options", true,
            "switcher/fix_schema_list_order", true
        )
        if config = "default" && values.Has(key) {
            value := values[key]
            return true
        }
        return false
    }

    config_begin_list(config, path) {
        local size := 0
        if config = "default" && path = "switcher/save_options" {
            size := 2
        } else if config = "schema_b" && path = "switches" {
            size := 2
        } else if config = "schema_b" && path = "switches/@1/options" {
            size := 2
        }
        return size ? { root: path, index: 0, size: size, path: "" } : 0
    }

    config_next(iter) {
        if iter.index >= iter.size {
            return false
        }
        iter.path := iter.root . "/@" . iter.index
        iter.index += 1
        return true
    }

    config_end(iter) {
    }

    schema_open(schema_id) {
        return schema_id
    }

    config_load_string(yaml) {
        return { yaml: yaml }
    }

    config_close(config) {
        return true
    }
}
