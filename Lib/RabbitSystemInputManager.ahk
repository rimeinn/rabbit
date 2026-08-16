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

#Include RabbitCommon.ahk
#Include RabbitSystemInputProfiles.ahk

class RabbitSystemInputManager {
    __New(rime_api, profiles_api := 0) {
        this.rime := rime_api
        this.profiles := profiles_api
        this.restore_state := RabbitSystemInputRestoreState()
        this.bypass := false
        this.configuration_required := false
    }

    Initialize(serialized_state := "") {
        this.bypass := this.ShouldBypass()
        if this.bypass {
            return
        }
        this.EnsureProfilesApi()
        if serialized_state && serialized_state != "none" {
            this.restore_state := RabbitSystemInputRestoreState.Deserialize(serialized_state)
        }
        if !this.restore_state.profile {
            this.restore_state.profile := this.profiles.GetActiveProfile()
        }
    }

    Prepare(config) {
        if this.bypass {
            return true
        }
        this.EnsureProfilesApi()
        local current := this.profiles.GetActiveProfile()
        if this.profiles.IsRabbitCompatible(current) {
            return true
        }
        if !current.IsKeyboardLayout()
            && current.profile_type != RabbitSystemInputProfile.INPUT_PROCESSOR {
            throw Error("Windows 返回了未知的系统输入 profile 类型。")
        }
        local enabled := []
        for profile in this.profiles.EnumerateProfiles() {
            if profile.IsEnabled() && this.profiles.IsRabbitCompatible(profile) {
                enabled.Push(profile)
            }
        }

        local configured_klid := this.NormalizeKlid(config.system_input_layout)
        local target := this.FindByKlid(enabled, configured_klid)
        if !target {
            this.configuration_required := true
            return false
        }

        local switch_window := this.profiles.GetForegroundWindow()
        if !this.profiles.Activate(target, false, switch_window) {
            throw Error("Windows 未能切换到所选键盘布局。")
        }
        this.restore_state.pending := true
        local active := this.profiles.GetActiveKeyboardProfile(target, switch_window)
        if !active {
            throw Error("Windows 未能确认所选键盘布局已经生效。")
        }

        return true
    }

    Restore() {
        if this.bypass || this.ShouldBypass() || !this.restore_state.pending
            || !this.restore_state.profile {
            return true
        }
        try {
            this.EnsureProfilesApi()
            return this.profiles.Activate(this.restore_state.profile)
        } catch {
            return false
        }
    }

    SerializeState() {
        return this.bypass ? "none" : this.restore_state.Serialize()
    }

    ShouldBypass() {
        return !!FileExist(RabbitUserDataPath() . "\.lang")
    }

    FindByKlid(profiles, klid) {
        if !klid {
            return 0
        }
        for profile in profiles {
            if StrUpper(profile.klid) = klid {
                return profile
            }
        }
        return 0
    }

    NormalizeKlid(value) {
        local klid := StrUpper(value)
        return RegExMatch(klid, "^[0-9A-F]{8}$") ? klid : ""
    }

    EnsureProfilesApi() {
        if !this.profiles {
            this.profiles := RabbitSystemInputProfiles()
        }
    }
}
