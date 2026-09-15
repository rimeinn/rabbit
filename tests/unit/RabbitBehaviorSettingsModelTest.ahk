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

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitBehaviorSettingsModel.ahk

RunTest("behavior settings model loads effective defaults", TestBehaviorSettingsModelLoadsDefaults.Bind())
RunTest("behavior settings model isolates config files", TestBehaviorSettingsModelIsolatesConfigFiles.Bind())
RunTest("behavior settings model replaces bindings without losing fields", TestBehaviorSettingsModelBindings.Bind())
RunTest("behavior settings model selects deployment granularity", TestBehaviorDeploymentGranularity.Bind())
RunTest("behavior settings model owns punctuation maps", TestBehaviorPunctuatorMaps.Bind())
RunTest("behavior settings model owns recognizer patterns", TestBehaviorRecognizerPatterns.Bind())

TestBehaviorSettingsModelLoadsDefaults() {
    local calls := []
    local model := CreateBehaviorModel(calls)
    try {
        AssertTrue(model.show_tips, "The behavior model loaded the wrong status-tip value.")
        AssertEqual(1500, model.show_tips_time, "The behavior model loaded the wrong status-tip duration.")
        AssertEqual(
            "Control+Shift+F12",
            model.suspend_hotkey,
            "The behavior model loaded the wrong suspend hotkey."
        )
        AssertEqual(12, model.send_by_clipboard_length, "The model loaded the wrong clipboard threshold.")
        AssertTrue(model.good_old_caps_lock, "The model loaded the wrong Caps Lock compatibility value.")
        AssertEqual("inline_ascii", model.switch_key["Shift_L"], "The model loaded the wrong switch action.")
        AssertEqual(6, model.page_size, "The model loaded the wrong candidate page size.")
        AssertEqual("①", model.alternative_select_labels[1], "The model loaded the wrong candidate label.")
        AssertEqual("", model.alternative_select_keys, "The model loaded the wrong candidate selection keys.")
        AssertTrue(!model.page_down_cycle, "The model loaded the wrong page-cycle value.")
        AssertEqual(1, model.bindings.Length, "The model loaded the wrong binding count.")
        AssertEqual("kept", model.bindings[1]["custom_field"], "The model discarded an unknown binding field.")
        AssertTrue(!model.punctuator_use_space, "The model loaded the wrong punctuation spacing value.")
        AssertEqual(".:", model.punctuator_digit_separators, "The model loaded the wrong digit separators.")
        AssertEqual("forward", model.punctuator_digit_separator_action,
            "The model loaded the wrong digit separator action.")
        AssertTrue(!model.recognizer_use_space, "The model loaded the wrong recognizer spacing value.")
        AssertEqual(
            "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            model.recognizer_patterns["email"],
            "The model loaded the wrong recognizer pattern."
        )
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
        values.suspend_hotkey := "Alt+F12"
        values.send_by_clipboard_length := 0
        AssertTrue(model.Save(values), "The model failed to save Rabbit-only behavior settings.")
        AssertTrue(BehaviorCallsHave(calls, "save:rabbit"), "The model did not save rabbit.custom.yaml.")
        AssertTrue(!BehaviorCallsHave(calls, "save:default"), "A Rabbit-only edit wrote default.custom.yaml.")
        AssertTrue(
            BehaviorCallsHave(calls, "set_string:rabbit:suspend_hotkey:Alt+F12"),
            "The suspend hotkey was not customized."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "set_int:rabbit:send_by_clipboard_length:0"),
            "The clipboard strategy was not customized."
        )

        calls.Length := 0
        values := model.GetCurrentValues()
        values.suspend_hotkey := ""
        AssertTrue(model.Save(values), "The model failed to disable the suspend hotkey.")
        AssertTrue(
            BehaviorCallsHave(calls, "reset:rabbit:suspend_hotkey"),
            "An empty suspend hotkey did not clear the customization."
        )

        calls.Length := 0
        values := model.GetCurrentValues()
        values.page_size := 7
        AssertTrue(model.Save(values), "The model failed to save a default setting.")
        AssertTrue(!BehaviorCallsHave(calls, "save:rabbit"), "A default-only edit wrote rabbit.custom.yaml.")
        AssertTrue(BehaviorCallsHave(calls, "set_int:default:menu/page_size:7"), "The page size was not customized.")
        AssertTrue(BehaviorCallsHave(calls, "save:default"), "The model did not save default.custom.yaml.")

        calls.Length := 0
        values := model.GetCurrentValues()
        values.alternative_select_labels := ["一", "二"]
        AssertTrue(model.Save(values), "The model failed to save candidate labels as a list.")
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:menu/alternative_select_labels"),
            "Replacing candidate labels did not clear the full-list patch."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:menu/alternative_select_labels/@legacy"),
            "Replacing candidate labels did not clear a nested list patch."
        )
        AssertTrue(
            BehaviorCallsContain(calls, "item:default:menu/alternative_select_labels:", '"一"'),
            "The candidate labels were not written as a complete list."
        )

        calls.Length := 0
        values := model.GetCurrentValues()
        values.alternative_select_labels_reset := true
        AssertTrue(model.Save(values), "The model failed to restore candidate labels.")
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:menu/alternative_select_labels"),
            "Restoring candidate labels did not remove the full-list patch."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:menu/alternative_select_labels/@legacy"),
            "Restoring candidate labels did not remove a nested list patch."
        )

        calls.Length := 0
        values := model.GetCurrentValues()
        values.alternative_select_keys := "asdfg"
        values.page_down_cycle := true
        AssertTrue(model.Save(values), "The model failed to save menu navigation settings.")
        AssertTrue(
            BehaviorCallsHave(calls, "set_string:default:menu/alternative_select_keys:asdfg"),
            "The candidate selection keys were not customized."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "set_bool:default:menu/page_down_cycle:1"),
            "The page-cycle setting was not customized."
        )
        values := model.GetCurrentValues()
        values.alternative_select_keys := "aa"
        AssertThrows(model.Save.Bind(model, values), "The model accepted duplicate candidate selection keys.")
        values.alternative_select_keys := "a`n"
        AssertThrows(model.Save.Bind(model, values), "The model accepted a non-printable selection key.")

        calls.Length := 0
        values := model.GetCurrentValues()
        values.good_old_caps_lock := false
        values.switch_key["Shift_L"] := "set_ascii_mode"
        values.switch_key["Shift_R"] := "unset_ascii_mode"
        AssertTrue(model.Save(values), "The model failed to save ASCII composer settings.")
        AssertTrue(
            BehaviorCallsHave(calls, "set_bool:default:ascii_composer/good_old_caps_lock:0"),
            "The Caps Lock compatibility setting was not customized."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "set_string:default:ascii_composer/switch_key/Shift_L:set_ascii_mode"),
            "The set-ASCII action was not customized."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "set_string:default:ascii_composer/switch_key/Shift_R:unset_ascii_mode"),
            "The unset-ASCII action was not customized."
        )
        AssertTrue(
            !BehaviorCallsContain(calls, "set_string:default:ascii_composer/switch_key/", "Super"),
            "Saving exposed a deliberately unsupported Super key."
        )

        calls.Length := 0
        values := model.GetCurrentValues()
        values.punctuator_use_space := true
        values.punctuator_digit_separators := ",."
        values.punctuator_digit_separator_action := "commit"
        AssertTrue(model.Save(values), "The model failed to save punctuation scalar settings.")
        AssertTrue(
            BehaviorCallsHave(calls, "set_bool:default:punctuator/use_space:1"),
            "The punctuation spacing setting was not customized."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "set_string:default:punctuator/digit_separators:,."),
            "The digit separators were not customized."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "set_string:default:punctuator/digit_separator_action:commit"),
            "The digit separator action was not customized."
        )

        values := model.GetCurrentValues()
        values.punctuator_digit_separators := "a"
        AssertThrows(model.Save.Bind(model, values), "The model accepted a non-punctuation digit separator.")
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

