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

#Include RabbitLocaleFallback.ahk

class RabbitI18n {
    static locale := "zh-CN"
    static fallback := Map()
    static messages := Map()
    static diagnostics := []
    static directory := ""

    static LoadStartupConfig(rime_api, path, directory := A_ScriptDir . "\Locales") {
        local config := 0, preference := "auto", diagnostic := ""
        ; Read only the deployed YAML before Rime starts maintenance or command-line validation.
        try {
            if FileExist(path) {
                config := rime_api.config_load_string(FileRead(path, "UTF-8"))
                if config {
                    preference := rime_api.config_get_string(config, "language")
                    if !preference {
                        preference := "auto"
                    }
                }
            }
        } catch as err {
            diagnostic := err.Message
        } finally {
            if config {
                rime_api.config_close(config)
            }
        }
        this.Initialize(directory, preference)
        if diagnostic {
            this.diagnostics.Push(diagnostic)
        }
    }

    static LoadConfig(rime_api, directory := A_ScriptDir . "\Locales") {
        this.Initialize(directory, this.ReadPreference(rime_api))
    }

    static ReadPreference(rime_api) {
        local config := rime_api.config_open("rabbit"), preference := "auto"
        if config {
            try {
                preference := rime_api.config_get_string(config, "language")
                if !preference {
                    preference := "auto"
                }
            } finally {
                rime_api.config_close(config)
            }
        }
        return preference
    }

    static Initialize(directory, preference := "auto", system_locale := "") {
        local key, value
        this.directory := directory
        this.diagnostics := []
        this.fallback := RabbitLocaleFallback.Create()
        for key, value in this.ReadOptionalCatalog(directory . "\zh-CN.ini") {
            if value != "" {
                this.fallback[key] := value
            }
        }
        this.locale := this.ResolveLocale(preference, system_locale)
        this.messages := this.locale = "zh-CN" ? this.fallback.Clone()
            : this.ReadOptionalCatalog(directory . "\" . this.locale . ".ini")
    }

    static ResolveLocale(preference, system_locale := "") {
        local selected, alias, language
        if !system_locale {
            local locale_buffer := Buffer(170, 0)
            if DllCall("GetUserDefaultLocaleName", "Ptr", locale_buffer, "Int", 85) {
                system_locale := StrGet(locale_buffer)
            }
        }
        selected := preference = "auto" ? system_locale : preference
        if (alias := this.OfficialAlias(selected)) {
            return alias
        }
        for language in this.GetLanguages() {
            if selected = language.code {
                return language.code
            }
        }
        ; Unavailable regional variants can still use an official language family.
        ; Never construct a path directly from an unrecognized preference.
        if RegExMatch(selected, "i)^en(?:-|$)") {
            return "en-US"
        }
        if RegExMatch(selected, "i)^zh-(?:Hant-)?(?:HK|MO)(?:-|$)") {
            return "zh-HK"
        }
        if RegExMatch(selected, "i)^zh-(?:TW|Hant)(?:-|$)") {
            return "zh-TW"
        }
        return "zh-CN"
    }

    static OfficialAlias(code) {
        switch StrLower(code) {
            case "zh", "zh-hans", "zh-cn": return "zh-CN"
            case "zh-hant", "zh-tw": return "zh-TW"
            case "zh-hk": return "zh-HK"
            case "en", "en-us": return "en-US"
        }
        return ""
    }

    static GetLanguages(directory := "") {
        local languages := [
            {code: "zh-CN", name: "简体中文"},
            {code: "en-US", name: "English"},
            {code: "zh-HK", name: "繁體中文（香港）"},
            {code: "zh-TW", name: "繁體中文（台灣）"}
        ]
        local files := "", path, code, metadata, name, language, seen := Map()
        seen.CaseSense := "Off"
        for language in languages {
            seen[language.code] := true
        }
        if !directory {
            directory := this.directory ? this.directory
                : (A_IsCompiled ? A_ScriptDir . "\Locales" : A_LineFile . "\..\..\Locales")
        }
        Loop Files directory . "\*.ini", "F" {
            files .= A_LoopFileName . "`n"
        }
        ; Stable ordering keeps the language picker predictable across filesystem changes.
        for name in StrSplit(Sort(files), "`n") {
            if !name {
                continue
            }
            code := SubStr(name, 1, -4)
            if !RegExMatch(code, "i)^[a-z]{2,8}(?:-[a-z0-9]{1,8})*$")
                || this.OfficialAlias(code) || code = "auto" || seen.Has(code) {
                continue
            }
            path := directory . "\" . name
            metadata := this.ReadMetadata(path)
            if !metadata.Has("locale") || !metadata.Has("language_name")
                || metadata["locale"] != code || !Trim(metadata["language_name"]) {
                continue
            }
            seen[code] := true
            languages.Push({code: metadata["locale"], name: metadata["language_name"]})
        }
        return languages
    }

    static ReadMetadata(path) {
        local metadata := Map(), section := "", line, match
        try {
            ; Discovery reads metadata only; partial translations need no completeness validation.
            for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
                line := Trim(line)
                if RegExMatch(line, "^\[([^]]+)\]$", &match) {
                    section := match[1]
                } else if section == "meta"
                    && RegExMatch(line, "^(locale|language_name)=(.*)$", &match) {
                    if metadata.Has(match[1]) {
                        return Map()
                    }
                    metadata[match[1]] := Trim(match[2])
                }
            }
        } catch {
            return Map()
        }
        return metadata
    }

