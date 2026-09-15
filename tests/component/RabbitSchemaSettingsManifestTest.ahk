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

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitSchemaSettingsModel.ahk
#Include ..\..\Lib\RabbitSchemaSettingsDialog.ahk

RunTest("schema settings resolve manifests by data precedence", TestSchemaSettingsManifestPrecedence.Bind())
RunTest("schema settings validate manifest fields", TestSchemaSettingsManifestValidation.Bind())
RunTest("schema settings parse manifest groups", TestSchemaSettingsManifestGroups.Bind())
RunTest("schema settings parse ordered list fields", TestSchemaSettingsListManifest.Bind())
RunTest("punctuator maps validate and use a dedicated editor", TestPunctuatorMapEditor.Bind())
RunTest("recognizer patterns validate and use a dedicated editor", TestRecognizerPatternEditor.Bind())
RunTest("bundled schema settings fallback is valid", TestBundledSchemaSettingsFallback.Bind())
RunTest("schema settings load and save scalar values", TestSchemaSettingsModelPersistence.Bind())
RunTest("schema settings save menu values", TestSchemaSettingsMenuPersistence.Bind())
RunTest("schema settings save punctuation scalar values", TestSchemaSettingsPunctuatorScalarPersistence.Bind())
RunTest("schema settings save changed ordered lists", TestSchemaSettingsListPersistence.Bind())
RunTest("schema settings save punctuation maps", TestSchemaSettingsPunctuatorMapPersistence.Bind())
RunTest("schema settings save recognizer patterns", TestSchemaSettingsRecognizerPatternPersistence.Bind())
RunTest("schema settings dialog honors dark appearance", TestSchemaSettingsDialogDarkAppearance.Bind())
RunTest("schema settings dialog exposes menu controls", TestSchemaSettingsDialogMenuControls.Bind())
RunTest("schema settings dialog switches groups", TestSchemaSettingsDialogGroups.Bind())
RunTest("schema settings dialog reorders and resets lists", TestSchemaSettingsDialogLists.Bind())
RunTest("schema settings dialog supports librime binding values", TestSchemaSettingsDialogBindingValues.Bind())
RunTest("schema settings dialog exposes punctuation map fields", TestSchemaSettingsDialogPunctuatorMaps.Bind())
RunTest("schema settings dialog exposes recognizer pattern fields", TestSchemaSettingsDialogRecognizerPatterns.Bind())
RunTest("schema settings dialog sizes configured list rows", TestSchemaSettingsDialogListRows.Bind())
RunTest("schema settings dialog fits short described list groups", TestSchemaSettingsDialogDescribedLists.Bind())
RunTest("schema settings dialog reveals the final described list field", TestSchemaSettingsDialogLongDescribedLists.Bind())
RunTest("schema settings dialog lays out wrapped descriptions", TestSchemaSettingsDialogWrappedDescriptions.Bind())

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

