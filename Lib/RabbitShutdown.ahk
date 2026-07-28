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

RabbitShutdownRuntime(candidate_box, rime_api, session, mutex_instance, rime_initialized := true) {
    try {
        if candidate_box && HasMethod(candidate_box, "Dispose") {
            candidate_box.Dispose()
        }
    } finally {
        try {
            if session {
                try {
                    rime_api.destroy_session(session)
                } finally {
                    if rime_initialized {
                        rime_api.finalize()
                    }
                }
            } else if rime_initialized {
                rime_api.finalize()
            }
        } finally {
            if mutex_instance {
                mutex_instance.Close()
            }
        }
    }
}
