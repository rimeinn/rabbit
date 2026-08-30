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
 *
 */

#Include RabbitCommon.ahk

class RabbitApplicationOptions {
    __New() {
        this.maintenance := RABBIT_PARTIAL_MAINTENANCE
        this.keyboard_layout := 0
    }

    static Parse(args) {
        local argument, index, options, seen
        options := RabbitApplicationOptions()
        seen := Map()
        index := 1
        while index <= args.Length {
            argument := args[index]
            switch argument {
                case "--maintenance":
                    RabbitRequireUniqueOption(seen, argument)
                    options.maintenance := RabbitParseMaintenanceMode(
                        RabbitRequireOptionValue(args, &index, argument)
                    )
                case "--keyboard-layout":
                    RabbitRequireUniqueOption(seen, argument)
                    options.keyboard_layout := RabbitParseKeyboardLayout(
                        RabbitRequireOptionValue(args, &index, argument)
                    )
                default:
                    throw ValueError("未知的 Rabbit 参数：" . argument)
            }
            index++
        }
        return options
    }
}

class RabbitDeployerOptions {
    __New() {
        this.command := "settings"
        this.target := ""
        this.installing := false
        this.return_to_rabbit := false
        this.keyboard_layout := 0
        this.keyboard_layout_provided := false
    }

    static Parse(args) {
        local argument, index, options, positionals, seen
        options := RabbitDeployerOptions()
        positionals := []
        seen := Map()
        index := 1
        while index <= args.Length {
            argument := args[index]
            switch argument {
                case "--install":
                    RabbitRequireUniqueOption(seen, argument)
                    options.installing := true
                case "--return-to-rabbit":
                    RabbitRequireUniqueOption(seen, argument)
                    options.return_to_rabbit := true
                case "--keyboard-layout":
                    RabbitRequireUniqueOption(seen, argument)
                    options.keyboard_layout := RabbitParseKeyboardLayout(
                        RabbitRequireOptionValue(args, &index, argument)
                    )
                    options.keyboard_layout_provided := true
                default:
                    if SubStr(argument, 1, 2) = "--" {
                        throw ValueError("未知的 RabbitDeployer 参数：" . argument)
                    }
                    positionals.Push(argument)
            }
            index++
        }

        if positionals.Length > 2 {
            throw ValueError("RabbitDeployer 收到了过多的位置参数。")
        }
        if positionals.Length >= 1 {
            options.command := positionals[1]
        }
        if positionals.Length >= 2 {
            options.target := positionals[2]
        }
        options.Validate()
        return options
    }

    Validate() {
        switch this.command {
            case "settings":
            case "legacy-settings":
                if this.target && this.target != "dictionary" {
                    throw ValueError("legacy-settings 仅支持 dictionary 子命令。")
                }
            case "deploy", "sync":
                if this.target {
                    throw ValueError(this.command . " 命令不接受目标参数。")
                }
            default:
                throw ValueError("未知的 RabbitDeployer 命令：" . this.command)
        }

        if this.installing {
            if this.command = "settings" && this.target != "input-schemes" {
                throw ValueError("首次安装必须打开 settings input-schemes。")
            }
            if this.command = "legacy-settings" && this.target {
                throw ValueError("旧版首次安装不接受子命令。")
            }
            if this.command != "settings" && this.command != "legacy-settings" {
                throw ValueError("--install 仅适用于设置命令。")
            }
        }
        if this.return_to_rabbit && !this.keyboard_layout_provided {
            throw ValueError("--return-to-rabbit 要求同时提供 --keyboard-layout。")
        }
    }
}

RabbitRequireUniqueOption(seen, option) {
    if seen.Has(option) {
        throw ValueError("参数重复：" . option)
    }
    seen[option] := true
}

RabbitRequireOptionValue(args, &index, option) {
    if index >= args.Length || SubStr(args[index + 1], 1, 2) = "--" {
        throw ValueError(option . " 缺少参数值。")
    }
    index++
    return args[index]
}

RabbitParseMaintenanceMode(value) {
    switch value {
        case "none":
            return RABBIT_NO_MAINTENANCE
        case "partial":
            return RABBIT_PARTIAL_MAINTENANCE
        case "full":
            return RABBIT_FULL_MAINTENANCE
        default:
            throw ValueError("未知的维护模式：" . value)
    }
}

RabbitMaintenanceModeName(value) {
    switch value {
        case RABBIT_NO_MAINTENANCE:
            return "none"
        case RABBIT_PARTIAL_MAINTENANCE:
            return "partial"
        case RABBIT_FULL_MAINTENANCE:
            return "full"
        default:
            throw ValueError("无效的维护模式：" . value)
    }
}

RabbitParseKeyboardLayout(value) {
    local layout
    try {
        layout := Number(value)
    } catch {
        throw ValueError("无效的键盘布局：" . value)
    }
    if Type(layout) != "Integer" || layout <= 0 {
        throw ValueError("无效的键盘布局：" . value)
    }
    return layout
}

RabbitFormatKeyboardLayout(layout) {
    return Format("0x{:04X}", layout)
}

RabbitQuoteCommandLineArgument(argument) {
    local backslashes := 0
    local character, quoted := '"'
    argument := String(argument)
    Loop Parse argument {
        character := A_LoopField
        if character = "\" {
            backslashes++
            continue
        }
        if character = '"' {
            quoted .= RabbitRepeatString("\", backslashes * 2 + 1) . '"'
        } else {
            quoted .= RabbitRepeatString("\", backslashes) . character
        }
        backslashes := 0
    }
    return quoted . RabbitRepeatString("\", backslashes * 2) . '"'
}

RabbitBuildCommandLine(arguments) {
    local argument, command_line := ""
    for argument in arguments {
        command_line .= (command_line ? " " : "") . RabbitQuoteCommandLineArgument(argument)
    }
    return command_line
}

RabbitRepeatString(value, count) {
    local result := ""
    Loop count {
        result .= value
    }
    return result
}
