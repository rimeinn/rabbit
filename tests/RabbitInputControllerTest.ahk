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

#Include <RabbitConfigSnapshot>
#Include <RabbitInput>

RunTest("input hotkey ownership", TestInputHotkeyOwnership.Bind())
RunTest("latest candidate update ordering", TestLatestCandidateUpdateOrdering.Bind())
RunTest("focus change clears composition", TestFocusChangeClearsComposition.Bind())

TestInputHotkeyOwnership() {
    local input := RabbitInputController(
        {},
        1,
        {},
        RabbitConfigSnapshot(),
        {},
        {}
    )
    input.RegisterHotKeys()
    AssertTrue(input.registered_hotkeys.Length > 0, "The input owner did not record its hotkeys.")
    input.Dispose()
    input.Dispose()
    Persistent(false)
    AssertEqual(0, input.registered_hotkeys.Length, "The input owner did not release its hotkeys.")
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

class RabbitInputCandidateProbe {
    __New() {
        this.hide_calls := 0
    }

    Hide() {
        this.hide_calls++
    }
}
