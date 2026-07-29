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

#Include <RabbitCommon>

class SwitcherSettingsDialog extends Gui {
    available_schemas := 0
    selected_schemas := 0

    __New(settings, levers_api) {
        local EM_SETCUEBANNER
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】方案选单设定", this)
        this.settings := settings
        this.loaded := false
        this.modified := false
        this.api := levers_api
        this.accepted := false
        this.disposed := false

        this.item_data := Map()

        ; Layout
        this.MarginX := 15
        this.MarginY := 15
        this.AddText(, "请勾选所需的输入方案：")
        this.schema_list := this.AddListView("Section Checked NoSort w220 h175", ["方案名称"])
        this.schema_list.OnEvent("Click", (ctrl, lvid) => this.OnSchemaListClick(lvid))
        this.schema_list.OnEvent("ItemCheck", (ctrl, lvid, checked) => this.OnSchemaListItemCheck(lvid, checked))
        this.description := this.AddText("YP w285 h175", "选中列表中的输入方案以查看简介")
        this.AddText("XS", "在玉兔毫里，以下快捷键可唤出方案选单，以切换模式或选用其他输入方案。")
        this.hotkeys := this.AddEdit("-Multi ReadOnly r1 w505")
        this.proxy_prompt := this.AddText("XS", "代理服务器：")
        this.proxy := this.AddEdit("X+10 -Multi r1 w300")
        DllCall("SendMessage", "Ptr", this.proxy.Hwnd, "UInt", EM_SETCUEBANNER := 0x1501, "UPtr", true, "WStr", "如 http://127.0.0.1:7890", "Ptr")
        this.use_git := this.AddCheckbox("X+20", "使用 Git")
        this.use_git.Value := 1
        this.more_schemas := this.AddButton("XS w155", "获取更多输入方案…")
        this.more_schemas.OnEvent("Click", (*) => this.OnGetSchema())
        this.ok := this.AddButton("X+60 YP w90", "中")
        this.ok.OnEvent("Click", (*) => this.OnOK())

        try {
            this.Populate()
        } catch {
            this.Dispose()
            throw
        }
    }

    Populate() {
        local item, info, row, txt
        if !this.settings {
            return
        }
        this.item_data := Map()
        this.ReleaseSchemaLists()
        local available := this.api.get_available_schema_list(this.settings)
        local selected := 0
        try {
            selected := this.api.get_selected_schema_list(this.settings)
        } catch {
            this.api.schema_list_destroy(available)
            throw
        }
        this.available_schemas := available
        this.selected_schemas := selected
        this.schema_list.Delete()

        local recruited := Map()

        local selected_list := selected.list
        local available_list := available.list
        Loop selected.size {
            local schema_id := selected_list[A_Index].schema_id
            Loop available.size {
                item := available_list[A_Index]
                info := RimeSchemaInfo(item)
                if item.schema_id == schema_id && (!recruited.Has(info.Ptr) || recruited[info.Ptr] == false) {
                    recruited[info.Ptr] := true
                    row := this.schema_list.Add("Check", item.name)
                    this.item_data[row] := info
                    break
                }
            }
        }
        Loop available.size {
            item := available_list[A_Index]
            info := RimeSchemaInfo(item)
            if !recruited.Has(info.Ptr) || recruited[info.Ptr] == false {
                recruited[info.Ptr] := true
                row := this.schema_list.Add(, item.name)
                this.item_data[row] := info
            }
        }
        txt := this.api.get_hotkeys(this.settings)
        this.hotkeys.Value := txt
        this.loaded := true
        this.modified := false
    }

    OnSchemaListClick(lvid) {
        if !this.loaded || !this.schema_list || lvid <= 0 || lvid > this.schema_list.GetCount() {
            return
        }
        this.ShowDetails(this.item_data[lvid])
    }

    OnSchemaListItemCheck(lvid, checked) {
        if !this.loaded || !this.schema_list || lvid <= 0 || lvid > this.schema_list.GetCount() {
            return
        }
        this.modified := true
    }

    ShowDetails(info) {
        local details, name, author, description
        if !info {
            return
        }
        details := ""
        if (name := this.api.get_schema_name(info)) {
            details .= name
        }
        if (author := this.api.get_schema_author(info)) {
            details .= "`r`n`r`n" . author
        }
        if (description := this.api.get_schema_description(info)) {
            details .= "`r`n`r`n" . description
        }
        this.description.Value := details
    }

    OnOK() {
        local selection, row, info
        if this.modified && !!this.settings && this.schema_list.GetCount() != 0 {
            selection := []
            row := 0
            while (row := this.schema_list.GetNext(row, "Checked")) {
                if (info := this.item_data[row]) {
                    selection.Push(this.api.get_schema_id(info))
                }
            }
            if selection.Length == 0 {
                MsgBox("至少要选用一项吧。", "玉兔毫不是这般用法", "Icon!")
                return
            }
            this.api.select_schemas(this.settings, selection)
        }
        this.Exit(true)
    }

    OnGetSchema() {
        if !FileExist(Format("{}\rime-install.bat", A_ScriptDir)) {
            MsgBox("未找到东风破安装脚本，请检查安装目录。", ":-(", "Ok Iconx")
            return
        }

        if this.proxy.Value {
            EnvSet("http_proxy", this.proxy.Value)
            EnvSet("https_proxy", this.proxy.Value)
        }
        if this.use_git.Value {
            EnvSet("use_plum", "1")
        } else {
            EnvSet("use_plum", "0")
        }
        EnvSet("rime_dir", RabbitUserDataPath())
        this.Opt("+Disabled")
        RunWait(Format("cmd.exe /k {}\rime-install.bat", A_ScriptDir), A_ScriptDir)
        this.Opt("-Disabled")
        WinActivate("ahk_id " . this.Hwnd)
        this.api.load_settings(this.settings)
        this.Populate()
    }

    Exit(yes) {
        this.accepted := yes
        this.Dispose()
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try {
            this.item_data := Map()
            this.ReleaseSchemaLists()
        } finally {
            try this.Destroy()
        }
    }

    ReleaseSchemaLists() {
        try {
            if this.selected_schemas {
                this.api.schema_list_destroy(this.selected_schemas)
                this.selected_schemas := 0
            }
        } finally {
            if this.available_schemas {
                this.api.schema_list_destroy(this.available_schemas)
                this.available_schemas := 0
            }
        }
    }
}
