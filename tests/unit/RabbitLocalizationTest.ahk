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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitI18n.ahk
#Include ..\..\Lib\RabbitDeployerWorkflow.ahk
#Include ..\..\Lib\RabbitSettingsWindow.ahk
#Include ..\..\Lib\RabbitColorScheme.ahk
#Include ..\..\Lib\RabbitColorSchemeDialog.ahk
#Include ..\..\Lib\RabbitKeyBindingDialog.ahk
#Include ..\..\Lib\RabbitAdvancedFontSettingsDialog.ahk
#Include ..\..\Lib\RabbitAdvancedFontSettingsModel.ahk

RunTest("settings controls use the active locale", TestLocalizedSettingsControls.Bind())
RunTest("settings dialogs preserve config keys in English", TestLocalizedSettingsDialogs.Bind())
RunTest("translation references exist in the default catalog", TestTranslationReferences.Bind())

TestLocalizedSettingsControls() {
    local directory := A_LineFile . "\..\..\..\Locales", window := 0
    try {
        RabbitI18n.Initialize(directory, "en-US")
        window := RabbitSettingsWindow()
        window.SelectPage(2)
        AssertEqual("Move up", window.switcher_move_up.Text, "Scheme controls were not translated.")
        window.SelectPage(3)
        AssertEqual("No change", RabbitSettingsWindow.SWITCH_ACTION_LABELS[1],
            "Switch action labels were cached before locale initialization.")
        AssertEqual("noop", RabbitSettingsWindow.SWITCH_ACTION_VALUES[1], "A persisted action was translated.")
        AssertEqual("Show input mode tips", window.show_tips.Text, "Behavior controls were not translated.")
        window.SelectPage(4)
        AssertEqual("Add or update", window.application_update_button.Text, "Application controls were not translated.")
        window.SelectPage(5)
        AssertEqual("Save snapshot", window.dictionary_backup.Text, "Dictionary controls were not translated.")
        window.SelectPage(6)
        AssertEqual("Sync user data", window.sync_button.Text, "Maintenance controls were not translated.")
        AssertEqual("Records exported: 2.", RabbitI18n.Text("messages.exported", Map("count", 2)),
            "Count message was not translated.")
    } finally {
        if window {
            window.Dispose()
        }
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}

TestLocalizedSettingsDialogs() {
    local directory := A_LineFile . "\..\..\..\Locales", owner := Gui(), dialog := 0
    local color_scheme, values, error_message := ""
    try {
        RabbitI18n.Initialize(directory, "en-US")
        dialog := RabbitKeyBindingDialog(owner)
        AssertEqual("Add key binding", dialog.Title, "Key binding title was not translated.")
        AssertEqual("OK", dialog.save_button.Text, "Dialog confirmation was not translated.")
        dialog.Dispose()
        dialog := 0
        color_scheme := RabbitColorScheme.CreateDefault("test", "User supplied name")
        dialog := RabbitColorSchemeDialog(owner, color_scheme)
        AssertEqual("Edit color scheme", dialog.Title, "Color dialog title was not translated.")
        AssertEqual("User supplied name", dialog.name_edit.Value, "User content was translated.")
        dialog.Dispose()
        dialog := 0
        values := Map()
        for role in RabbitAdvancedFontSettingsModel.ROLES {
            values[role.key] := "Microsoft YaHei UI"
        }
        dialog := RabbitAdvancedFontSettingsDialog(owner, values, ["Microsoft YaHei UI"])
        AssertEqual("Advanced font settings", dialog.Title, "Font dialog title was not translated.")
        AssertEqual("Candidate text", RabbitAdvancedFontSettingsModel.ROLES[1].label,
            "Font role names were cached before locale initialization.")
        AssertEqual("font_face", RabbitAdvancedFontSettingsModel.ROLES[1].key, "A persisted font key was translated.")
        try {
            RabbitColorScheme.ParseArgbText("invalid")
        } catch as err {
            error_message := err.Message
        }
        AssertEqual("Colors must use #RRGGBB or #AARRGGBB format.", error_message,
            "Color validation was not translated.")
    } finally {
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}

TestTranslationReferences() {
    local root := A_LineFile . "\..\..\..", catalog, source, position, found, match
    catalog := RabbitI18n.ReadCatalog(root . "\Locales\zh-CN.ini")
    Loop Files root . "\Lib\Rabbit*.ahk" {
        source := FileRead(A_LoopFileFullPath, "UTF-8")
        position := 1
        while (found := RegExMatch(source, 'RabbitI18n\.Text\("([a-z_]+\.[a-z_]+)"', &match, position)) {
            AssertTrue(catalog.Has(match[1]), "Missing catalog key " . match[1] . " in " . A_LoopFileName)
            position := found + StrLen(match[0])
        }
    }
}

RunTest("Traditional Chinese settings expose both regional language choices", TestTraditionalSettingsChoices.Bind())

TestTraditionalSettingsChoices() {
    local directory := A_LineFile . "\..\..\..\Locales", locale, window := 0
    try {
        for locale in ["zh-HK", "zh-TW"] {
            RabbitI18n.Initialize(directory, locale)
            window := RabbitSettingsWindow()
            AssertEqual("【玉兔毫】設定", window.Title, "Traditional settings title was not loaded.")
            window.SelectPage(3)
            AssertEqual("zh-HK", window.language_values[4], "Hong Kong language is not selectable.")
            AssertEqual("zh-TW", window.language_values[5], "Taiwan language is not selectable.")
            window.behavior_tabs.Choose(3)
            window.OnBehaviorTabChanged()
            AssertTrue(window.language_choice.Visible, "Regional language picker is hidden.")
            AssertEqual("介面語言：", window.language_label.Text, "Regional language label is not translated.")
            window.Dispose()
            window := 0
        }
    } finally {
        if window {
            window.Dispose()
        }
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}

RunTest("settings discover language names and preserve configured aliases", TestDiscoveredLanguageChoices.Bind())

TestDiscoveredLanguageChoices() {
    local directory := A_Temp . "\rabbit-picker-" . DllCall("GetCurrentProcessId")
    local repository := A_LineFile . "\..\..\..\Locales", window := 0
    try {
        DirCreate(directory)
        FileAppend("[meta]`nlocale=ja-JP`nlanguage_name=日本語", directory . "\ja-JP.ini", "UTF-8-RAW")
        RabbitI18n.Initialize(directory, "zh-CN")
        window := RabbitSettingsWindow()
        window.SelectPage(3)
        window.PopulateLanguageChoices("ja-JP")
        AssertEqual("日本語", window.language_choice.Text, "Picker did not use the discovered name.")
        AssertEqual("ja-JP", window.language_values[window.language_choice.Value], "Picker lost the language code.")
        window.PopulateLanguageChoices("de-DE")
        AssertEqual(6, window.language_values.Length, "Unavailable catalog added a metadata-less picker entry.")
        AssertEqual("简体中文", window.language_choice.Text, "Unavailable preference did not show its fallback.")
        window.PopulateLanguageChoices("zh-Hant")
        AssertEqual("繁體中文（台灣）", window.language_choice.Text, "Official alias created a duplicate picker item.")
        AssertEqual("zh-Hant", window.language_values[window.language_choice.Value], "Saved alias was normalized.")
    } finally {
        if window {
            window.Dispose()
        }
        if FileExist(directory . "\ja-JP.ini") {
            FileDelete(directory . "\ja-JP.ini")
        }
        if DirExist(directory) {
            DirDelete(directory)
        }
        RabbitI18n.Initialize(repository, "zh-CN")
    }
}
