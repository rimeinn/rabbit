/*
 * Copyright (c) 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
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

class RabbitDeploymentPlan {
    rabbit_config_changed := false
    default_config_changed := false
    full_workspace_required := false

    RequireRabbitConfig() {
        this.rabbit_config_changed := true
        return this
    }

    RequireDefaultConfig() {
        this.default_config_changed := true
        return this
    }

    RequireWorkspace() {
        this.full_workspace_required := true
        return this
    }

    Merge(other) {
        if !(other is RabbitDeploymentPlan) {
            throw TypeError("Expected a RabbitDeploymentPlan.")
        }
        this.rabbit_config_changed := this.rabbit_config_changed || other.rabbit_config_changed
        this.default_config_changed := this.default_config_changed || other.default_config_changed
        this.full_workspace_required := this.full_workspace_required || other.full_workspace_required
        return this
    }

    IsEmpty() {
        return !this.rabbit_config_changed && !this.default_config_changed && !this.full_workspace_required
    }

    static RabbitConfig() {
        return RabbitDeploymentPlan().RequireRabbitConfig()
    }

    static DefaultConfig() {
        return RabbitDeploymentPlan().RequireDefaultConfig()
    }

    static Workspace() {
        return RabbitDeploymentPlan().RequireWorkspace()
    }

    static FullRedeploy() {
        return RabbitDeploymentPlan().RequireWorkspace().RequireRabbitConfig()
    }
}
