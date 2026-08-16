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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitSystemInputDialog.ahk
#Include ..\..\Lib\RabbitSystemInputManager.ahk
#Include ..\..\Lib\RabbitSystemInputSettings.ahk

RunTest("system input restore state round trip", TestSystemInputRestoreStateRoundTrip.Bind())
RunTest("keyboard activation always reloads and broadcasts", TestKeyboardActivationAlwaysReloadsAndBroadcasts.Bind())
RunTest("foreground keyboard confirms cross-thread activation", TestForegroundKeyboardConfirmsActivation.Bind())
RunTest("input processor activation still requires TSF success", TestInputProcessorActivationRequiresTsfSuccess.Bind())
RunTest("system input compatibility is conservative", TestSystemInputCompatibilityIsConservative.Bind())
RunTest("safe system input remains untouched", TestSafeSystemInputRemainsUntouched.Bind())
RunTest("incompatible keyboard uses configured layout", TestIncompatibleKeyboardUsesConfiguredLayout.Bind())
RunTest("configured keyboard replaces an input processor", TestConfiguredKeyboardReplacesInputProcessor.Bind())
RunTest("missing system input config requests deployer", TestMissingSystemInputConfigRequestsDeployer.Bind())
RunTest("unavailable configured keyboard requests deployer", TestUnavailableConfiguredKeyboardRequestsDeployer.Bind())
RunTest("system input dialog prefers enabled US layout", TestSystemInputDialogPrefersUsLayout.Bind())
RunTest("system input dialog stages configured available layout", TestSystemInputDialogStagesConfiguredLayout.Bind())
RunTest("system input dialog activates before closing", TestSystemInputDialogActivatesBeforeClosing.Bind())
RunTest("system input settings load ownership", TestSystemInputSettingsLoadOwnership.Bind())
RunTest("system input settings save ownership", TestSystemInputSettingsSaveOwnership.Bind())
RunTest("system input restore survives deployer restart", TestSystemInputRestoreSurvivesRestart.Bind())
RunTest("legacy language override bypasses system input", TestLegacyLanguageOverrideBypassesInput.Bind())

TestSystemInputRestoreStateRoundTrip() {
    local original := RabbitSystemInputProfile(
        RabbitSystemInputProfile.INPUT_PROCESSOR,
        0x0804,
        "{81D4E9C9-1D3B-41BC-9E6C-4B40BF79E35E}",
        "{FA550B04-5AD7-411F-A5AC-CA038EC515D7}",
        0,
        0,
        0x08040804
    )
    local serialized := RabbitSystemInputRestoreState(original, true).Serialize()
    local restored := RabbitSystemInputRestoreState.Deserialize(serialized)

    AssertTrue(restored.pending, "The pending restore flag was not serialized.")
    AssertEqual(original.langid, restored.profile.langid, "The restore language was not serialized.")
    AssertEqual(original.clsid, restored.profile.clsid, "The restore CLSID was not serialized.")
    AssertEqual(
        original.guid_profile,
        restored.profile.guid_profile,
        "The restore profile GUID was not serialized."
    )
    AssertEqual(
        original.hkl_substitute,
        restored.profile.hkl_substitute,
        "The restore substitute layout was not serialized."
    )
}

TestKeyboardActivationAlwaysReloadsAndBroadcasts() {
    local profile := RabbitCreateSystemInputProfile("00000404", false)
    local profiles := RabbitSystemInputActivationProbe(1, true)

    AssertTrue(
        profiles.Activate(profile, true),
        "The keyboard layout did not use the load-and-broadcast path."
    )
    AssertEqual(2, profiles.load_count, "A newly enabled keyboard was not reloaded before broadcasting.")
    AssertTrue(profiles.requested, "The loaded keyboard layout was not broadcast.")
}

TestForegroundKeyboardConfirmsActivation() {
    local target := RabbitCreateSystemInputProfile("00000404", true)
    local profiles := RabbitSystemInputForegroundProbe(target)

    AssertTrue(
        profiles.GetActiveKeyboardProfile(target, 42),
        "The foreground input thread did not confirm a cross-thread keyboard switch."
    )
}

TestInputProcessorActivationRequiresTsfSuccess() {
    local profiles := RabbitSystemInputActivationProbe(1)

    AssertTrue(
        !profiles.Activate(RabbitCreateInputProcessorProfile()),
        "A failed TSF input processor activation was treated as successful."
    )
    AssertTrue(!profiles.requested, "A failed input processor activation requested a language switch.")
}

