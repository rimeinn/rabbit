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

class DictManagementDialog extends Gui {
    __New(rime_api, levers_api) {
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】用户词典管理", this)
        this.rime := rime_api
        this.api := levers_api
        this.disposed := false

        ; Layout
        this.MarginX := 15
        this.MarginY := 15
        this.AddText(, "用户词典列表：")
        this.dict_list := this.AddListBox("w190 h270", [])
        this.dict_list.OnEvent("Change", (*) => this.OnUserDictListSelChange())
        this.AddText("Section X+25 YP w315", " 当你需要将包含输入习惯的用户词典迁移到另一份配备了 Rime 输入法的系统，请在左列选中词典名称，「输出词典快照」将快照文件传到另一系统上，「合入词典快照」快照文件中的词条将合并到其所属的词典中。")
        this.backup := this.AddButton("Disabled Y+30 w150", "输出词典快照")
        this.backup.OnEvent("Click", (*) => this.OnBackup())
        this.AddButton("X+20 YP w150", "合入词典快照").OnEvent("Click", (*) => this.OnRestore())
        this.AddText("XS w315", "「导出文本码表」是为输入方案制作者设计的功能，将使用期间新造的词组以 Rime 词典中的码表格式导出，以便查看、编辑。「导入文本码表」可用于将其他来源的词库整理成 TSV 格式后导入到 Rime。在 Rime 输入法之间转移数据，请使用词典快照。")
        this.export := this.AddButton("Disabled Y+30 w150", "导出文本码表")
        this.export.OnEvent("Click", (*) => this.OnExport())
        this.import := this.AddButton("Disabled X+20 YP w150", "导入文本码表")
        this.import.OnEvent("Click", (*) => this.OnImport())

        this.Populate()
    }

    Populate() {
        local iter, dict
        if !(iter := this.api.user_dict_iterator_init()) {
            return
        }
        try {
            while (dict := this.api.next_user_dict(iter)) {
                this.dict_list.Add([dict])
            }
        } finally {
            this.api.user_dict_iterator_destroy(iter)
        }
        this.dict_list.Choose(0)
    }

    OnBackup() {
        local file
        local sel := this.dict_list.Value
        if sel <= 0 || sel > ControlGetItems(this.dict_list).Length {
            MsgBox("请在左列选择要导出的词典名称。", ":-(", "Ok Iconi")
            return
        }

        local path := this.rime.get_user_data_sync_dir()
        if !DirExist(path) {
            try {
                DirCreate(path)
            } catch {
                MsgBox("未能完成导出操作。会不会是同步文件夹无法访问？", ":-(", "Ok Iconx")
                return
            }
        }

        local dict_name := this.dict_list.Text
        file := path . "\" . dict_name . ".userdb.txt"
        if !this.api.backup_user_dict(dict_name) {
            MsgBox("不知哪里出错了，未能完成导出操作。", ":-(", "Ok Iconx")
            return
        } else if !FileExist(file) {
            MsgBox("咦，输出的快照文件找不着了。", ":-(", "Ok Iconx")
            return
        }
        Run(A_ComSpec . " /c explorer.exe /select,`"" . file . "`"", , "Hide")
    }

    OnRestore() {
        local selected_path
        local filter := "词典快照 (*.userdb.txt; *.userdb.kct.snapshot)"
        if (selected_path := FileSelect("1", , "打开", filter)) { ; file must exist
            if !this.api.restore_user_dict(selected_path) {
                MsgBox("不知哪里出错了，未能完成操作。", ":-(", "Ok Iconx")
            } else {
                MsgBox("完成了。", ":-)", "Ok Iconi")
            }
        }
    }

    OnExport() {
        local sel := this.dict_list.Value
        if sel <= 0 || sel > ControlGetItems(this.dict_list).Length {
            MsgBox("请在左列选择要导出的词典名称。", ":-(", "Ok Iconi")
            return
        }

        local dict_name := this.dict_list.Text
        local file_name := dict_name . "_export.txt"
        local filter := "文本文档 (*.txt)"
        if (selected_path := FileSelect("S18", file_name, "另存为", filter)) { ; path must exist + warning on overwriting
            if SubStr(selected_path, -4) != ".txt" {
                selected_path .= ".txt"
            }
            local result := this.api.export_user_dict(dict_name, selected_path)
            if result < 0 {
                MsgBox("不知哪里出错了，未能完成操作。", ":-(", "Ok Iconx")
            } else if !FileExist(selected_path) {
                MsgBox("咦，导出的文件找不着了。", ":-(", "Ok Iconx")
            } else {
                MsgBox("导出了 " . result . " 条记录。", ":-)", "Ok Iconi")
                Run(A_ComSpec . " /c explorer.exe /select,`"" . selected_path . "`"", , "Hide")
            }
        }
    }

    OnImport() {
        local dict_name := this.dict_list.Text
        local file_name := dict_name . "_export.txt"
        local filter := "文本文档 (*.txt)"
        if (selected_path := FileSelect("1", file_name, "打开", filter)) { ; file must exist
            local result := this.api.import_user_dict(dict_name, selected_path)
            if result < 0 {
                MsgBox("不知哪里出错了，未能完成操作。", ":-(", "Ok Iconx")
            } else {
                MsgBox("导入了 " . result . " 条记录。", ":-)", "Ok Iconi")
            }
        }
    }

    OnUserDictListSelChange() {
        local index := this.dict_list.Value
        local enabled := index <= 0 ? false : true
        this.backup.Enabled := enabled
        this.export.Enabled := enabled
        this.import.Enabled := enabled
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try this.Destroy()
    }
}
