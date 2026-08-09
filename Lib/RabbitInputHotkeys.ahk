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

#Include RabbitKeyTable.ahk

class RabbitInputHotkeys {
    __New() {
        this._registrations := []
        this._registration_map := Map()
        this._standalone_sources := Map()
    }

    AddConfig(rime_api, config) {
        if !rime_api || !config {
            return
        }
        this.AddSwitcherHotkeys(rime_api, config)
        this.AddKeyBinderBindings(rime_api, config)
        this.AddAsciiComposerSwitchKeys(rime_api, config)
    }

    Finalize() {
        local registration
        for registration in this._registrations {
            if !this._standalone_sources.Has(registration.key) {
                continue
            }
            local sources := this._standalone_sources[registration.key]
            registration.pass_through := sources.Has("ascii")
                && !sources.Has("key_binder")
                && !sources.Has("switcher")
        }
    }

    GetRegistrations() {
        return this._registrations.Clone()
    }

    AddSwitcherHotkeys(rime_api, config) {
        local iter, hotkey
        if !(iter := rime_api.config_begin_list(config, "switcher/hotkeys")) {
            return
        }
        try {
            while rime_api.config_next(iter) {
                if (hotkey := rime_api.config_get_string(config, iter.path)) {
                    this.AddBinding(hotkey, "switcher")
                }
            }
        } finally {
            rime_api.config_end(iter)
        }
    }

    AddKeyBinderBindings(rime_api, config) {
        local iter, accept
        if !(iter := rime_api.config_begin_list(config, "key_binder/bindings")) {
            return
        }
        try {
            while rime_api.config_next(iter) {
                if rime_api.config_test_get_string(
                    config,
                    iter.path . "/accept",
                    &accept
                ) {
                    this.AddBinding(accept, "key_binder")
                }
            }
        } finally {
            rime_api.config_end(iter)
        }
    }

    AddAsciiComposerSwitchKeys(rime_api, config) {
        local iter, switch_action
        if !(iter := rime_api.config_begin_map(config, "ascii_composer/switch_key")) {
            return
        }
        try {
            while rime_api.config_next(iter) {
                switch_action := rime_api.config_get_string(config, iter.path)
                ; librime treats noop as a disabled switch key; do not intercept it as an ASCII source.
                if switch_action != "noop" {
                    this.AddBinding(iter.key, "ascii")
                }
            }
        } finally {
            rime_api.config_end(iter)
        }
    }

    AddBinding(binding, source) {
        local release := false
        local modifiers := []
        local target := ""
        local token
        for token in StrSplit(binding, "+") {
            token := Trim(token)
            if !token {
                return
            }
            if token = "Release" {
                if release {
                    return
                }
                release := true
                continue
            }
            if this.IsModifier(token) {
                if this.ArrayHas(modifiers, token) {
                    return
                }
                modifiers.Push(token)
            } else if target {
                return
            } else {
                target := token
            }
        }

        if !target {
            if modifiers.Length != 1 {
                return
            }
            this.AddStandalone(modifiers[1], release, source)
            return
        }

        if this.IsModifier(target) {
            if modifiers.Length {
                return
            }
            this.AddStandalone(target, release, source)
            return
        }

        if !this.TryNormalizeKey(target, &target) {
            ; Unsupported or malformed entries are intentionally ignored. The
            ; input layer only registers key names it can map without changing
            ; the existing Alt/Win support boundary.
            return
        }
        if !modifiers.Length {
            if release {
                this.AddRegistration(target, 0, true, "", false)
            }
            return
        }
        if this.HasUnsupportedWinModifier(modifiers) {
            ; Win-key combinations are intentionally unsupported for now.
            return
        }

        local prefix := ""
        for token in modifiers {
            prefix .= this.ModifierPrefix(token)
        }
        this.AddRegistration(target, this.ModifierMask(modifiers), release, prefix, false)
    }

