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

#Include RabbitBehaviorSettingsModel.ahk

class RabbitKeyBindingDialog extends Gui {
    static STANDARD_ACTIONS := ["send", "toggle", "select", "send_sequence"]

    __New(owner, binding := 0) {
        local action_key, action_value
        super.__New(
            "+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox",
            binding ? "编辑快捷键规则" : "添加快捷键规则",
            this
        )
        this.binding := binding
            ? RabbitBehaviorSettingsModel.CloneValue(binding)
            : Map()
        this.original_action_key := RabbitKeyBindingDialog.FindAction(this.binding, &action_value)
        action_key := this.original_action_key ? this.original_action_key : "send"
        if !this.original_action_key {
            action_value := ""
        }
        this.result := 0
        this.MarginX := 20
        this.MarginY := 18
        this.SetFont("s10", "Microsoft YaHei UI")

        this.AddText("x20 y22 w86 h22", "接收按键：")
        this.accept := this.AddEdit("x110 y18 w330 r1 -Multi", this.binding.Has("accept") ? this.binding["accept"] : "")
        this.AddText("x20 y60 w86 h22", "生效条件：")
        this.when := this.AddComboBox(
            "x110 y56 w330",
            ["composing", "has_menu", "paging", "always"]
        )
        this.when.Text := this.binding.Has("when") ? this.binding["when"] : "composing"
        this.AddText("x20 y98 w86 h22", "动作字段：")
        this.action_key := this.AddComboBox("x110 y94 w150", RabbitKeyBindingDialog.STANDARD_ACTIONS)
        this.action_key.Text := action_key
        this.AddText("x274 y98 w48 h22", "值：")
        this.action_value := this.AddEdit("x326 y94 w114 r1 -Multi", action_value)

        this.status := this.AddText("x20 y136 w420 h24 cRed", "")
        this.save_button := this.AddButton("x272 y172 w80 h32 Default", "确定")
        this.save_button.OnEvent("Click", (*) => this.SaveBinding())
        this.cancel_button := this.AddButton("x360 y172 w80 h32", "取消")
        this.cancel_button.OnEvent("Click", (*) => this.Destroy())
        this.OnEvent("Escape", (*) => this.Destroy())
    }

    ShowModal() {
        this.Show("w460 h222")
        WinWaitClose("ahk_id " . this.Hwnd)
        return this.result
    }

    SaveBinding() {
        local accept := Trim(this.accept.Value)
        local action_key := Trim(this.action_key.Text)
        local action_value := Trim(this.action_value.Value)
        local when := Trim(this.when.Text)
        if !accept {
            this.status.Value := "接收按键不能为空。"
            return false
        }
        if !action_key || action_key = "accept" || action_key = "when" {
            this.status.Value := "动作字段无效。"
            return false
        }
        if !action_value {
            this.status.Value := "动作值不能为空。"
            return false
        }

        if this.original_action_key && this.original_action_key != action_key {
            this.binding.Delete(this.original_action_key)
        }
        this.binding["accept"] := accept
        if when {
            this.binding["when"] := when
        } else if this.binding.Has("when") {
            this.binding.Delete("when")
        }
        this.binding[action_key] := action_value
        this.result := this.binding
        this.Destroy()
        return true
    }

    static FindAction(binding, &value) {
        local item, key
        for key in RabbitKeyBindingDialog.STANDARD_ACTIONS {
            if binding.Has(key) {
                value := binding[key]
                return key
            }
        }
        for key, item in binding {
            if key != "accept" && key != "when" {
                value := item
                return key
            }
        }
        value := ""
        return ""
    }
}