TestBehaviorDeploymentGranularity() {
    local calls := []
    local model := CreateBehaviorModel(calls)
    local plan, values
    try {
        values := model.GetCurrentValues()
        AssertTrue(model.GetDeploymentPlan(values).IsEmpty(), "Unchanged behavior settings requested deployment.")

        values.show_tips := !values.show_tips
        plan := model.GetDeploymentPlan(values)
        AssertTrue(plan.rabbit_config_changed, "A Rabbit setting did not request rabbit.yaml deployment.")
        AssertTrue(!plan.default_config_changed, "A Rabbit setting requested default.yaml deployment.")
        AssertTrue(!plan.full_workspace_required, "A Rabbit setting requested workspace deployment.")

        values := model.GetCurrentValues()
        values.good_old_caps_lock := !values.good_old_caps_lock
        plan := model.GetDeploymentPlan(values)
        AssertTrue(plan.default_config_changed, "An ASCII composer setting did not request default.yaml deployment.")
        AssertTrue(!plan.rabbit_config_changed, "An ASCII composer setting requested rabbit.yaml deployment.")
        AssertTrue(!plan.full_workspace_required, "An ASCII composer setting requested workspace deployment.")

        values := model.GetCurrentValues()
        values.page_size += 1
        plan := model.GetDeploymentPlan(values)
        AssertTrue(plan.full_workspace_required, "A schema-visible menu setting did not request workspace deployment.")
        AssertTrue(!plan.rabbit_config_changed, "A menu setting requested rabbit.yaml deployment.")

        values := model.GetCurrentValues()
        values.alternative_select_keys := "asdfg"
        plan := model.GetDeploymentPlan(values)
        AssertTrue(plan.full_workspace_required, "Candidate selection keys did not request workspace deployment.")

        values := model.GetCurrentValues()
        values.page_down_cycle := !values.page_down_cycle
        plan := model.GetDeploymentPlan(values)
        AssertTrue(plan.full_workspace_required, "Page cycling did not request workspace deployment.")
    } finally {
        model.Dispose()
    }
}

