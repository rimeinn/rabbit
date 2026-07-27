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
#Include <RabbitConfig>

A_IconTip := "玉兔毫（维护中）"

global TRAY_SCHEMA_NAME := ""
global TRAY_ASCII_MODE := 0
global TRAY_FULL_SHAPE := 0
global TRAY_ASCII_PUNCT := 0

UpdateTrayIcon()

SetupTrayMenu() {
    static rabbit_script := Format("`"{}\Rabbit.ahk`"", A_ScriptDir)
    static rabbit_ico    := Format("{}\Lib\rabbit.ico", A_ScriptDir)
    A_TrayMenu.Delete()
    if !IN_MAINTENANCE {
        A_TrayMenu.Add("输入法设定", (*) => RunDeployer("configure", RabbitGlobals.keyboard_layout))
        A_TrayMenu.Add("用户词典管理", (*) => RunDeployer("dict", RabbitGlobals.keyboard_layout))
        A_TrayMenu.Add("用户资料同步", (*) => RunDeployer("sync", RabbitGlobals.keyboard_layout))

        A_TrayMenu.Add()

        A_TrayMenu.Add("用户文件夹", (*) => Run(RabbitUserDataPath()))
        A_TrayMenu.Add(A_IsCompiled ? "程序文件夹" : "脚本文件夹", (*) => Run(A_ScriptDir))
        A_TrayMenu.Add("日志文件夹", (*) => Run(RabbitLogPath()))

        A_TrayMenu.Add()

        if FileExist(A_Startup . "\Rabbit.lnk") {
            A_TrayMenu.Add("从开机启动删除", (*) => (FileDelete(A_Startup . "\Rabbit.lnk"), SetupTrayMenu()))
        } else {
            A_TrayMenu.Add("添加到开机启动", (*) => (FileCreateShortcut(A_AhkPath, A_Startup . "\Rabbit.lnk", A_ScriptDir, rabbit_script, "玉兔毫输入法", rabbit_ico), SetupTrayMenu()))
        }
        A_TrayMenu.Add("添加到桌面快捷方式", (*) => FileCreateShortcut(A_AhkPath, A_Desktop . "\Rabbit.lnk", A_ScriptDir, rabbit_script, "玉兔毫输入法", rabbit_ico))

        A_TrayMenu.Add()

        A_TrayMenu.Add("仓库主页", (*) => Run("https://github.com/rimeinn/rabbit"))
        A_TrayMenu.Add("参加讨论", (*) => Run("https://github.com/rimeinn/rabbit/discussions"))
        A_TrayMenu.Add("关于", (*) => MsgBox(Format("由 AutoHotkey 实现的 Rime 输入法引擎前端`r`n版本：{}{}", RABBIT_VERSION, A_IsCompiled ? "（已编译）" : ""), "玉兔毫输入法"))

        A_TrayMenu.Add()

        A_TrayMenu.Add("检查新版本", (*) => CheckNewVersion())
        A_TrayMenu.Add("重新部署", (*) => RunDeployer("deploy", RabbitGlobals.keyboard_layout))

        A_TrayMenu.Add()
        A_TrayMenu.Add(A_IsSuspended ? "启用玉兔毫" : "禁用玉兔毫", (*) => ToggleSuspend())
    }
    A_TrayMenu.Add("退出玉兔毫", (*) => ExitApp())
}

RunDeployer(cmd, argv*) {
    local args, arg
    args := ""
    for arg in argv {
        args .= " " . arg
    }
    args := LTrim(args, " ")
    ; MsgBox(cmd . " " . args)
    if A_IsCompiled {
        Run(Format("`"{}\RabbitDeployer.exe`" {} {}", A_ScriptDir, cmd, args))
    } else {
        Run(Format("{} `"{}\RabbitDeployer.ahk`" {} {}", A_AhkPath, A_ScriptDir, cmd, args))
    }
    ExitApp(1)
}

ToggleSuspend() {
    global rime, session_id, box, STATUS_TOOLTIP
    if box && HasMethod(box, "Hide") {
        box.Hide()
    }
    rime.clear_composition(session_id)
    Suspend(-1)
    UpdateTrayTip()
    UpdateTrayIcon()
    if RabbitConfig.show_tips {
        ToolTip(A_IsSuspended ? "禁用" : "启用", , , STATUS_TOOLTIP)
        SetTimer(() => ToolTip(, , , STATUS_TOOLTIP), -RabbitConfig.show_tips_time)
    }
    SetupTrayMenu()
}

ClickHandler(wParam, lParam, msg, hWnd) {
    local status_text
    if !rime || !IsSet(session_id) || !session_id || A_IsSuspended {
        return
    }
    if lParam == WM_LBUTTONDOWN {
        RabbitGlobals.on_tray_icon_click := true
    } else if lParam == WM_LBUTTONUP {
        local old_ascii_mode := rime.get_option(session_id, "ascii_mode")
        rime.set_option(session_id, "ascii_mode", !old_ascii_mode)
        local new_ascii_mode := rime.get_option(session_id, "ascii_mode")
        if IsSet(UpdateWinAscii) {
            UpdateWinAscii(new_ascii_mode, true, RabbitGlobals.active_win, true)
        }
        status_text := new_ascii_mode ? ASCII_MODE_TRUE_LABEL_ABBR : ASCII_MODE_FALSE_LABEL_ABBR
        if RabbitConfig.show_tips {
            ToolTip(status_text, , , STATUS_TOOLTIP)
            SetTimer(() => ToolTip(, , , STATUS_TOOLTIP), -RabbitConfig.show_tips_time)
        }
        WinActivate("ahk_exe " . RabbitGlobals.active_win)
        RabbitGlobals.on_tray_icon_click := false
    }
}

UpdateTrayTip(schema_name := TRAY_SCHEMA_NAME, ascii_mode := TRAY_ASCII_MODE, full_shape := TRAY_FULL_SHAPE, ascii_punct := TRAY_ASCII_PUNCT) {
    global TRAY_SCHEMA_NAME, TRAY_ASCII_MODE, TRAY_FULL_SHAPE, TRAY_ASCII_PUNCT
    TRAY_SCHEMA_NAME := schema_name ? schema_name : TRAY_SCHEMA_NAME
    TRAY_ASCII_MODE := !!ascii_mode
    TRAY_FULL_SHAPE := !!full_shape
    TRAY_ASCII_PUNCT := !!ascii_punct
    local ss := A_IsSuspended ? "（已禁用）" : ""
    A_IconTip := Format(
        "玉兔毫 {} {}`n左键切换模式，右键打开菜单`n{} | {} | {}", ss, TRAY_SCHEMA_NAME,
        (TRAY_ASCII_MODE ? ASCII_MODE_TRUE_LABEL : ASCII_MODE_FALSE_LABEL),
        (TRAY_FULL_SHAPE ? FULL_SHAPE_TRUE_LABEL : FULL_SHAPE_FALSE_LABEL),
        (TRAY_ASCII_PUNCT ? ASCII_PUNCT_TRUE_LABEL : ASCII_PUNCT_FALSE_LABEL)
    )
}

UpdateTrayIcon() {
    local icon_path, icon_num
    global TRAY_ASCII_MODE
    icon_path := RabbitGlobals.current_schema_icon
    if !IsSet(icon_path) || !icon_path {
        icon_path := "Lib\rabbit.ico"
    }
    if A_IsCompiled {
        icon_num := IN_MAINTENANCE ? 3 : (TRAY_ASCII_MODE ? 2 : (RabbitGlobals.current_schema_icon ? 0 : 1))
        if icon_num {
            TraySetIcon(A_ScriptFullPath, icon_num)
        } else {
            TraySetIcon(RabbitGlobals.current_schema_icon)
        }
    } else {
        TraySetIcon((A_IsSuspended || IN_MAINTENANCE) ? "Lib\rabbit-alt.ico" : (TRAY_ASCII_MODE ? "Lib\rabbit-ascii.ico" : icon_path), , true)
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
    local ver := ""
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
            if SubStr(match[1], 1, 1) == "v" {
                ver := SubStr(match[1], 2)
            } else {
                ver := match[1]
            }
        } else {
            MsgBox("无法解析版本字段，请稍后再试", "玉兔毫输入法")
            return
        }
    }

    if ver == "" {
        MsgBox("无法获取最新版本号，请稍后再试", "玉兔毫输入法")
        return
    }

    if VerCompare(ver, RABBIT_VERSION) > 0 {
        down := MsgBox(Format("发现新版本：{}`r`n是否前往下载？", ver), "玉兔毫输入法", "YesNo")
        if down == "Yes" {
            arch := A_Is64BitOS ? "x64" : "x86"
            Run(Format("https://github.com/rimeinn/rabbit/releases/download/v{1}/rabbit-v{1}-{2}.zip", ver, arch))
        }
    } else {
        MsgBox("当前已是最新版本", "玉兔毫输入法")
    }
}
