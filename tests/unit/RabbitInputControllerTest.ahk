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
#Include ..\..\Lib\RabbitConfigSnapshot.ahk
#Include ..\..\Lib\RabbitInput.ahk

RunTest("input hotkey ownership", TestInputHotkeyOwnership.Bind())
RunTest("configured input hotkey selection", TestConfiguredInputHotkeySelection.Bind())
RunTest("noop ASCII switch key is ignored", TestNoopAsciiSwitchKeyIsIgnored.Bind())
RunTest("release fallback replays key-up", TestReleaseFallbackReplaysKeyUp.Bind())
RunTest("latest candidate update ordering", TestLatestCandidateUpdateOrdering.Bind())
RunTest("focus change clears composition", TestFocusChangeClearsComposition.Bind())
RunTest("non-text target bypasses Rime input", TestNonTextTargetBypassesRimeInput.Bind())
RunTest("switcher temporary schema preserves mode baseline", TestSwitcherTemporarySchemaPreservesModeBaseline.Bind())
RunTest("switcher ASCII selection shows mode status", TestSwitcherAsciiSelectionShowsModeStatus.Bind())

TestInputHotkeyOwnership() {
    local input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(Map("suspend_hotkey", "Control+Alt+Space")),
        {},
        {}
    )
    input.RegisterHotKeys()
    AssertTrue(
        ArrayContains(input.registered_hotkeys, "$^!Space"),
        "The suspend hotkey was not registered before its options were updated."
    )
    AssertTrue(
        !ArrayContains(input.registered_hotkeys, "$<+Enter"),
        "A left Shift combination was registered without a standalone Shift binding."
    )
    AssertTrue(
        !ArrayContains(input.registered_hotkeys, "$>+Enter"),
        "A right Shift combination was registered without a standalone Shift binding."
    )
    AssertTrue(input.registered_hotkeys.Length > 0, "The input owner did not record its hotkeys.")
    input.Dispose()
    input.Dispose()
    Persistent(false)
    AssertEqual(0, input.registered_hotkeys.Length, "The input owner did not release its hotkeys.")
}

TestConfiguredInputHotkeySelection() {
    local hotkeys := RabbitInputHotkeys()
    hotkeys.AddBinding("Control+space", "key_binder")
    hotkeys.AddBinding("Control+Shift+percent", "key_binder")
    hotkeys.AddBinding("Release+Shift+Tab", "switcher")
    hotkeys.AddBinding("Alt+v", "key_binder")
    hotkeys.AddBinding("Shift_L", "ascii")
    hotkeys.AddBinding("Shift_L", "key_binder")
    hotkeys.AddBinding("Control_L", "key_binder")
    hotkeys.AddBinding("Super+space", "key_binder")
    hotkeys.AddBinding("Control+UnknownKey", "key_binder")
    hotkeys.Finalize()

    local registrations := hotkeys.GetRegistrations()
    local control_space := FindInputRegistration(registrations, "^Space")
    local percent := FindInputRegistration(registrations, "^+%")
    local release_tab := FindInputRegistration(registrations, "+Tab Up")
    local alt_v := FindInputRegistration(registrations, "!v")
    local shift := FindInputRegistration(registrations, "LShift")
    local control := FindInputRegistration(registrations, "LCtrl")

    AssertTrue(control_space, "The configured Control+space binding was not collected.")
    AssertTrue(percent, "The configured Control+Shift+percent binding was not collected.")
    AssertEqual(
        KeyDef.mask["Ctrl"],
        control_space.mask,
        "The configured Control+space mask was not preserved."
    )
    AssertTrue(release_tab, "The configured Release+Shift+Tab binding was not collected.")
    AssertTrue(
        release_tab.mask & KeyDef.mask["Up"],
        "A Release binding was not marked as a key-up event."
    )
    AssertTrue(alt_v, "A configured Alt combination was not collected.")
    AssertTrue(shift && !shift.pass_through, "A key_binder standalone modifier was not protected from unconditional pass-through.")
    AssertTrue(
        FindInputRegistration(registrations, "LShift Up"),
        "An ASCII standalone modifier did not retain its key-up event."
    )
    AssertTrue(control && !control.pass_through, "A key_binder Control modifier was not protected from unconditional pass-through.")
    AssertTrue(
        !FindInputRegistration(registrations, "#Space"),
        "An unsupported Win combination was collected."
    )
    AssertTrue(
        !FindInputRegistration(registrations, "^UnknownKey"),
        "An unsupported key was collected."
    )

    local ascii_only := RabbitInputHotkeys()
    ascii_only.AddBinding("Shift_L", "ascii")
    ascii_only.Finalize()
    local ascii_shift := FindInputRegistration(ascii_only.GetRegistrations(), "LShift")
    AssertTrue(ascii_shift && ascii_shift.pass_through, "An ASCII-only standalone modifier was not marked for immediate pass-through.")

    local input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(Map("input_hotkeys", ascii_only)),
        {},
        {}
    )
    input.RegisterHotKeys()
    AssertTrue(
        ArrayContains(input.registered_hotkeys, "$~LShift"),
        "An ASCII-only standalone modifier was not registered for immediate pass-through."
    )
    AssertTrue(
        ArrayContains(input.registered_hotkeys, "$~LShift Up"),
        "An ASCII-only standalone modifier key-up was not registered for immediate pass-through."
    )
    AssertTrue(
        ArrayContains(input.registered_hotkeys, "$<+Enter"),
        "An ASCII-only left Shift combination was not registered."
    )
    AssertTrue(
        !ArrayContains(input.registered_hotkeys, "$>+Enter"),
        "A right Shift combination was registered without a right standalone Shift binding."
    )
    input.Dispose()

    local right_ascii_only := RabbitInputHotkeys()
    right_ascii_only.AddBinding("Shift_R", "ascii")
    right_ascii_only.Finalize()
    local right_input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(Map("input_hotkeys", right_ascii_only)),
        {},
        {}
    )
    right_input.RegisterHotKeys()
    AssertTrue(
        ArrayContains(right_input.registered_hotkeys, "$>+Enter"),
        "An ASCII-only right Shift combination was not registered."
    )
    AssertTrue(
        !ArrayContains(right_input.registered_hotkeys, "$<+Enter"),
        "A left Shift combination was registered without a left standalone Shift binding."
    )
    right_input.Dispose()
}

