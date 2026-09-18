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

#Include RabbitCommon.ahk
#Include RabbitI18n.ahk
#Include RabbitCommandLine.ahk
#Include RabbitDeploymentCoordinator.ahk
#Include RabbitFrontendRuntime.ahk
#Include RabbitMaintenanceIpc.ahk
#Include RabbitSettingsController.ahk
#Include RabbitTrayMenu.ahk

class RabbitApplication {
    __New(rime_api) {
        this.rime := rime_api
        this.application_mutex := RabbitApplicationMutex()
        this.keyboard_layout := 0
        this.runtime := 0
        this.coordinator := 0
        this.ipc_server := 0
        this.tray := 0
        this.settings := 0
        this.tray_click_callback := 0
        this.rime_message_callback := this.OnRimeMessage.Bind(this)
        this.exit_callback := this.OnExit.Bind(this)
        this.exit_registered := false
        this.tray_message_registered := false
        this.shutting_down := false
    }

    Run(args) {
        RabbitI18n.LoadStartupConfig(this.rime, RabbitUserDataPath() . "\build\rabbit.yaml")
        A_IconTip := RabbitI18n.Text("tray.maintenance")
        local options := RabbitApplicationOptions.Parse(args)
        this.keyboard_layout := this.ResolveKeyboardLayout(options.keyboard_layout)
        this.SetDefaultKeyboard()
        OnExit(this.exit_callback)
        this.exit_registered := true

        local fail_count := 0
        while !this.application_mutex.Create()
            || this.application_mutex.lasterr == ERROR_ALREADY_EXISTS {
            this.application_mutex.Close()
            fail_count += 1
            if fail_count > 500 {
                TrayTip()
                TrayTip(RabbitI18n.Text("frontend.startup_busy"))
                Sleep(2000)
                ExitApp()
            }
        }

        local first_run := !FileExist(RabbitUserDataPath() . "\default.custom.yaml")
            || !FileExist(RabbitUserDataPath() . "\rabbit.custom.yaml")
            || !FileExist(RabbitUserDataPath() . "\user.yaml")
            || !FileExist(RabbitUserDataPath() . "\installation.yaml")
            || !FileExist(RabbitUserDataPath() . "\build\rabbit.yaml")

        this.settings := this.CreateSettingsController()
        this.tray := this.CreateTrayController()
        this.coordinator := this.CreateDeploymentCoordinator()
        this.tray.SetupMenu()
        this.tray.UpdateIcon()
        this.tray_click_callback := this.tray.OnClick.Bind(this.tray)
        OnMessage(AHK_NOTIFYICON, this.tray_click_callback)
        this.tray_message_registered := true
        if !this.StartFrontendRuntime(options.maintenance, first_run) {
            return
        }
        this.EnsureIpcServer()
    }

    CreateTrayController() {
        return RabbitTrayController(
            0,
            0,
            0,
            0,
            0,
            this.keyboard_layout,
            this.settings.Show.Bind(this.settings),
            this.SubmitMaintenance.Bind(this)
        )
    }

    CreateDeploymentCoordinator() {
        return RabbitDeploymentCoordinator(
            this.settings,
            this.StopFrontendRuntime.Bind(this),
            this.StartFrontendRuntime.Bind(this),
            this.OnMaintenanceComplete.Bind(this)
        )
    }

    EnsureIpcServer() {
        if !this.ipc_server {
            this.ipc_server := RabbitMaintenanceIpcServer(this.SubmitMaintenance.Bind(this))
        }
        return this.ipc_server
    }

    CreateFrontendRuntime() {
        return RabbitFrontendRuntime(
            this.rime,
            this.tray,
            this.keyboard_layout,
            this.rime_message_callback
        )
    }

    CreateDeploymentStartupGate() {
        return RabbitDeploymentMutex()
    }

    WaitForDeploymentStartupGate() {
        Sleep(100)
    }

    AcquireDeploymentStartupGate() {
        local mutex
        loop {
            mutex := this.CreateDeploymentStartupGate()
            if mutex.Create() && mutex.lasterr != ERROR_ALREADY_EXISTS {
                return mutex
            }
            mutex.Close()
            this.WaitForDeploymentStartupGate()
        }
    }

    StartFrontendRuntime(maintenance := RABBIT_NO_MAINTENANCE, first_run := false) {
        local deployment_gate
        if this.runtime && this.runtime.started {
            return true
        }
        deployment_gate := this.AcquireDeploymentStartupGate()
        try {
            this.runtime := this.CreateFrontendRuntime()
            return this.runtime.Start(maintenance, first_run, this.RunFirstInstallation.Bind(this))
        } catch {
            this.runtime := 0
            throw
        } finally {
            deployment_gate.Close()
        }
    }

    StopFrontendRuntime() {
        if !this.runtime {
            return
        }
        this.runtime.Stop()
        this.runtime := 0
    }

    RunDeployer(command, args*) {
        this.Shutdown(1)
        this.LaunchDeployer(command, args*)
        this.ExitApplication(1)
    }