TestBehaviorPunctuatorMaps() {
    local calls := [], model := CreateBehaviorModel(calls), values, plan
    try {
        values := model.GetCurrentValues()
        AssertEqual(
            "（",
            values.punctuator_maps[RabbitPunctuatorMap.FULL_SHAPE_PATH]["("]["pair"][1],
            "The behavior model did not load the full-shape punctuation map."
        )
        values.punctuator_maps[RabbitPunctuatorMap.FULL_SHAPE_PATH]["("]["pair"][1] := "【"
        plan := model.GetDeploymentPlan(values)
        AssertTrue(plan.full_workspace_required, "A punctuation map did not request workspace deployment.")
        calls.Length := 0
        AssertTrue(model.Save(values), "The behavior model failed to save a punctuation map.")
        AssertTrue(
            BehaviorCallsContain(calls, "item:default:punctuator/full_shape:", '"(": {"pair": ["【", "）"]}'),
            "The behavior model did not write the complete full-shape map."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:punctuator/full_shape/@legacy"),
            "Replacing a punctuation map did not clear a nested patch."
        )
        values := model.GetCurrentValues()
        values.punctuator_reset_fields := Map(RabbitPunctuatorMap.FULL_SHAPE_PATH, true)
        calls.Length := 0
        AssertTrue(model.Save(values), "The behavior model failed to restore a punctuation map.")
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:punctuator/full_shape"),
            "Restoring a punctuation map did not remove its full-map override."
        )
    } finally {
        model.Dispose()
    }
}

