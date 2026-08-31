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
