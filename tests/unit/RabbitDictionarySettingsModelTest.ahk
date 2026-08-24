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

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitDictionarySettingsModel.ahk

RunTest("dictionary settings model operations", TestDictionarySettingsModelOperations.Bind())

TestDictionarySettingsModelOperations() {
    local calls := []
    local model := RabbitDictionarySettingsModel(
        RabbitDictionarySettingsRimeProbe(calls),
        RabbitDictionarySettingsLeversProbe(calls),
        (*) => RabbitDictionarySettingsMutexProbe(calls)
    )
    try {
        AssertEqual(2, model.dictionaries.Length, "The dictionary model loaded the wrong item count.")
        AssertEqual("rabbit", model.dictionaries[1], "The dictionary model loaded the wrong first item.")
        AssertEqual("sync", model.GetUserDataSyncDir(), "The dictionary model returned the wrong sync path.")
        AssertTrue(model.Backup("rabbit"), "The dictionary model failed to back up a dictionary.")
        AssertTrue(model.Restore("snapshot"), "The dictionary model failed to restore a snapshot.")
        AssertEqual(3, model.Export("rabbit", "export.txt"), "The dictionary model failed to export.")
        AssertEqual(4, model.Import("rabbit", "import.txt"), "The dictionary model failed to import.")
    } finally {
        model.Dispose()
        model.Dispose()
    }
    AssertEqual(
        "mutex_create,task,iter,next:rabbit,next:luna,iter_destroy,mutex_close,sync_dir," .
            "mutex_create,backup:rabbit,mutex_close,mutex_create,restore:snapshot,mutex_close," .
            "mutex_create,export:rabbit:export.txt,mutex_close,mutex_create,import:rabbit:import.txt," .
            "mutex_close",
        JoinDictionarySettingsCalls(calls),
        "The dictionary model did not serialize its operations with the maintenance mutex."
    )
}

JoinDictionarySettingsCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitDictionarySettingsRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    api_available(name) {
        return true
    }

    run_task(name) {
        this.calls.Push("task")
    }

    get_user_data_sync_dir() {
        this.calls.Push("sync_dir")
        return "sync"
    }
}

class RabbitDictionarySettingsLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    user_dict_iterator_init() {
        this.calls.Push("iter")
        return { index: 0, items: ["rabbit", "luna"] }
    }

    next_user_dict(iter) {
        iter.index += 1
        if iter.index > iter.items.Length {
            return ""
        }
        this.calls.Push("next:" . iter.items[iter.index])
        return iter.items[iter.index]
    }

    user_dict_iterator_destroy(iter) {
        this.calls.Push("iter_destroy")
    }

    backup_user_dict(dict_name) {
        this.calls.Push("backup:" . dict_name)
        return true
    }

    restore_user_dict(snapshot_file) {
        this.calls.Push("restore:" . snapshot_file)
        return true
    }

    export_user_dict(dict_name, text_file) {
        this.calls.Push("export:" . dict_name . ":" . text_file)
        return 3
    }

    import_user_dict(dict_name, text_file) {
        this.calls.Push("import:" . dict_name . ":" . text_file)
        return 4
    }
}

class RabbitDictionarySettingsMutexProbe {
    __New(calls) {
        this.calls := calls
        this.lasterr := 0
    }

    Create() {
        this.calls.Push("mutex_create")
        return true
    }

    Close() {
        this.calls.Push("mutex_close")
    }
}
