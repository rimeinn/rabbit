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
 */

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitSchemaSettingsModel.ahk
#Include ..\..\Lib\RabbitSchemaSettingsDialog.ahk

RunTest("schema settings resolve manifests by data precedence", TestSchemaSettingsManifestPrecedence.Bind())
RunTest("schema settings validate manifest fields", TestSchemaSettingsManifestValidation.Bind())
RunTest("schema settings parse manifest groups", TestSchemaSettingsManifestGroups.Bind())
RunTest("bundled schema settings fallback is valid", TestBundledSchemaSettingsFallback.Bind())
RunTest("schema settings load and save scalar values", TestSchemaSettingsModelPersistence.Bind())
RunTest("schema settings dialog honors dark appearance", TestSchemaSettingsDialogDarkAppearance.Bind())
RunTest("schema settings dialog switches groups", TestSchemaSettingsDialogGroups.Bind())

TestSchemaSettingsManifestPrecedence() {
    local root := A_Temp . "\\rabbit-schema-settings-" . A_TickCount
    local user_dir := root . "\\user"
    local shared_dir := root . "\\shared"
    local manifest
    try {
        DirCreate(user_dir)
        DirCreate(shared_dir)
        FileAppend(SchemaManifestText("User"), user_dir . "\\demo.rabbit.ini", "UTF-8")
        FileAppend(SchemaManifestText("Shared"), shared_dir . "\\demo.rabbit.ini", "UTF-8")
        FileAppend(SchemaManifestText("Fallback"), shared_dir . "\\schema.rabbit-fallback.ini", "UTF-8")

        manifest := RabbitSchemaSettingsManifest.Load("demo", user_dir, shared_dir)
        AssertEqual("User", manifest.title, "The user manifest did not take precedence.")
        AssertEqual("menu/page_size", manifest.fields[1].path, "The manifest lost its field path.")

        FileDelete(user_dir . "\\demo.rabbit.ini")
        manifest := RabbitSchemaSettingsManifest.Load("demo", user_dir, shared_dir)
        AssertEqual("Shared", manifest.title, "The shared schema manifest was not used after the user manifest.")

        FileDelete(shared_dir . "\\demo.rabbit.ini")
        manifest := RabbitSchemaSettingsManifest.Load("demo", user_dir, shared_dir)
        AssertEqual("Fallback", manifest.title, "The shared fallback manifest was not used last.")
    } finally {
        if DirExist(root) {
            DirDelete(root, true)
        }
    }
}

TestSchemaSettingsManifestValidation() {
    local root := A_Temp . "\\rabbit-schema-settings-invalid-" . A_TickCount
    local path := root . "\\invalid.ini"
    try {
        DirCreate(root)
        FileAppend("[meta]`nformat=1`n[field.bad]`npath=engine/filters/@next`ntype=string`nlabel=Bad`n", path, "UTF-8")
        AssertThrows(
            RabbitSchemaSettingsManifest.Parse.Bind(path),
            "The manifest accepted a patch-operation path."
        )
        AssertThrows(
            RabbitSchemaSettingsManifest.ValidateSchemaId.Bind("..\\demo"),
            "The manifest accepted an unsafe schema id."
        )
    } finally {
        if DirExist(root) {
            DirDelete(root, true)
        }
    }
}

TestSchemaSettingsManifestGroups() {
    local root := A_Temp . "\\rabbit-schema-settings-groups-" . A_TickCount
    local path := root . "\\groups.ini"
    local manifest
    try {
        DirCreate(root)
        FileAppend(SchemaGroupedManifestText(), path, "UTF-8")
        manifest := RabbitSchemaSettingsManifest.Parse(path)
        AssertEqual(2, manifest.groups.Length, "The manifest lost a declared settings group.")
        AssertEqual("general", manifest.groups[1].id, "The manifest changed group order.")
        AssertEqual("advanced", manifest.fields[2].group, "The field did not retain its group.")

        FileDelete(path)
        FileAppend(
            StrReplace(SchemaGroupedManifestText(), "group=advanced", "group=missing"),
            path,
            "UTF-8"
        )
        AssertThrows(
            RabbitSchemaSettingsManifest.Parse.Bind(path),
            "The manifest accepted a field from an undeclared group."
        )
    } finally {
        if DirExist(root) {
            DirDelete(root, true)
        }
    }
}

