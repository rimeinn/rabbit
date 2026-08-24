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

class RabbitSettingsWindow extends Gui {
    static pages := [
        { title: "外观", description: "设置配色、字体和现代候选窗布局。" },
        { title: "输入方案", description: "选择、排序输入方案并设置方案选单快捷键。" },
        { title: "输入与行为", description: "设置玉兔毫的输入、提示和候选行为。" },
        { title: "应用适配", description: "按应用程序设置默认输入状态。" },
        { title: "用户词典", description: "备份、恢复、导入和导出用户词典。" },
        { title: "维护与同步", description: "重新部署、同步用户资料并查看诊断信息。" },
        { title: "关于", description: "查看版本、许可证和项目链接。" },
    ]

    __New(workflow := 0) {
        local page_names := []
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】设置", this)
        this.workflow := workflow
        this.disposed := false
        this.selected_page := 0

        this.SetFont("s10", "Microsoft YaHei UI")
        this.MarginX := 20
        this.MarginY := 20

        this.SetFont("s16 w600")
        this.AddText("x20 y20 w170 h32 Center", "玉兔毫")
        this.SetFont("s9 w400")
        this.AddText("x20 y52 w170 h22 Center cGray", "Windows 设置")

        for page in RabbitSettingsWindow.pages {
            page_names.Push(page.title)
        }
        this.navigation := this.AddListBox("x20 y88 w170 h390 -Multi", page_names)
        this.navigation.OnEvent("Change", (*) => this.SelectPage(this.navigation.Value))

        this.AddText("x205 y20 w1 h458 +0x10")
        this.SetFont("s18 w600")
        this.page_title := this.AddText("x230 y28 w570 h38", "")
        this.SetFont("s10 w400")
        this.page_description := this.AddText("x230 y72 w570 h28 cGray", "")
        this.AddText("x230 y112 w570 h1 +0x10")

        this.placeholder := this.AddGroupBox("x230 y136 w570 h290", "页面内容")
        this.placeholder_text := this.AddText(
            "x254 y174 w520 h80",
            "这里将逐步迁入现有部署器功能。当前页面骨架不会读取或修改配置。"
        )

        this.dictionary_group := this.AddGroupBox("x230 y136 w570 h180 Hidden", "用户词典")
        this.dictionary_text := this.AddText(
            "x254 y174 w520 h52 Hidden",
            "管理用户词典快照，或以文本码表格式导入、导出词条。"
        )
        this.dictionary_button := this.AddButton("x254 y246 w160 h32 Hidden", "打开词典管理")
        this.dictionary_button.OnEvent("Click", (*) => this.RunDictionaryManagement())

        this.maintenance_group := this.AddGroupBox("x230 y136 w570 h220 Hidden", "维护与同步")
        this.maintenance_text := this.AddText(
            "x254 y174 w520 h52 Hidden",
            "重新部署使配置改动生效；同步用户资料会合并本机与同步目录中的数据。"
        )
        this.deploy_button := this.AddButton("x254 y246 w130 h32 Hidden", "重新部署")
        this.deploy_button.OnEvent("Click", (*) => this.RunDeploy())
        this.sync_button := this.AddButton("x398 y246 w130 h32 Hidden", "同步用户资料")
        this.sync_button.OnEvent("Click", (*) => this.RunSync())
        this.operation_status := this.AddText("x254 y302 w520 h28 Hidden", "")

        this.AddText("x230 y452 w420 h22 cGray", "设置内容将在确认后统一保存和部署。")
        this.close_button := this.AddButton("x700 y444 w100 h32", "关闭")
        this.close_button.OnEvent("Click", this.OnClose.Bind(this))
        this.OnEvent("Close", this.OnClose.Bind(this))
        this.OnEvent("Escape", this.OnClose.Bind(this))

        this.SelectPage(1)
    }

    SelectPage(index) {
        local page
        if index < 1 || index > RabbitSettingsWindow.pages.Length {
            return false
        }
        this.selected_page := index
        if this.navigation.Value != index {
            this.navigation.Choose(index)
        }
        page := RabbitSettingsWindow.pages[index]
        this.page_title.Value := page.title
        this.page_description.Value := page.description
        this.SetPlaceholderVisible(index != 5 && index != 6)
        this.SetDictionaryVisible(index = 5)
        this.SetMaintenanceVisible(index = 6)
        return true
    }

    SetPlaceholderVisible(visible) {
        this.placeholder.Visible := visible
        this.placeholder_text.Visible := visible
    }

    SetDictionaryVisible(visible) {
        this.dictionary_group.Visible := visible
        this.dictionary_text.Visible := visible
        this.dictionary_button.Visible := visible
    }

    SetMaintenanceVisible(visible) {
        this.maintenance_group.Visible := visible
        this.maintenance_text.Visible := visible
        this.deploy_button.Visible := visible
        this.sync_button.Visible := visible
        this.operation_status.Visible := visible
    }

    RunDictionaryManagement() {
        if !this.workflow {
            return false
        }
        try {
            return this.workflow.DictManagement() = 0
        } catch as error {
            MsgBox("未能打开用户词典管理：`n" . error.Message, "【玉兔毫】", "Ok Iconx")
            return false
        }
    }

    RunDeploy() {
        return this.RunMaintenanceAction(
            (*) => this.workflow.UpdateWorkspace(true),
            "部署完成。",
            "部署失败。"
        )
    }

    RunSync() {
        return this.RunMaintenanceAction(
            (*) => this.workflow.SyncUserData(),
            "同步完成。",
            "同步失败。"
        )
    }

    RunMaintenanceAction(action, success_message, failure_message) {
        local result
        if !this.workflow {
            return false
        }
        this.Opt("+Disabled")
        this.operation_status.Value := "正在执行…"
        try {
            result := action.Call()
            this.operation_status.Value := result = 0 ? success_message : failure_message
            return result = 0
        } catch as error {
            this.operation_status.Value := failure_message . " " . error.Message
            return false
        } finally {
            this.Opt("-Disabled")
        }
    }

    WaitClose() {
        local hwnd := this.Hwnd
        WinWaitClose("ahk_id " . hwnd)
    }

    OnClose(*) {
        this.Dispose()
        return true
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try this.Destroy()
    }
}
