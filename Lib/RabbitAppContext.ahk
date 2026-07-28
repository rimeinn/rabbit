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

#Include <RabbitShutdown>

class RabbitAppContext {
    __New(rime_api, mutex_instance) {
        this.rime := rime_api
        this.mutex := mutex_instance
        this.traits := 0
        this.session_id := 0
        this.candidate_box := 0
        this.config := 0
        this.keyboard_layout := 0
        this.rime_initialized := false
        this.input := 0
        this.runtime_state := 0
        this.appearance := 0
        this.disposed := false
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        try {
            if this.input {
                this.input.Dispose()
            }
        } finally {
            try {
                if this.runtime_state {
                    this.runtime_state.Dispose()
                }
            } finally {
                try {
                    if this.appearance {
                        this.appearance.Dispose()
                    }
                } finally {
                    RabbitShutdownRuntime(
                        this.candidate_box,
                        this.rime,
                        this.session_id,
                        this.mutex,
                        this.rime_initialized
                    )
                }
            }
        }
    }
}
