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

#Include <RabbitAppContext>
#Include <RabbitCandidateBoxFactory>
#Include <RabbitConfig>
#Include <RabbitInput>
#Include <RabbitRuntimeState>
#Include <RabbitTrayMenu>
#Include <RabbitUIStyle>

class RabbitApplication {
    __New(rime_api) {
        this.context := RabbitAppContext(rime_api, RabbitMutex())
        this.tray := 0
        this.tray_click_callback := 0
        this.rime_message_callback := this.OnRimeMessage.Bind(this)
        this.exit_callback := this.OnExit.Bind(this)
        this.exit_registered := false
        this.tray_message_registered := false
        this.shutting_down := false
    }

    Run(args) {
        local fail_count, status
        this.context.keyboard_layout := this.ResolveKeyboardLayout(args)
        this.SetDefaultKeyboard()
        OnExit(this.exit_callback)
        this.exit_registered := true

        fail_count := 0
        while !this.context.mutex.Create() {
            this.context.mutex.Close()
            fail_count++
            if fail_count > 500 {
                TrayTip()
                TrayTip("有其他进程正在使用 RIME，启动失败")
                Sleep(2000)
                ExitApp()
            }
        }

        local first_run := !FileExist(RabbitUserDataPath() . "\default.custom.yaml")
            || !FileExist(RabbitUserDataPath() . "\rabbit.custom.yaml")
            || !FileExist(RabbitUserDataPath() . "\user.yaml")
            || !FileExist(RabbitUserDataPath() . "\installation.yaml")
            || !FileExist(RabbitUserDataPath() . "\build\rabbit.yaml")

        this.context.traits := RabbitCreateTraits()
        this.context.rime.setup(this.context.traits)
        this.context.rime.set_notification_handler(this.rime_message_callback, 0)
        this.context.rime.initialize(this.context.traits)
        this.context.rime_initialized := true

        local maintenance := args.Length == 0 ? RABBIT_PARTIAL_MAINTENANCE : args[1]
        if maintenance != RABBIT_NO_MAINTENANCE {
            RabbitUpdateMaintenanceTrayIcon()
            if first_run {
                this.RunDeployer("install", this.context.keyboard_layout)
            } else if this.context.rime.start_maintenance(
                maintenance == RABBIT_FULL_MAINTENANCE) {
                this.context.rime.join_maintenance_thread()
            }
        } else {
            TrayTip()
            TrayTip("维护完成", RABBIT_IME_NAME)
            SetTimer(TrayTip, -2000)
        }

        this.context.session_id := this.context.rime.create_session()
        if !this.context.session_id {
            this.SetDefaultKeyboard(this.context.keyboard_layout)
            throw Error("未能成功创建 RIME 会话。")
        }

        RabbitCleanOldLogs()
        RabbitCleanMisplacedConfigs()
        local loaded := RabbitConfigLoader.Load(this.context.rime)
        this.context.config := loaded.config
        if loaded.dark_mode {
            DarkMode.set(loaded.dark_mode)
        }

        local use_legacy_candidate_box := RabbitIsOldWindows()
            || this.context.config.use_legacy_candidate_box
        this.context.candidate_box := RabbitCandidateBoxFactory(loaded.style).Create(
            use_legacy_candidate_box)
        this.context.runtime_state := RabbitRuntimeState(
            this.context.rime,
            this.context.session_id,
            this.context.config
        )
        this.tray := RabbitTrayController(
            this.context.rime,
            this.context.session_id,
            this.context.candidate_box,
            this.context.config,
            this.context.runtime_state,
            this.context.keyboard_layout,
            this.RunDeployer.Bind(this)
        )
        this.context.runtime_state.SetTray(this.tray)
        this.context.input := RabbitInputController(
            this.context.rime,
            this.context.session_id,
            this.context.candidate_box,
            this.context.config,
            this.context.runtime_state,
            this.tray
        )
        this.context.appearance := RabbitAppearanceController(
            this.context.rime,
            this.context.candidate_box,
            loaded.style,
            loaded.dark_mode
        )

        this.context.input.RegisterHotKeys()
        this.context.input.StartFocusMonitor()
        this.context.runtime_state.UpdateStateLabels()
        if (status := this.context.rime.get_status(this.context.session_id)) {
            local schema_id := status.schema_id
            local schema_name := status.schema_name
            local ascii_mode := status.is_ascii_mode
            local full_shape := status.is_full_shape
            local ascii_punct := status.is_ascii_punct
            this.context.rime.free_status(status)
            this.tray.UpdateTip(schema_name, ascii_mode, full_shape, ascii_punct)
            this.tray.UpdateSchemaIcon(schema_id)
        }

        this.tray.SetupMenu()
        this.tray.UpdateIcon()
        this.tray_click_callback := this.tray.OnClick.Bind(this.tray)
        OnMessage(AHK_NOTIFYICON, this.tray_click_callback)
        this.tray_message_registered := true
        this.context.appearance.Register()
        this.context.runtime_state.StartTimer()
    }

    RunDeployer(command, args*) {
        this.Shutdown(1)
        this.LaunchDeployer(command, args*)
        this.ExitApplication(1)
    }

    LaunchDeployer(command, args*) {
        RabbitLaunchDeployer(command, args*)
    }

    ExitApplication(code) {
        ExitApp(code)
    }

    ResolveKeyboardLayout(args) {
        local layout
        if args.Length >= 3 {
            layout := Number(args[3])
        }
        if !IsSet(layout) || layout == 0 {
            layout := DllCall("GetKeyboardLayout", "UInt", 0)
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
                TrayTip("维护中", RABBIT_IME_NAME)
            } else if msg_value = "success" {
                TrayTip()
                TrayTip("维护完成", RABBIT_IME_NAME)
                SetTimer(TrayTip, -2000)
            } else {
                TrayTip(
                    msg_type . ": " . msg_value . " (" . session_id . ")",
                    RABBIT_IME_NAME
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
            this.SetDefaultKeyboard(this.context.keyboard_layout)
        }
        TrayTip()
        ToolTip(, , , STATUS_TOOLTIP)
        if this.tray_message_registered {
            OnMessage(AHK_NOTIFYICON, this.tray_click_callback, 0)
            this.tray_message_registered := false
        }
        this.context.Dispose()
    }
}
