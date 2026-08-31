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
 */

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitUIStyleSettings.ahk

RunTest("UI style settings save typography and layout", TestUIStyleSettingsSaveTypographyAndLayout.Bind())
RunTest("UI style settings patch individual color schemes", TestUIStyleSettingsPatchColorSchemes.Bind())
RunTest("UI style settings restore dark scheme following", TestUIStyleSettingsRestoreDarkFollowing.Bind())
RunTest("UI style settings reuse common style fields across color schemes", TestUIStyleSettingsReuseBaseStyle.Bind())

TestUIStyleSettingsSaveTypographyAndLayout() {
    local calls := []
    local levers := RabbitUIStyleSettingsLeversProbe(calls)
    local settings := UIStyleSettings(0, levers)
    try {
        AssertTrue(settings.SelectColorScheme("aqua"), "The settings model rejected a light color scheme.")
        settings.SetStyleValues(Map(
            "font_face", "Test Candidate Font",
            "preedit_font_face", "Test Preedit Font",
            "font_point", 18,
            "layout_type", "flow",
            "flow_rows", 4,
            "candidate_padding_x", 3,
            "candidate_padding_y", 4,
            "candidate_spacing", 7,
            "floating_preedit", true,
            "floating_preedit_opacity", 0.65,
            "floating_preedit_min_height", 24
        ))
        AssertTrue(settings.Save(), "The settings model failed to save appearance values.")
    } finally {
        settings.Dispose()
    }
    local joined := JoinUIStyleSettingsCalls(calls)
    for expected in [
        "string:style/font_face:Test Candidate Font",
        "string:style/preedit_font_face:Test Preedit Font",
        "string:style/layout/type:flow",
        "int:style/font_point:18",
        "int:style/layout/flow_rows:4",
        "int:style/layout/candidate_padding_x:3",
        "int:style/layout/candidate_padding_y:4",
        "int:style/layout/candidate_spacing:7",
        "int:style/floating_preedit_min_height:24",
        "bool:style/floating_preedit:1",
        "double:style/floating_preedit_opacity:0.65",
    ] {
        AssertTrue(InStr(joined, expected), "The settings model omitted " . expected . ".")
    }
    AssertEqual("save", calls[calls.Length - 1], "The settings model did not save before disposal.")
    AssertEqual("destroy", calls[calls.Length], "The settings model did not dispose after saving.")
}

TestUIStyleSettingsPatchColorSchemes() {
    local calls := []
    local rime := RabbitUIStyleSettingsRimeProbe(calls)
    local settings := UIStyleSettings(rime, RabbitUIStyleSettingsLeversProbe(calls))
    try {
        settings.SelectColorScheme("aqua")
        settings.UpsertColorScheme(RabbitColorScheme.CreateDefault("custom_blue", "Custom Blue"))
        settings.DeleteColorScheme("old_custom")
        AssertTrue(settings.Save(), "The settings model failed to save color-scheme changes.")
    } finally {
        settings.Dispose()
    }
    local joined := JoinUIStyleSettingsCalls(calls)
    AssertTrue(
        InStr(joined, "item:preset_color_schemes/custom_blue:73"),
        "The custom scheme was not written at its individual path."
    )
    AssertTrue(
        InStr(joined, "item:preset_color_schemes/old_custom:0"),
        "The deleted scheme path was not removed."
    )
    AssertTrue(
        !InStr(joined, "item:preset_color_schemes:73"),
        "The settings model replaced the whole color-scheme map."
    )
    AssertTrue(InStr(joined, "Custom Blue"), "The scheme map was not serialized.")
}

TestUIStyleSettingsRestoreDarkFollowing() {
    local calls := []
    local settings := UIStyleSettings(0, RabbitUIStyleSettingsLeversProbe(calls))
    try {
        settings.SelectColorScheme("aqua")
        AssertTrue(settings.FollowLightColorScheme(), "The settings model rejected dark-mode following.")
        AssertTrue(settings.Save(), "The settings model failed to save dark-mode following.")
    } finally {
        settings.Dispose()
    }
    local joined := JoinUIStyleSettingsCalls(calls)
    AssertTrue(
        InStr(joined, "item:style/color_scheme_dark:0"),
        "Dark-mode following did not remove the explicit dark scheme."
    )
}