TestNoopAsciiSwitchKeyIsIgnored() {
    local hotkeys := RabbitInputHotkeys()
    local rime := RabbitInputHotkeysConfigProbe(Map(
        "Control_L", "noop",
        "Shift_L", "inline_ascii"
    ))
    hotkeys.AddAsciiComposerSwitchKeys(rime, {})
    hotkeys.Finalize()

    AssertTrue(
        !FindInputRegistration(hotkeys.GetRegistrations(), "LCtrl"),
        "An ascii_composer switch key configured as noop was registered."
    )
    AssertTrue(
        FindInputRegistration(hotkeys.GetRegistrations(), "LShift"),
        "A non-noop ascii_composer switch key was not registered."
    )
}

FindInputRegistration(registrations, hotkey) {
    local registration
    for registration in registrations {
        if registration.hotkey = hotkey {
            return registration
        }
    }
    return 0
}

TestReleaseFallbackReplaysKeyUp() {
    local input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(),
        {},
        {}
    )
    AssertEqual(
        "{Blind}{Tab Up}",
        input.BuildFallbackInput("Tab", KeyDef.mask["Up"]),
        "An unprocessed Release binding was replayed as a key press."
    )
    AssertEqual(
        "{Blind}{Space Up}",
        input.BuildFallbackInput("Space", KeyDef.mask["Up"]),
        "An unprocessed Space release was not replayed as a key-up event."
    )
    AssertEqual(
        "+{A}",
        input.BuildFallbackInput("A", KeyDef.mask["Shift"]),
        "A normal shifted key fallback changed unexpectedly."
    )
}

ArrayContains(array, value) {
    local item
    for item in array {
        if item = value {
            return true
        }
    }
    return false
}

TestLatestCandidateUpdateOrdering() {
    local input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(),
        {},
        {}
    )
    local previous_critical := A_IsCritical
    local stale_ran := false
    local latest_ran := false
    local latest_was_critical := false
    local failure_caught := false

    stale_update(*) {
        stale_ran := true
    }
    latest_update(*) {
        latest_ran := true
        latest_was_critical := !!A_IsCritical
    }
    failing_update(*) {
        throw Error("Injected candidate update failure.")
    }

    input.candidate_revision := 2
    AssertTrue(
        !input.RunCandidateUpdate(1, stale_update),
        "An outdated candidate update was accepted."
    )
    AssertTrue(!stale_ran, "An outdated candidate update reached the renderer.")

    AssertTrue(
        input.RunCandidateUpdate(2, latest_update),
        "The latest candidate update was rejected."
    )
    AssertTrue(latest_ran, "The latest candidate update did not reach the renderer.")
    AssertTrue(latest_was_critical, "The renderer was interruptible during a candidate update.")
    AssertEqual(
        previous_critical,
        A_IsCritical,
        "The candidate update did not restore the previous critical state."
    )

    try {
        input.RunCandidateUpdate(2, failing_update)
    } catch {
        failure_caught := true
    }
    AssertTrue(failure_caught, "The injected candidate update failure was not observed.")
    AssertEqual(
        previous_critical,
        A_IsCritical,
        "A failed candidate update did not restore the previous critical state."
    )
}