TestSystemInputCompatibilityIsConservative() {
    local profiles := RabbitSystemInputCompatibilityProbe()

    AssertTrue(
        profiles.IsRabbitCompatible(RabbitCreateSystemInputProfile("00000409", true)),
        "US English was not recognized as compatible."
    )
    AssertTrue(
        profiles.IsRabbitCompatible(RabbitCreateSystemInputProfile("00000809", true)),
        "UK English was not recognized as compatible."
    )
    AssertTrue(
        profiles.IsRabbitCompatible(RabbitCreateSystemInputProfile("00060409", true)),
        "Colemak was not recognized as compatible."
    )
    for klid in ["00020409", "00000404", "00000401", "00000407"] {
        AssertTrue(
            !profiles.IsRabbitCompatible(RabbitCreateSystemInputProfile(klid, true)),
            "An incompatible or dead-key layout was recognized as compatible: " . klid
        )
    }
}

TestSafeSystemInputRemainsUntouched() {
    local safe := RabbitCreateSystemInputProfile("00000809", true)
    local profiles := RabbitSystemInputProfilesProbe([safe, safe])
    local manager := RabbitSystemInputManagerProbe(0, profiles)

    manager.Initialize()
    AssertTrue(manager.Prepare(RabbitConfigSnapshot()), "A safe layout stopped startup.")
    AssertEqual("", JoinSystemInputCalls(profiles.calls), "A safe layout was unnecessarily changed.")
    AssertTrue(!manager.restore_state.pending, "A safe layout created pending restore state.")
}

TestIncompatibleKeyboardUsesConfiguredLayout() {
    local original := RabbitCreateSystemInputProfile("00000407", true)
    local target := RabbitCreateSystemInputProfile("00000409", true)
    local profiles := RabbitSystemInputProfilesProbe([original, original, target], [original, target])
    local manager := RabbitSystemInputManagerProbe(0, profiles)

    manager.Initialize()
    AssertTrue(
        manager.Prepare(RabbitConfigSnapshot(Map("system_input_layout", "00000409"))),
        "An incompatible ordinary keyboard did not switch to the configured layout."
    )
    AssertEqual(
        "activate:00000409:0",
        JoinSystemInputCalls(profiles.calls),
        "The incompatible ordinary keyboard remained active."
    )
}

TestConfiguredKeyboardReplacesInputProcessor() {
    local original := RabbitCreateInputProcessorProfile()
    local target := RabbitCreateSystemInputProfile("00000809", true)
    local profiles := RabbitSystemInputProfilesProbe([original, original, target], [target])
    local manager := RabbitSystemInputManagerProbe(0, profiles)

    manager.Initialize()
    AssertTrue(
        manager.Prepare(RabbitConfigSnapshot(Map("system_input_layout", "00000809"))),
        "The configured keyboard did not allow startup."
    )
    AssertTrue(manager.restore_state.pending, "The system input override was not marked for restore.")
    AssertEqual(
        "activate:00000809:0",
        JoinSystemInputCalls(profiles.calls),
        "The configured keyboard was not activated without re-enabling it."
    )

    manager.Restore()
    AssertEqual(
        "activate:00000809:0,activate:input:0",
        JoinSystemInputCalls(profiles.calls),
        "The original input processor was not restored."
    )
}

TestMissingSystemInputConfigRequestsDeployer() {
    local original := RabbitCreateInputProcessorProfile()
    local profiles := RabbitSystemInputProfilesProbe([original, original])
    local manager := RabbitSystemInputManagerProbe(0, profiles)

    manager.Initialize()
    AssertTrue(!manager.Prepare(RabbitConfigSnapshot()), "Missing configuration allowed startup.")
    AssertTrue(manager.configuration_required, "Missing configuration did not request the deployer.")
    AssertEqual("", JoinSystemInputCalls(profiles.calls), "The frontend changed the system layout before deployment.")
}

TestUnavailableConfiguredKeyboardRequestsDeployer() {
    local original := RabbitCreateInputProcessorProfile()
    local profiles := RabbitSystemInputProfilesProbe([original, original])
    local manager := RabbitSystemInputManagerProbe(0, profiles)

    manager.Initialize()
    AssertTrue(
        !manager.Prepare(RabbitConfigSnapshot(Map("system_input_layout", "00010409"))),
        "An unavailable configured keyboard allowed startup."
    )
    AssertTrue(manager.configuration_required, "An unavailable keyboard did not request the deployer.")
    AssertEqual("", JoinSystemInputCalls(profiles.calls), "The frontend enabled an unavailable keyboard.")
}

