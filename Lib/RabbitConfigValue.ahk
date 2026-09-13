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

class RabbitConfigValue {
    static Read(api, config, key, &value) {
        local item, iter, child
        if (iter := api.config_begin_map(config, key)) {
            try {
                value := Map()
                while api.config_next(iter) {
                    item := api.config_get_item(config, iter.path)
                    if item {
                        try {
                            if this.Read(api, item, "/", &child) {
                                value[iter.key] := child
                            }
                        } finally {
                            api.config_close(item)
                        }
                    }
                }
                return true
            } finally {
                api.config_end(iter)
            }
        }
        if (iter := api.config_begin_list(config, key)) {
            try {
                value := []
                while api.config_next(iter) {
                    item := api.config_get_item(config, iter.path)
                    if item {
                        try {
                            if this.Read(api, item, "/", &child) {
                                value.Push(child)
                            }
                        } finally {
                            api.config_close(item)
                        }
                    }
                }
                return true
            } finally {
                api.config_end(iter)
            }
        }
        if api.config_test_get_string(config, key, &value) {
            return true
        }
        if api.config_test_get_int(config, key, &value) {
            return true
        }
        if api.config_test_get_double(config, key, &value) {
            return true
        }
        if api.config_test_get_bool(config, key, &value) {
            return true
        }
        return false
    }

    static Clone(value) {
        local copy, item, key
        if value is Map {
            copy := Map()
            for key, item in value {
                copy[key] := this.Clone(item)
            }
            return copy
        }
        if value is Array {
            copy := []
            for item in value {
                copy.Push(this.Clone(item))
            }
            return copy
        }
        return value
    }

    static ValuesEqual(left, right) {
        local key, value
        if left is Map {
            if !(right is Map) || left.Count != right.Count {
                return false
            }
            for key, value in left {
                if !right.Has(key) || !this.ValuesEqual(value, right[key]) {
                    return false
                }
            }
            return true
        }
        if left is Array {
            if !(right is Array) || left.Length != right.Length {
                return false
            }
            Loop left.Length {
                if !this.ValuesEqual(left[A_Index], right[A_Index]) {
                    return false
                }
            }
            return true
        }
        return !(right is Map) && !(right is Array) && left == right && Type(left) = Type(right)
    }

    static ToYaml(value) {
        local parts, item, key
        if value is Map {
            parts := []
            for key, item in value {
                parts.Push(this.QuoteYaml(key) . ": " . this.ToYaml(item))
            }
            return "{" . this.Join(parts, ", ") . "}"
        }
        if value is Array {
            parts := []
            for item in value {
                parts.Push(this.ToYaml(item))
            }
            return "[" . this.Join(parts, ", ") . "]"
        }
        if Type(value) = "Integer" || Type(value) = "Float" {
            return String(value)
        }
        return this.QuoteYaml(value)
    }

    static QuoteYaml(value) {
        local escaped := StrReplace(String(value), "\", "\\")
        escaped := StrReplace(escaped, '"', '\"')
        escaped := StrReplace(escaped, "`r", "\r")
        escaped := StrReplace(escaped, "`n", "\n")
        return '"' . escaped . '"'
    }

    static Join(items, separator) {
        local result := ""
        for item in items {
            result .= (result ? separator : "") . item
        }
        return result
    }
}
