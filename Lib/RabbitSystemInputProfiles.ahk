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

class RabbitSystemInputProfile {
    static INPUT_PROCESSOR := 1
    static KEYBOARD_LAYOUT := 2
    static ENABLED := 0x2

    __New(
        profile_type,
        langid,
        clsid,
        guid_profile,
        hkl,
        flags := 0,
        hkl_substitute := 0
    ) {
        this.profile_type := profile_type
        this.langid := langid
        this.clsid := clsid
        this.guid_profile := guid_profile
        this.hkl := hkl
        this.flags := flags
        this.hkl_substitute := hkl_substitute
        this.klid := ""
        this.display_name := ""
    }

    IsKeyboardLayout() {
        return this.profile_type == RabbitSystemInputProfile.KEYBOARD_LAYOUT
    }

    IsEnabled() {
        return !!(this.flags & RabbitSystemInputProfile.ENABLED)
    }

    Serialize() {
        return Format(
            "{};{:04X};{};{};{:X};{:X}",
            this.profile_type,
            this.langid,
            this.clsid,
            this.guid_profile,
            this.hkl,
            this.hkl_substitute
        )
    }

    static Deserialize(value) {
        local fields := StrSplit(value, ";")
        if fields.Length != 5 && fields.Length != 6 {
            throw ValueError("Invalid system input profile state.")
        }
        return RabbitSystemInputProfile(
            Number(fields[1]),
            Number("0x" . fields[2]),
            fields[3],
            fields[4],
            Number("0x" . fields[5]),
            0,
            fields.Length == 6 ? Number("0x" . fields[6]) : 0
        )
    }
}

class RabbitSystemInputRestoreState {
    __New(profile := 0, pending := false) {
        this.profile := profile
        this.pending := pending
    }

    Serialize() {
        if !this.profile {
            return "none"
        }
        return "v2;" . (this.pending ? "1" : "0") . ";" . this.profile.Serialize()
    }

    static Deserialize(value) {
        if !value || value = "none" {
            return RabbitSystemInputRestoreState()
        }
        local fields := StrSplit(value, ";")
        if (fields[1] != "v1" || fields.Length != 7)
            && (fields[1] != "v2" || fields.Length != 8) {
            throw ValueError("Invalid system input restore state.")
        }
        return RabbitSystemInputRestoreState(
            RabbitSystemInputProfile.Deserialize(
                fields[3] . ";" . fields[4] . ";" . fields[5] . ";"
                    . fields[6] . ";" . fields[7]
                    . (fields.Length == 8 ? ";" . fields[8] : "")
            ),
            fields[2] == "1"
        )
    }
}

class RabbitSystemInputProfiles {
    static CLSID_INPUT_PROCESSOR_PROFILES := "{33C53A50-F456-4884-B049-85FD643ECFED}"
    static IID_PROFILE_MANAGER := "{71C6E74C-0F28-11D8-A82A-00065B84435C}"
    static GUID_TIP_KEYBOARD := "{34745C63-B2F0-4784-8B67-5E12C8701A31}"
    static NULL_GUID := "{00000000-0000-0000-0000-000000000000}"

    static TF_IPPMF_ENABLEPROFILE := 0x00000001
    static TF_IPPMF_DONTCARECURRENTINPUTLANGUAGE := 0x00000004
    static TF_IPPMF_FORSESSION := 0x20000000

    ; Rabbit registers printable characters as AutoHotkey key names. Ordinary layouts
    ; outside this set can expose non-ASCII names or map Rabbit punctuation to another key.
    static COMPATIBLE_KLIDS := Map(
        "00000409", true, ; US
        "00000809", true, ; United Kingdom
        "00010409", true, ; United States-Dvorak
        "00030409", true, ; United States-Dvorak for left hand
        "00040409", true, ; United States-Dvorak for right hand
        "00060409", true  ; Colemak
    )

    __New(profile_manager := 0) {
        this.profile_manager := profile_manager ? profile_manager : ComObject(
            RabbitSystemInputProfiles.CLSID_INPUT_PROCESSOR_PROFILES,
            RabbitSystemInputProfiles.IID_PROFILE_MANAGER
        )
        this.layout_records := this.LoadLayoutRecords()
    }

