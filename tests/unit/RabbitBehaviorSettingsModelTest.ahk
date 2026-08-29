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
#Include ..\..\Lib\RabbitBehaviorSettingsModel.ahk

RunTest("behavior settings model loads effective defaults", TestBehaviorSettingsModelLoadsDefaults.Bind())
RunTest("behavior settings model isolates config files", TestBehaviorSettingsModelIsolatesConfigFiles.Bind())
RunTest("behavior settings model replaces bindings without losing fields", TestBehaviorSettingsModelBindings.Bind())

TestBehaviorSettingsModelLoadsDefaults() {
    local calls := []
    local model := CreateBehaviorModel(calls)
    try {
        AssertTrue(model.show_tips, "The behavior model loaded the wrong status-tip value.")
        AssertEqual(1500, model.show_tips_time, "The behavior model loaded the wrong status-tip duration.")
        AssertEqual("inline_ascii", model.switch_key["Shift_L"], "The model loaded the wrong switch action.")
        AssertEqual(6, model.page_size, "The model loaded the wrong candidate page size.")
        AssertEqual("①", model.alternative_select_labels[1], "The model loaded the wrong candidate label.")
        AssertEqual(1, model.bindings.Length, "The model loaded the wrong binding count.")
        AssertEqual("kept", model.bindings[1]["custom_field"], "The model discarded an unknown binding field.")
    } finally {
        model.Dispose()
        model.Dispose()
    }
    AssertTrue(BehaviorCallsHave(calls, "destroy:default"), "The model did not destroy its default settings.")
    AssertTrue(BehaviorCallsHave(calls, "destroy:rabbit"), "The model did not destroy its Rabbit settings.")
}

TestBehaviorSettingsModelIsolatesConfigFiles() {
    local calls := []
    local model := CreateBehaviorModel(calls)
    try {
        calls.Length := 0
        local values := model.GetCurrentValues()
        values.show_tips := false
        AssertTrue(model.Save(values), "The model failed to save Rabbit-only behavior settings.")
        AssertTrue(BehaviorCallsHave(calls, "save:rabbit"), "The model did not save rabbit.custom.yaml.")
        AssertTrue(!BehaviorCallsHave(calls, "save:default"), "A Rabbit-only edit wrote default.custom.yaml.")

        calls.Length := 0
        values := model.GetCurrentValues()
        values.page_size := 7
        AssertTrue(model.Save(values), "The model failed to save a default setting.")
        AssertTrue(!BehaviorCallsHave(calls, "save:rabbit"), "A default-only edit wrote rabbit.custom.yaml.")
        AssertTrue(BehaviorCallsHave(calls, "set_int:default:menu/page_size:7"), "The page size was not customized.")
        AssertTrue(BehaviorCallsHave(calls, "save:default"), "The model did not save default.custom.yaml.")
    } finally {
        model.Dispose()
    }
}

TestBehaviorSettingsModelBindings() {
    local calls := []
    local model := CreateBehaviorModel(calls)
    try {
        calls.Length := 0
        local values := model.GetCurrentValues()
        values.bindings[1]["send"] := "Down"
        AssertTrue(model.Save(values), "The model failed to replace the effective binding list.")
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:key_binder/bindings/+"),
            "The model did not clear an appended binding patch."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:key_binder/bindings/@0"),
            "The model did not clear an indexed binding patch."
        )
        AssertTrue(
            BehaviorCallsContain(calls, 'item:default:key_binder/bindings:', '"custom_field": "kept"'),
            "The full-list replacement dropped an unknown binding field."
        )
    } finally {
        model.Dispose()
    }
}

CreateBehaviorModel(calls) {
    return RabbitBehaviorSettingsModel(
        RabbitBehaviorLeversProbe(calls),
        RabbitBehaviorRimeProbe(calls)
    )
}

BehaviorCallsHave(calls, expected) {
    for call in calls {
        if call = expected {
            return true
        }
    }
    return false
}

BehaviorCallsContain(calls, prefix, text) {
    for call in calls {
        if InStr(call, prefix) = 1 && InStr(call, text) {
            return true
        }
    }
    return false
}

class RabbitBehaviorLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    custom_settings_init(config_id, generator_id) {
        this.calls.Push("init:" . config_id)
        return config_id
    }

    load_settings(settings) {
        this.calls.Push("load:" . settings)
        return true
    }

    settings_get_config(settings) {
        this.calls.Push("config:" . settings)
        return settings
    }

    customize_bool(settings, key, value) {
        this.calls.Push("set_bool:" . settings . ":" . key . ":" . value)
        return true
    }

    customize_int(settings, key, value) {
        this.calls.Push("set_int:" . settings . ":" . key . ":" . value)
        return true
    }

    customize_string(settings, key, value) {
        this.calls.Push("set_string:" . settings . ":" . key . ":" . value)
        return true
    }

    customize_item(settings, key, value) {
        if !value {
            this.calls.Push("reset:" . settings . ":" . key)
        } else {
            this.calls.Push("item:" . settings . ":" . key . ":" . value.yaml)
        }
        return true
    }

    save_settings(settings) {
        this.calls.Push("save:" . settings)
        return true
    }

    custom_settings_destroy(settings) {
        this.calls.Push("destroy:" . settings)
    }
}

class RabbitBehaviorRimeProbe {
    __New(calls) {
        this.calls := calls
        this.switch_key := Map(
            "Shift_L", "inline_ascii",
            "Shift_R", "commit_text",
            "Control_L", "noop",
            "Control_R", "noop",
            "Caps_Lock", "clear",
            "Eisu_toggle", "clear"
        )
        this.binding_values := Map(
            "accept", "Control+p",
            "send", "Up",
            "when", "composing",
            "custom_field", "kept"
        )
    }

    config_test_get_bool(config, key, &value) {
        if config != "rabbit" {
            return false
        }
        value := key = "show_tips" || key = "bypass_password_fields"
        return true
    }

    config_test_get_int(config, key, &value) {
        if config = "rabbit" && key = "show_tips_time" {
            value := 1500
            return true
        }
        if config = "default" && key = "menu/page_size" {
            value := 6
            return true
        }
        return false
    }

    config_test_get_double(config, key, &value) {
        return false
    }

    config_test_get_string(config, key, &value) {
        local name
        if config != "default" {
            return false
        }
        if InStr(key, "ascii_composer/switch_key/") = 1 {
            name := SubStr(key, StrLen("ascii_composer/switch_key/") + 1)
            value := this.switch_key[name]
            return true
        }
        if key = "menu/alternative_select_labels/@0" {
            value := "①"
            return true
        }
        if InStr(key, "key_binder/bindings/@0/") = 1 {
            name := SubStr(key, StrLen("key_binder/bindings/@0/") + 1)
            value := this.binding_values[name]
            return true
        }
        return false
    }

    config_begin_list(config, path) {
        if config != "default" {
            return 0
        }
        if path = "menu/alternative_select_labels" {
            return RabbitBehaviorConfigIterator([["0", "menu/alternative_select_labels/@0"]])
        }
        if path = "key_binder/bindings" {
            return RabbitBehaviorConfigIterator([["0", "key_binder/bindings/@0"]])
        }
        return 0
    }

    config_begin_map(config, path) {
        local items := []
        if config != "default" || path != "key_binder/bindings/@0" {
            return 0
        }
        for key, value in this.binding_values {
            items.Push([key, path . "/" . key])
        }
        return RabbitBehaviorConfigIterator(items)
    }

    config_next(iter) {
        return iter.MoveNext()
    }

    config_end(iter) {
    }

    config_load_string(yaml) {
        return { yaml: yaml }
    }

    config_close(config) {
    }
}

class RabbitBehaviorConfigIterator {
    __New(items) {
        this.items := items
        this.index := 0
        this.key := ""
        this.path := ""
    }

    MoveNext() {
        this.index += 1
        if this.index > this.items.Length {
            return false
        }
        this.key := this.items[this.index][1]
        this.path := this.items[this.index][2]
        return true
    }
}
