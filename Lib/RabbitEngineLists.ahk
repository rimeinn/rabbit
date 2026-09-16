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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

class RabbitEngineLists {
    static PATH := "engine"
    static NAMES := ["processors", "segmentors", "translators", "filters"]

    static ListPath(name) {
        local known_name
        for known_name in this.NAMES {
            if known_name = name {
                return this.PATH . "/" . name
            }
        }
        throw ValueError("Unknown engine list: " . name)
    }

    static Validate(value) {
        local item, items, name, result := Map()
        if !(value is Map) {
            throw ValueError("Expected a map of engine lists.")
        }
        for name in this.NAMES {
            if !value.Has(name) || !(items := value[name]) is Array {
                throw ValueError("Expected a string list for engine/" . name . ".")
            }
            result[name] := []
            for item in items {
                if item is Map || item is Array || Type(item) != "String" || InStr(item, "`r") || InStr(item, "`n") {
                    throw ValueError("Expected a string list for engine/" . name . ".")
                }
                result[name].Push(item)
            }
        }
        return result
    }
}