TestFocusChangeClearsComposition() {
    local rime := RabbitInputRimeProbe()
    local candidate_box := RabbitInputCandidateProbe()
    local input := RabbitInputController(
        rime,
        42,
        candidate_box,
        RabbitConfigSnapshot(),
        {},
        {}
    )
    local composing_context := {
        composition: { length: 1 },
        menu: { num_candidates: 0 }
    }
    local empty_context := {
        composition: { length: 0 },
        menu: { num_candidates: 0 }
    }

    input.UpdateCompositionOwner(composing_context, 100)
    input.prev_show := true
    input.candidate_revision := 7

    AssertTrue(
        !input.CancelCompositionIfFocusChanged(100),
        "The composition was cleared while its window still had focus."
    )
    AssertEqual(0, rime.clear_calls, "The unchanged focus reached Rime cleanup.")
    AssertEqual(0, candidate_box.hide_calls, "The unchanged focus hid the candidate box.")

    AssertTrue(
        input.CancelCompositionIfFocusChanged(200),
        "The composition survived a foreground-window change."
    )
    AssertEqual(1, rime.clear_calls, "The focus change did not clear the Rime composition.")
    AssertEqual(42, rime.cleared_session_id, "The focus change cleared the wrong Rime session.")
    AssertEqual(1, candidate_box.hide_calls, "The focus change did not hide the candidate box.")
    AssertEqual(0, input.composition_owner_hwnd, "The old composition retained its window owner.")
    AssertEqual(8, input.candidate_revision, "The focus change did not invalidate old rendering.")
    AssertTrue(!input.prev_show, "The focus change retained the previous candidate position state.")

    input.UpdateCompositionOwner(composing_context, 300)
    input.UpdateCompositionOwner(empty_context, 300)
    AssertEqual(0, input.composition_owner_hwnd, "An empty context retained a composition owner.")
}

TestNonTextTargetBypassesRimeInput() {
    local rime := RabbitInputRimeProbe()
    local candidate_box := RabbitInputCandidateProbe()
    local input := RabbitInputTargetControllerProbe(
        rime,
        candidate_box,
        RabbitInputTargetProbe(RabbitInputTarget.NO)
    )
    input.composition_owner_hwnd := 100
    input.prev_show := true

    input.ProcessTextKey("A", 0)

    AssertEqual(1, rime.clear_calls, "A non-text target did not clear the active Rime composition.")
    AssertEqual(1, candidate_box.hide_calls, "A non-text target did not hide the candidate box.")
    AssertEqual(1, input.replayed_keys.Length, "The ordinary text key was not replayed to the target.")
    AssertEqual("A", input.replayed_keys[1].key, "The wrong key was replayed to the target.")
}

TestSwitcherTemporarySchemaPreservesModeBaseline() {
    local input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(),
        {},
        {}
    )
    local entering := input.ResolveSwitcherStatus("xmjd6", false, false, false, ".default")
    AssertTrue(entering.processing_switcher, "The switcher temporary schema was not recognized.")
    AssertEqual("xmjd6", input.switcher_state.schema_id, "The real schema was not cached for switcher selection.")

    local expanding := input.ResolveSwitcherStatus(".default", false, false, false, ".default")
    AssertTrue(expanding.processing_switcher, "The expanded switcher menu was treated as a real schema.")

    local selected := input.ResolveSwitcherStatus(".default", false, false, false, "xmjd6")
    AssertTrue(!selected.processing_switcher, "Returning from switcher did not restore normal status handling.")
    AssertEqual("xmjd6", selected.schema_id, "The switcher selection did not use the real schema as its baseline.")
    AssertEqual(false, selected.ascii_mode, "The switcher selection did not preserve the prior ASCII state.")
    AssertEqual(0, input.switcher_state, "The completed switcher selection retained stale state.")
}

