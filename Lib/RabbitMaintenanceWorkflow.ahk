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
 */

#Include RabbitCommon.ahk
#Include RabbitDeploymentPlan.ahk
#Include RabbitI18n.ahk

class RabbitMaintenanceWorkflow {
    __New(rime_api, lock_operations := true) {
        this.rime := rime_api
        this.lock_operations := !!lock_operations
    }

    CreateMutex() {
        return RabbitDeploymentMutex()
    }

    UpdateWorkspace(report_errors := false) {
        return this.Deploy(RabbitDeploymentPlan.FullRedeploy(), report_errors)
    }

    Deploy(plan, report_errors := false) {
        if !(plan is RabbitDeploymentPlan) {
            throw TypeError("Expected a RabbitDeploymentPlan.")
        }
        if plan.IsEmpty() {
            return 0
        }
        if !this.lock_operations {
            return this.DeployUnlocked(plan)
        }
        local mutex := this.CreateMutex()
        if !mutex.Create() {
            return 1
        }
        try {
            if mutex.lasterr == ERROR_ALREADY_EXISTS {
                if report_errors {
                    MsgBox(
                        RabbitI18n.Text("frontend.deploy_busy_deferred"),
                        RabbitI18n.Text("about.message_title"),
                        "Ok Iconi"
                    )
                }
                return 1
            }
            return this.DeployUnlocked(plan)
        } finally {
            mutex.Close()
        }
    }

    DeployUnlocked(plan) {
        if plan.full_workspace_required {
            if !this.rime.deploy() {
                return 1
            }
        } else if plan.default_config_changed
            && !this.rime.deploy_config_file("default.yaml", "config_version") {
            return 1
        }
        if plan.rabbit_config_changed
            && !this.rime.deploy_config_file("rabbit.yaml", "config_version") {
            return 1
        }
        for schema_id in plan.schema_config_ids {
            if !this.rime.deploy_config_file(schema_id . ".schema.yaml", "schema/version") {
                return 1
            }
        }
        return 0
    }

    SyncUserData() {
        if !this.lock_operations {
            return this.SyncUserDataUnlocked()
        }
        local mutex := this.CreateMutex()
        if !mutex.Create() {
            return 1
        }
        try {
            if mutex.lasterr == ERROR_ALREADY_EXISTS {
                MsgBox(RabbitI18n.Text("frontend.deploy_busy"), RabbitI18n.Text("about.message_title"), "Ok Iconi")
                return 1
            }
            return this.SyncUserDataUnlocked()
        } finally {
            mutex.Close()
        }
    }

    SyncUserDataUnlocked() {
        if !this.rime.sync_user_data() {
            return 1
        }
        this.rime.join_maintenance_thread()
        return 0
    }
}
