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
#Include <RabbitConfigSnapshot>

A_IconTip := "玉兔毫（维护中）"

RabbitSetupMaintenanceTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("退出玉兔毫", (*) => ExitApp())
    RabbitUpdateMaintenanceTrayIcon()
}

RabbitUpdateMaintenanceTrayIcon() {
    if A_IsCompiled {
        TraySetIcon(A_ScriptFullPath, 3)
    } else if FileExist("Lib\rabbit-alt.ico") {
        TraySetIcon("Lib\rabbit-alt.ico", , true)
    }
}

RabbitLaunchDeployer(command, args*) {
    local arguments := ""
    for argument in args {
        arguments .= " " . argument
    }
    arguments := LTrim(arguments, " ")
    if A_IsCompiled {
        Run(Format("`"{}\RabbitDeployer.exe`" {} {}", A_ScriptDir, command, arguments))
    } else {
        Run(Format("{} `"{}\RabbitDeployer.ahk`" {} {}", A_AhkPath, A_ScriptDir, command, arguments))
    }
}

class RabbitTrayController {
    __New(
        rime_api,
        session_id,
        candidate_box,
        config,
        runtime_state,
        keyboard_layout,
        deployer_callback
    ) {
        this.rime := rime_api
        this.session_id := session_id
        this.candidate_box := candidate_box
        this.config := config
        this.runtime_state := runtime_state
        this.keyboard_layout := keyboard_layout
        this.deployer_callback := deployer_callback
        this.schema_name := ""
        this.ascii_mode := false
        this.full_shape := false
        this.ascii_punct := false
        this.current_schema_icon := ""
    }

    SetupMenu() {
        static rabbit_script := Format("`"{}\Rabbit.ahk`"", A_ScriptDir)
        static rabbit_ico := Format("{}\Lib\rabbit.ico", A_ScriptDir)
        A_TrayMenu.Delete()
        A_TrayMenu.Add(
            "输入法设定",
            (*) => this.StartDeployer("configure")
        )
        A_TrayMenu.Add(
            "用户词典管理",
            (*) => this.StartDeployer("dict")
        )
        A_TrayMenu.Add(
            "用户资料同步",
            (*) => this.StartDeployer("sync")
        )
        A_TrayMenu.Add()
        A_TrayMenu.Add("用户文件夹", (*) => Run(RabbitUserDataPath()))
        A_TrayMenu.Add(A_IsCompiled ? "程序文件夹" : "脚本文件夹", (*) => Run(A_ScriptDir))
        A_TrayMenu.Add("日志文件夹", (*) => Run(RabbitLogPath()))
        A_TrayMenu.Add()

        if FileExist(A_Startup . "\Rabbit.lnk") {
            A_TrayMenu.Add(
                "从开机启动删除",
                (*) => (FileDelete(A_Startup . "\Rabbit.lnk"), this.SetupMenu())
            )
        } else {
            A_TrayMenu.Add(
                "添加到开机启动",
                (*) => (
                    FileCreateShortcut(
                        A_AhkPath,
                        A_Startup . "\Rabbit.lnk",
                        A_ScriptDir,
                        rabbit_script,
                        "玉兔毫输入法",
                        rabbit_ico
                    ),
                    this.SetupMenu()
                )
            )
        }
        A_TrayMenu.Add(
            "添加到桌面快捷方式",
            (*) => FileCreateShortcut(
                A_AhkPath,
                A_Desktop . "\Rabbit.lnk",
                A_ScriptDir,
                rabbit_script,
                "玉兔毫输入法",
                rabbit_ico
            )
        )
        A_TrayMenu.Add()
        A_TrayMenu.Add("仓库主页", (*) => Run("https://github.com/rimeinn/rabbit"))
        A_TrayMenu.Add("参加讨论", (*) => Run("https://github.com/rimeinn/rabbit/discussions"))
        A_TrayMenu.Add(
            "关于",
            (*) => MsgBox(
                Format(
                    "由 AutoHotkey 实现的 Rime 输入法引擎前端`r`n版本：{}{}",
                    RABBIT_VERSION,
                    A_IsCompiled ? "（已编译）" : ""
                ),
                "玉兔毫输入法"
            )
        )
        A_TrayMenu.Add()
        A_TrayMenu.Add("检查新版本", (*) => this.CheckNewVersion())
        A_TrayMenu.Add(
            "重新部署",
            (*) => this.StartDeployer("deploy")
        )
        A_TrayMenu.Add()
        A_TrayMenu.Add(
            A_IsSuspended ? "启用玉兔毫" : "禁用玉兔毫",
            (*) => this.ToggleSuspend()
        )
        A_TrayMenu.Add("退出玉兔毫", (*) => ExitApp())
    }

    StartDeployer(command) {
        this.deployer_callback.Call(command, this.keyboard_layout)
    }

    ToggleSuspend() {
        if this.candidate_box && HasMethod(this.candidate_box, "Hide") {
            this.candidate_box.Hide()
        }
        this.rime.clear_composition(this.session_id)
        Suspend(-1)
        this.UpdateTip()
        this.UpdateIcon()
        if this.config.show_tips {
            ToolTip(A_IsSuspended ? "禁用" : "启用", , , STATUS_TOOLTIP)
            SetTimer(
                () => ToolTip(, , , STATUS_TOOLTIP),
                -this.config.show_tips_time
            )
        }
        this.SetupMenu()
    }

    OnClick(wParam, lParam, msg, hWnd) {
        local status_text
        if !this.rime || !this.session_id || A_IsSuspended {
            return
        }
        if lParam == WM_LBUTTONDOWN {
            this.runtime_state.on_tray_icon_click := true
        } else if lParam == WM_LBUTTONUP {
            local old_ascii_mode := this.rime.get_option(this.session_id, "ascii_mode")
            this.rime.set_option(this.session_id, "ascii_mode", !old_ascii_mode)
            local new_ascii_mode := this.rime.get_option(this.session_id, "ascii_mode")
            this.runtime_state.UpdateWinAscii(
                new_ascii_mode,
                true,
                this.runtime_state.active_win,
                true
            )
            status_text := new_ascii_mode
                ? this.runtime_state.ascii_mode_true_label_abbr
                : this.runtime_state.ascii_mode_false_label_abbr
            if this.config.show_tips {
                ToolTip(status_text, , , STATUS_TOOLTIP)
                SetTimer(
                    () => ToolTip(, , , STATUS_TOOLTIP),
                    -this.config.show_tips_time
                )
            }
            WinActivate("ahk_exe " . this.runtime_state.active_win)
            this.runtime_state.on_tray_icon_click := false
        }
    }

    UpdateTip(
        schema_name := this.schema_name,
        ascii_mode := this.ascii_mode,
        full_shape := this.full_shape,
        ascii_punct := this.ascii_punct
    ) {
        this.schema_name := schema_name ? schema_name : this.schema_name
        this.ascii_mode := !!ascii_mode
        this.full_shape := !!full_shape
        this.ascii_punct := !!ascii_punct
        local suspended := A_IsSuspended ? "（已禁用）" : ""
        A_IconTip := Format(
            "玉兔毫 {} {}`n左键切换模式，右键打开菜单`n{} | {} | {}",
            suspended,
            this.schema_name,
            this.ascii_mode
                ? this.runtime_state.ascii_mode_true_label
                : this.runtime_state.ascii_mode_false_label,
            this.full_shape
                ? this.runtime_state.full_shape_true_label
                : this.runtime_state.full_shape_false_label,
            this.ascii_punct
                ? this.runtime_state.ascii_punct_true_label
                : this.runtime_state.ascii_punct_false_label
        )
    }

    UpdateSchemaIcon(schema_id) {
        local icon_path
        if this.config.TryGetSchemaIcon(schema_id, &icon_path) {
            this.current_schema_icon := icon_path
            if icon_path {
                this.UpdateIcon()
            }
        }
    }

    UpdateIcon() {
        local icon_path := this.current_schema_icon
        local icon_num
        if !icon_path {
            icon_path := "Lib\rabbit.ico"
        }
        if A_IsCompiled {
            icon_num := this.ascii_mode ? 2 : (this.current_schema_icon ? 0 : 1)
            if icon_num {
                TraySetIcon(A_ScriptFullPath, icon_num)
            } else if FileExist(this.current_schema_icon) {
                TraySetIcon(this.current_schema_icon)
            }
        } else {
            icon_path := A_IsSuspended
                ? "Lib\rabbit-alt.ico"
                : (this.ascii_mode ? "Lib\rabbit-ascii.ico" : icon_path)
            if FileExist(icon_path) {
                TraySetIcon(icon_path, , true)
            }
        }
    }

    CheckNewVersion() {
        local http, url, status, response_text, match, down, arch
        if !IsDigit(SubStr(RABBIT_VERSION, 1, 1)) {
            MsgBox("非正式版本，请前往仓库检查新版本", "玉兔毫输入法")
            return
        }
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        url := "https://api.github.com/repos/rimeinn/rabbit/releases/latest"
        local version := ""
        try {
            http.Open("GET", url, true)
            http.SetRequestHeader("Accept", "application/vnd.github+json")
            http.SetRequestHeader("X-GitHub-Api-Version", "2022-11-28")
            http.SetRequestHeader("User-Agent", "AutoHotkey")
            http.Send()
            http.WaitForResponse()
            status := http.Status
            if status != 200 {
                MsgBox("无法获取最新版本信息，请检查网络连接", "玉兔毫输入法")
                return
            }
            response_text := http.ResponseText
            if RegExMatch(response_text, '"name"\s*:\s*"(.*?)"', &match) {
                version := SubStr(match[1], 1, 1) == "v" ? SubStr(match[1], 2) : match[1]
            } else {
                MsgBox("无法解析版本字段，请稍后再试", "玉兔毫输入法")
                return
            }
        }
        if version == "" {
            MsgBox("无法获取最新版本号，请稍后再试", "玉兔毫输入法")
            return
        }
        if VerCompare(version, RABBIT_VERSION) > 0 {
            down := MsgBox(
                Format("发现新版本：{}`r`n是否前往下载？", version),
                "玉兔毫输入法",
                "YesNo"
            )
            if down == "Yes" {
                arch := A_Is64BitOS ? "x64" : "x86"
                Run(Format(
                    "https://github.com/rimeinn/rabbit/releases/download/v{1}/rabbit-v{1}-{2}.zip",
                    version,
                    arch
                ))
            }
        } else {
            MsgBox("当前已是最新版本", "玉兔毫输入法")
        }
    }
}
