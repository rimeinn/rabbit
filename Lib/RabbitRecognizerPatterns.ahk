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

class RabbitRecognizerPatterns {
    static PATH := "recognizer/patterns"
    static USE_SPACE_PATH := "recognizer/use_space"

    static Read(api, config, path := this.PATH) {
        local value
        if !RabbitConfigValue.Read(api, config, path, &value) {
            return Map()
        }
        return this.Validate(value)
    }

    static Validate(value) {
        local tag, pattern, result := Map()
        if !(value is Map) {
            throw ValueError(RabbitI18n.Text("recognizer.patterns_invalid"))
        }
        for tag, pattern in value {
            this.ValidateTag(tag)
            if pattern is Map || pattern is Array {
                throw ValueError(RabbitI18n.Text("recognizer.pattern_invalid"))
            }
            result[String(tag)] := String(pattern)
        }
        return result
    }

    static ValidateTag(tag) {
        tag := String(tag)
        if !tag {
            throw ValueError(RabbitI18n.Text("recognizer.pattern_tag_required"))
        }
        if InStr(tag, "`r") || InStr(tag, "`n") {
            throw ValueError(RabbitI18n.Text("recognizer.pattern_tag_invalid"))
        }
        return tag
    }

    static Summary(value) {
        local count := value is Map ? value.Count : 0
        return RabbitI18n.Text("recognizer.pattern_summary", Map("count", count))
    }

    static DisplayValue(value) {
        local result := StrReplace(StrReplace(String(value), "`r", ""), "`n", "\\n")
        return StrLen(result) > 120 ? SubStr(result, 1, 117) . "..." : result
    }
}
