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

RunTest("behavior settings model lifecycle", TestBehaviorSettingsModelLifecycle.Bind())

TestBehaviorSettingsModelLifecycle() {
    local calls := []
    local model := RabbitBehaviorSettingsModel(
        RabbitBehaviorLeversProbe(calls),
        RabbitBehaviorRimeProbe(calls)
    )
    try {
        AssertTrue(model.show_tips, "The behavior model loaded the wrong status-tip value.")
        AssertEqual(1500, model.show_tips_time, "The behavior model loaded the wrong status-tip duration.")
        AssertTrue(model.bypass_password_fields, "The behavior model loaded the wrong password-field value.")
        AssertTrue(model.Save({
            show_tips: false,
            show_tips_time: 900,
            global_ascii: true,
            fix_candidate_box: true,
            use_legacy_candidate_box: false,
            bypass_password_fields: false,
        }), "The behavior model failed to save valid settings.")
    } finally {
        model.Dispose()
        model.Dispose()
    }
    AssertEqual(
        "init,load,config,get_bool:show_tips,get_int:show_tips_time,get_bool:global_ascii," .
            "get_bool:fix_candidate_box,get_bool:use_legacy_candidate_box,get_bool:bypass_password_fields," .
            "set_bool:show_tips:0,set_int:show_tips_time:900,set_bool:global_ascii:1," .
            "set_bool:fix_candidate_box:1,set_bool:use_legacy_candidate_box:0," .
            "set_bool:bypass_password_fields:0,save,destroy",
        JoinBehaviorCalls(calls),
        "The behavior model did not load, save, and dispose in order."
    )
}

JoinBehaviorCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitBehaviorLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    custom_settings_init(config_id, generator_id) {
        this.calls.Push("init")
        return 42
    }

    load_settings(settings) {
        this.calls.Push("load")
        return true
    }

    settings_get_config(settings) {
        this.calls.Push("config")
        return 84
    }

    customize_bool(settings, key, value) {
        this.calls.Push("set_bool:" . key . ":" . value)
        return true
    }

    customize_int(settings, key, value) {
        this.calls.Push("set_int:" . key . ":" . value)
        return true
    }

    save_settings(settings) {
        this.calls.Push("save")
        return true
    }

    custom_settings_destroy(settings) {
        this.calls.Push("destroy")
    }
}

class RabbitBehaviorRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    config_test_get_bool(config, key, &value) {
        this.calls.Push("get_bool:" . key)
        value := key = "show_tips" || key = "bypass_password_fields"
        return true
    }

    config_test_get_int(config, key, &value) {
        this.calls.Push("get_int:" . key)
        value := 1500
        return true
    }
}
