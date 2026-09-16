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

#Include RabbitAppContext.ahk
#Include RabbitCandidateBoxFactory.ahk
#Include RabbitCommon.ahk
#Include RabbitConfig.ahk
#Include RabbitI18n.ahk
#Include RabbitInput.ahk
#Include RabbitRuntimeState.ahk
#Include RabbitStatusTip.ahk
#Include RabbitTrayMenu.ahk
#Include RabbitUIStyle.ahk

class RabbitFrontendRuntime {
    __New(rime_api, tray, keyboard_layout, notification_callback) {
        this.rime := rime_api
        this.tray := tray
        this.keyboard_layout := keyboard_layout
        this.notification_callback := notification_callback
        this.context := RabbitAppContext(rime_api, 0)
        this.context.keyboard_layout := keyboard_layout
        this.started := false
        this.stopped := false
    }

    Start(maintenance := RABBIT_PARTIAL_MAINTENANCE, first_run := false, first_install_callback := 0) {
        if this.started || this.stopped {
            throw Error("A frontend runtime can only be started once.")
        }
        try {
            this.context.traits := this.CreateTraits()
            this.rime.setup(this.context.traits)
            this.rime.set_notification_handler(this.notification_callback, 0)
            this.rime.initialize(this.context.traits)
            this.context.rime_initialized := true

            RabbitDebug(
                Format(
                    "runtime startup: keyboard_layout=0x{:04x} maintenance={} first_run={}",
                    this.keyboard_layout & 0xffff,
                    maintenance,
                    first_run
                ),
                Format("RabbitFrontendRuntime.ahk:{}", A_LineNumber)
            )
            this.RunStartupMaintenance(maintenance, first_run, first_install_callback)
            if this.stopped {
                return false
            }

            this.context.session_id := this.rime.create_session()
            if !this.context.session_id {
                throw Error(RabbitI18n.Text("frontend.session_error"))
            }
            RabbitDebug(
                Format("runtime startup: rime session created (id={})", this.context.session_id),
                Format("RabbitFrontendRuntime.ahk:{}", A_LineNumber)
            )

            this.PrepareRuntimeFiles()
            this.LoadRuntimeLocale()
            local loaded := this.LoadConfig()
            this.context.config := loaded.config
            if loaded.dark_mode {
                DarkMode.set(loaded.dark_mode)
            }

            local use_legacy_candidate_box := RabbitIsOldWindows()
                || this.context.config.use_legacy_candidate_box
            this.context.candidate_box := this.CreateCandidateBox(loaded.style, use_legacy_candidate_box)
            if !use_legacy_candidate_box {
                this.context.status_tip := this.CreateStatusTip(loaded.style, this.context.config)
            }
            this.context.runtime_state := this.CreateRuntimeState(
                this.rime,
                this.context.session_id,
                this.context.config
            )
            this.tray.BindRuntime(
                this.rime,
                this.context.session_id,
                this.context.candidate_box,
                this.context.config,
                this.context.runtime_state,
                this.context.status_tip
            )
            this.context.runtime_state.SetTray(this.tray)
            this.context.input := this.CreateInputController(
                this.rime,
                this.context.session_id,
                this.context.candidate_box,
                this.context.config,
                this.context.runtime_state,
                this.tray
            )
            this.context.appearance := this.CreateAppearanceController(
                this.rime,
                this.context.candidate_box,
                loaded.style,
                loaded.dark_mode,
                this.context.status_tip
            )

            this.context.input.RegisterHotKeys()
            this.context.input.StartFocusMonitor()
            this.context.runtime_state.UpdateStateLabels()
            this.RefreshTrayStatus()
            this.context.appearance.Register()
            this.context.runtime_state.StartTimer()
            this.started := true
            return true
        } catch {
            this.Stop()
            throw
        }
    }

    CreateTraits() {
        return RabbitCreateTraits()
    }

    RunStartupMaintenance(maintenance, first_run, first_install_callback) {
        if maintenance != RABBIT_NO_MAINTENANCE {
            RabbitUpdateMaintenanceTrayIcon()
            if first_run && first_install_callback {
                first_install_callback.Call()
            } else if this.rime.start_maintenance(maintenance == RABBIT_FULL_MAINTENANCE) {
                this.rime.join_maintenance_thread()
            }
        } else {
            TrayTip()
            TrayTip(RabbitI18n.Text("frontend.maintenance_done"), RabbitI18n.Text("settings.product"))
            SetTimer(TrayTip, -2000)
        }
    }

    PrepareRuntimeFiles() {
        RabbitCleanOldLogs()
        RabbitCleanMisplacedConfigs()
    }

    LoadRuntimeLocale() {
        RabbitI18n.LoadConfig(this.rime)
    }

    LoadConfig() {
        return RabbitConfigLoader.Load(this.rime)
    }

    CreateCandidateBox(style, use_legacy_candidate_box) {
        return RabbitCandidateBoxFactory(style).Create(use_legacy_candidate_box)
    }

    CreateStatusTip(style, config) {
        return RabbitStatusTip(style, config)
    }

    CreateRuntimeState(rime_api, session_id, config) {
        return RabbitRuntimeState(rime_api, session_id, config)
    }

    CreateInputController(rime_api, session_id, candidate_box, config, runtime_state, tray) {
        return RabbitInputController(rime_api, session_id, candidate_box, config, runtime_state, tray)
    }

    CreateAppearanceController(rime_api, candidate_box, style, dark_mode, status_tip) {
        return RabbitAppearanceController(rime_api, candidate_box, style, dark_mode, status_tip)
    }

    RefreshTrayStatus() {
        local status
        if (status := this.rime.get_status(this.context.session_id)) {
            local schema_id := status.schema_id
            local schema_name := status.schema_name
            local ascii_mode := status.is_ascii_mode
            local full_shape := status.is_full_shape
            local ascii_punct := status.is_ascii_punct
            this.rime.free_status(status)
            this.tray.UpdateTip(schema_name, ascii_mode, full_shape, ascii_punct)
            this.tray.UpdateSchemaIcon(schema_id)
        }
    }

    Stop() {
        if this.stopped {
            return
        }
        this.stopped := true
        try {
            this.context.Dispose()
        } finally {
            this.tray.UnbindRuntime()
            this.started := false
        }
    }

    Dispose() {
        this.Stop()
    }
}