    GetActiveProfile() {
        local profile_buffer := Buffer(this.ProfileBufferSize(), 0)
        local category := this.GuidFromString(RabbitSystemInputProfiles.GUID_TIP_KEYBOARD)
        local result := ComCall(10, this.profile_manager, "Ptr", category, "Ptr", profile_buffer)
        if result != 0 {
            throw OSError(result, , "Windows did not return an active system input profile.")
        }
        return this.ReadProfile(profile_buffer)
    }

    EnumerateProfiles() {
        local enumerator := ComValue(13, 0)
        local result := ComCall(6, this.profile_manager, "UShort", 0, "Ptr*", enumerator)
        if result != 0 {
            throw OSError(result, , "Windows did not enumerate system input profiles.")
        }

        local profiles := []
        local profile_buffer := Buffer(this.ProfileBufferSize(), 0)
        local fetched := 0
        while ComCall(4, enumerator, "UInt", 1, "Ptr", profile_buffer, "UInt*", &fetched) == 0
            && fetched == 1 {
            local profile := this.ReadProfile(profile_buffer)
            if profile.IsKeyboardLayout() && profile.klid {
                profiles.Push(profile)
            }
        }
        return profiles
    }

    EnumerateAvailableLayouts(enabled_profiles) {
        local enabled_klids := Map()
        for profile in enabled_profiles {
            enabled_klids[StrUpper(profile.klid)] := true
        }

        local profiles := []
        for klid, record in this.layout_records {
            ; IME registry entries are input processors, not ordinary keyboard layouts.
            if !RabbitSystemInputProfiles.COMPATIBLE_KLIDS.Has(klid)
                || enabled_klids.Has(klid) || !this.IsLayoutLoadable(record) || record.ime_file {
                continue
            }
            local profile := RabbitSystemInputProfile(
                RabbitSystemInputProfile.KEYBOARD_LAYOUT,
                Number("0x" . SubStr(klid, 5, 4)),
                RabbitSystemInputProfiles.NULL_GUID,
                RabbitSystemInputProfiles.NULL_GUID,
                0
            )
            profile.klid := klid
            profile.display_name := this.GetDisplayName(profile)
            profiles.Push(profile)
        }
        return profiles
    }

    IsRabbitCompatible(profile) {
        return profile.IsKeyboardLayout()
            && RabbitSystemInputProfiles.COMPATIBLE_KLIDS.Has(StrUpper(profile.klid))
    }

