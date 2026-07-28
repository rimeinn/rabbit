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

RunTest("shutdown cleanup after candidate disposal failure", TestShutdownCleanupAfterDisposalFailure.Bind())

TestShutdownCleanupAfterDisposalFailure() {
    local calls := []
    local candidate_box := RabbitFailingCandidateDisposal(calls)
    local rime_api := RabbitShutdownRimeProbe(calls)
    local mutex_instance := RabbitShutdownMutexProbe(calls)

    AssertThrows(
        RabbitShutdownRuntime.Bind(candidate_box, rime_api, 42, mutex_instance),
        "Candidate disposal failure must be propagated after cleanup.")
    AssertEqual(
        "dispose,destroy:42,finalize,close",
        JoinShutdownCalls(calls),
        "Shutdown must complete Rime and mutex cleanup after candidate disposal fails.")
}

JoinShutdownCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitFailingCandidateDisposal {
    __New(calls) {
        this.calls := calls
    }

    Dispose() {
        this.calls.Push("dispose")
        throw Error("Injected candidate disposal failure.")
    }
}

class RabbitShutdownRimeProbe {
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

class RabbitShutdownMutexProbe {
    __New(calls) {
        this.calls := calls
    }

    Close() {
        this.calls.Push("close")
    }
}
