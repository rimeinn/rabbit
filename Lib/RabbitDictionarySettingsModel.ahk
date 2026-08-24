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

#Include RabbitCommon.ahk

class RabbitDictionarySettingsModel {
    __New(rime_api, levers_api, mutex_factory) {
        this.rime := rime_api
        this.api := levers_api
        this.mutex_factory := mutex_factory
        this.dictionaries := []
        this.disposed := false
        if !this.Load() {
            throw Error("未能读取用户词典列表。")
        }
    }

    Load() {
        return this.RunLocked(this.LoadUnlocked.Bind(this))
    }

    LoadUnlocked() {
        local dict, iter
        if this.rime.api_available("run_task") {
            this.rime.run_task("installation_update")
        }
        this.dictionaries := []
        if !(iter := this.api.user_dict_iterator_init()) {
            return true
        }
        try {
            while (dict := this.api.next_user_dict(iter)) {
                this.dictionaries.Push(dict)
            }
        } finally {
            this.api.user_dict_iterator_destroy(iter)
        }
        return true
    }

    GetUserDataSyncDir() {
        return this.rime.get_user_data_sync_dir()
    }

    Backup(dict_name) {
        return this.RunLocked((*) => this.api.backup_user_dict(dict_name))
    }

    Restore(snapshot_file) {
        return this.RunLocked((*) => this.api.restore_user_dict(snapshot_file))
    }

    Export(dict_name, text_file) {
        return this.RunLocked((*) => this.api.export_user_dict(dict_name, text_file))
    }

    Import(dict_name, text_file) {
        return this.RunLocked((*) => this.api.import_user_dict(dict_name, text_file))
    }

    RunLocked(action) {
        local mutex := this.mutex_factory.Call()
        if !mutex.Create() {
            throw Error("未能启动用户词典操作。")
        }
        try {
            if mutex.lasterr == ERROR_ALREADY_EXISTS {
                throw Error("正在执行另一项维护任务，请稍后再试。")
            }
            return action.Call()
        } finally {
            mutex.Close()
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        this.dictionaries := []
    }

    __Delete() {
        this.Dispose()
    }
}
