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

RunTest("switcher settings model lifecycle", TestSwitcherSettingsModelLifecycle.Bind())

TestSwitcherSettingsModelLifecycle() {
    local calls := []
    local api := RabbitSwitcherModelLeversProbe(calls)
    local model := RabbitSwitcherSettingsModelProbe(api)

    try {
        AssertEqual(2, model.items.Length, "The switcher model loaded the wrong number of schemas.")
        AssertEqual("schema_b", model.items[1].id, "The switcher model lost the selected schema order.")
        AssertTrue(model.items[1].selected, "The switcher model did not mark the selected schema.")
        AssertEqual("schema_a", model.items[2].id, "The switcher model lost an available schema.")
        AssertTrue(!model.items[2].selected, "The switcher model selected an available schema.")
        AssertEqual("Control+grave", model.hotkeys, "The switcher model loaded the wrong hotkeys.")
        AssertTrue(model.Save(["schema_a"], "F4"), "The switcher model failed to save valid settings.")
    } finally {
        model.Dispose()
        model.Dispose()
    }

    AssertEqual(
        "init,load,available,selected,hotkeys,destroy,destroy,select:schema_a,hotkeys_set:F4,save,settings_destroy",
        JoinSwitcherModelCalls(calls),
        "The switcher model did not own or save its Rime settings correctly."
    )
}

JoinSwitcherModelCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
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

    get_available_schema_list(settings) {
        this.calls.Push("available")
        return {
            size: 2,
            list: [
                { id: "schema_a", name: "方案 A", author: "", description: "A" },
                { id: "schema_b", name: "方案 B", author: "", description: "B" },
            ],
        }
    }

    get_selected_schema_list(settings) {
        this.calls.Push("selected")
        return {
            size: 1,
            list: [
                { schema_id: "schema_b", name: "方案 B" },
            ],
        }
    }

    schema_list_destroy(list) {
        this.calls.Push("destroy")
    }

    get_hotkeys(settings) {
        this.calls.Push("hotkeys")
        return "Control+grave"
    }

    select_schemas(settings, schema_ids) {
        this.calls.Push("select:" . schema_ids[1])
        return true
    }

    set_hotkeys(settings, hotkeys) {
        this.calls.Push("hotkeys_set:" . hotkeys)
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