    IsLayoutLoadable(record) {
        if !record.layout_file {
            return false
        }
        return !!FileExist(record.layout_file)
            || !!FileExist(A_WinDir . "\System32\" . record.layout_file)
    }

    Activate(profile, enable := false, target_window := 0) {
        if profile.IsKeyboardLayout() {
            return this.ActivateKeyboardProfile(profile, enable, target_window)
        }

        local result := 0
        try {
            result := this.CallActivateProfile(profile, enable)
        } catch {
            return false
        }
        if result != 0 {
            return false
        }
        if this.IsActive(profile, target_window) {
            return true
        }

        local activation_hkl := this.GetActivationHkl(profile)
        if !activation_hkl {
            return false
        }
        this.RequestLanguageChange(activation_hkl, target_window)
        return this.WaitUntilActive(profile, target_window)
    }

    ActivateKeyboardProfile(profile, enable := false, target_window := 0) {
        ; Keep the original SetDefaultKeyboard sequence: always load the KLID immediately before broadcasting its HKL.
        profile.hkl := this.LoadKeyboardProfile(profile.klid)
        if !profile.hkl {
            return false
        }
        if enable {
            ; Enabling is persistent TSF bookkeeping. It must not replace the actual keyboard switch below.
            try this.CallActivateProfile(profile, true)
            profile.hkl := this.LoadKeyboardProfile(profile.klid)
            if !profile.hkl {
                return false
            }
        }
        if !this.RequestLanguageChange(profile.hkl, target_window) {
            return false
        }
        return this.WaitUntilActive(profile, target_window)
    }

    LoadKeyboardProfile(klid) {
        return DllCall(
            "LoadKeyboardLayoutW",
            "WStr", klid,
            "UInt", 0,
            "Ptr"
        )
    }

    CallActivateProfile(profile, enable := false) {
        local clsid := this.GuidFromString(profile.clsid)
        local guid_profile := this.GuidFromString(profile.guid_profile)
        local flags := RabbitSystemInputProfiles.TF_IPPMF_FORSESSION
            | RabbitSystemInputProfiles.TF_IPPMF_DONTCARECURRENTINPUTLANGUAGE
        if enable {
            flags |= RabbitSystemInputProfiles.TF_IPPMF_ENABLEPROFILE
        }
        return ComCall(
            3,
            this.profile_manager,
            "UInt", profile.profile_type,
            "UShort", profile.langid,
            "Ptr", clsid,
            "Ptr", guid_profile,
            "Ptr", profile.hkl,
            "UInt", flags
        )
    }

    SameProfile(left, right) {
        if !left || !right || left.profile_type != right.profile_type || left.langid != right.langid {
            return false
        }
        if left.IsKeyboardLayout() {
            return left.hkl == right.hkl
                || (left.klid && right.klid && StrUpper(left.klid) = StrUpper(right.klid))
        }
        return StrUpper(left.clsid) = StrUpper(right.clsid)
            && StrUpper(left.guid_profile) = StrUpper(right.guid_profile)
    }

    ReadProfile(buffer) {
        local hkl_offset := this.HklOffset()
        local profile := RabbitSystemInputProfile(
            NumGet(buffer, 0, "UInt"),
            NumGet(buffer, 4, "UShort"),
            this.GuidToString(buffer.Ptr + 8),
            this.GuidToString(buffer.Ptr + 24),
            NumGet(buffer, hkl_offset, "Ptr"),
            NumGet(buffer, hkl_offset + A_PtrSize, "UInt"),
            NumGet(buffer, 56, "Ptr")
        )
        if profile.IsKeyboardLayout() {
            profile.klid := this.ResolveKlid(profile)
            profile.display_name := this.GetDisplayName(profile)
        }
        return profile
    }

    IsActive(profile, target_window := 0) {
        if profile.IsKeyboardLayout() {
            return !!this.GetActiveKeyboardProfile(profile, target_window)
        }
        return this.SameProfile(this.GetActiveProfile(), profile)
    }

    GetActiveKeyboardProfile(profile, target_window := 0) {
        if target_window {
            local target_active := this.GetWindowKeyboardProfile(target_window)
            return target_active && this.SameProfile(target_active, profile) ? target_active : 0
        }
        local active := this.GetActiveProfile()
        if active.IsKeyboardLayout() && this.SameProfile(active, profile) {
            return active
        }
        return 0
    }

    GetForegroundWindow() {
        return DllCall("user32\GetForegroundWindow", "Ptr")
    }

    GetWindowKeyboardProfile(window) {
        if !window || !DllCall("user32\IsWindow", "Ptr", window, "Int") {
            return 0
        }
        local process_id := 0
        local thread_id := DllCall(
            "user32\GetWindowThreadProcessId",
            "Ptr", window,
            "UInt*", &process_id,
            "UInt"
        )
        if !thread_id {
            return 0
        }
        local hkl := DllCall("user32\GetKeyboardLayout", "UInt", thread_id, "Ptr")
        if !hkl {
            return 0
        }
        local profile := RabbitSystemInputProfile(
            RabbitSystemInputProfile.KEYBOARD_LAYOUT,
            hkl & 0xFFFF,
            RabbitSystemInputProfiles.NULL_GUID,
            RabbitSystemInputProfiles.NULL_GUID,
            hkl,
            RabbitSystemInputProfile.ENABLED
        )
        profile.klid := this.ResolveKlid(profile)
        profile.display_name := this.GetDisplayName(profile)
        return profile
    }

    GetActivationHkl(profile) {
        if profile.IsKeyboardLayout() {
            return profile.hkl
        }
        if profile.hkl_substitute {
            return profile.hkl_substitute
        }
        for candidate in this.EnumerateProfiles() {
            if candidate.IsEnabled() && candidate.langid == profile.langid {
                return candidate.hkl
            }
        }
        return 0
    }

    RequestLanguageChange(hkl, target_window := 0) {
        try {
            ; Preserve Rabbit's original system-wide switching behavior.
            PostMessage(0x0050, 0, hkl, 0xFFFF)
            return true
        }
        return false
    }

    WaitUntilActive(profile, target_window := 0, timeout_ms := 2000) {
        local deadline := A_TickCount + timeout_ms
        while A_TickCount < deadline {
            Sleep(20)
            if this.IsActive(profile, target_window) {
                return true
            }
        }
        return false
    }

    ResolveKlid(profile) {
        local hkl_value := profile.hkl & 0xFFFFFFFF
        local direct := Format("{:08X}", hkl_value)
        if this.layout_records.Has(direct) {
            return direct
        }

        local low_word := hkl_value & 0xFFFF
        local high_word := (hkl_value >> 16) & 0xFFFF
        local default_klid := Format("0000{:04X}", low_word)
        if high_word == low_word && this.layout_records.Has(default_klid) {
            return default_klid
        }
        if (high_word & 0xF000) == 0xF000 {
            local layout_id := Format("{:04X}", high_word & 0x0FFF)
            for klid, record in this.layout_records {
                if record.layout_id && StrUpper(record.layout_id) = layout_id {
                    return klid
                }
            }
        }

        local match := ""
        for klid, record in this.layout_records {
            if Number("0x" . SubStr(klid, 5, 4)) != profile.langid {
                continue
            }
            if match {
                return ""
            }
            match := klid
        }
        return match
    }

    GetDisplayName(profile) {
        local language_name := this.GetLanguageName(profile.langid)
        local layout_name := profile.klid && this.layout_records.Has(profile.klid)
            ? this.layout_records[profile.klid].name : ""
        if language_name && layout_name && language_name != layout_name {
            return language_name . " — " . layout_name
        }
        return language_name ? language_name : (layout_name ? layout_name : profile.klid)
    }

    GetLanguageName(langid) {
        if langid == 0x0C00 {
            return ""
        }
        local locale_name := Buffer(170, 0)
        if !DllCall(
            "LCIDToLocaleName",
            "UInt", langid,
            "Ptr", locale_name,
            "Int", 85,
            "UInt", 0x08000000,
            "Int"
        ) {
            return Format("0x{:04X}", langid)
        }
        local display_name := Buffer(512, 0)
        if !DllCall(
            "GetLocaleInfoEx",
            "Ptr", locale_name,
            "UInt", 0x00000002,
            "Ptr", display_name,
            "Int", 256,
            "Int"
        ) {
            return StrGet(locale_name)
        }
        return StrGet(display_name)
    }

    LoadLayoutRecords() {
        local records := Map()
        local root := "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts"
        Loop Reg, root, "K" {
            local klid := StrUpper(A_LoopRegName)
            if !RegExMatch(klid, "^[0-9A-F]{8}$") {
                continue
            }
            local key := root . "\" . A_LoopRegName
            local layout_name := RegRead(key, "Layout Display Name", "")
            if layout_name {
                layout_name := this.LoadIndirectString(layout_name)
            }
            if !layout_name {
                layout_name := RegRead(key, "Layout Text", klid)
            }
            records[klid] := {
                layout_id: RegRead(key, "Layout Id", ""),
                layout_file: RegRead(key, "Layout File", ""),
                ime_file: RegRead(key, "Ime File", ""),
                name: layout_name
            }
        }
        return records
    }

    LoadIndirectString(value) {
        local text_buffer := Buffer(1024, 0)
        try {
            local result := DllCall(
                "shlwapi\SHLoadIndirectString",
                "WStr", value,
                "Ptr", text_buffer,
                "UInt", 512,
                "Ptr", 0,
                "HRESULT"
            )
            return result == 0 ? StrGet(text_buffer) : ""
        } catch {
            return ""
        }
    }

    GuidFromString(value) {
        local guid := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "WStr", value, "Ptr", guid, "HRESULT")
        return guid
    }

    GuidToString(pointer) {
        local value := Buffer(78, 0)
        if !DllCall("ole32\StringFromGUID2", "Ptr", pointer, "Ptr", value, "Int", 39, "Int") {
            return RabbitSystemInputProfiles.NULL_GUID
        }
        return StrGet(value)
    }

    HklOffset() {
        return 56 + A_PtrSize + 4 + (A_PtrSize == 8 ? 4 : 0)
    }

    ProfileBufferSize() {
        return this.HklOffset() + A_PtrSize + 4 + (A_PtrSize == 8 ? 4 : 0)
    }
}
