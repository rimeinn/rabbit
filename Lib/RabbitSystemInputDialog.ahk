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

#Include RabbitSystemInputProfiles.ahk

class RabbitSystemInputDialog extends Gui {
    __New(enabled_profiles, available_profiles, configured_klid := "") {
        super.__New("-MaximizeBox -MinimizeBox", "【玉兔毫】系统键盘布局", this)
        this.enabled_profiles := enabled_profiles.Clone()
        this.available_profiles := available_profiles.Clone()
        this.pending_profile := 0
        this.accepted := false
        this.selected_profile := 0
        this.accept_callback := 0
        this.activation_attempted := false
        this.activation_succeeded := false
        this.disposed := false

        this.MarginX := 15
        this.MarginY := 15
        this.AddText("w430", "当前系统输入法可能会与玉兔毫同时处理键盘输入。`r`n请选择玉兔毫运行期间使用的键盘布局：")
        this.enabled_list := this.AddDropDownList("w430")
        this.AddText("xm y+18", "或者选择新的键盘布局：")
        this.available_list := this.AddComboBox("Section w340")
        this.add_button := this.AddButton("ys w80", "添加")
        this.add_button.OnEvent("Click", (*) => this.StageAvailableProfile())
        this.ok_button := this.AddButton("xm+245 y+22 w90 Default", "确定")
        this.cancel_button := this.AddButton("x+10 w90", "取消")
        this.ok_button.OnEvent("Click", (*) => this.OnOK())
        this.cancel_button.OnEvent("Click", (*) => this.Exit(false))
        this.OnEvent("Close", (*) => this.Exit(false))
        this.OnEvent("Escape", (*) => this.Exit(false))

        this.PopulateAvailable()
        this.SelectInitialProfile(configured_klid)
    }

    SelectInitialProfile(configured_klid) {
        local index := this.FindByKlid(this.enabled_profiles, configured_klid)
        if index {
            this.PopulateEnabled(index)
            return
        }

        index := this.FindByKlid(this.available_profiles, configured_klid)
        if index {
            this.available_list.Choose(index)
            this.StageAvailableProfile()
            return
        }

        index := this.FindByKlid(this.enabled_profiles, "00000409")
        this.PopulateEnabled(index ? index : (this.enabled_profiles.Length ? 1 : 0))
    }

    StageAvailableProfile() {
        local index := this.available_list.Value
        if index < 1 || index > this.available_profiles.Length {
            return
        }
        this.pending_profile := this.available_profiles[index]
        this.PopulateEnabled(this.enabled_profiles.Length + 1)
    }

    PopulateEnabled(selected_index := 0) {
        local names := []
        for profile in this.enabled_profiles {
            names.Push(profile.display_name)
        }
        if this.pending_profile {
            names.Push(this.pending_profile.display_name . "（待添加）")
        }
        this.enabled_list.Delete()
        if names.Length {
            this.enabled_list.Add(names)
        }
        if selected_index {
            this.enabled_list.Choose(selected_index)
        }
    }

    PopulateAvailable() {
        local names := []
        for profile in this.available_profiles {
            names.Push(profile.display_name)
        }
        if names.Length {
            this.available_list.Add(names)
            this.available_list.Choose(1)
        } else {
            this.add_button.Enabled := false
        }
    }

    OnOK() {
        local index := this.enabled_list.Value
        if index < 1 {
            MsgBox(
                "必须选择一个键盘布局，否则系统输入法会与玉兔毫冲突。",
                "【玉兔毫】",
                "Ok Icon!"
            )
            return
        }
        if index <= this.enabled_profiles.Length {
            this.selected_profile := this.enabled_profiles[index]
        } else if this.pending_profile && index == this.enabled_profiles.Length + 1 {
            this.selected_profile := this.pending_profile
        } else {
            return
        }
        if this.accept_callback {
            this.activation_attempted := true
            this.activation_succeeded := this.accept_callback.Call(this.selected_profile, this.Hwnd)
        }
        this.Exit(true)
    }

    FindByKlid(profiles, klid) {
        if !klid {
            return 0
        }
        for index, profile in profiles {
            if StrUpper(profile.klid) = StrUpper(klid) {
                return index
            }
        }
        return 0
    }

    Exit(accepted) {
        this.accepted := accepted
        this.Dispose()
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try this.Destroy()
    }
}
