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
#Include <RabbitDictManagementDialog>
#Include <RabbitSwitcherSettingsDialog>
#Include <RabbitUIStyleSettings>
#Include <RabbitUIStyleSettingsDialog>

CreateFileIfNotExist(filename) {
    user_data_dir := RabbitUserDataPath() . "\"
    if not InStr(DirExist(user_data_dir), "D")
        DirCreate(user_data_dir)
    filepath := user_data_dir . filename
    if not InStr(FileExist(filepath), "N")
        FileAppend("", filepath)
}

ConfigureSwitcher(levers, switcher_settings, &reconfigured) {
    if !IsSet(reconfigured)
        reconfigured := false
    if not levers.load_settings(switcher_settings)
        return false
    ; To mimic a dialog
    result := {
        yes : false
    }
    dialog := SwitcherSettingsDialog(switcher_settings, result)
    dialog.Show()
    WinWaitClose(dialog)

    if result.yes {
        if levers.save_settings(switcher_settings)
            reconfigured := true
        return true
    }
    return false
}

ConfigureUI(levers, ui_style_settings, &reconfigured) {
    if !IsSet(reconfigured)
        reconfigured := false
    local settings := ui_style_settings.settings
    if !levers.load_settings(settings)
        return false
    result := {
        yes : false
    }
    dialog := UIStyleSettingsDialog(ui_style_settings, result)
    dialog.Show()
    WinWaitClose(dialog)

    if result.yes {
        if levers.save_settings(settings)
            reconfigured := true
        return true
    }
    return false
}

class Configurator extends Class {
    __New() {
        CreateFileIfNotExist("default.custom.yaml")
        CreateFileIfNotExist("rabbit.custom.yaml")
    }

    Initialize() {
        global rabbit_traits
        rabbit_traits := CreateTraits()
        rime.setup(rabbit_traits)
        rime.deployer_initialize(0)
    }

    Run(installing) {
        levers := RimeLeversApi()
        if not levers
            return 1

        switcher_settings := levers.switcher_settings_init()
        ui_style_settings := UIStyleSettings()
        skip_switcher_settings := installing && !levers.is_first_run(switcher_settings)
        skip_ui_style_settings := installing && !levers.is_first_run(ui_style_settings.settings)

        if !skip_switcher_settings {
            if !ConfigureSwitcher(levers, switcher_settings, &reconfigured)
                skip_ui_style_settings := true ; user cancelled
        }
        if !skip_ui_style_settings
            ConfigureUI(levers, ui_style_settings, &reconfigured)

        levers.custom_settings_destroy(switcher_settings)

        if installing || reconfigured
            return this.UpdateWorkspace()

        return 0
    }

    UpdateWorkspace(report_errors := false) {
        mutex := RabbitMutex()
        if not mutex.Create() {
            ; TODO: log error
            return 1
        }

        if mutex.lasterr == ERROR_ALREADY_EXISTS {
            ; TODO: log error
            mutex.Close()
            if report_errors {
                MsgBox("正在执行另一项部署任务，方才所做的修改将在输入法再次启动后生效。", "【玉兔毫】", "Ok Iconi")
            }
            return 1
        }

        {
            rime.deploy()
            rime.deploy_config_file("rabbit.yaml", "config_version")
        }

        mutex.Close()

        return 0
    }

    DictManagement() {
        mutex := RabbitMutex()
        if not mutex.Create() {
            ; TODO: log error
            return 1
        }

        if mutex.lasterr == ERROR_ALREADY_EXISTS {
            ; TODO: log error
            mutex.Close()
            MsgBox("正在执行另一项部署任务，请稍后再试。", "【玉兔毫】", "Ok Iconi")
            return 1
        }

        {
            if rime.api_available("run_task") {
                rime.run_task("installation_update")
            }
            dialog := DictManagementDialog()
            dialog.Show()
            WinWaitClose(dialog)
        }

        mutex.Close()

        return 0
    }

    SyncUserData() {
        mutex := RabbitMutex()
        if not mutex.Create() {
            ; TODO: log error
            return 1
        }

        if mutex.lasterr == ERROR_ALREADY_EXISTS {
            ; TODO: log error
            mutex.Close()
            MsgBox("正在执行另一项部署任务，请稍后再试。", "【玉兔毫】", "Ok Iconi")
            return 1
        }

        {
            if not rime.sync_user_data() {
                mutex.Close()
                return 1
            }
            rime.join_maintenance_thread()
        }

        mutex.Close()

        return 0
    }
}