TestSystemInputDialogPrefersUsLayout() {
    local uk := RabbitCreateSystemInputProfile("00000809", true)
    local us := RabbitCreateSystemInputProfile("00000409", true)
    local dialog := RabbitSystemInputDialog([uk, us], [])

    dialog.OnOK()

    AssertTrue(dialog.accepted, "The dialog did not accept an enabled keyboard layout.")
    AssertEqual("00000409", dialog.selected_profile.klid, "The dialog did not prefer US English.")
}

TestSystemInputDialogStagesConfiguredLayout() {
    local uk := RabbitCreateSystemInputProfile("00000809", true)
    local dvorak := RabbitCreateSystemInputProfile("00010409", false)
    local dialog := RabbitSystemInputDialog([uk], [dvorak], "00010409")

    AssertEqual(
        "00010409",
        dialog.pending_profile.klid,
        "The configured available keyboard was not staged."
    )
    dialog.OnOK()

    AssertEqual(
        "00010409",
        dialog.selected_profile.klid,
        "The staged configured keyboard was not selected."
    )
    AssertTrue(!dialog.selected_profile.IsEnabled(), "Staging prematurely enabled the keyboard layout.")
}

TestSystemInputDialogActivatesBeforeClosing() {
    local us := RabbitCreateSystemInputProfile("00000409", true)
    local dialog := RabbitSystemInputDialog([us], [])
    local window_was_alive := false
    dialog.accept_callback := (profile, window) => (
        window_was_alive := !!DllCall("user32\IsWindow", "Ptr", window, "Int")
    )

    dialog.OnOK()

    AssertTrue(dialog.activation_attempted, "The selected keyboard was not activated from the OK event.")
    AssertTrue(dialog.activation_succeeded, "The in-dialog keyboard activation was not recorded.")
    AssertTrue(window_was_alive, "The keyboard was activated only after the dialog had been destroyed.")
}

TestSystemInputSettingsSaveOwnership() {
    local calls := []
    local settings := RabbitSystemInputSettings(0, RabbitSystemInputLeversProbe(calls))

    AssertTrue(settings.Save("00000809"), "The system input setting was not saved.")
    AssertEqual(
        "init,load,customize:system_input_layout:00000809,save,destroy",
        JoinSystemInputCalls(calls),
        "The system input settings resource was not owned for the full save operation."
    )
}

TestSystemInputSettingsLoadOwnership() {
    local calls := []
    local settings := RabbitSystemInputSettings(
        RabbitSystemInputSettingsRimeProbe(calls),
        RabbitSystemInputLeversProbe(calls)
    )
    local klid := ""

    AssertTrue(settings.Load(&klid), "The system input setting was not loaded.")
    AssertEqual("00000409", klid, "The loaded system input KLID was incorrect.")
    AssertEqual(
        "user_config_open:rabbit.custom,get_string:patch/system_input_layout,config_close",
        JoinSystemInputCalls(calls),
        "The system input settings resource was not owned for the full load operation."
    )
}

TestSystemInputRestoreSurvivesRestart() {
    local original := RabbitCreateInputProcessorProfile()
    local target := RabbitCreateSystemInputProfile("00000809", true)
    local state := RabbitSystemInputRestoreState(original, true).Serialize()
    local profiles := RabbitSystemInputProfilesProbe([target])
    local manager := RabbitSystemInputManagerProbe(0, profiles)

    manager.Initialize(state)
    AssertTrue(manager.Prepare(RabbitConfigSnapshot()), "A restarted safe layout stopped startup.")
    manager.Restore()

    AssertEqual(
        "activate:input:0",
        JoinSystemInputCalls(profiles.calls),
        "The deployer restart lost the original input processor."
    )
}

TestLegacyLanguageOverrideBypassesInput() {
    local profiles := RabbitSystemInputProfilesProbe([])
    local manager := RabbitSystemInputBypassManagerProbe(0, profiles)

    manager.Initialize()

    AssertTrue(manager.Prepare(RabbitConfigSnapshot()), "The legacy override did not bypass preparation.")
    AssertEqual("none", manager.SerializeState(), "The legacy override exposed restore state.")
    AssertTrue(manager.Restore(), "The legacy override did not bypass restoration.")
    AssertEqual("", JoinSystemInputCalls(profiles.calls), "The legacy override touched system input.")
}

RabbitCreateInputProcessorProfile() {
    return RabbitSystemInputProfile(
        RabbitSystemInputProfile.INPUT_PROCESSOR,
        0x0804,
        "{81D4E9C9-1D3B-41BC-9E6C-4B40BF79E35E}",
        "{FA550B04-5AD7-411F-A5AC-CA038EC515D7}",
        0,
        RabbitSystemInputProfile.ENABLED,
        0x08040804
    )
}

