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

#Include RabbitConfigValue.ahk

#Include RabbitI18n.ahk

class RabbitPunctuatorMap {
    static FULL_SHAPE_PATH := "punctuator/full_shape"
    static HALF_SHAPE_PATH := "punctuator/half_shape"
    static SYMBOLS_PATH := "punctuator/symbols"
    static USE_SPACE_PATH := "punctuator/use_space"
    static DIGIT_SEPARATORS_PATH := "punctuator/digit_separators"
    static DIGIT_SEPARATOR_ACTION_PATH := "punctuator/digit_separator_action"
    static DIGIT_SEPARATORS_DEFAULT := ".:"
    static DIGIT_SEPARATOR_ACTIONS := ["forward", "commit"]
    static DIGIT_SEPARATOR_ACTION_DEFAULT := "forward"
    static PATHS := [this.FULL_SHAPE_PATH, this.HALF_SHAPE_PATH, this.SYMBOLS_PATH]
    static TYPE_VALUES := ["direct", "list", "pair", "commit", "custom"]

    static IsEditablePath(path) {
        return path = this.FULL_SHAPE_PATH || path = this.HALF_SHAPE_PATH || path = this.SYMBOLS_PATH
    }

    static IsShapePath(path) {
        return path = this.FULL_SHAPE_PATH || path = this.HALF_SHAPE_PATH
    }

    static PathLabel(path) {
        switch path {
            case this.FULL_SHAPE_PATH: return RabbitI18n.Text("punctuator.full_shape")
            case this.HALF_SHAPE_PATH: return RabbitI18n.Text("punctuator.half_shape")
            case this.SYMBOLS_PATH: return RabbitI18n.Text("punctuator.symbols")
        }
        return path
    }

    static Read(api, config, path) {
        local value
        if !RabbitConfigValue.Read(api, config, path, &value) {
            ; librime's symbols map is optional in the minimal default preset.
            return Map()
        }
        if !(value is Map) {
            throw Error(RabbitI18n.Text("punctuator.map_invalid"))
        }
        return this.Validate(value, path)
    }

    static Validate(value, path) {
        local definition, key, result := Map()
        if !this.IsEditablePath(path) || !(value is Map) {
            throw ValueError(RabbitI18n.Text("punctuator.map_invalid"))
        }
        for key, definition in value {
            this.ValidateKey(key, path)
            this.ValidateDefinition(definition)
            result[String(key)] := RabbitConfigValue.Clone(definition)
        }
        return result
    }

    static ValidateKey(key, path) {
        key := String(key)
        if !key {
            throw ValueError(RabbitI18n.Text("punctuator.key_required"))
        }
        if this.IsShapePath(path) && (StrLen(key) != 1 || Ord(key) < 0x20 || Ord(key) > 0x7e) {
            throw ValueError(RabbitI18n.Text("punctuator.shape_key_invalid"))
        }
        return true
    }

    static ValidateDefinition(definition) {
        local item
        if definition is Map {
            if definition.Has("commit") && !this.IsScalar(definition["commit"]) {
                throw ValueError(RabbitI18n.Text("punctuator.definition_invalid"))
            }
            if definition.Has("pair") {
                if !(definition["pair"] is Array) || definition["pair"].Length != 2 {
                    throw ValueError(RabbitI18n.Text("punctuator.definition_invalid"))
                }
                for item in definition["pair"] {
                    if !this.IsScalar(item) {
                        throw ValueError(RabbitI18n.Text("punctuator.definition_invalid"))
                    }
                }
            }
            return true
        }
        if definition is Array {
            if !definition.Length {
                throw ValueError(RabbitI18n.Text("punctuator.definition_invalid"))
            }
            for item in definition {
                if !this.IsScalar(item) {
                    throw ValueError(RabbitI18n.Text("punctuator.definition_invalid"))
                }
            }
            return true
        }
        if !this.IsScalar(definition) {
            throw ValueError(RabbitI18n.Text("punctuator.definition_invalid"))
        }
        return true
    }

    static IsScalar(value) {
        return !(value is Map) && !(value is Array)
    }

    static DefinitionKind(definition) {
        if definition is Map {
            if definition.Has("commit") {
                return "commit"
            }
            if definition.Has("pair") {
                return "pair"
            }
            return "custom"
        }
        return definition is Array ? "list" : "direct"
    }

    static DefinitionTypeLabel(definition) {
        switch this.DefinitionKind(definition) {
            case "direct": return RabbitI18n.Text("punctuator.type_direct")
            case "list": return RabbitI18n.Text("punctuator.type_list")
            case "pair": return RabbitI18n.Text("punctuator.type_pair")
            case "commit": return RabbitI18n.Text("punctuator.type_commit")
            default: return RabbitI18n.Text("punctuator.type_custom")
        }
    }

    static DefinitionSummary(definition) {
        local parts := [], item
        switch this.DefinitionKind(definition) {
            case "direct": return this.DisplayValue(definition)
            case "commit": return RabbitI18n.Text("punctuator.commit_summary", Map(
                "value", this.DisplayValue(definition["commit"])
            ))
            case "pair":
                return this.DisplayValue(definition["pair"][1]) . " → " . this.DisplayValue(definition["pair"][2])
            case "list":
                for item in definition {
                    parts.Push(this.DisplayValue(item))
                }
                return "[" . RabbitConfigValue.Join(parts, " | ") . "]"
            default:
                return RabbitConfigValue.ToYaml(definition)
        }
    }

    static DisplayValue(value) {
        local result := String(value)
        result := StrReplace(result, "`r", "")
        result := StrReplace(result, "`n", "\\n")
        return StrLen(result) > 80 ? SubStr(result, 1, 77) . "..." : result
    }

    static Summary(value) {
        local count := value is Map ? value.Count : 0
        return RabbitI18n.Text("punctuator.map_summary", Map("count", count))
    }

    static ValidateDigitSeparators(value) {
        local code
        value := String(value)
        Loop Parse value {
            code := Ord(A_LoopField)
            if !this.IsAsciiPunctuationCode(code) {
                throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map(
                    "field", RabbitI18n.Text("punctuator.digit_separators")
                )))
            }
        }
        return value
    }

    static IsAsciiPunctuationCode(code) {
        return (code >= 0x21 && code <= 0x2f)
            || (code >= 0x3a && code <= 0x40)
            || (code >= 0x5b && code <= 0x60)
            || (code >= 0x7b && code <= 0x7e)
    }

    static NormalizeDigitSeparatorAction(value) {
        return String(value) = "commit" ? "commit" : this.DIGIT_SEPARATOR_ACTION_DEFAULT
    }

    static ValidateDigitSeparatorAction(value) {
        value := String(value)
        if value != "forward" && value != "commit" {
            throw ValueError(RabbitI18n.Text("models.schema_settings_value", Map(
                "field", RabbitI18n.Text("punctuator.digit_separator_action")
            )))
        }
        return value
    }
}