TestBundledSchemaSettingsFallback() {
    local manifest := RabbitSchemaSettingsManifest.Parse(
        A_ScriptDir . "\..\..\schemas\schema.rabbit-fallback.ini"
    )
    AssertEqual(1, manifest.fields.Length, "The bundled fallback unexpectedly changed its field set.")
    AssertEqual(1, manifest.groups.Length, "The bundled fallback unexpectedly has multiple groups.")
    AssertEqual("general", manifest.fields[1].group, "The bundled fallback did not assign its field to a group.")
    AssertEqual("menu/page_size", manifest.fields[1].path, "The bundled fallback omitted the page-size setting.")
}

TestSchemaSettingsModelPersistence() {
    local calls := []
    local manifest := {
        title: "Test",
        description: "",
        groups: [{
            id: "general",
            label: "General",
            description: "",
        }],
        fields: [{
            id: "page_size",
            group: "general",
            path: "menu/page_size",
            type: "integer",
            label: "Page size",
            description: "",
            min: 1,
            max: 10,
            options: [],
        }],
    }
    local rime := RabbitSchemaSettingsRimeProbe(Map("menu/page_size", 9), calls)
    local model := RabbitSchemaSettingsModelProbe(rime, RabbitSchemaSettingsLeversProbe(calls), "demo", manifest)
    AssertTrue(model.Load(), "The schema settings model could not open an effective schema.")
    AssertEqual(9, model.values["page_size"], "The schema settings model read the wrong effective value.")
    AssertTrue(model.Save(Map("page_size", 7)), "The schema settings model did not save a valid value.")
    AssertEqual(
        "schema_open:demo,config_close,init:demo.schema,load,integer:menu/page_size:7,save,destroy",
        JoinSchemaSettingsCalls(calls),
        "The schema settings model did not write the schema custom settings through Levers."
    )
    AssertThrows(
        model.NormalizeValues.Bind(model, Map("page_size", 11)),
        "The schema settings model accepted a value above the manifest maximum."
    )
}