TestSchemaSettingsListManifest() {
    local root := A_Temp . "\\rabbit-schema-settings-lists-" . A_TickCount
    local path := root . "\\lists.ini"
    local manifest, newline := Chr(10)
    try {
        DirCreate(root)
        FileAppend(
            "[meta]`nformat=1`n[field.processors]`npath=engine/processors`ntype=list`nlabel=Processors`n"
                . "[field.bindings]`npath=key_binder/bindings`ntype=key_binding_list`nlabel=Bindings`n",
            path,
            "UTF-8"
        )
        manifest := RabbitSchemaSettingsManifest.Parse(path)
        AssertEqual("list", manifest.fields[1].type, "The string list type was not retained.")
        AssertEqual("key_binding_list", manifest.fields[2].type, "The binding-list type was not retained.")
        AssertEqual(
            RabbitSchemaSettingsManifest.DEFAULT_LIST_ROWS,
            manifest.fields[1].rows,
            "A missing string-list row count did not use the default."
        )
        AssertEqual(
            RabbitSchemaSettingsManifest.DEFAULT_LIST_ROWS,
            manifest.fields[2].rows,
            "A missing binding-list row count did not use the default."
        )

        FileDelete(path)
        FileAppend(
            "[meta]" . newline . "format=1" . newline
                . "[field.processors]" . newline . "path=engine/processors" . newline . "type=list" . newline
                . "label=Processors" . newline . "rows=1" . newline
                . "[field.bindings]" . newline . "path=key_binder/bindings" . newline
                . "type=key_binding_list" . newline . "label=Bindings" . newline . "rows=10" . newline,
            path,
            "UTF-8"
        )
        manifest := RabbitSchemaSettingsManifest.Parse(path)
        AssertEqual(1, manifest.fields[1].rows, "The string-list row count was not retained.")
        AssertEqual(10, manifest.fields[2].rows, "The binding-list row count was not retained.")

        FileDelete(path)
        FileAppend(
            "[meta]" . newline . "format=1" . newline
                . "[field.processors]" . newline . "path=engine/processors" . newline . "type=list" . newline
                . "label=Processors" . newline . "rows=11" . newline
                . "[field.bindings]" . newline . "path=key_binder/bindings" . newline
                . "type=key_binding_list" . newline . "label=Bindings" . newline . "rows=rows" . newline,
            path,
            "UTF-8"
        )
        manifest := RabbitSchemaSettingsManifest.Parse(path)
        AssertEqual(
            RabbitSchemaSettingsManifest.DEFAULT_LIST_ROWS,
            manifest.fields[1].rows,
            "An oversized string-list row count did not use the default."
        )
        AssertEqual(
            RabbitSchemaSettingsManifest.DEFAULT_LIST_ROWS,
            manifest.fields[2].rows,
            "A non-integer binding-list row count did not use the default."
        )
        AssertEqual(
            RabbitSchemaSettingsManifest.DEFAULT_LIST_ROWS,
            RabbitSchemaSettingsManifest.ParseListRows(Map("rows", "11")),
            "An oversized list row count did not use the default."
        )
        AssertEqual(
            RabbitSchemaSettingsManifest.DEFAULT_LIST_ROWS,
            RabbitSchemaSettingsManifest.ParseListRows(Map("rows", "rows")),
            "A non-integer list row count did not use the default."
        )

        FileDelete(path)
        FileAppend(
            "[meta]`nformat=1`n[field.bindings]`npath=menu/bindings`ntype=key_binding_list`nlabel=Bindings`n",
            path,
            "UTF-8"
        )
        AssertThrows(
            RabbitSchemaSettingsManifest.Parse.Bind(path),
            "The binding-list type accepted an unrelated path."
        )

        FileDelete(path)
        FileAppend(
            "[meta]`nformat=1`n[field.records]`npath=menu/records`ntype=record_list`nlabel=Records`n",
            path,
            "UTF-8"
        )
        AssertThrows(
            RabbitSchemaSettingsManifest.Parse.Bind(path),
            "The manifest accepted the reserved record-list type."
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
    AssertEqual(12, manifest.fields.Length, "The bundled fallback unexpectedly changed its field set.")
    AssertEqual(3, manifest.groups.Length, "The bundled fallback unexpectedly has the wrong groups.")
    AssertEqual("menu", manifest.fields[1].group, "The bundled fallback did not assign its field to a group.")
    AssertEqual("menu/page_size", manifest.fields[1].path, "The bundled fallback omitted the page-size setting.")
    AssertEqual("list", manifest.fields[2].type, "The bundled fallback omitted candidate label support.")
    AssertTrue(manifest.fields[2].default is Array, "The candidate label default was not parsed as an empty list.")
    AssertEqual(
        "menu/alternative_select_keys",
        manifest.fields[3].path,
        "The bundled fallback omitted candidate selection-key support."
    )
    AssertTrue(manifest.fields[3].has_default && manifest.fields[3].default = "",
        "The candidate selection-key default was not parsed.")
    AssertEqual("boolean", manifest.fields[4].type, "The bundled fallback omitted page-cycle support.")
    AssertTrue(!manifest.fields[4].default, "The page-cycle default was not parsed.")
    AssertEqual("punctuator_map", manifest.fields[5].type, "The bundled fallback omitted punctuation map support.")
    AssertEqual(
        "punctuator/full_shape",
        manifest.fields[5].path,
        "The bundled fallback omitted the full-shape punctuation map."
    )
    AssertEqual("boolean", manifest.fields[8].type, "The bundled fallback omitted punctuation spacing support.")
    AssertTrue(!manifest.fields[8].default, "The punctuation spacing default was not parsed.")
    AssertEqual(
        "punctuator/digit_separators",
        manifest.fields[9].path,
        "The bundled fallback omitted digit separator support."
    )
    AssertEqual(".:", manifest.fields[9].default, "The digit separator default was not parsed.")
    AssertEqual("enum", manifest.fields[10].type, "The bundled fallback omitted digit separator action support.")
    AssertEqual("forward", manifest.fields[10].default, "The digit separator action default was not parsed.")
    AssertEqual(2, manifest.fields[10].options.Length, "The digit separator action options were incomplete.")
    AssertEqual("recognizer", manifest.fields[11].group, "The bundled fallback omitted the recognizer group.")
    AssertEqual("boolean", manifest.fields[11].type, "The bundled fallback omitted recognizer spacing support.")
    AssertTrue(!manifest.fields[11].default, "The recognizer spacing default was not parsed.")
    AssertEqual("recognizer_patterns", manifest.fields[12].type,
        "The bundled fallback omitted recognizer pattern support.")
    AssertEqual("recognizer/patterns", manifest.fields[12].path,
        "The bundled fallback omitted the recognizer pattern path.")
}

TestPunctuatorMapEditor() {
    local owner := Gui(), dialog := 0, entry_dialog := 0
    local value := Map(
        "(", Map("pair", ["（", "）"]),
        ")", "）",
        ",", ["，", ","]
    )
    try {
        value := RabbitPunctuatorMap.Validate(value, RabbitPunctuatorMap.FULL_SHAPE_PATH)
        AssertEqual("pair", RabbitPunctuatorMap.DefinitionKind(value["("]),
            "The punctuation map did not recognize paired definitions.")
        AssertEqual("list", RabbitPunctuatorMap.DefinitionKind(value[","]),
            "The punctuation map did not recognize candidate definitions.")
        AssertThrows(
            RabbitPunctuatorMap.Validate.Bind(Map("ab", "x"), RabbitPunctuatorMap.FULL_SHAPE_PATH),
            "The full-shape map accepted a multi-character trigger."
        )

        dialog := RabbitPunctuatorMapDialog(
            owner,
            RabbitPunctuatorMap.FULL_SHAPE_PATH,
            value,
            0,
            (*) => true
        )
        AssertEqual(3, dialog.list.GetCount(), "The punctuation editor lost map entries.")
        AssertEqual("(", dialog.list.GetText(1, 1), "The punctuation editor changed map order.")
        entry_dialog := RabbitPunctuatorEntryDialog(
            dialog,
            RabbitPunctuatorMap.FULL_SHAPE_PATH,
            "(",
            value["("],
            0,
            (*) => true
        )
        AssertEqual(3, entry_dialog.type_choice.Value, "The entry editor did not select paired output.")
    } finally {
        if entry_dialog {
            entry_dialog.Dispose()
        }
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestRecognizerPatternEditor() {
    local owner := Gui(), dialog := 0, entry_dialog := 0
    local value := Map(
        "email", "[A-Za-z]+@[A-Za-z]+\\.[A-Za-z]+",
        "url", "https?://[^ ]+"
    )
    try {
        value := RabbitRecognizerPatterns.Validate(value)
        AssertEqual(2, value.Count, "The recognizer pattern validator lost entries.")
        AssertThrows(
            RabbitRecognizerPatterns.Validate.Bind(Map("", "pattern")),
            "The recognizer pattern validator accepted an empty tag."
        )
        AssertThrows(
            RabbitRecognizerPatterns.Validate.Bind(Map("tag", Map("nested", true))),
            "The recognizer pattern validator accepted a nested definition."
        )
        dialog := RabbitRecognizerPatternsDialog(owner, value, (*) => true)
        AssertEqual(2, dialog.list.GetCount(), "The recognizer editor lost pattern entries.")
        AssertEqual("email", dialog.list.GetText(1, 1), "The recognizer editor changed pattern order.")
        entry_dialog := RabbitRecognizerPatternEntryDialog(dialog, "email", value["email"], (*) => true)
        AssertEqual("email", entry_dialog.tag_edit.Value, "The pattern entry editor lost the tag.")
        AssertEqual(value["email"], entry_dialog.pattern_edit.Value,
            "The pattern entry editor changed the regular expression.")
    } finally {
        if entry_dialog {
            entry_dialog.Dispose()
        }
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
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

TestSchemaSettingsMenuPersistence() {
    local calls := [], values, model
    local manifest := SchemaSettingsMenuManifest()
    local rime := RabbitSchemaSettingsListRimeProbe(Map(
        "menu/page_size", 5,
        "menu/alternative_select_labels", ["①", "②", "③"],
        "menu/alternative_select_keys", "asdfg",
        "menu/page_down_cycle", 0
    ), ["menu/alternative_select_labels/@legacy"], calls)
    model := RabbitSchemaSettingsModelProbe(
        rime,
        RabbitSchemaSettingsListLeversProbe(calls),
        "demo",
        manifest
    )
    AssertTrue(model.Load(), "The schema settings model could not load menu settings.")
    AssertEqual(5, model.values["page_size"], "The menu page size was loaded incorrectly.")
    AssertEqual("②", model.values["alternative_select_labels"][2],
        "The menu labels were loaded incorrectly.")
    AssertEqual("asdfg", model.values["alternative_select_keys"],
        "The candidate selection keys were loaded incorrectly.")
    AssertTrue(!model.values["page_down_cycle"], "The page-cycle value was loaded incorrectly.")

    values := RabbitConfigValue.Clone(model.values)
    values["page_size"] := 6
    values["alternative_select_labels"] := ["一", "二"]
    values["alternative_select_keys"] := " asdfg"
    values["page_down_cycle"] := true
    AssertTrue(model.Save(values), "The schema settings model failed to save menu settings.")
    AssertTrue(SchemaSettingsCallsHave(calls, "integer:menu/page_size:6"),
        "The schema settings model did not save the menu page size.")
    AssertTrue(SchemaSettingsCallsHave(calls, "string:menu/alternative_select_keys: asdfg"),
        "The schema settings model did not preserve candidate selection keys.")
    AssertTrue(SchemaSettingsCallsHave(calls, "boolean:menu/page_down_cycle:1"),
        "The schema settings model did not save the page-cycle value.")
    AssertTrue(SchemaSettingsCallsHave(calls, "reset:menu/alternative_select_labels/@legacy"),
        "Replacing menu labels did not clear a nested patch.")
    AssertTrue(SchemaSettingsCallsContain(calls, "item:menu/alternative_select_labels:", '"一"'),
        "The schema settings model did not save the complete menu label list.")

    values["alternative_select_keys"] := "aa"
    AssertThrows(model.NormalizeValues.Bind(model, values),
        "The schema settings model accepted duplicate candidate selection keys.")
}

TestSchemaSettingsPunctuatorScalarPersistence() {
    local calls := []
    local model := RabbitSchemaSettingsModelProbe(
        RabbitSchemaSettingsRimeProbe(Map(), calls),
        RabbitSchemaSettingsLeversProbe(calls),
        "demo",
        SchemaSettingsPunctuatorScalarManifest()
    )
    local values
    AssertTrue(model.Load(), "The schema settings model could not load punctuation scalar defaults.")
    AssertTrue(!model.values["use_space"], "The punctuation spacing default was not loaded.")
    AssertEqual(".:", model.values["digit_separators"], "The digit separator default was not loaded.")
    AssertEqual("forward", model.values["digit_separator_action"],
        "The digit separator action default was not loaded.")

    values := RabbitConfigValue.Clone(model.values)
    values["use_space"] := true
    values["digit_separators"] := ",."
    values["digit_separator_action"] := "commit"
    AssertTrue(model.Save(values), "The schema settings model failed to save punctuation scalar values.")
    AssertTrue(SchemaSettingsCallsHave(calls, "boolean:punctuator/use_space:1"),
        "The schema settings model did not save punctuation spacing.")
    AssertTrue(SchemaSettingsCallsHave(calls, "string:punctuator/digit_separators:,."),
        "The schema settings model did not save digit separators.")
    AssertTrue(SchemaSettingsCallsHave(calls, "string:punctuator/digit_separator_action:commit"),
        "The schema settings model did not save the digit separator action.")
    values["digit_separators"] := "a"
    AssertThrows(model.NormalizeValues.Bind(model, values),
        "The schema settings model accepted a non-punctuation digit separator.")
    values["digit_separators"] := ".:"
    values["digit_separator_action"] := "unknown"
    AssertThrows(model.NormalizeValues.Bind(model, values),
        "The schema settings model accepted an unsupported digit separator action.")
}

TestSchemaSettingsListPersistence() {
    local calls := []
    local manifest := SchemaSettingsListManifest()
    local rime := RabbitSchemaSettingsListRimeProbe(Map(
        "engine/processors", ["ascii_composer", "recognizer", "table_translator@custom_phrase"],
        "key_binder/bindings", [Map("accept", "Tab", "when", "composing", "send", "Down", "custom", "kept")]
    ), [
        "engine/processors/+",
        "engine/processors/@after recognizer",
        "key_binder/bindings/-",
        "key_binder/bindings/@5",
    ], calls)
    local model := RabbitSchemaSettingsModelProbe(rime, RabbitSchemaSettingsListLeversProbe(calls), "demo", manifest)
    local values
    AssertTrue(model.Load(), "The schema settings model could not read ordered lists.")
    AssertEqual(
        "table_translator@custom_phrase",
        model.values["processors"][3],
        "The string list changed processor text."
    )
    AssertEqual("kept", model.values["bindings"][1]["custom"], "The binding list dropped an unknown field.")

    calls.Length := 0
    AssertTrue(model.Save(RabbitConfigValue.Clone(model.values)), "The unchanged lists failed to save.")
    AssertEqual(0, calls.Length, "Unchanged lists opened or wrote custom settings.")
    AssertEqual(0, model.ensure_count, "Unchanged lists created a custom configuration file.")

    values := RabbitConfigValue.Clone(model.values)
    values["processors"].InsertAt(1, values["processors"].RemoveAt(3))
    AssertTrue(model.Save(values), "The model failed to replace a string list.")
    AssertTrue(
        SchemaSettingsCallsHave(calls, "reset:engine/processors/+"),
        "Replacing a list did not clear an appended patch."
    )
    AssertTrue(
        SchemaSettingsCallsHave(calls, "reset:engine/processors/@after recognizer"),
        "Replacing a list did not clear an ordered patch."
    )
    AssertTrue(
        SchemaSettingsCallsContain(calls, "item:engine/processors:", "table_translator@custom_phrase"),
        "The replacement did not preserve the processor expression."
    )

    calls.Length := 0
    values := RabbitConfigValue.Clone(model.values)
    values["bindings"][1]["send"] := "Up"
    AssertTrue(model.Save(values), "The model failed to replace a key-binding list.")
    AssertTrue(
        SchemaSettingsCallsHave(calls, "reset:key_binder/bindings/@5"),
        "Replacing bindings did not clear an indexed patch."
    )
    AssertTrue(
        SchemaSettingsCallsContain(calls, "item:key_binder/bindings:", '"custom": "kept"'),
        "Replacing bindings dropped an unknown binding field."
    )

    calls.Length := 0
    AssertTrue(
        model.Save(RabbitConfigValue.Clone(model.values), Map("processors", true)),
        "The model failed to restore a list default."
    )
    AssertTrue(
        SchemaSettingsCallsHave(calls, "reset:engine/processors"),
        "Restoring a list default did not remove its full-list override."
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

TestSchemaSettingsDialogMenuControls() {
    local calls := [], owner := Gui(), dialog := 0
    local model := RabbitSchemaSettingsModelProbe(
        RabbitSchemaSettingsRimeProbe(Map(), calls),
        RabbitSchemaSettingsLeversProbe(calls),
        "demo",
        SchemaSettingsMenuManifest()
    )
    try {
        model.values := Map(
            "page_size", 5,
            "alternative_select_labels", [],
            "alternative_select_keys", "",
            "page_down_cycle", false
        )
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        AssertTrue(dialog.field_controls.Has("page_size"), "The schema dialog omitted the menu page-size field.")
        AssertTrue(
            dialog.field_controls.Has("alternative_select_keys"),
            "The schema dialog omitted the candidate selection-key field."
        )
        AssertEqual(
            "1234567890",
            SchemaSettingsEditCue(dialog.field_controls["alternative_select_keys"]),
            "The schema dialog did not show the empty selection-key cue."
        )
        AssertTrue(dialog.field_controls.Has("alternative_select_labels"),
            "The schema dialog omitted the candidate label list.")
        AssertTrue(dialog.field_controls.Has("page_down_cycle"),
            "The schema dialog omitted the page-cycle field.")
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

TestSchemaSettingsDialogLists() {
    local calls := []
    local owner := Gui()
    local model := RabbitSchemaSettingsModelProbe(
        RabbitSchemaSettingsRimeProbe(Map(), calls),
        RabbitSchemaSettingsLeversProbe(calls),
        "demo",
        SchemaSettingsListManifest()
    )
    local bindings, dialog := 0, header_y, list_y, processors
    try {
        model.values := Map(
            "processors", ["ascii_composer", "recognizer"],
            "bindings", [Map("accept", "Tab", "when", "composing", "send", "Down")]
        )
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        processors := model.manifest.fields[1]
        AssertTrue(dialog.field_controls.Has("processors"), "The dialog did not create a string-list editor.")
        AssertTrue(dialog.field_controls.Has("bindings"), "The dialog did not create a key-binding editor.")
        bindings := dialog.field_controls["bindings"]
        AssertTrue(
            HasProp(bindings, "accept_header") && HasProp(bindings, "when_header") && HasProp(bindings, "action_header"),
            "Dark key-binding lists did not create all replacement headers."
        )
        AssertTrue(
            WinGetStyle("ahk_id " . bindings.list.Hwnd) & 0x4000,
            "Dark key-binding lists kept the native light header."
        )
        AssertEqual(
            "surface",
            dialog.content_window_theme.roles[bindings.accept_header.Hwnd],
            "The replacement key-binding header did not use the surface theme."
        )
        bindings.accept_header.GetPos(, &header_y)
        bindings.list.GetPos(, &list_y)
        AssertEqual(24, list_y - header_y, "The key-binding list did not begin below its replacement header.")
        AssertTrue(
            dialog.content_list_hwnds.Has(dialog.field_controls["processors"].list.Hwnd),
            "The string-list editor was not registered for native wheel scrolling."
        )
        AssertTrue(
            dialog.content_list_hwnds.Has(dialog.field_controls["bindings"].list.Hwnd),
            "The key-binding editor was not registered for native wheel scrolling."
        )
        AssertEqual(
            0,
            dialog.GetListControlAtWheelPoint(0),
            "The list wheel hit test did not safely ignore a point outside the content panel."
        )
        dialog.field_controls["processors"].list.Choose(2)
        AssertTrue(dialog.MoveListItem(processors, -1), "The dialog could not move a list item upward.")
        AssertEqual(
            "recognizer",
            dialog.draft_values["processors"][1],
            "Moving a list item changed its order incorrectly."
        )
        AssertTrue(dialog.RestoreListDefault(processors), "The dialog could not mark a list for reset.")
        AssertTrue(dialog.reset_fields.Has("processors"), "The list reset was not retained.")
        dialog.field_controls["processors"].list.Choose(1)
        AssertTrue(dialog.MoveListItem(processors, 1), "The dialog could not edit after a pending reset.")
        AssertTrue(!dialog.reset_fields.Has("processors"), "Editing a list did not cancel its pending reset.")
    } finally {
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestSchemaSettingsDialogBindingValues() {
    local calls := [], dialog := 0, model, owner := Gui()
    try {
        model := RabbitSchemaSettingsModelProbe(
            RabbitSchemaSettingsRimeProbe(Map(), calls),
            RabbitSchemaSettingsLeversProbe(calls),
            "demo",
            SchemaSettingsListManifest()
        )
        model.values := Map(
            "processors", ["ascii_composer"],
            "bindings", [
                Map("accept", "F1", "when", "predicting", "set_option", "ascii_mode"),
                Map("accept", "F2", "when", "always", "unset_option", "ascii_mode")
            ]
        )
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        local bindings := dialog.field_controls["bindings"].list
        AssertEqual("F1", bindings.GetText(1, 1), "The schema binding list lost the first key.")
        AssertEqual("predicting", bindings.GetText(1, 2), "The schema binding list lost the predicting condition.")
        AssertEqual(
            "set_option: ascii_mode",
            bindings.GetText(1, 3),
            "The schema binding list lost the set_option action."
        )
        AssertEqual("always", bindings.GetText(2, 2), "The schema binding list lost the always condition.")
        AssertEqual(
            "unset_option: ascii_mode",
            bindings.GetText(2, 3),
            "The schema binding list lost the unset_option action."
        )
    } finally {
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestSchemaSettingsPunctuatorMapPersistence() {
    local calls := [], manifest := SchemaSettingsPunctuatorManifest(), values, model
    local rime := RabbitSchemaSettingsListRimeProbe(Map(
        "punctuator/full_shape", Map(
            "(", Map("pair", ["（", "）"]),
            ")", "）",
            ",", ["，", ","]
        )
    ), ["punctuator/full_shape/@legacy"], calls)
    model := RabbitSchemaSettingsModelProbe(
        rime,
        RabbitSchemaSettingsListLeversProbe(calls),
        "demo",
        manifest
    )
    AssertTrue(model.Load(), "The schema settings model could not read a punctuation map.")
    AssertEqual("）", model.values["full_shape"][")"], "The punctuation map lost a scalar definition.")
    AssertEqual("list", RabbitPunctuatorMap.DefinitionKind(model.values["full_shape"][","]),
        "The punctuation map lost a candidate definition.")

    values := RabbitConfigValue.Clone(model.values)
    values["full_shape"]["("]["pair"][1] := "【"
    AssertTrue(model.Save(values), "The schema settings model failed to save a punctuation map.")
    AssertTrue(
        SchemaSettingsCallsHave(calls, "reset:punctuator/full_shape/@legacy"),
        "Replacing a punctuation map did not clear a nested patch."
    )
    AssertTrue(
        SchemaSettingsCallsContain(calls, "item:punctuator/full_shape:", '"(": {"pair": ["【", "）"]}'),
        "Replacing a punctuation map did not write the complete map."
    )

    calls.Length := 0
    AssertTrue(
        model.Save(RabbitConfigValue.Clone(model.values), Map("full_shape", true)),
        "The schema settings model failed to restore a punctuation map."
    )
    AssertTrue(
        SchemaSettingsCallsHave(calls, "reset:punctuator/full_shape"),
        "Restoring a punctuation map did not remove its full-map override."
    )
    AssertTrue(
        SchemaSettingsCallsHave(calls, "reset:punctuator/full_shape/@legacy"),
        "Restoring a punctuation map did not remove its nested patch."
    )
}

TestSchemaSettingsRecognizerPatternPersistence() {
    local calls := [], manifest := SchemaSettingsRecognizerManifest(), values, model
    local rime := RabbitSchemaSettingsListRimeProbe(Map(
        "recognizer/use_space", 0,
        "recognizer/patterns", Map(
            "email", "old@example\\.com",
            "url", "https?://[^ ]+"
        )
    ), ["recognizer/patterns/@legacy"], calls)
    model := RabbitSchemaSettingsModelProbe(
        rime,
        RabbitSchemaSettingsListLeversProbe(calls),
        "demo",
        manifest
    )
    AssertTrue(model.Load(), "The schema settings model could not read recognizer settings.")
    AssertTrue(!model.values["use_space"], "The recognizer spacing value was loaded incorrectly.")
    AssertEqual("old@example\\.com", model.values["patterns"]["email"],
        "The recognizer pattern was loaded incorrectly.")

    values := RabbitConfigValue.Clone(model.values)
    values["use_space"] := true
    values["patterns"]["email"] := "new@example\\.com"
    AssertTrue(model.Save(values), "The schema settings model failed to save recognizer settings.")
    AssertTrue(SchemaSettingsCallsHave(calls, "boolean:recognizer/use_space:1"),
        "The schema settings model did not save recognizer spacing.")
    AssertTrue(SchemaSettingsCallsHave(calls, "reset:recognizer/patterns/@legacy"),
        "Replacing recognizer patterns did not clear a nested patch.")
    AssertTrue(SchemaSettingsCallsContain(calls, "item:recognizer/patterns:", '"email": "new@example\\\\.com"'),
        "Replacing recognizer patterns did not write the complete map.")

    calls.Length := 0
    AssertTrue(
        model.Save(RabbitConfigValue.Clone(model.values), Map("patterns", true)),
        "The schema settings model failed to restore recognizer patterns."
    )
    AssertTrue(SchemaSettingsCallsHave(calls, "reset:recognizer/patterns"),
        "Restoring recognizer patterns did not remove the full-map override.")
    AssertTrue(SchemaSettingsCallsHave(calls, "reset:recognizer/patterns/@legacy"),
        "Restoring recognizer patterns did not remove a nested patch.")
}

TestSchemaSettingsDialogPunctuatorMaps() {
    local calls := [], dialog := 0, owner := Gui(), reset_width, summary_width
    local model := RabbitSchemaSettingsModelProbe(
        RabbitSchemaSettingsRimeProbe(Map(), calls),
        RabbitSchemaSettingsLeversProbe(calls),
        "demo",
        SchemaSettingsPunctuatorManifest()
    )
    try {
        model.values := Map("full_shape", Map("(", Map("pair", ["（", "）"])))
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        AssertTrue(dialog.field_controls.Has("full_shape"), "The schema dialog did not create a punctuation editor.")
        dialog.field_controls["full_shape"].reset_button.GetPos(,, &reset_width)
        dialog.field_controls["full_shape"].summary.GetPos(,, &summary_width)
        AssertTrue(reset_width >= 120, "The punctuation reset button is too narrow for localized text.")
        AssertTrue(summary_width >= 200, "The punctuation map summary lost its usable width.")
        AssertEqual(
            "1 个映射项",
            dialog.field_controls["full_shape"].summary.Value,
            "The punctuation editor did not summarize its map."
        )
        AssertTrue(
            dialog.RestorePunctuatorMapDefault(model.manifest.fields[1]),
            "The schema dialog could not stage a punctuation reset."
        )
        AssertTrue(
            dialog.reset_fields.Has("full_shape"),
            "The punctuation reset was not retained."
        )
    } finally {
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestSchemaSettingsDialogRecognizerPatterns() {
    local calls := [], dialog := 0, owner := Gui(), model
    model := RabbitSchemaSettingsModelProbe(
        RabbitSchemaSettingsRimeProbe(Map(), calls),
        RabbitSchemaSettingsLeversProbe(calls),
        "demo",
        SchemaSettingsRecognizerManifest()
    )
    try {
        model.values := Map(
            "use_space", false,
            "patterns", Map("email", "email pattern")
        )
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        AssertTrue(dialog.field_controls.Has("patterns"), "The schema dialog did not create a recognizer editor.")
        AssertEqual("1 个模式", dialog.field_controls["patterns"].summary.Value,
            "The recognizer editor did not summarize its patterns.")
        AssertTrue(
            dialog.RestoreRecognizerPatternsDefault(model.manifest.fields[2]),
            "The schema dialog could not stage a recognizer reset."
        )
        AssertTrue(dialog.reset_fields.Has("patterns"), "The recognizer reset was not retained.")
    } finally {
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestSchemaSettingsDialogWrappedDescriptions() {
    local calls := [], content_height, content_y, dialog := 0, field_y, header_height, model, owner := Gui()
    local long_description := "This deliberately long description verifies that schema settings text wraps "
        . "without overlapping the next control in a narrow page. "
        . "It must remain completely readable after the window chooses its content height."
    try {
        model := RabbitSchemaSettingsModelProbe(
            RabbitSchemaSettingsRimeProbe(Map(), calls),
            RabbitSchemaSettingsLeversProbe(calls),
            "demo",
            SchemaSettingsWrappedDescriptionManifest(long_description)
        )
        model.values := Map("page_size", 5)
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => true)
        dialog.outer_muted_controls[1].GetPos(, , , &header_height)
        AssertTrue(header_height > 34, "A wrapped manifest description kept the old fixed height.")
        dialog.content_muted_controls[1].GetPos(, &content_y, , &content_height)
        AssertTrue(content_height > 30, "A wrapped group description kept the old fixed height.")
        dialog.field_controls["page_size"].GetPos(, &field_y)
        AssertTrue(field_y >= content_y + content_height + 10,
            "The first field overlapped its wrapped group description.")
        dialog.content_muted_controls[2].GetPos(, &content_y, , &content_height)
        AssertTrue(content_height > 30, "A wrapped field description kept the old fixed height.")
        AssertTrue(dialog.content_virtual_height >= content_y + content_height + 14,
            "The content scrolling range clipped a wrapped field description.")
    } finally {
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestSchemaSettingsDialogListRows() {
    local calls := [], long_binding_height, long_dialog := 0, long_model, long_string_height
    local owner := Gui()
    local short_binding_height, short_dialog := 0, short_model, short_string_height
    try {
        short_model := RabbitSchemaSettingsModelProbe(
            RabbitSchemaSettingsRimeProbe(Map(), calls),
            RabbitSchemaSettingsLeversProbe(calls),
            "demo",
            SchemaSettingsListManifest(1, 1)
        )
        short_model.values := Map(
            "processors", ["ascii_composer", "recognizer"],
            "bindings", [Map("accept", "Tab", "when", "composing", "send", "Down")]
        )
        short_dialog := RabbitSchemaSettingsDialog(owner, short_model, "Demo", (*) => true)
        short_dialog.field_controls["processors"].list.GetPos(, , , &short_string_height)
        short_dialog.field_controls["bindings"].list.GetPos(, , , &short_binding_height)

        long_model := RabbitSchemaSettingsModelProbe(
            RabbitSchemaSettingsRimeProbe(Map(), calls),
            RabbitSchemaSettingsLeversProbe(calls),
            "demo",
            SchemaSettingsListManifest(10, 10)
        )
        long_model.values := Map(
            "processors", ["ascii_composer", "recognizer"],
            "bindings", [Map("accept", "Tab", "when", "composing", "send", "Down")]
        )
        long_dialog := RabbitSchemaSettingsDialog(owner, long_model, "Demo", (*) => true)
        long_dialog.field_controls["processors"].list.GetPos(, , , &long_string_height)
        long_dialog.field_controls["bindings"].list.GetPos(, , , &long_binding_height)
        AssertTrue(long_string_height > short_string_height,
            "The configured string-list row count did not change its height.")
        AssertTrue(long_binding_height > short_binding_height,
            "The configured key-binding row count did not change its height.")
    } finally {
        if short_dialog {
            short_dialog.Dispose()
        }
        if long_dialog {
            long_dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestSchemaSettingsDialogDescribedLists() {
    local calls := [], dialog := 0, model, owner := Gui()
    try {
        model := RabbitSchemaSettingsModelProbe(
            RabbitSchemaSettingsRimeProbe(Map(), calls),
            RabbitSchemaSettingsLeversProbe(calls),
            "demo",
            SchemaSettingsListManifest(3, 3, "A short group description.")
        )
        model.values := Map(
            "processors", ["ascii_composer", "recognizer"],
            "bindings", [Map("accept", "Tab", "when", "composing", "send", "Down")]
        )
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => false)
        AssertTrue(
            dialog.content_virtual_height <= dialog.content_viewport_height,
            "A short described list group exceeded its content viewport."
        )
        AssertEqual(0, dialog.content_scroll_max,
            "A short described list group unexpectedly enabled page scrolling.")
    } finally {
        if dialog {
            dialog.Dispose()
        }
        owner.Destroy()
    }
}

TestSchemaSettingsDialogLongDescribedLists() {
    local calls := [], dialog := 0, model, owner := Gui()
    local description := "This description must be fully visible after scrolling to the end of the settings page."
    try {
        model := RabbitSchemaSettingsModelProbe(
            RabbitSchemaSettingsRimeProbe(Map(), calls),
            RabbitSchemaSettingsLeversProbe(calls),
            "demo",
            SchemaSettingsListManifest(10, 10, "A short group description.", description)
        )
        model.values := Map(
            "processors", ["ascii_composer", "recognizer"],
            "bindings", [Map("accept", "Tab", "when", "composing", "send", "Down")]
        )
        dialog := RabbitSchemaSettingsDialog(owner, model, "Demo", (*) => false)
        AssertTrue(dialog.content_scroll_max > 0, "The long described list group did not require scrolling.")
        dialog.ScrollContentTo(dialog.content_scroll_max)
        AssertTrue(
            dialog.GetContentControlBottom(dialog.content_muted_controls[5]) <= dialog.content_viewport_height,
            "Scrolling to the end clipped the final list description."
        )
    } finally {
        if dialog {
            dialog.Dispose()
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

SchemaSettingsWrappedDescriptionManifest(description) {
    return {
        title: "Settings",
        description: description,
        groups: [{ id: "general", label: "General", description: description }],
        fields: [{
            id: "page_size",
            group: "general",
            path: "menu/page_size",
            type: "integer",
            label: "Page size",
            description: description,
            min: 1,
            max: 10,
            options: [],
        }],
    }
}

SchemaSettingsListManifest(processor_rows := "", binding_rows := "", group_description := "", field_description := "") {
    return {
        title: "Settings",
        description: "",
        groups: [{ id: "general", label: "General", description: group_description }],
        fields: [
            {
                id: "processors",
                group: "general",
                path: "engine/processors",
                type: "list",
                label: "Processors",
                description: field_description,
                min: "",
                max: "",
                options: [],
                rows: processor_rows,
            },
            {
                id: "bindings",
                group: "general",
                path: "key_binder/bindings",
                type: "key_binding_list",
                label: "Bindings",
                description: field_description,
                min: "",
                max: "",
                options: [],
                rows: binding_rows,
            },
        ],
    }
}

SchemaSettingsMenuManifest() {
    return {
        title: "Settings",
        description: "",
        groups: [{ id: "menu", label: "Candidate menu", description: "" }],
        fields: [
            {
                id: "page_size",
                group: "menu",
                path: "menu/page_size",
                type: "integer",
                label: "Page size",
                description: "",
                min: 1,
                max: 10,
                options: [],
            },
            {
                id: "alternative_select_labels",
                group: "menu",
                path: "menu/alternative_select_labels",
                type: "list",
                label: "Candidate labels",
                description: "",
                min: "",
                max: "",
                options: [],
                rows: 3,
                has_default: true,
                default: [],
            },
            {
                id: "alternative_select_keys",
                group: "menu",
                path: "menu/alternative_select_keys",
                type: "string",
                label: "Candidate selection keys",
                description: "",
                min: "",
                max: "",
                options: [],
                has_default: true,
                default: "",
            },
            {
                id: "page_down_cycle",
                group: "menu",
                path: "menu/page_down_cycle",
                type: "boolean",
                label: "Cycle pages",
                description: "",
                min: "",
                max: "",
                options: [],
                has_default: true,
                default: false,
            },
        ],
    }
}

SchemaSettingsPunctuatorManifest() {
    return {
        title: "Settings",
        description: "",
        groups: [{ id: "punctuator", label: "Punctuation", description: "" }],
        fields: [{
            id: "full_shape",
            group: "punctuator",
            path: "punctuator/full_shape",
            type: "punctuator_map",
            label: "Full-shape map",
            description: "",
            min: "",
            max: "",
            options: [],
        }],
    }
}

SchemaSettingsPunctuatorScalarManifest() {
    return {
        title: "Settings",
        description: "",
        groups: [{ id: "punctuator", label: "Punctuation", description: "" }],
        fields: [
            {
                id: "use_space",
                group: "punctuator",
                path: "punctuator/use_space",
                type: "boolean",
                label: "Use space",
                description: "",
                min: "",
                max: "",
                options: [],
                has_default: true,
                default: false,
            },
            {
                id: "digit_separators",
                group: "punctuator",
                path: "punctuator/digit_separators",
                type: "string",
                label: "Digit separators",
                description: "",
                min: "",
                max: "",
                options: [],
                has_default: true,
                default: ".:",
            },
            {
                id: "digit_separator_action",
                group: "punctuator",
                path: "punctuator/digit_separator_action",
                type: "enum",
                label: "Digit separator action",
                description: "",
                min: "",
                max: "",
                options: ["forward", "commit"],
                has_default: true,
                default: "forward",
            },
        ],
    }
}

SchemaSettingsRecognizerManifest() {
    return {
        title: "Settings",
        description: "",
        groups: [{ id: "recognizer", label: "Recognizer", description: "" }],
        fields: [
            {
                id: "use_space",
                group: "recognizer",
                path: "recognizer/use_space",
                type: "boolean",
                label: "Use space",
                description: "",
                min: "",
                max: "",
                options: [],
                has_default: true,
                default: false,
            },
            {
                id: "patterns",
                group: "recognizer",
                path: "recognizer/patterns",
                type: "recognizer_patterns",
                label: "Recognition patterns",
                description: "",
                min: "",
                max: "",
                options: [],
            },
        ],
    }
}

SchemaSettingsEditCue(ctrl) {
    static EM_GETCUEBANNER := 0x1502
    local buf := Buffer(256, 0)
    DllCall(
        "User32\SendMessageW",
        "Ptr",
        ctrl.Hwnd,
        "UInt",
        EM_GETCUEBANNER,
        "Ptr",
        buf.Ptr,
        "Ptr",
        buf.Size / 2,
        "Ptr"
    )
    return StrGet(buf, "UTF-16")
}

JoinSchemaSettingsCalls(calls) {
    local result := "", call
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

SchemaSettingsCallsHave(calls, expected) {
    local call
    for call in calls {
        if call = expected {
            return true
        }
    }
    return false
}

SchemaSettingsCallsContain(calls, prefix, expected) {
    local call
    for call in calls {
        if SubStr(call, 1, StrLen(prefix)) = prefix && InStr(call, expected) {
            return true
        }
    }
    return false
}

class RabbitSchemaSettingsModelProbe extends RabbitSchemaSettingsModel {
    __New(rime_api, levers_api, schema_id, manifest := 0) {
        super.__New(rime_api, levers_api, schema_id, manifest)
        this.ensure_count := 0
    }

    EnsureCustomFile() {
        this.ensure_count += 1
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

    config_test_get_bool(config, path, &value) {
        if !this.values.Has(path) || Type(this.values[path]) != "Integer"
            || this.values[path] != 0 && this.values[path] != 1 {
            return false
        }
        value := !!this.values[path]
        return true
    }

    config_test_get_string(config, path, &value) {
        if !this.values.Has(path) || Type(this.values[path]) != "String" {
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

    customize_bool(settings, path, value) {
        this.calls.Push("boolean:" . path . ":" . value)
        return true
    }

    customize_string(settings, path, value) {
        this.calls.Push("string:" . path . ":" . value)
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

class RabbitSchemaSettingsListRimeProbe {
    __New(values, patch_keys, calls) {
        this.values := values
        this.patch_keys := patch_keys
        this.calls := calls
    }

    schema_open(schema_id) {
        return "schema"
    }

    user_config_open(config_id) {
        return "user"
    }

    config_close(config) {
    }

    config_begin_map(config, path) {
        local items := [], key, value
        if Type(config) = "String" && config = "user" && path = "patch" {
            for key in this.patch_keys {
                items.Push({ key: key, path: "patch/" . key, value: "" })
            }
        } else if config is Map && config.Has("value") && path = "/" && config["value"] is Map {
            for key, value in config["value"] {
                items.Push({ key: key, path: key, value: value })
            }
        } else if Type(config) = "String" && config = "schema"
            && this.TryGetValue(config, path, &value) && value is Map {
            for key, value in value {
                items.Push({ key: key, path: path . "/" . key, value: value })
            }
        } else {
            return 0
        }
        return { items: items, index: 0, key: "", path: "" }
    }

    config_begin_list(config, path) {
        local index, items := [], prefix := Type(config) = "String" && config = "schema" ? path . "/" : "", value
        if !this.TryGetValue(config, path, &value) || !(value is Array) {
            return 0
        }
        for index, value in value {
            items.Push({ key: String(index - 1), path: prefix . (index - 1), value: value })
        }
        return { items: items, index: 0, key: "", path: "" }
    }

    config_next(iter) {
        local item
        iter.index += 1
        if iter.index > iter.items.Length {
            return false
        }
        item := iter.items[iter.index]
        iter.key := item.key
        iter.path := item.path
        return true
    }

    config_end(iter) {
    }

    config_get_item(config, path) {
        local value
        if !this.TryGetValue(config, path, &value) {
            return 0
        }
        return Map("value", value)
    }

    config_test_get_string(config, path, &value) {
        return this.TryGetScalar(config, path, "String", &value)
    }

    config_test_get_int(config, path, &value) {
        return this.TryGetScalar(config, path, "Integer", &value)
    }

    config_test_get_double(config, path, &value) {
        return this.TryGetScalar(config, path, "Float", &value)
    }

    config_test_get_bool(config, path, &value) {
        if !this.TryGetValue(config, path, &value) || Type(value) != "Integer"
            || value != 0 && value != 1 {
            return false
        }
        return true
    }

    config_load_string(value) {
        return Map("yaml", value)
    }

    TryGetScalar(config, path, expected_type, &value) {
        return this.TryGetValue(config, path, &value) && Type(value) = expected_type
    }

    TryGetValue(config, path, &value) {
        local base_path, base_value, index, remainder
        if config is Map && config.Has("value") {
            if path = "/" {
                value := config["value"]
                return true
            }
            if config["value"] is Map && config["value"].Has(path) {
                value := config["value"][path]
                return true
            }
            if config["value"] is Array && RegExMatch(path, "^\d+$") {
                index := Integer(path) + 1
                if index >= 1 && index <= config["value"].Length {
                    value := config["value"][index]
                    return true
                }
            }
            return false
        }
        if Type(config) != "String" || config != "schema" {
            return false
        }
        if this.values.Has(path) {
            value := this.values[path]
            return true
        }
        for base_path, base_value in this.values {
            if base_value is Map && SubStr(path, 1, StrLen(base_path) + 1) = base_path . "/" {
                remainder := SubStr(path, StrLen(base_path) + 2)
                if base_value.Has(remainder) {
                    value := base_value[remainder]
                    return true
                }
            }
            if !(base_value is Array) || SubStr(path, 1, StrLen(base_path) + 1) != base_path . "/" {
                continue
            }
            remainder := SubStr(path, StrLen(base_path) + 2)
            if RegExMatch(remainder, "^\d+$") {
                index := Integer(remainder) + 1
                if index >= 1 && index <= base_value.Length {
                    value := base_value[index]
                    return true
                }
            }
        }
        return false
    }
}

class RabbitSchemaSettingsListLeversProbe {
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

    customize_item(settings, path, value) {
        this.calls.Push(value ? "item:" . path . ":" . value["yaml"] : "reset:" . path)
        return true
    }

    customize_bool(settings, path, value) {
        this.calls.Push("boolean:" . path . ":" . value)
        return true
    }

    customize_int(settings, path, value) {
        this.calls.Push("integer:" . path . ":" . value)
        return true
    }

    customize_string(settings, path, value) {
        this.calls.Push("string:" . path . ":" . value)
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