TestUIStyleSettingsReuseBaseStyle() {
    local calls := []
    local rime := RabbitUIStyleSettingsReadRimeProbe()
    local settings := UIStyleSettings(rime, RabbitUIStyleSettingsLeversProbe(calls))
    try {
        AssertTrue(settings.Load(), "The settings model failed to load its style config.")
        local current := settings.GetCurrentStyle()
        local reads_after_current := rime.shared_reads
        local presets := settings.GetPresetColorSchemes()
        AssertEqual(2, presets.Length, "The settings model loaded the wrong preset count.")
        AssertEqual(
            reads_after_current,
            rime.shared_reads,
            "Enumerating color schemes reread the common typography and layout fields."
        )
        AssertEqual(0xff101010, current.back_color, "The active scheme lost its background color.")
        AssertEqual(0xff101010, presets[1].style.back_color, "The first preset used the wrong background color.")
        AssertEqual(0xff202020, presets[2].style.back_color, "The second preset used the wrong background color.")
        AssertEqual(
            presets[2].style.back_color,
            presets[2].style.candidate_back_color,
            "The optimized preset path changed dependent color fallbacks."
        )
    } finally {
        settings.Dispose()
    }
}

JoinUIStyleSettingsCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitUIStyleSettingsLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    custom_settings_init(config_id, generator_id) {
        this.calls.Push("init")
        return 42
    }

    custom_settings_destroy(settings) {
        this.calls.Push("destroy")
    }

    load_settings(settings) {
        this.calls.Push("load")
        return true
    }

    settings_get_config(settings) {
        return "config"
    }

    save_settings(settings) {
        this.calls.Push("save")
        return true
    }

    customize_string(settings, key, value) {
        this.calls.Push("string:" . key . ":" . value)
        return true
    }

    customize_int(settings, key, value) {
        this.calls.Push("int:" . key . ":" . value)
        return true
    }

    customize_bool(settings, key, value) {
        this.calls.Push("bool:" . key . ":" . value)
        return true
    }

    customize_double(settings, key, value) {
        this.calls.Push("double:" . key . ":" . value)
        return true
    }

    customize_item(settings, key, value) {
        this.calls.Push("item:" . key . ":" . value)
        return true
    }
}

class RabbitUIStyleSettingsRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    config_load_string(yaml) {
        this.calls.Push("yaml:" . yaml)
        return 73
    }

    config_close(config) {
        this.calls.Push("close:" . config)
    }
}

class RabbitUIStyleSettingsReadRimeProbe {
    __New() {
        this.shared_reads := 0
        this.preset_keys := ["aqua", "azure"]
    }

    user_config_open(config_id) {
        return 0
    }

    config_begin_map(config, path) {
        if path != "preset_color_schemes" {
            return 0
        }
        return { index: 0, key: "", path: "" }
    }

    config_next(iter) {
        iter.index += 1
        if iter.index > this.preset_keys.Length {
            return false
        }
        iter.key := this.preset_keys[iter.index]
        iter.path := "preset_color_schemes/" . iter.key
        return true
    }

    config_end(iter) {
    }

    config_get_cstring(config, key) {
        if RegExMatch(key, "^preset_color_schemes/([^/]+)/name$", &match) {
            return "Scheme " . match[1]
        }
        if InStr(key, "/author") {
            return "Tester"
        }
        return ""
    }

    config_get_string(config, key) {
        if InStr(key, "style/") = 1 {
            this.shared_reads += 1
        }
        switch key {
            case "style/font_face", "style/preedit_font_face", "style/label_font_face", "style/comment_font_face":
                return "Test Font"
            case "style/color_scheme":
                return "aqua"
        }
        if InStr(key, "/color_format") {
            return "argb"
        }
        return ""
    }

    config_get_int(config, key) {
        if InStr(key, "style/") = 1 {
            this.shared_reads += 1
        }
        return 14
    }

    config_test_get_string(config, key, &value) {
        if InStr(key, "style/") = 1 {
            this.shared_reads += 1
            return false
        }
        if InStr(key, "preset_color_schemes/aqua/back_color") {
            value := "0xff101010"
            return true
        }
        if InStr(key, "preset_color_schemes/azure/back_color") {
            value := "0xff202020"
            return true
        }
        return false
    }

    config_test_get_int(config, key, &value) {
        this.shared_reads += 1
        return false
    }

    config_test_get_bool(config, key, &value) {
        this.shared_reads += 1
        return false
    }

    config_test_get_double(config, key, &value) {
        this.shared_reads += 1
        return false
    }
}