    AddStandalone(modifier, release, source) {
        local info
        if !this.TryGetModifierInfo(modifier, &info) {
            return
        }
        if info.HasOwnProp("unsupported") && info.unsupported {
            ; Standalone Alt and Win are intentionally unsupported for now.
            return
        }
        local key
        for key in info.keys {
            this.AddRegistration(
                key,
                info.mask,
                release,
                "",
                false
            )
            if source = "ascii" && !release {
                ; AsciiComposer needs the real modifier lifecycle to measure
                ; the single-modifier press duration before toggling.
                this.AddRegistration(
                    key,
                    info.mask,
                    true,
                    "",
                    false
                )
            }
            if !this._standalone_sources.Has(key) {
                this._standalone_sources[key] := Map()
            }
            this._standalone_sources[key][source] := true
        }
    }

    AddRegistration(key, mask, release, prefix, pass_through) {
        local id := key . "|" . mask . "|" . (release ? 1 : 0) . "|" . prefix
        if this._registration_map.Has(id) {
            return
        }
        local registration := {
            key: key,
            mask: mask | (release ? KeyDef.mask["Up"] : 0),
            hotkey: prefix . key . (release ? " Up" : ""),
            pass_through: pass_through
        }
        this._registration_map[id] := registration
        this._registrations.Push(registration)
    }

    TryNormalizeKey(token, &key) {
        if KeyDef.rime_to_ahk.Has(token) {
            key := KeyDef.rime_to_ahk[token]
            return this.IsKnownKey(key)
        }
        local normalized := StrLower(token)
        if KeyDef.rime_to_ahk.Has(normalized) {
            key := KeyDef.rime_to_ahk[normalized]
            return this.IsKnownKey(key)
        }
        if this.IsKnownKey(token) {
            key := token
            return true
        }
        return false
    }

    IsKnownKey(key) {
        return KeyDef.plain_keycode.Has(key)
            || KeyDef.shifted_keycode.Has(key)
            || KeyDef.other_keycode.Has(key)
    }

    IsModifier(token) {
        local info
        return this.TryGetModifierInfo(token, &info)
    }

    TryGetModifierInfo(token, &info) {
        switch token {
            case "Shift":
                info := { ahk: "+", mask: KeyDef.mask["Shift"], keys: ["LShift", "RShift"] }
            case "Shift_L":
                info := { ahk: "<+", mask: KeyDef.mask["Shift"], keys: ["LShift"] }
            case "Shift_R":
                info := { ahk: ">+", mask: KeyDef.mask["Shift"], keys: ["RShift"] }
            case "Control":
                info := { ahk: "^", mask: KeyDef.mask["Ctrl"], keys: ["LCtrl", "RCtrl"] }
            case "Control_L":
                info := { ahk: "<^", mask: KeyDef.mask["Ctrl"], keys: ["LCtrl"] }
            case "Control_R":
                info := { ahk: ">^", mask: KeyDef.mask["Ctrl"], keys: ["RCtrl"] }
            case "Alt":
                info := { ahk: "!", mask: KeyDef.mask["Alt"], keys: ["LAlt", "RAlt"], unsupported: true }
            case "Alt_L":
                info := { ahk: "<!", mask: KeyDef.mask["Alt"], keys: ["LAlt"], unsupported: true }
            case "Alt_R":
                info := { ahk: ">!", mask: KeyDef.mask["Alt"], keys: ["RAlt"], unsupported: true }
            case "Super":
                info := { ahk: "#", mask: KeyDef.mask["Win"], keys: ["LWin", "RWin"], unsupported: true }
            case "Super_L":
                info := { ahk: "<#", mask: KeyDef.mask["Win"], keys: ["LWin"], unsupported: true }
            case "Super_R":
                info := { ahk: ">#", mask: KeyDef.mask["Win"], keys: ["RWin"], unsupported: true }
            default:
                return false
        }
        return true
    }

    ModifierPrefix(token) {
        local info
        this.TryGetModifierInfo(token, &info)
        return info.ahk
    }

    ModifierMask(modifiers) {
        local mask := 0
        local modifier
        for modifier in modifiers {
            local info
            this.TryGetModifierInfo(modifier, &info)
            mask |= info.mask
        }
        return mask
    }

    HasUnsupportedWinModifier(modifiers) {
        local modifier
        for modifier in modifiers {
            if modifier = "Super" || InStr(modifier, "Super_") = 1 {
                return true
            }
        }
        return false
    }

    ArrayHas(array, value) {
        local item
        for item in array {
            if item = value {
                return true
            }
        }
        return false
    }
}
