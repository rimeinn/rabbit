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
#Include ..\..\Lib\RabbitLocaleFallback.ahk

RunTest("translation catalogs and fallback", TestRabbitI18n.Bind())
RunTest("translation validation and substitution", TestRabbitI18nValidation.Bind())
RunTest("translation parser rejects invalid catalogs", TestRabbitI18nParser.Bind())
RunTest("language reads deployed Rime config", TestRabbitI18nConfig.Bind())

TestRabbitI18n() {
    local directory := A_LineFile . "\..\..\..\locales", reference, translated
    try {
        RabbitI18n.Initialize(directory, "en-US")
        AssertEqual("Input settings", RabbitI18n.Text("tray.settings"), "English catalog was not loaded.")
        RabbitI18n.messages.Delete("tray.settings")
        AssertEqual("输入法设定", RabbitI18n.Text("tray.settings"), "Missing translation did not fall back.")
        AssertEqual("unknown.key", RabbitI18n.Text("unknown.key"), "Missing key was hidden.")
        RabbitI18n.Initialize(directory, "auto", "en-GB")
        AssertEqual("en-US", RabbitI18n.locale, "System language family was not resolved.")
        RabbitI18n.Initialize(directory, "../../invalid", "en-US")
        AssertEqual("zh-CN", RabbitI18n.locale, "Invalid preference did not fall back.")
        reference := RabbitI18n.ReadCatalog(directory . "\zh-CN.ini")
        AssertTrue(reference.Count > 20, "Reference catalog is empty.")
        translated := RabbitI18n.ReadCatalog(directory . "\en-US.ini")
        AssertEqual(0, RabbitI18n.Validate(reference, translated).Length, "English catalog is inconsistent.")
    } finally {
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}

TestRabbitI18nValidation() {
    local previous := RabbitI18n.messages
    try {
        RabbitI18n.messages := Map("test.message", "{second}: {first} {first}")
        AssertEqual("B: {second} {second}",
            RabbitI18n.Text("test.message", Map("first", "{second}", "second", "B")),
            "Substitution changed placeholder-looking user data.")
        AssertEqual("line`nnext\n", RabbitI18n.Decode("line\nnext\\n"), "Escapes were decoded incorrectly.")
        AssertEqual(4, RabbitI18n.Validate(Map("a", "{name}", "b", "text"),
            Map("a", "{other}", "extra", "text")).Length, "Catalog errors were not detected.")
    } finally {
        RabbitI18n.messages := previous
    }
}

TestRabbitI18nParser() {
    local path := A_Temp . "\rabbit-i18n-" . DllCall("GetCurrentProcessId") . ".ini"
    local catalog, rejected, content
    try {
        FileAppend("[test]`nmessage=你好=a;b\nnext`n", path, "UTF-8-RAW")
        catalog := RabbitI18n.ReadCatalog(path)
        AssertEqual("你好=a;b`nnext", catalog["test.message"], "UTF-8 or value punctuation was lost.")
        for content in ["[test]`na=one`na=two", "missing section", "[test]`na=\q"] {
            FileDelete(path)
            FileAppend(content, path, "UTF-8-RAW")
            rejected := false
            try {
                RabbitI18n.ReadCatalog(path)
            } catch {
                rejected := true
            }
            AssertTrue(rejected, "Invalid catalog was accepted: " . content)
        }
    } finally {
        if FileExist(path) {
            FileDelete(path)
        }
    }
    AssertEqual(0, RabbitI18n.ReadCatalog(path).Count, "Missing catalog did not return an empty map.")
}

TestRabbitI18nConfig() {
    local directory := A_LineFile . "\..\..\..\locales"
    local api := RabbitI18nConfigFake()
    try {
        RabbitI18n.LoadConfig(api, directory)
        AssertEqual("en-US", RabbitI18n.locale, "Deployed preference was not loaded.")
        AssertTrue(api.closed, "Deployed configuration was not closed.")
        api.value := "zh-CN"
        RabbitI18n.LoadConfig(api, directory)
        AssertEqual("zh-CN", RabbitI18n.locale, "Changed deployed preference was not loaded.")
    } finally {
        RabbitI18n.Initialize(directory, "zh-CN")
    }
}

class RabbitI18nConfigFake {
    value := "en-US"
    closed := false

    config_open(name) {
        AssertEqual("rabbit", name, "Language must use the deployed rabbit configuration.")
        this.closed := false
        return 42
    }

    config_get_string(config, key) {
        AssertEqual(42, config, "Wrong configuration handle.")
        AssertEqual("language", key, "Wrong language configuration key.")
        return this.value
    }

    config_close(config) {
        AssertEqual(42, config, "Wrong closed configuration handle.")
        this.closed := true
    }
}

RunTest("embedded catalog matches the Chinese source", TestEmbeddedCatalogMatchesSource.Bind())
RunTest("missing and damaged catalogs retain a usable UI", TestMissingLocaleFallback.Bind())

TestEmbeddedCatalogMatchesSource() {
    local source := RabbitI18n.ReadCatalog(A_LineFile . "\..\..\..\locales\zh-CN.ini")
    local embedded := RabbitLocaleFallback.Create(), key, value
    AssertEqual(source.Count, embedded.Count, "Regenerate the embedded fallback after editing Chinese translations.")
    for key, value in source {
        AssertTrue(embedded.Has(key), "Missing embedded key: " . key)
        AssertEqual(value, embedded[key], "Stale embedded translation: " . key)
    }
}

TestMissingLocaleFallback() {
    local directory := A_Temp . "\rabbit-missing-locales-" . DllCall("GetCurrentProcessId")
    local repository_catalogs := A_LineFile . "\..\..\..\locales"
    try {
        RabbitI18n.Initialize(directory, "en-US")
        AssertEqual("输入法设定", RabbitI18n.Text("tray.settings"), "Missing locale directory exposed keys.")
        AssertEqual(2, RabbitI18n.diagnostics.Length, "Missing catalogs were not reported.")
        DirCreate(directory)
        FileAppend("[tray]`nsettings=Custom English", directory . "\en-US.ini", "UTF-8-RAW")
        RabbitI18n.Initialize(directory, "en-US")
        AssertEqual("Custom English", RabbitI18n.Text("tray.settings"), "Existing translation was ignored.")
        AssertEqual("取消", RabbitI18n.Text("common.cancel"), "Missing Chinese catalog disabled fallback.")
        FileAppend("[broken", directory . "\zh-CN.ini", "UTF-8-RAW")
        RabbitI18n.Initialize(directory, "zh-CN")
        AssertEqual("取消", RabbitI18n.Text("common.cancel"), "Malformed catalog disabled fallback.")
        AssertEqual(1, RabbitI18n.diagnostics.Length, "Malformed catalog was not reported.")
    } finally {
        for name in ["en-US.ini", "zh-CN.ini"] {
            if FileExist(directory . "\" . name) {
                FileDelete(directory . "\" . name)
            }
        }
        if DirExist(directory) {
            DirDelete(directory)
        }
        RabbitI18n.Initialize(repository_catalogs, "zh-CN")
    }
}