    SubmitMaintenance(command, args*) {
        switch command {
            case "deploy":
                local plan := args.Length && args[1] is RabbitDeploymentPlan
                    ? args[1]
                    : RabbitDeploymentPlan.FullRedeploy()
                local completion_callback := args.Length >= 2 ? args[2] : 0
                local accepted := this.coordinator.Submit(plan, completion_callback)
                if accepted && !plan.IsEmpty() {
                    this.ShowMaintenanceIndicator()
                }
                return accepted
            case "sync":
                return this.coordinator.SubmitSync(args.Length ? args[1] : 0)
            case "dictionary":
                return this.coordinator.SubmitDictionary(
                    args.Length >= 1 ? args[1] : "",
                    args.Length >= 2 ? args[2] : "",
                    args.Length >= 3 ? args[3] : "",
                    args.Length >= 4 ? args[4] : 0
                )
            default:
                this.RunDeployer(command, args*)
                return true
        }
    }

    CreateSettingsController() {
        return RabbitSettingsController(
            this.rime,
            this.SubmitMaintenance.Bind(this),
            this.OnSettingsLanguageChanged.Bind(this)
        )
    }

    OnMaintenanceComplete(result, resumed) {
        if !resumed {
            this.ShowMaintenanceResult(result, resumed)
            return
        }
        this.EnsureIpcServer()
        this.RestoreTrayAfterMaintenance()
        this.ShowMaintenanceResult(result, resumed)
    }

    ShowMaintenanceIndicator() {
        if this.tray {
            this.tray.last_icon_key := ""
        }
        RabbitUpdateMaintenanceTrayIcon()
        TrayTip()
        TrayTip(RabbitI18n.Text("frontend.maintenance"), RabbitI18n.Text("settings.product"))
    }

    RestoreTrayAfterMaintenance() {
        if !this.tray || !this.runtime || !this.runtime.started {
            return
        }
        this.tray.last_icon_key := ""
        this.tray.UpdateTip()
        this.tray.UpdateIcon()
    }

    ShowMaintenanceResult(result, resumed) {
        if !resumed {
            TrayTip(
                RabbitI18n.Text("frontend.session_error"),
                RabbitI18n.Text("settings.product")
            )
            return
        }
        TrayTip(
            RabbitI18n.Text(result = 0 ? "frontend.maintenance_done" : "frontend.maintenance_failed", Map(
                "detail", result,
                "session", 0
            )),
            RabbitI18n.Text("settings.product")
        )
        SetTimer(TrayTip, -2000)
    }

    OnSettingsLanguageChanged() {
        if this.tray {
            this.tray.SetupMenu()
            if this.runtime && this.runtime.started {
                this.runtime.context.runtime_state.UpdateStateLabels()
                this.tray.UpdateTip()
            }
        }
    }

    LaunchDeployer(command, args*) {
        RabbitLaunchDeployer(command, args*)
    }

    ExitApplication(code) {
        ExitApp(code)
    }

    UseLegacySettings() {
        return RabbitIsOldWindows()
    }

    RunFirstInstallation() {
        if !this.UseLegacySettings() {
            this.settings.ShowInstallation("input-schemes")
            return false
        }
        this.RunDeployer(
            "legacy-settings",
            "--install",
            "--return-to-rabbit",
            "--keyboard-layout",
            RabbitFormatKeyboardLayout(this.keyboard_layout)
        )
        return false
    }

    ResolveKeyboardLayout(layout := 0) {
        if layout == 0 {
            layout := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr")
        }
        return layout
    }

    SetDefaultKeyboard(locale_id := 0x0409) {
        local lang, WM_INPUTLANGCHANGEREQUEST, HWND_BROADCAST
        if FileExist(RabbitUserDataPath() . "\.lang") {
            return
        }
        local locale_id_hex := Format("{:08x}", locale_id & 0xffff)
        lang := DllCall("LoadKeyboardLayout", "Str", locale_id_hex, "Int", 0)
        PostMessage(
            WM_INPUTLANGCHANGEREQUEST := 0x0050,
            0,
            lang,
            HWND_BROADCAST := 0xffff
        )
    }

    OnRimeMessage(context_object, session_id, message_type, message_value) {
        local msg_type := StrGet(message_type, "UTF-8")
        local msg_value := StrGet(message_value, "UTF-8")
        if msg_type = "deploy" {
            if msg_value = "start" {
                TrayTip()
                TrayTip(RabbitI18n.Text("frontend.maintenance"), RabbitI18n.Text("settings.product"))
            } else if msg_value = "success" {
                TrayTip()
                TrayTip(RabbitI18n.Text("frontend.maintenance_done"), RabbitI18n.Text("settings.product"))
                SetTimer(TrayTip, -2000)
            } else {
                TrayTip(
                    RabbitI18n.Text("frontend.maintenance_failed", Map("detail", msg_value, "session", session_id)),
                    RabbitI18n.Text("settings.product")
                )
            }
        }
    }

    OnExit(reason, code) {
        this.Shutdown(code)
    }

    Shutdown(code := 0) {
        if this.shutting_down {
            return
        }
        this.shutting_down := true
        if code == 0 {
            this.SetDefaultKeyboard(this.keyboard_layout)
        }
        TrayTip()
        ToolTip(, , , STATUS_TOOLTIP)
        if this.tray_message_registered {
            OnMessage(AHK_NOTIFYICON, this.tray_click_callback, 0)
            this.tray_message_registered := false
        }
        if this.ipc_server {
            this.ipc_server.Dispose()
            this.ipc_server := 0
        }
        if this.coordinator {
            this.coordinator.Dispose()
            this.coordinator := 0
        }
        if this.settings {
            this.settings.Dispose()
            this.settings := 0
        }
        this.StopFrontendRuntime()
        if this.tray && HasMethod(this.tray, "Dispose") {
            this.tray.Dispose()
            this.tray := 0
        }
        this.application_mutex.Close()
    }
}
