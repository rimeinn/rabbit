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
#Include ..\..\Lib\RabbitApplicationSettingsModel.ahk

RunTest("application settings model lifecycle", TestApplicationSettingsModelLifecycle.Bind())
RunTest("application settings process validation", TestApplicationSettingsProcessValidation.Bind())

TestApplicationSettingsModelLifecycle() {
    local calls := []
    local model := RabbitApplicationSettingsModel(
        RabbitApplicationSettingsLeversProbe(calls),
        RabbitApplicationSettingsRimeProbe(calls)
    )
    try {
        AssertEqual(2, model.rules.Count, "The application model loaded the wrong rule count.")
        AssertTrue(model.rules["cmd.exe"], "The application model loaded the wrong English rule.")
        AssertTrue(!model.rules["notepad.exe"], "The application model loaded the wrong Chinese rule.")
        AssertTrue(model.Save(Map(
            "cmd.exe", { reset: true },
            "notepad.exe", { reset: false, ascii_mode: true }
        )), "The application model failed to save valid changes.")
    } finally {
        model.Dispose()
        model.Dispose()
    }
    AssertEqual(
        "init,load,config,begin,next:cmd.exe,get:cmd.exe,next:notepad.exe,get:notepad.exe,end," .
            "load,reset:cmd.exe,set:notepad.exe:1,save,destroy",
        JoinApplicationSettingsCalls(calls),
        "The application model did not load, save, and dispose in order."
    )
}

TestApplicationSettingsProcessValidation() {
    AssertEqual(
        "code.exe",
        RabbitApplicationSettingsModel.NormalizeProcessName("  CODE.EXE "),
        "The application model did not normalize a process name."
    )
    AssertTrue(
        RabbitApplicationSettingsModel.IsValidProcessName("nxplayer.bin"),
        "The application model rejected a valid process name."
    )
    AssertTrue(
        !RabbitApplicationSettingsModel.IsValidProcessName("C:\\Windows\\notepad.exe"),
        "The application model accepted a process path."
    )
    AssertTrue(!RabbitApplicationSettingsModel.IsValidProcessName(".."), "The application model accepted dots.")
}

JoinApplicationSettingsCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitApplicationSettingsLeversProbe {
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
        this.calls.Push("set:" . this.ProcessName(key) . ":" . value)
        return true
    }

    customize_item(settings, key, value) {
        this.calls.Push("reset:" . this.ProcessName(key))
        return value = 0
    }

    save_settings(settings) {
        this.calls.Push("save")
        return true
    }

    custom_settings_destroy(settings) {
        this.calls.Push("destroy")
    }

    ProcessName(key) {
        return StrReplace(StrReplace(key, "app_options/", ""), "/ascii_mode", "")
    }
}

class RabbitApplicationSettingsRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    config_begin_map(config, key) {
        this.calls.Push("begin")
        return { items: ["cmd.exe", "notepad.exe"], index: 0, key: "" }
    }

    config_next(iter) {
        iter.index += 1
        if iter.index > iter.items.Length {
            return false
        }
        iter.key := iter.items[iter.index]
        this.calls.Push("next:" . iter.key)
        return true
    }

    config_test_get_bool(config, key, &value) {
        local process_name := StrReplace(StrReplace(key, "app_options/", ""), "/ascii_mode", "")
        this.calls.Push("get:" . process_name)
        value := process_name = "cmd.exe"
        return true
    }

    config_end(iter) {
        this.calls.Push("end")
    }
}