TestBehaviorRecognizerPatterns() {
    local calls := [], model := CreateBehaviorModel(calls), values, plan
    try {
        values := model.GetCurrentValues()
        AssertEqual(2, values.recognizer_patterns.Count, "The behavior model loaded the wrong pattern count.")
        values.recognizer_use_space := true
        values.recognizer_patterns["email"] := "^foo@bar\\.example$"
        plan := model.GetDeploymentPlan(values)
        AssertTrue(plan.full_workspace_required, "A recognizer setting did not request workspace deployment.")
        calls.Length := 0
        AssertTrue(model.Save(values), "The behavior model failed to save recognizer settings.")
        AssertTrue(
            BehaviorCallsHave(calls, "set_bool:default:recognizer/use_space:1"),
            "The recognizer spacing setting was not customized."
        )
        AssertTrue(
            BehaviorCallsContain(calls, "item:default:recognizer/patterns:", '"email": "^foo@bar\\\\.example$"'),
            "The behavior model did not write the complete recognizer pattern map."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:recognizer/patterns/@legacy"),
            "Replacing recognizer patterns did not clear a nested patch."
        )

        values := model.GetCurrentValues()
        values.recognizer_reset_fields := Map(RabbitRecognizerPatterns.PATH, true)
        calls.Length := 0
        AssertTrue(model.Save(values), "The behavior model failed to restore recognizer patterns.")
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:recognizer/patterns"),
            "Restoring recognizer patterns did not remove the full-map override."
        )
        AssertTrue(
            BehaviorCallsHave(calls, "reset:default:recognizer/patterns/@legacy"),
            "Restoring recognizer patterns did not remove a nested patch."
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
        this.punctuator_maps := Map(
            RabbitPunctuatorMap.FULL_SHAPE_PATH, Map("(", Map("pair", ["（", "）"])),
            RabbitPunctuatorMap.HALF_SHAPE_PATH, Map(")", ")"),
            RabbitPunctuatorMap.SYMBOLS_PATH, Map("...", ["…", "..."])
        )
        this.punctuator_use_space := false
        this.punctuator_digit_separators := ".:"
        this.punctuator_digit_separator_action := "forward"
        this.alternative_select_keys := ""
        this.page_down_cycle := false
        this.recognizer_use_space := false
        this.recognizer_patterns := Map(
            "email", "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            "url", "https?://[^ ]+"
        )
    }

    config_test_get_bool(config, key, &value) {
        if config is Map && config.Has("value") && key = "/"
            && Type(config["value"]) = "Integer" && (config["value"] = 0 || config["value"] = 1) {
            value := config["value"]
            return true
        }
        if config = "default" && key = "ascii_composer/good_old_caps_lock" {
            value := true
            return true
        }
        if config = "default" && key = RabbitPunctuatorMap.USE_SPACE_PATH {
            value := this.punctuator_use_space
            return true
        }
        if config = "default" && key = RabbitMenuSettings.PAGE_DOWN_CYCLE_PATH {
            value := this.page_down_cycle
            return true
        }
        if config = "default" && key = RabbitRecognizerPatterns.USE_SPACE_PATH {
            value := this.recognizer_use_space
            return true
        }
        if config != "rabbit" {
            return false
        }
        value := key = "show_tips" || key = "bypass_password_fields"
        return true
    }

    config_test_get_int(config, key, &value) {
        if config is Map && config.Has("value") && key = "/" && Type(config["value"]) = "Integer" {
            value := config["value"]
            return true
        }
        if config = "rabbit" && key = "show_tips_time" {
            value := 1500
            return true
        }
        if config = "rabbit" && key = "send_by_clipboard_length" {
            value := 12
            return true
        }
        if config = "default" && key = "menu/page_size" {
            value := 6
            return true
        }
        return false
    }

    config_test_get_double(config, key, &value) {
        if config is Map && config.Has("value") && key = "/" && Type(config["value"]) = "Float" {
            value := config["value"]
            return true
        }
        return false
    }

    config_test_get_string(config, key, &value) {
        local name
        if config is Map && config.Has("value") && key = "/" && Type(config["value"]) = "String" {
            value := config["value"]
            return true
        }
        if config = "rabbit" && key = "suspend_hotkey" {
            value := "Control+Shift+F12"
            return true
        }
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
        if key = RabbitMenuSettings.ALTERNATIVE_SELECT_KEYS_PATH {
            value := this.alternative_select_keys
            return true
        }
        if key = RabbitPunctuatorMap.DIGIT_SEPARATORS_PATH {
            value := this.punctuator_digit_separators
            return true
        }
        if key = RabbitPunctuatorMap.DIGIT_SEPARATOR_ACTION_PATH {
            value := this.punctuator_digit_separator_action
            return true
        }
        if InStr(key, RabbitRecognizerPatterns.PATH . "/") = 1 {
            name := SubStr(key, StrLen(RabbitRecognizerPatterns.PATH) + 2)
            if this.recognizer_patterns.Has(name) {
                value := this.recognizer_patterns[name]
                return true
            }
        }
        if InStr(key, "key_binder/bindings/@0/") = 1 {
            name := SubStr(key, StrLen("key_binder/bindings/@0/") + 1)
            value := this.binding_values[name]
            return true
        }
        return false
    }

    config_begin_list(config, path) {
        local value
        if config is Map && config.Has("value") && path = "/" && config["value"] is Array {
            return RabbitBehaviorConfigIterator(this.ConfigItems(config["value"], true))
        }
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
        if config = "user" && path = "patch" {
            return RabbitBehaviorConfigIterator([
                ["menu/alternative_select_labels/@legacy", "patch/menu_labels_legacy"],
                ["punctuator/full_shape/@legacy", "patch/punctuator_legacy"],
                ["recognizer/patterns/@legacy", "patch/recognizer_legacy"]
            ])
        }
        if config is Map && config.Has("value") && path = "/" && config["value"] is Map {
            return RabbitBehaviorConfigIterator(this.ConfigItems(config["value"], false))
        }
        if config = "default" && this.punctuator_maps.Has(path) {
            return RabbitBehaviorConfigIterator(this.ConfigItems(this.punctuator_maps[path], false, path . "/"))
        }
        if config = "default" && path = RabbitRecognizerPatterns.PATH {
            return RabbitBehaviorConfigIterator(this.ConfigItems(this.recognizer_patterns, false, path . "/"))
        }
        if config != "default" || path != "key_binder/bindings/@0" {
            return 0
        }
        for key, value in this.binding_values {
            items.Push([key, path . "/" . key])
        }
        return RabbitBehaviorConfigIterator(items)
    }

    user_config_open(config_id) {
        return config_id = "default.custom" ? "user" : 0
    }

    config_get_item(config, path) {
        local value
        if config is Map && config.Has("value") {
            if path = "/" {
                return 0
            }
            if config["value"] is Map && config["value"].Has(path) {
                return Map("value", config["value"][path])
            }
            if config["value"] is Array && RegExMatch(path, "^\d+$") {
                value := Integer(path) + 1
                return value <= config["value"].Length ? Map("value", config["value"][value]) : 0
            }
        }
        if config = "default" {
            for path_name, value_map in this.punctuator_maps {
                if SubStr(path, 1, StrLen(path_name) + 1) = path_name . "/" {
                    value := SubStr(path, StrLen(path_name) + 2)
                    if value_map.Has(value) {
                        return Map("value", value_map[value])
                    }
                }
            }
            if SubStr(path, 1, StrLen(RabbitRecognizerPatterns.PATH) + 1) = RabbitRecognizerPatterns.PATH . "/" {
                value := SubStr(path, StrLen(RabbitRecognizerPatterns.PATH) + 2)
                if this.recognizer_patterns.Has(value) {
                    return Map("value", this.recognizer_patterns[value])
                }
            }
        }
        return 0
    }

    ConfigItems(value, list, prefix := "") {
        local items := [], item, key
        for key, item in value {
            items.Push([list ? String(key - 1) : key, prefix . (list ? String(key - 1) : key)])
        }
        return items
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

RunTest("language preference saves only to rabbit customization", TestBehaviorLanguagePreference.Bind())

TestBehaviorLanguagePreference() {
    local calls := [], model := CreateBehaviorModel(calls), values
    try {
        AssertEqual("auto", model.language, "Missing language did not default to auto.")
        values := model.GetCurrentValues()
        values.language := "en-US"
        calls.Length := 0
        AssertTrue(model.Save(values), "Language preference was not saved.")
        AssertTrue(BehaviorCallsHave(calls, "set_string:rabbit:language:en-US"), "Wrong language patch.")
        AssertTrue(!BehaviorCallsHave(calls, "save:default"), "Language modified default.custom.yaml.")
        AssertEqual("en-US", model.GetCurrentValues().language, "Saved preference was not retained.")
        calls.Length := 0
        AssertTrue(model.Save(values), "Unchanged preference failed to save.")
        AssertTrue(!BehaviorCallsHave(calls, "save:rabbit"), "Unchanged language was written again.")
    } finally {
        model.Dispose()
    }
}
