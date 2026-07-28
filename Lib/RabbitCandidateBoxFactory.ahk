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

#Include <RabbitCandidateBox>
#Include <RabbitLegacyCandidateBox>

class RabbitCandidateBoxFactory {
    __New(style, modern_constructor := CandidateBox, legacy_constructor := LegacyCandidateBox) {
        this.style := style
        this.modern_constructor := modern_constructor
        this.legacy_constructor := legacy_constructor
    }

    Create(use_legacy_candidate_box) {
        local constructor
        constructor := use_legacy_candidate_box ? this.legacy_constructor : this.modern_constructor
        return constructor.Call(this.style)
    }
}