    static ReadOptionalCatalog(path) {
        if !FileExist(path) {
            this.Report("Translation catalog missing: " . path)
            return Map()
        }
        try {
            return this.ReadCatalog(path)
        } catch as err {
            this.Report("Translation catalog ignored: " . path . " (" . err.Message . ")")
            return Map()
        }
    }

    static Report(message) {
        this.diagnostics.Push(message)
        OutputDebug(message)
    }

    static ReadCatalog(path) {
        local result := Map(), section := "", line, match, key
        result.CaseSense := "On"
        if !FileExist(path) {
            return result
        }
        ; Read UTF-8 explicitly: Windows profile APIs assume ANSI for BOM-less INI files.
        for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
            line := Trim(line)
            if !line || SubStr(line, 1, 1) = ";" {
                continue
            }
            if RegExMatch(line, "^\[([a-zA-Z0-9_]+)\]$", &match) {
                section := match[1]
            } else if section && RegExMatch(line, "^([a-zA-Z0-9_]+)=(.*)$", &match) {
                key := section . "." . match[1]
                if result.Has(key) {
                    throw Error("Duplicate translation key: " . key, , path)
                }
                result[key] := this.Decode(match[2])
            } else {
                throw Error("Invalid translation line: " . line, , path)
            }
        }
        return result
    }

    static Decode(value) {
        local result := "", index := 1, char, escaped
        while index <= StrLen(value) {
            char := SubStr(value, index++, 1)
            if char = "\" && index <= StrLen(value) {
                escaped := SubStr(value, index++, 1)
                switch escaped {
                    case "n": result .= "`n"
                    case "r": result .= "`r"
                    case "\": result .= "\"
                    default: throw Error("Unknown translation escape: \" . escaped)
                }
            } else {
                result .= char
            }
        }
        return result
    }

    static Text(key, values := 0) {
        local template, result := "", position := 1, found, match
        if !this.fallback.Count {
            this.Initialize(A_IsCompiled ? A_ScriptDir . "\Locales" : A_LineFile . "\..\..\Locales", "zh-CN")
        }
        if this.messages.Has(key) && this.messages[key] != "" {
            template := this.messages[key]
        } else if this.fallback.Has(key) {
            template := this.fallback[key]
        } else {
            OutputDebug("Missing translation: " . key)
            return key
        }
        ; Substitute once so placeholder-looking user data stays literal.
        while (found := RegExMatch(template, "\{([a-zA-Z_][a-zA-Z0-9_]*)\}", &match, position)) {
            result .= SubStr(template, position, found - position)
            result .= IsObject(values) && values.Has(match[1]) ? values[match[1]] : match[0]
            position := found + StrLen(match[0])
        }
        return result . SubStr(template, position)
    }

    static Placeholders(value) {
        local result := Map(), position := 1, found, match
        while (found := RegExMatch(value, "\{([a-zA-Z_][a-zA-Z0-9_]*)\}", &match, position)) {
            result[match[1]] := true
            position := found + StrLen(match[0])
        }
        return result
    }

    static Validate(reference, translated) {
        local errors := [], key, value, expected, actual, name
        for key, value in reference {
            if !translated.Has(key) || translated[key] = "" {
                errors.Push("Missing translation: " . key)
                continue
            }
            expected := this.Placeholders(value)
            actual := this.Placeholders(translated[key])
            for name in expected {
                if !actual.Has(name) {
                    errors.Push("Missing placeholder: " . key . " {" . name . "}")
                }
            }
            for name in actual {
                if !expected.Has(name) {
                    errors.Push("Unexpected placeholder: " . key . " {" . name . "}")
                }
            }
        }
        for key in translated {
            if !reference.Has(key) {
                errors.Push("Unknown translation key: " . key)
            }
        }
        return errors
    }
}