TestSchemaSettingsDialogDarkAppearance() {
    local calls := []
    local owner := Gui()
    local model := RabbitSchemaSettingsModelProbe(
        RabbitSchemaSettingsRimeProbe(Map(), calls),
        RabbitSchemaSettingsLeversProbe(calls),
        "demo",
        SchemaSettingsDialogManifest()
    )
    local dialog := 0
    try {
        model.values := Map("page_size", 5)
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        AssertTrue(dialog.window_theme.dark_mode, "The schema settings dialog ignored dark mode.")
        AssertEqual(
            RabbitWindowThemeController.DARK_BACKGROUND,
            dialog.BackColor,
            "The schema settings dialog did not use the dark window background."
        )
    } finally {
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestSchemaSettingsDialogGroups() {
    local calls := []
    local owner := Gui()
    local long_dialog := 0, long_manifest, long_values := Map()
    local model := RabbitSchemaSettingsModelProbe(
        RabbitSchemaSettingsRimeProbe(Map(), calls),
        RabbitSchemaSettingsLeversProbe(calls),
        "demo",
        SchemaSettingsGroupedDialogManifest()
    )
    local dialog := 0
    try {
        model.values := Map("page_size", 5, "auto_select", false)
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        AssertTrue(!!dialog.group_list, "Multiple manifest groups did not create navigation.")
        AssertEqual(2, dialog.groups.Length, "The group navigation showed the wrong count.")
        AssertTrue(dialog.field_controls.Has("page_size"), "The first group did not show its field.")
        dialog.field_controls["page_size"].Value := 7
        AssertTrue(dialog.SelectGroup(2), "The second group could not be selected.")
        AssertTrue(dialog.field_controls.Has("auto_select"), "The selected group did not show its field.")
        AssertEqual("7", dialog.draft_values["page_size"], "Changing groups lost the first group's pending value.")
        AssertTrue(!dialog.content_scroll_max, "A short settings group unexpectedly needed scrolling.")
        dialog.Dispose()
        dialog := 0

        long_manifest := SchemaSettingsLongGroupManifest()
        for field in long_manifest.fields {
            long_values[field.id] := "value"
        }
        model := RabbitSchemaSettingsModelProbe(
            RabbitSchemaSettingsRimeProbe(Map(), calls),
            RabbitSchemaSettingsLeversProbe(calls),
            "demo",
            long_manifest
        )
        model.values := long_values
        long_dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        AssertTrue(long_dialog.content_scroll_max > 0, "A long settings group did not enable scrolling.")
        long_dialog.ScrollContentTo(64)
        AssertEqual(64, long_dialog.content_scroll_y, "The settings content did not scroll to the requested position.")
    } finally {
        if dialog {
            dialog.Dispose()
        }
        if long_dialog {
            long_dialog.Dispose()
        }
        owner.Destroy()
    }
}

SchemaManifestText(title) {
    return "[meta]`nformat=1`ntitle=" . title . "`n[field.page_size]`npath=menu/page_size`ntype=integer`nlabel=Page size`nmin=1`nmax=10`n"
}

SchemaGroupedManifestText() {
    local newline := Chr(10)
    return "[meta]" . newline . "format=1" . newline
        . "[group.general]" . newline . "label=General" . newline
        . "[group.advanced]" . newline . "label=Advanced" . newline
        . "[field.page_size]" . newline . "group=general" . newline
        . "path=menu/page_size" . newline . "type=integer" . newline . "label=Page size" . newline
        . "[field.auto_select]" . newline . "group=advanced" . newline
        . "path=speller/auto_select" . newline . "type=boolean" . newline . "label=Auto select" . newline
}

SchemaSettingsDialogManifest() {
    return {
        title: "Settings",
        description: "Description",
        groups: [{
            id: "general",
            label: "General",
            description: "",
        }],
        fields: [{
            id: "page_size",
            group: "general",
            path: "menu/page_size",
            type: "integer",
            label: "Page size",
            description: "Description",
            min: 1,
            max: 10,
            options: [],
        }],
    }
}

SchemaSettingsGroupedDialogManifest() {
    return {
        title: "Settings",
        description: "",
        groups: [
            { id: "general", label: "General", description: "" },
            { id: "advanced", label: "Advanced", description: "" },
        ],
        fields: [
            {
                id: "page_size",
                group: "general",
                path: "menu/page_size",
                type: "integer",
                label: "Page size",
                description: "",
                min: 1,
                max: 10,
                options: [],
            },
            {
                id: "auto_select",
                group: "advanced",
                path: "speller/auto_select",
                type: "boolean",
                label: "Auto select",
                description: "",
                min: "",
                max: "",
                options: [],
            },
        ],
    }
}

SchemaSettingsLongGroupManifest() {
    local fields := [], index
    loop 30 {
        index := A_Index
        fields.Push({
            id: "setting_" . index,
            group: "general",
            path: "translator/setting_" . index,
            type: "string",
            label: "Setting " . index,
            description: "A long settings page needs scrolling.",
            min: "",
            max: "",
            options: [],
        })
    }
    return {
        title: "Settings",
        description: "",
        groups: [{ id: "general", label: "General", description: "" }],
        fields: fields,
    }
}

JoinSchemaSettingsCalls(calls) {
    local result := "", call
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitSchemaSettingsModelProbe extends RabbitSchemaSettingsModel {
    EnsureCustomFile() {
    }
}

class RabbitSchemaSettingsRimeProbe {
    __New(values, calls) {
        this.values := values
        this.calls := calls
    }

    schema_open(schema_id) {
        this.calls.Push("schema_open:" . schema_id)
        return "schema"
    }

    config_close(config) {
        this.calls.Push("config_close")
    }

    config_test_get_int(config, path, &value) {
        if !this.values.Has(path) {
            return false
        }
        value := this.values[path]
        return true
    }
}

class RabbitSchemaSettingsLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    custom_settings_init(config_id, generator_id) {
        this.calls.Push("init:" . config_id)
        return "settings"
    }

    load_settings(settings) {
        this.calls.Push("load")
        return true
    }

    customize_int(settings, path, value) {
        this.calls.Push("integer:" . path . ":" . value)
        return true
    }

    save_settings(settings) {
        this.calls.Push("save")
        return true
    }

    custom_settings_destroy(settings) {
        this.calls.Push("destroy")
    }
}