TestSwitcherAsciiSelectionShowsModeStatus() {
    local rime := RabbitSwitcherStatusRimeProbe([
        RabbitSwitcherStatus("xmjd6", "星猫键道", false),
        RabbitSwitcherStatus(".default", ".default", false),
        RabbitSwitcherStatus(".default", ".default", false),
        RabbitSwitcherStatus(".default", ".default", false),
        RabbitSwitcherStatus(".default", ".default", false),
        RabbitSwitcherStatus("xmjd6", "星猫键道", true)
    ])
    local runtime_state := RabbitSwitcherStatusRuntimeProbe()
    local tray := RabbitSwitcherStatusTrayProbe()
    local input := RabbitInputController(
        rime,
        42,
        {},
        RabbitConfigSnapshot(),
        runtime_state,
        tray,
        RabbitInputTargetProbe(RabbitInputTarget.UNKNOWN)
    )

    input.ProcessKey("F4", 0)
    input.ProcessKey("2", 0)
    input.ProcessKey("2", 0)

    AssertEqual(1, tray.status_tips.Length, "The switcher ASCII selection displayed an unexpected number of status tips.")
    AssertEqual("西", tray.status_tips[1].text, "The switcher ASCII selection displayed the schema name instead of the mode label.")
    AssertTrue(tray.status_tips[1].show_icon, "The switcher ASCII selection did not show the mode icon.")
    AssertEqual(0, runtime_state.state_label_updates, "The switcher temporary schema refreshed real schema labels.")
}

class RabbitInputRimeProbe {
    __New() {
        this.clear_calls := 0
        this.cleared_session_id := 0
    }

    clear_composition(session_id) {
        this.clear_calls++
        this.cleared_session_id := session_id
    }
}

RabbitSwitcherStatus(schema_id, schema_name, ascii_mode) {
    return {
        schema_id: schema_id,
        schema_name: schema_name,
        is_ascii_mode: ascii_mode,
        is_full_shape: false,
        is_ascii_punct: false
    }
}

class RabbitSwitcherStatusRimeProbe {
    __New(statuses) {
        this.statuses := statuses
        this.status_index := 0
    }

    get_status(session_id) {
        this.status_index++
        return this.statuses[this.status_index]
    }

    free_status(status) {
    }

    process_key(session_id, keycode, mask) {
        return true
    }

    get_commit(session_id) {
        return 0
    }

    get_context(session_id) {
        return 0
    }
}

class RabbitSwitcherStatusRuntimeProbe {
    __New() {
        this.ascii_mode_false_label_abbr := "中"
        this.ascii_mode_true_label_abbr := "西"
        this.full_shape_false_label_abbr := "半"
        this.full_shape_true_label_abbr := "全"
        this.ascii_punct_false_label_abbr := "。"
        this.ascii_punct_true_label_abbr := "."
        this.state_label_updates := 0
    }

    UpdateStateLabels() {
        this.state_label_updates++
    }

    UpdateWinAscii(target, use_target) {
    }
}

class RabbitSwitcherStatusTrayProbe {
    __New() {
        this.status_tips := []
    }

    UpdateTip(schema_name, ascii_mode, full_shape, ascii_punct) {
    }

    UpdateSchemaIcon(schema_id) {
    }

    ShowStatusTip(text, show_icon := false) {
        this.status_tips.Push({ text: text, show_icon: show_icon })
    }
}

class RabbitInputCandidateProbe {
    __New() {
        this.hide_calls := 0
    }

    Hide() {
        this.hide_calls++
    }
}

class RabbitInputHotkeysConfigProbe {
    __New(values) {
        this.values := values
    }

    config_begin_map(config, path) {
        return RabbitInputHotkeysMapIterator(this.values)
    }

    config_next(iter) {
        return iter.MoveNext()
    }

    config_get_string(config, path) {
        local parts := StrSplit(path, "/")
        return this.values[parts[parts.Length]]
    }

    config_end(iter) {
    }
}

class RabbitInputHotkeysMapIterator {
    __New(values) {
        this.keys := []
        local key
        for key, _ in values {
            this.keys.Push(key)
        }
        this.index := 0
        this.key := ""
        this.path := ""
    }

    MoveNext() {
        this.index++
        if this.index > this.keys.Length {
            return false
        }
        this.key := this.keys[this.index]
        this.path := "ascii_composer/switch_key/" . this.key
        return true
    }
}

class RabbitInputTargetProbe {
    __New(result) {
        this.result := result
    }

    Classify(*) {
        return this.result
    }
}

class RabbitInputTargetControllerProbe extends RabbitInputController {
    __New(rime, candidate_box, input_target) {
        super.__New(
            rime,
            42,
            candidate_box,
            RabbitConfigSnapshot(),
            {},
            {},
            input_target
        )
        this.replayed_keys := []
    }

    GetForegroundWindow() {
        return 100
    }

    ReplayInput(key, mask, pass_through := false) {
        this.replayed_keys.Push({
            key: key,
            mask: mask,
            pass_through: pass_through
        })
    }
}
