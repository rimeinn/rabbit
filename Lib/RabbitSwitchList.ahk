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

class RabbitSwitchList {
    static PATH := "switches"
    static TOGGLE := "toggle"
    static RADIO := "radio"

    static Read(api, config, path := this.PATH) {
        local value
        if !RabbitConfigValue.Read(api, config, path, &value) {
            return []
        }
        return this.Validate(value)
    }

    static Validate(value) {
        local item, result := []
        if !(value is Array) {
            throw ValueError(RabbitI18n.Text("switch_list.list_invalid"))
        }
        for item in value {
            result.Push(this.ValidateItem(item))
        }
        return result
    }

    static ValidateItem(value) {
        local item, name, option, options, reset, states, abbrev
        if !(value is Map) {
            throw ValueError(RabbitI18n.Text("switch_list.entry_invalid"))
        }
        if value.Has("name") = value.Has("options") {
            throw ValueError(RabbitI18n.Text("switch_list.kind_required"))
        }
        item := RabbitConfigValue.Clone(value)
        if value.Has("name") {
            name := this.ValidateText(value["name"], "switch_list.name_invalid")
            if !Trim(name) {
                throw ValueError(RabbitI18n.Text("switch_list.name_required"))
            }
            item["name"] := name
        } else {
            options := value["options"]
            if !(options is Array) || !options.Length {
                throw ValueError(RabbitI18n.Text("switch_list.options_required"))
            }
            item["options"] := this.ValidateTextList(options, "switch_list.option_invalid")
            for option in item["options"] {
                if !Trim(option) {
                    throw ValueError(RabbitI18n.Text("switch_list.option_required"))
                }
            }
            if this.HasDuplicate(item["options"]) {
                throw ValueError(RabbitI18n.Text("switch_list.option_duplicate"))
            }
        }
        if value.Has("states") {
            states := value["states"]
            if !(states is Array) {
                throw ValueError(RabbitI18n.Text("switch_list.states_invalid"))
            }
            item["states"] := this.ValidateTextList(states, "switch_list.state_invalid")
        }
        if value.Has("abbrev") {
            abbrev := value["abbrev"]
            if !(abbrev is Array) {
                throw ValueError(RabbitI18n.Text("switch_list.abbrev_invalid"))
            }
            item["abbrev"] := this.ValidateTextList(abbrev, "switch_list.abbrev_invalid")
        }
        if value.Has("reset") {
            reset := value["reset"]
            if Type(reset) = "String" && RegExMatch(Trim(reset), "^-?\d+$") {
                reset := Integer(Trim(reset))
            }
            if Type(reset) != "Integer" || reset < -1 {
                throw ValueError(RabbitI18n.Text("switch_list.reset_invalid"))
            }
            if reset >= 0 {
                if value.Has("name") && reset > 1 {
                    throw ValueError(RabbitI18n.Text("switch_list.reset_invalid"))
                }
                if value.Has("options") && reset >= item["options"].Length {
                    throw ValueError(RabbitI18n.Text("switch_list.reset_invalid"))
                }
            }
            item["reset"] := reset
        }
        return item
    }

    static ValidateTextList(value, error_key) {
        local item, result := []
        for item in value {
            result.Push(this.ValidateText(item, error_key))
        }
        return result
    }

    static ValidateText(value, error_key) {
        if value is Map || value is Array || Type(value) != "String"
            || InStr(value, "`r") || InStr(value, "`n") {
            throw ValueError(RabbitI18n.Text(error_key))
        }
        return value
    }

    static HasDuplicate(values) {
        local value, seen := Map()
        for value in values {
            if seen.Has(value) {
                return true
            }
            seen[value] := true
        }
        return false
    }

    static Kind(value) {
        return value is Map && value.Has("name") ? this.TOGGLE : this.RADIO
    }

    static OptionNames(value) {
        return this.Kind(value) = this.TOGGLE ? [value["name"]] : value["options"]
    }

    static Options(value) {
        return this.Kind(value) = this.TOGGLE ? [] : value["options"]
    }

    static States(value) {
        return value is Map && value.Has("states") && value["states"] is Array
            ? value["states"] : []
    }

    static Abbreviations(value) {
        return value is Map && value.Has("abbrev") && value["abbrev"] is Array
            ? value["abbrev"] : []
    }

    static Reset(value) {
        return value is Map && value.Has("reset") && Type(value["reset"]) = "Integer"
            ? value["reset"] : -1
    }

    static TypeLabel(value) {
        return this.Kind(value) = this.TOGGLE
            ? RabbitI18n.Text("switch_list.toggle") : RabbitI18n.Text("switch_list.radio")
    }

    static OptionSummary(value) {
        local option, options := this.OptionNames(value), result := ""
        for option in options {
            result .= (result ? ", " : "") . option
        }
        return result
    }

    static StateSummary(value) {
        local state, states := this.States(value), result := ""
        for state in states {
            result .= (result ? " / " : "") . state
        }
        return result ? result : RabbitI18n.Text("switch_list.no_states")
    }

    static ResetSummary(value) {
        local reset := this.Reset(value), states := this.States(value)
        if reset < 0 {
            return RabbitI18n.Text("switch_list.no_default")
        }
        return reset + 1 <= states.Length && states[reset + 1]
            ? states[reset + 1] : String(reset)
    }

    static Summary(value) {
        local count := value is Array ? value.Length : 0
        return RabbitI18n.Text("switch_list.summary", Map("count", count))
    }
}
