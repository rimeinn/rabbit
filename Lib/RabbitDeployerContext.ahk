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

#Include <RabbitCommon>

class RabbitDeployerContext {
    __New(rime_api) {
        this.rime := rime_api
        this.traits := 0
        this.command := ""
        this.keyboard_layout := 0
        this.result := 0
        this.maintenance_mode := RABBIT_NO_MAINTENANCE
        this.rime_initialized := false
        this.disposed := false
    }

    Initialize() {
        if this.rime_initialized {
            return
        }
        this.traits := RabbitCreateTraits()
        this.rime.setup(this.traits)
        this.rime.deployer_initialize(0)
        this.rime_initialized := true
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        if this.rime_initialized {
            this.rime.finalize()
            this.rime_initialized := false
        }
        this.traits := 0
    }
}