RabbitCreateSystemInputProfile(klid, enabled) {
    local profile := RabbitSystemInputProfile(
        RabbitSystemInputProfile.KEYBOARD_LAYOUT,
        Number("0x" . SubStr(klid, 5, 4)),
        RabbitSystemInputProfiles.NULL_GUID,
        RabbitSystemInputProfiles.NULL_GUID,
        Number("0x" . klid),
        enabled ? RabbitSystemInputProfile.ENABLED : 0
    )
    profile.klid := klid
    profile.display_name := klid
    return profile
}

JoinSystemInputCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitSystemInputManagerProbe extends RabbitSystemInputManager {
    __New(rime_api, profiles) {
        super.__New(rime_api, profiles)
    }

    ShouldBypass() {
        return false
    }

}

class RabbitSystemInputProfilesProbe {
    __New(active_profiles, enabled_profiles := 0, available_profiles := 0) {
        this.active_profiles := active_profiles
        this.active_index := 0
        this.enabled_profiles := enabled_profiles ? enabled_profiles : []
        this.available_profiles := available_profiles ? available_profiles : []
        this.calls := []
    }

    GetActiveProfile() {
        this.active_index++
        return this.active_profiles[this.active_index]
    }

    EnumerateProfiles() {
        return this.enabled_profiles
    }

    EnumerateAvailableLayouts(enabled_profiles) {
        return this.available_profiles
    }

    IsRabbitCompatible(profile) {
        return RabbitSystemInputProfiles.COMPATIBLE_KLIDS.Has(StrUpper(profile.klid))
    }

    GetForegroundWindow() {
        return 42
    }

    Activate(profile, enable := false, target_window := 0) {
        this.calls.Push("activate:" . (profile.klid ? profile.klid : "input") . ":" . enable)
        return true
    }

    GetActiveKeyboardProfile(profile, target_window := 0) {
        local active := this.GetActiveProfile()
        return this.SameProfile(active, profile) ? active : 0
    }

    SameProfile(left, right) {
        return left.profile_type == right.profile_type && left.klid == right.klid
    }
}

class RabbitSystemInputCompatibilityProbe extends RabbitSystemInputProfiles {
    __New() {
    }
}

class RabbitSystemInputActivationProbe extends RabbitSystemInputProfiles {
    __New(activation_result, throw_activation_error := false) {
        this.activation_result := activation_result
        this.throw_activation_error := throw_activation_error
        this.load_count := 0
        this.requested := false
    }

    LoadKeyboardProfile(klid) {
        this.load_count++
        return Number("0x" . klid)
    }

    CallActivateProfile(profile, enable := false) {
        if this.throw_activation_error {
            throw Error("Simulated TSF refresh lag.")
        }
        return this.activation_result
    }

    IsActive(profile, target_window := 0) {
        return this.requested
    }

    GetActivationHkl(profile) {
        return profile.hkl
    }

    RequestLanguageChange(hkl, target_window := 0) {
        this.requested := true
        return true
    }
}

class RabbitSystemInputForegroundProbe extends RabbitSystemInputProfiles {
    __New(foreground_profile) {
        this.foreground_profile := foreground_profile
    }

    GetActiveProfile() {
        return RabbitCreateInputProcessorProfile()
    }

    GetWindowKeyboardProfile(window) {
        return this.foreground_profile
    }
}

class RabbitSystemInputBypassManagerProbe extends RabbitSystemInputManager {
    ShouldBypass() {
        return true
    }
}

class RabbitSystemInputLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    custom_settings_init(config_id, generator_id) {
        this.calls.Push("init")
        return 42
    }

    load_settings(settings) {
        this.calls.Push("load")
        return true
    }

    settings_get_config(settings) {
        this.calls.Push("get_config")
        return 84
    }

    customize_string(settings, key, value) {
        this.calls.Push("customize:" . key . ":" . value)
        return true
    }

    save_settings(settings) {
        this.calls.Push("save")
        return true
    }

    custom_settings_destroy(settings) {
        this.calls.Push("destroy")
    }
}

class RabbitSystemInputSettingsRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    user_config_open(config_id) {
        this.calls.Push("user_config_open:" . config_id)
        return 84
    }

    config_get_string(config, key) {
        this.calls.Push("get_string:" . key)
        return "00000409"
    }

    config_close(config) {
        this.calls.Push("config_close")
    }
}
