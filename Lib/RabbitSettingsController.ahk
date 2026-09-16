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

#Include RabbitI18n.ahk
#Include RabbitSettingsWorkflow.ahk
#Include RabbitSettingsWindow.ahk

class RabbitSettingsController {
    __New(rime_api, maintenance_callback, language_callback := 0) {
        this.rime := rime_api
        this.maintenance_callback := maintenance_callback
        this.language_callback := language_callback
        this.window := 0
        this.workflow := this.CreateWorkflow()
        this.disposed := false
    }

    CreateWorkflow() {
        return RabbitSettingsControllerWorkflow(this.rime, this.maintenance_callback)
    }

    CreateWindow(page_id := "", installing := false) {
        return RabbitSettingsWindow(
            this.workflow,
            false,
            RabbitAppearancePreview,
            0,
            page_id,
            installing,
            RabbitWindowThemeController,
            true
        )
    }

    Show(page_id := "") {
        if this.disposed {
            return false
        }
        local page_index := RabbitSettingsWindow.PageIndex(page_id)
        if !page_index {
            throw ValueError(RabbitI18n.Text("messages.unknown_page", Map("page", page_id)))
        }
        if this.window && !this.window.disposed {
            this.window.SelectPage(page_index)
            this.ActivateWindow(this.window)
            return true
        }
        return this.CreateAndShow(page_id)
    }

    CreateAndShow(page_id := "", installing := false, state := 0) {
        local window := this.CreateWindow(page_id, installing)
        this.window := window
        window.closed_callback := this.OnWindowClosed.Bind(this, window)
        window.language_reload_callback := this.ReloadLanguage.Bind(this)
        window.nonblocking_language_reload := true
        if state {
            window.RestoreLanguageReloadState(state)
        }
        window.Show(state ? Format("x{} y{}", state.x, state.y) : "Center")
        return true
    }

    ActivateWindow(window) {
        WinActivate("ahk_id " . window.Hwnd)
    }

    ReloadLanguage(window) {
        if this.disposed || window != this.window {
            return false
        }
        local preference := RabbitI18n.ReadPreference(this.rime)
        if RabbitI18n.ResolveLocale(preference) = RabbitI18n.locale {
            return false
        }
        local state := window.CaptureLanguageReloadState()
        window.Dispose()
        this.ActivateLanguage(preference)
        this.CreateAndShow(state.page_id, state.installing, state)
        return true
    }

    ActivateLanguage(preference) {
        RabbitI18n.Initialize(A_ScriptDir . "\Locales", preference)
        if this.language_callback {
            this.language_callback.Call()
        }
    }

    OnWindowClosed(expected_window, closed_window) {
        if expected_window = closed_window && this.window = closed_window {
            this.window := 0
        }
    }

    BeginMaintenance(operation) {
        if this.window && !this.window.disposed {
            this.window.BeginMaintenance(operation)
        }
    }

    PrepareForMaintenance() {
        if !this.window || this.window.disposed {
            return true
        }
        return this.window.PrepareForMaintenance()
    }

    ResumeAfterMaintenance(result) {
        if this.window && !this.window.disposed {
            this.window.ResumeAfterMaintenance(this.workflow, result)
        }
    }

    RuntimeResumeFailed(err) {
        if this.window && !this.window.disposed {
            this.window.RuntimeResumeFailed(err)
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        if this.window && !this.window.disposed {
            this.window.Dispose()
        }
        this.window := 0
        this.workflow := 0
    }
}

; Stage 1 keeps the existing process-handoff maintenance behavior while the
; settings GUI moves to the frontend. The workflow split in stage 2 removes
; this compatibility adapter.
class RabbitSettingsControllerWorkflow extends RabbitSettingsWorkflow {
    __New(rime_api, maintenance_callback) {
        super.__New(rime_api)
        this.maintenance_callback := maintenance_callback
    }

    UpdateWorkspace(report_errors := false) {
        return this.Deploy(RabbitDeploymentPlan.FullRedeploy(), report_errors)
    }

    Deploy(plan, report_errors := false) {
        if plan.IsEmpty() {
            return 0
        }
        return this.maintenance_callback.Call("deploy", plan) ? 0 : 1
    }

    SyncUserData() {
        return this.maintenance_callback.Call("sync") ? 0 : 1
    }

    DictManagement() {
        this.maintenance_callback.Call("legacy-settings", "dictionary")
        return 0
    }
}
