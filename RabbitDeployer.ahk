/*
 * Copyright (c) 2023 - 2025 Xuesong Peng <pengxuesong.cn@gmail.com>
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
#Requires AutoHotkey v2.0
#SingleInstance Ignore

;@Ahk2Exe-SetInternalName rabbit-deployer
;@Ahk2Exe-SetProductName 玉兔毫部署应用
;@Ahk2Exe-SetOrigFilename RabbitDeployer.ahk

#Include <RabbitCommon>
#Include <RabbitTrayMenu>
#Include <RabbitThemesUI>

;@Ahk2Exe-SetMainIcon Lib\rabbit-alt.ico
global IN_MAINTENANCE := true
global rime
global INVALID_FILE_ATTRIBUTES := -1
global FILE_ATTRIBUTE_DIRECTORY := 0x00000010

OnExit(ExitRabbitDeployer)

RabbitDeployerMain(A_Args)

; args[1]: command
; args[2]: keyboard layout
RabbitDeployerMain(args) {
    if args.Length >= 2
        layout := Number(args[2])
    else
        layout := 0
    IN_MAINTENANCE := true
    UpdateTrayIcon()
    TrayTip()
    TrayTip("维护中", RABBIT_IME_NAME)
    SetupTrayMenu()

    command := args.Length > 0 ? args[1] : ""
    conf := Configurator()
    conf.Initialize()
    switch command {
        case "deploy":
            res := conf.UpdateWorkspace()
            opt := RABBIT_NO_MAINTENANCE
        case "dict":
            res := conf.DictManagement()
            opt := RABBIT_PARTIAL_MAINTENANCE
        case "sync":
            res := conf.SyncUserData()
            opt := RABBIT_PARTIAL_MAINTENANCE
        default:
            res := conf.Run(command = "install")
            opt := RABBIT_NO_MAINTENANCE
    }

    if args.Length > 1 {
        if A_IsCompiled
            Run(Format("`"{}\Rabbit.exe`" {} {} {}", A_ScriptDir, opt, res, layout))
        else
            Run(Format("{} `"{}\Rabbit.ahk`" {} {} {}", A_AhkPath, A_ScriptDir, opt, res, layout))
        ExitApp()
    }
    return res
}

ExitRabbitDeployer(reason, code) {
    TrayTip()
}

CreateFileIfNotExist(filename) {
    user_data_dir := RabbitUserDataPath() . "\"
    if not InStr(DirExist(user_data_dir), "D")
        DirCreate(user_data_dir)
    filepath := user_data_dir . filename
    if not InStr(FileExist(filepath), "N")
        FileAppend("", filepath)
}

ConfigureSwitcher(levers, switcher_settings, &reconfigured) {
    if !IsSet(reconfigured)
        reconfigured := false
    if not levers.load_settings(switcher_settings)
        return false
    ; To mimic a dialog
    result := {
        yes : false
    }
    dialog := SwitcherSettingsDialog(switcher_settings, result)
    dialog.Show()
    WinWaitClose(dialog)

    if result.yes {
        if levers.save_settings(switcher_settings)
            reconfigured := true
        return true
    }
    return false
}

ConfigureUI(levers, ui_style_settings, &reconfigured) {
    if !IsSet(reconfigured)
        reconfigured := false
    local settings := ui_style_settings.settings
    if !levers.load_settings(settings)
        return false
    result := {
        yes : false
    }
    dialog := UIStyleSettingsDialog(ui_style_settings, result)
    dialog.Show()
    WinWaitClose(dialog)

    if result.yes {
        if levers.save_settings(settings)
            reconfigured := true
        return true
    }
    return false
}

class Configurator extends Class {
    __New() {
        CreateFileIfNotExist("default.custom.yaml")
        CreateFileIfNotExist("rabbit.custom.yaml")
    }

    Initialize() {
        global rabbit_traits
        rabbit_traits := CreateTraits()
        rime.setup(rabbit_traits)
        rime.deployer_initialize(0)
    }

    Run(installing) {
        levers := RimeLeversApi()
        if not levers
            return 1

        switcher_settings := levers.switcher_settings_init()
        ui_style_settings := UIStyleSettings()
        skip_switcher_settings := installing && !levers.is_first_run(switcher_settings)
        skip_ui_style_settings := installing && !levers.is_first_run(ui_style_settings.settings)

        if !skip_switcher_settings {
            if !ConfigureSwitcher(levers, switcher_settings, &reconfigured)
                skip_ui_style_settings := true ; user cancelled
        }
        if !skip_ui_style_settings
            ConfigureUI(levers, ui_style_settings, &reconfigured)

        levers.custom_settings_destroy(switcher_settings)

        if installing || reconfigured
            return this.UpdateWorkspace()

        return 0
    }

    UpdateWorkspace(report_errors := false) {
        mutex := RabbitMutex()
        if not mutex.Create() {
            ; TODO: log error
            return 1
        }

        if mutex.lasterr == ERROR_ALREADY_EXISTS {
            ; TODO: log error
            mutex.Close()
            if report_errors {
                MsgBox("正在执行另一项部署任务，方才所做的修改将在输入法再次启动后生效。", "【玉兔毫】", "Ok Iconi")
            }
            return 1
        }

        {
            rime.deploy()
            rime.deploy_config_file("rabbit.yaml", "config_version")
        }

        mutex.Close()

        return 0
    }

    DictManagement() {
        mutex := RabbitMutex()
        if not mutex.Create() {
            ; TODO: log error
            return 1
        }

        if mutex.lasterr == ERROR_ALREADY_EXISTS {
            ; TODO: log error
            mutex.Close()
            MsgBox("正在执行另一项部署任务，请稍后再试。", "【玉兔毫】", "Ok Iconi")
            return 1
        }

        {
            if rime.api_available("run_task") {
                rime.run_task("installation_update")
            }
            dialog := DictManagementDialog()
            dialog.Show()
            WinWaitClose(dialog)
        }

        mutex.Close()

        return 0
    }

    SyncUserData() {
        mutex := RabbitMutex()
        if not mutex.Create() {
            ; TODO: log error
            return 1
        }

        if mutex.lasterr == ERROR_ALREADY_EXISTS {
            ; TODO: log error
            mutex.Close()
            MsgBox("正在执行另一项部署任务，请稍后再试。", "【玉兔毫】", "Ok Iconi")
            return 1
        }

        {
            if not rime.sync_user_data() {
                mutex.Close()
                return 1
            }
            rime.join_maintenance_thread()
        }

        mutex.Close()

        return 0
    }
}

class DictManagementDialog extends Gui {
    __New() {
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】用户词典管理", this)
        this.api := RimeLeversApi()

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
        if !iter := this.api.user_dict_iterator_init() {
            return
        }
        while dict := this.api.next_user_dict(iter) {
            this.dict_list.Add([dict])
        }
        this.api.user_dict_iterator_destroy(iter)
        this.dict_list.Choose(0)
    }

    OnBackup() {
        local sel := this.dict_list.Value
        if sel <= 0 || sel > ControlGetItems(this.dict_list).Length {
            MsgBox("请在左列选择要导出的词典名称。", ":-(", "Ok Iconi")
            return
        }

        local path := rime.get_user_data_sync_dir()
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
        local filter := "词典快照 (*.userdb.txt; *.userdb.kct.snapshot)"
        if selected_path := FileSelect("1", , "打开", filter) { ; file must exist
            if !this.api.restore_user_dict(selected_path)
                MsgBox("不知哪里出错了，未能完成操作。", ":-(", "Ok Iconx")
            else
                MsgBox("完成了。", ":-)", "Ok Iconi")
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
        if selected_path := FileSelect("S18", file_name, "另存为", filter) { ; path must exist + warning on overwriting
            if SubStr(selected_path, -4) != ".txt"
                selected_path .= ".txt"
            local result := this.api.export_user_dict(dict_name, selected_path)
            if result < 0
                MsgBox("不知哪里出错了，未能完成操作。", ":-(", "Ok Iconx")
            else if !FileExist(selected_path)
                MsgBox("咦，导出的文件找不着了。", ":-(", "Ok Iconx")
            else {
                MsgBox("导出了 " . result . " 条记录。", ":-)", "Ok Iconi")
                Run(A_ComSpec . " /c explorer.exe /select,`"" . selected_path . "`"", , "Hide")
            }
        }
    }

    OnImport() {
        local dict_name := this.dict_list.Text
        local file_name := dict_name . "_export.txt"
        local filter := "文本文档 (*.txt)"
        if selected_path := FileSelect("1", file_name, "打开", filter) { ; file must exist
            local result := this.api.import_user_dict(dict_name, selected_path)
            if result < 0
                MsgBox("不知哪里出错了，未能完成操作。", ":-(", "Ok Iconx")
            else
                MsgBox("导入了 " . result . " 条记录。", ":-)", "Ok Iconi")
        }
    }

    OnUserDictListSelChange() {
        local index := this.dict_list.Value
        local enabled := index <= 0 ? false : true
        this.backup.Enabled := enabled
        this.export.Enabled := enabled
        this.import.Enabled := enabled
    }
}

class SwitcherSettingsDialog extends Gui {
    __New(settings, result) {
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】方案选单设定", this)
        this.settings := settings
        this.loaded := false
        this.modified := false
        this.api := RimeLeversApi()

        this.item_data := Map()
        this.result := result

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

        this.Populate()
    }

    Populate() {
        if !this.settings
            return
        local available := this.api.get_available_schema_list(this.settings)
        local selected := this.api.get_selected_schema_list(this.settings)
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
        if !info
            return
        details := ""
        if name := this.api.get_schema_name(info)
            details .= name
        if author := this.api.get_schema_author(info)
            details .= "`r`n`r`n" . author
        if description := this.api.get_schema_description(info)
            details .= "`r`n`r`n" . description
        this.description.Value := details
    }

    OnOK() {
        if this.modified && !!this.settings && this.schema_list.GetCount() != 0 {
            selection := []
            row := 0
            while row := this.schema_list.GetNext(row, "Checked") {
                if info := this.item_data[row]
                    selection.Push(this.api.get_schema_id(info))
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
        WinActivate("ahk_id " this.Hwnd)
        this.api.load_settings(this.settings)
        this.Populate()
    }

    Exit(yes) {
        this.result.yes := yes
        this.Destroy()
    }
}

class UIStyleSettings {
    __New() {
        this.api := RimeLeversApi()
        this.settings := this.api.custom_settings_init("rabbit", "Rabbit.UIStyleSettings")
    }

    GetPresetColorSchemes() {
        global rime
        local result := []
        if !config := this.api.settings_get_config(this.settings)
            return result
        if !rime || !preset := rime.config_begin_map(config, "preset_color_schemes")
            return result
        while rime.config_next(preset) {
            local name_key := preset.path . "/name"
            if !name := rime.config_get_cstring(config, name_key)
                continue
            local author_key := preset.path . "/author"
            local author := rime.config_get_cstring(config, author_key)
            UIStyle.UpdateColor(config, StrLower(preset.key))
            result.Push({
                color_scheme_id: preset.key,
                name: name,
                author: author,
                border_color: UIStyle.border_color,
                text_color: UIStyle.text_color,
                back_color: UIStyle.back_color,
                hilited_text_color: UIStyle.hilited_text_color,
                hilited_back_color: UIStyle.hilited_back_color,
                hilited_candidate_text_color: UIStyle.hilited_candidate_text_color,
                hilited_candidate_back_color: UIStyle.hilited_candidate_back_color,
                candidate_text_color: UIStyle.candidate_text_color,
                candidate_back_color: UIStyle.candidate_back_color,
                font_face: UIStyle.font_face,
                font_point: UIStyle.font_point,
            })
        }
        return result
    }

    GetActiveColorScheme() {
        global rime
        if !config := this.api.settings_get_config(this.settings)
            return ""
        if !rime || !value := rime.config_get_cstring(config, "style/color_scheme")
            return ""
        return value
    }

    SelectColorScheme(color_scheme_id) {
        this.api.customize_string(this.settings, "style/color_scheme", color_scheme_id)
        return true
    }
}

class UIStyleSettingsDialog extends Gui {
    __New(settings, result) {
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】界面风格设定", this)
        this.settings := settings
        this.loaded := false
        this.api := RimeLeversApi()

        this.preset := []
        this.result := result

        ; Layout
        this.MarginX := 15
        this.MarginY := 15
        this.color_schemes_width := 220
        this.preview_width := 220
        this.preview_offset := 20
        this.AddText("x10 y10", "主题：").GetPos(, , , &h)
        this.title_height := h
        this.color_schemes := this.AddListBox(Format("Section r15 w{} -Multi", this.color_schemes_width))
        this.color_schemes.OnEvent("Change", (ctrl, info) => this.OnColorSchemeSelChange())
        this.color_schemes.GetPos(, , , &h)
        this.list_height := h
        this.AddGroupBox(Format("x+{} yp-8 w{} h{}", this.preview_offset, this.preview_width, this.list_height + 8), "预览")
        ; 0xE(SS_BITMAP) or 0x4E (Bitmap and Resizable, but text is unclear)
        this.preview_img := this.AddPicture("xp+50 yp+50 w180 h180 0xE BackgroundWhite")
        this.candidate_box := CandidatePreview(this.preview_img)

        this.set_font := this.AddButton(Format("xs ys+{} w120", this.list_height + this.MarginY), "设置字体")
        this.set_font.Opt("+Disabled") ; TODO: implement font setting
        this.ok := this.AddButton("x+180 w90", "中")
        this.ok.OnEvent("Click", (*) => this.OnOK())

        this.Populate()
    }

    Populate() {
        if !this.settings
            return
        local active := this.settings.GetActiveColorScheme()
        local active_index := 0
        this.preset := this.settings.GetPresetColorSchemes()
        local names := []
        for i, info in this.preset {
            names.Push(info.name)
            if info.color_scheme_id = active
                active_index := i
        }
        this.color_schemes.Opt("-Redraw")
        this.color_schemes.Add(names)
        this.color_schemes.Opt("+Redraw")
        if active_index > 0 {
            this.color_schemes.Choose(active_index)
            this.Preview(active_index)
        }
        this.loaded := true
    }

    OnColorSchemeSelChange() {
        local index := this.color_schemes.Value
        if index > 0 && index <= this.preset.Length {
            this.settings.SelectColorScheme(this.preset[index].color_scheme_id)
            this.Preview(index)
        }
        return 0
    }

    Preview(index) {
        if index <= 0 || index > this.preset.Length
            return
        local info := this.preset[index]
        this.candidate_box.Build(info, &box_width, &box_height)
        box_width := box_width / this.candidate_box.dpiScale
        box_height := box_height / this.candidate_box.dpiScale
        local box_x := this.MarginX + this.color_schemes_width + this.preview_offset + Round((this.preview_width - box_width) / 2)
        local box_y := this.MarginY + this.title_height + 8 + Round((this.list_height - box_height) / 2)
        this.preview_img.Move(box_x, box_y, box_width, box_height)
        this.candidate_box.Render(["输入法", "输入", "数", "书", "输"], 1)
    }

    OnOK() {
        this.Exit(true)
    }

    Exit(yes) {
        this.result.yes := yes
        this.Destroy()
    }
}
