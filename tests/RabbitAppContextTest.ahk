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

#Include <RabbitAppContext>

RunTest("application context disposal order", TestAppContextDisposalOrder.Bind())
RunTest("partial application context disposal", TestPartialAppContextDisposal.Bind())
RunTest("application context cleanup after owner failure", TestAppContextOwnerFailure.Bind())

TestAppContextDisposalOrder() {
    local calls := []
    local context := RabbitAppContext(
        RabbitAppContextRimeProbe(calls),
        RabbitAppContextDisposableProbe(calls, "close")
    )
    context.rime_initialized := true
    context.session_id := 42
    context.candidate_box := RabbitAppContextDisposableProbe(calls, "candidate")
    context.input := RabbitAppContextDisposableProbe(calls, "input")
    context.runtime_state := RabbitAppContextDisposableProbe(calls, "runtime")
    context.appearance := RabbitAppContextDisposableProbe(calls, "appearance")

    context.Dispose()
    context.Dispose()
    AssertEqual(
        "input,runtime,appearance,candidate,destroy:42,finalize,close",
        JoinShutdownCalls(calls),
        "The application context disposed resources out of order."
    )
}

TestPartialAppContextDisposal() {
    local calls := []
    local context := RabbitAppContext(
        RabbitAppContextRimeProbe(calls),
        RabbitAppContextDisposableProbe(calls, "close")
    )
    context.Dispose()
    AssertEqual(
        "close",
        JoinShutdownCalls(calls),
        "A partial application context finalized resources it did not initialize."
    )
}

TestAppContextOwnerFailure() {
    local calls := []
    local context := RabbitAppContext(
        RabbitAppContextRimeProbe(calls),
        RabbitAppContextDisposableProbe(calls, "close")
    )
    context.rime_initialized := true
    context.session_id := 42
    context.candidate_box := RabbitAppContextDisposableProbe(calls, "candidate")
    context.input := RabbitAppContextFailingProbe(calls, "input")
    context.runtime_state := RabbitAppContextDisposableProbe(calls, "runtime")
    context.appearance := RabbitAppContextDisposableProbe(calls, "appearance")

    local failed := false
    try {
        context.Dispose()
    } catch {
        failed := true
    }
    AssertTrue(failed, "The application context swallowed an owner disposal failure.")
    AssertEqual(
        "input,runtime,appearance,candidate,destroy:42,finalize,close",
        JoinShutdownCalls(calls),
        "An owner disposal failure skipped downstream application cleanup."
    )
}

class RabbitAppContextDisposableProbe {
    __New(calls, label) {
        this.calls := calls
        this.label := label
    }

    Dispose() {
        this.calls.Push(this.label)
    }

    Close() {
        this.calls.Push(this.label)
    }
}

class RabbitAppContextFailingProbe extends RabbitAppContextDisposableProbe {
    Dispose() {
        this.calls.Push(this.label)
        throw Error("Injected owner disposal failure.")
    }
}

class RabbitAppContextRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    destroy_session(session) {
        this.calls.Push("destroy:" . session)
    }

    finalize() {
        this.calls.Push("finalize")
    }
}
