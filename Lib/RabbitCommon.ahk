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

global RABBIT_VERSION := "dev"
;@Ahk2Exe-SetCompanyName rimeinn
;@Ahk2Exe-SetCopyright Copyright (c) 2023 - 2025 Xuesong Peng
;@Ahk2Exe-SetDescription 由 AutoHotkey 实现的 Rime 输入法
;@Ahk2Exe-Let U_version = %A_PriorLine~U)^(.+"){1}(.+)".*$~$2%
;@Ahk2Exe-SetVersion %U_version%
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetMainIcon Lib\rabbit.ico
;@Ahk2Exe-AddResource Lib\rabbit-ascii.ico, 160
;@Ahk2Exe-AddResource Lib\rabbit-alt.ico,   206

#Include <librime-ahk\rime_api>
#Include <librime-ahk\rime_levers_api>

global AHK_NOTIFYICON := 0x404
global WM_LBUTTONDOWN := 0x201
global WM_LBUTTONUP := 0x202
global WM_SETTINGCHANGE := 0x001A
global WM_DWMCOLORIZATIONCOLORCHANGED := 0x0320

global rime := RimeApi(A_ScriptDir . "\Lib\librime-ahk\rime.dll")
global RABBIT_IME_NAME := "玉兔毫"
global RABBIT_CODE_NAME := "Rabbit"
global RABBIT_NO_MAINTENANCE := "0"
global RABBIT_PARTIAL_MAINTENANCE := "1"
global RABBIT_FULL_MAINTENANCE := "2"

global IN_MAINTENANCE := false
global STATUS_TOOLTIP := 2
global box := 0
global rabbit_traits
global IS_DARK_MODE := false
global ASCII_MODE_FALSE_LABEL := "中文"
global ASCII_MODE_TRUE_LABEL := "西文"
global ASCII_MODE_FALSE_LABEL_ABBR := "中"
global ASCII_MODE_TRUE_LABEL_ABBR := "西"
global FULL_SHAPE_FALSE_LABEL := "半角"
global FULL_SHAPE_TRUE_LABEL := "全角"
global FULL_SHAPE_FALSE_LABEL_ABBR := "半"
global FULL_SHAPE_TRUE_LABEL_ABBR := "全"
global ASCII_PUNCT_FALSE_LABEL := "。，"
global ASCII_PUNCT_TRUE_LABEL := ". ,"
global ASCII_PUNCT_FALSE_LABEL_ABBR := "。"
global ASCII_PUNCT_TRUE_LABEL_ABBR := "."

global ERROR_ALREADY_EXISTS := 183 ; https://learn.microsoft.com/windows/win32/debug/system-error-codes--0-499-

IsOldWindows() {
    return VerCompare(A_OSVersion, "< 10")
}

class RabbitGlobals {
    static process_ascii := Map()
    static on_tray_icon_click := false
    static active_win := ""
    static current_schema_icon := ""
    static keyboard_layout := 0x0409
}

class RabbitMutex {
    handle := 0
    lasterr := 0
    Create() {
        this.lasterr := 0
        this.handle := DllCall("CreateMutex", "Ptr", 0, "Int", true, "Str", "RabbitDeployerMutex")
        if A_LastError == ERROR_ALREADY_EXISTS {
            this.lasterr := ERROR_ALREADY_EXISTS
        }
        return this.handle
    }
    Close() {
        if this.handle {
            DllCall("CloseHandle", "Ptr", this.handle)
            this.handle := 0
        }
    }
}

CreateTraits() {
    traits := RimeTraits()
    traits.distribution_name := RABBIT_IME_NAME
    traits.distribution_code_name := RABBIT_CODE_NAME
    traits.distribution_version := RABBIT_VERSION
    traits.app_name := "rime.rabbit"
    traits.shared_data_dir := RabbitSharedDataPath()
    traits.user_data_dir := RabbitUserDataPath()
    traits.prebuilt_data_dir := traits.shared_data_dir
    traits.log_dir := RabbitLogPath()

    return traits
}

RabbitUserDataPath() {
    if FileExist(A_ScriptDir . "\.portable") {
        RabbitDebug("run in portable mode.", Format("RabbitCommon.ahk:{}", A_LineNumber), 1)
        return A_ScriptDir . "\Rime"
    }
    try {
        local dir := RegRead("HKEY_CURRENT_USER\Software\Rime\Rabbit", "RimeUserDir")
    }
    if IsSet(dir) && dir && Type(dir) = "String" {
        size := DllCall("ExpandEnvironmentStrings", "Str", dir, "Ptr", 0, "UInt", 0)
        path := Buffer(size * 2, 0)
        DllCall("ExpandEnvironmentStrings", "Str", dir, "Ptr", path, "UInt", path.Size)
        return StrGet(path)
    }
    return A_ScriptDir . "\Rime"
}

RabbitSharedDataPath() {
    return A_ScriptDir . "\Data"
}

RabbitLogPath() {
    path := A_Temp . "\rime.rabbit"
    if !DirExist(path)
        DirCreate(path)
    return path
}

OnRimeMessage(context_object, session_id, message_type, message_value) {
    msg_type := StrGet(message_type, "UTF-8")
    msg_value := StrGet(message_value, "UTF-8")
    if msg_type = "deploy" {
        if msg_value = "start" {
            TrayTip()
            TrayTip("维护中", RABBIT_IME_NAME)
        } else if msg_value = "success" {
            TrayTip()
            TrayTip("维护完成", RABBIT_IME_NAME)
            SetTimer(TrayTip, -2000)
        } else {
            TrayTip(msg_type . ": " . msg_value . " (" . session_id . ")", RABBIT_IME_NAME)
        }
    } else {
        ; TrayTip(msg_type . ": " . msg_value . " (" . session_id . ")", RABBIT_IME_NAME)
    }
}

CleanOldLogs() {
    app_name := "rime.rabbit"
    dir := RabbitLogPath()
    if !DirExist(dir)
        return

    files := []
    try {
        loop files dir, "R" {
            if InStr(A_LoopFileAttrib, "N") && !InStr(A_LoopFileAttrib, "L")
                    && SubStr(A_LoopFileName, 1, StrLen(app_name)) == app_name
                    && SubStr(A_LoopFileName, -4) == ".log"
                    && !InStr(A_LoopFileName, A_YYYY A_MM A_DD) {
                files.Push(A_LoopFileFullPath)
            }
        }
    }

    for file in files {
        try {
            FileDelete(file)
        }
    }
}

CleanMisPlacedConfigs() {
    shared := RabbitSharedDataPath()
    user := RabbitUserDataPath()

    if shared == user
        return

    if FileExist(user . "\default.yaml") {
        RabbitWarn(Format("renaming unnecessary file {}\default.yaml", user), Format("RabbitCommon.ahk:{}", A_LineNumber))
        FileMove(user . "\default.yaml", user . "\default.yaml.old", 1)
    }
    if FileExist(user . "\rabbit.yaml") {
        RabbitWarn(Format("renaming unnecessary file {}\rabbit.yaml", user), Format("RabbitCommon.ahk:{}", A_LineNumber))
        FileMove(user . "\rabbit.yaml", user . "\rabbit.yaml.old", 1)
    }
}

RabbitLog(text) {
    try {
        FileAppend(text, "*", "UTF-8")
    }
}
RabbitLogLimit(text, label, limit := 1) {
    static labels := Map()
    if !labels.Has(label)
        labels[label] := 0
    if limit < 0 || labels[label] < limit {
        RabbitLog(text)
        labels[label] := labels[label] + 1
    }
}
RabbitError(text, location, limit := -1) {
    msg := Format("E{} {:5} {}] {}`r`n", FormatTime(, "yyyyMMdd HH:mm:ss       "), ProcessExist(), location, text)
    RabbitLogLimit(msg, location, limit)
}
RabbitWarn(text, location, limit := -1) {
    msg := Format("W{} {:5} {}] {}`r`n", FormatTime(, "yyyyMMdd HH:mm:ss       "), ProcessExist(), location, text)
    RabbitLogLimit(msg, location, limit)
}
RabbitInfo(text, location, limit := -1) {
    msg := Format("I{} {:5} {}] {}`r`n", FormatTime(, "yyyyMMdd HH:mm:ss       "), ProcessExist(), location, text)
    RabbitLogLimit(msg, location, limit)
}
RabbitDebug(text, location, limit := -1) {
    global RABBIT_VERSION
    if !SubStr(RABBIT_VERSION, 1, 3) = "dev"
        return
    msg := Format("D{} {:5} {}] {}`r`n", FormatTime(, "yyyyMMdd HH:mm:ss       "), ProcessExist(), location, text)
    RabbitLogLimit(msg, location, limit)
}
