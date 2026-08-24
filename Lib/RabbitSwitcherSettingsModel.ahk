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

#Include RabbitCommon.ahk

class RabbitSwitcherSettingsModel {
    __New(levers_api, rime_api) {
        this.api := levers_api
        this.rime := rime_api
        this.settings := 0
        this.items := []
        this.hotkeys := ""
        this.disposed := false

        try {
            this.settings := this.api.switcher_settings_init()
            if !this.settings || !this.Load() {
                throw Error("未能读取输入方案设置。")
            }
        } catch {
            this.Dispose()
            throw
        }
    }

    Load() {
        local available := 0
        local selected := 0
        local available_items := Map()
        local selected_ids := Map()
        local info, schema_id, selected_item
        if !this.api.load_settings(this.settings) {
            return false
        }

        try {
            available := this.api.get_available_schema_list(this.settings)
            selected := this.api.get_selected_schema_list(this.settings)
            if !available || !selected {
                return false
            }

            Loop available.size {
                info := this.CopySchemaInfo(available.list[A_Index])
                available_items[info.id] := info
            }

            this.items := []
            Loop selected.size {
                selected_item := selected.list[A_Index]
                schema_id := selected_item.schema_id
                if selected_ids.Has(schema_id) {
                    continue
                }
                selected_ids[schema_id] := true
                if available_items.Has(schema_id) {
                    info := available_items[schema_id]
                } else {
                    info := {
                        id: schema_id,
                        name: selected_item.name,
                        author: "",
                        description: "",
                    }
                }
                this.items.Push({
                    id: info.id,
                    name: info.name,
                    author: info.author,
                    description: info.description,
                    selected: true,
                })
            }

            for schema_id, available_info in available_items {
                if selected_ids.Has(schema_id) {
                    continue
                }
                this.items.Push({
                    id: available_info.id,
                    name: available_info.name,
                    author: available_info.author,
                    description: available_info.description,
                    selected: false,
                })
            }
            this.hotkeys := this.api.get_hotkeys(this.settings)
            return true
        } finally {
            if selected {
                this.api.schema_list_destroy(selected)
            }
            if available {
                this.api.schema_list_destroy(available)
            }
        }
    }

    CopySchemaInfo(item) {
        local info := RimeSchemaInfo(item)
        return {
            id: this.api.get_schema_id(info),
            name: this.api.get_schema_name(info),
            author: this.api.get_schema_author(info),
            description: this.api.get_schema_description(info),
        }
    }

    Save(schema_ids, hotkeys) {
        if schema_ids.Length = 0 {
            return false
        }
        if !this.api.load_settings(this.settings) {
            return false
        }
        if !this.api.select_schemas(this.settings, schema_ids) {
            return false
        }
        if !this.CustomizeHotkeys(hotkeys) {
            return false
        }
        return !!this.api.save_settings(this.settings)
    }

    CustomizeHotkeys(hotkeys) {
        local config := 0
        local escaped, hotkey, item_count := 0
        local yaml := "["
        Loop Parse hotkeys, "," {
            hotkey := Trim(A_LoopField)
            if !hotkey {
                continue
            }
            escaped := StrReplace(StrReplace(hotkey, "\", "\\"), '"', '\"')
            yaml .= (item_count ? ", " : "") . '"' . escaped . '"'
            item_count += 1
        }
        yaml .= "]"

        if !(config := this.rime.config_load_string(yaml)) {
            return false
        }
        try {
            return !!this.api.customize_item(this.settings, "switcher/hotkeys", config)
        } finally {
            this.rime.config_close(config)
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        if this.settings {
            this.api.custom_settings_destroy(this.settings)
            this.settings := 0
        }
        this.items := []
    }

    __Delete() {
        this.Dispose()
    }
}
