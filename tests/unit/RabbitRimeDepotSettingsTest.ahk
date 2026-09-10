/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitRimeDepotSettings.ahk

try {
    RabbitRimeDepotSettingsTestMain()
} catch as err {
    TestReportFailure("unhandled test error", err)
    ExitApp(1)
}

RabbitRimeDepotSettingsTestMain() {
    RunTest("RimeDepot settings maps Rabbit values", RabbitRimeDepotSettingsMapTest.Bind())
    RunTest("RimeDepot settings reads merged config and closes it", RabbitRimeDepotSettingsLoadTest.Bind())
    RunTest("RimeDepot settings saves through Levers", RabbitRimeDepotSettingsSaveTest.Bind())
    ExitApp(0)
}

RabbitRimeDepotSettingsMapTest() {
    local settings := RabbitRimeDepotSettings(Map(
        "RppiIndexUrl", "https://example.invalid/rppi.json",
        "Proxy", " http://proxy.invalid:8080 ",
        "UseGit", "yes",
        "GitPath", " C:\\Tools\\git.exe "
    ))
    local options := settings.ToServiceOptions("C:\\Rime\\depot", "C:\\Rime")
    AssertEqual("https://example.invalid/rppi.json", settings.rppi_url,
        "The settings adapter did not accept the service URL alias.")
    AssertEqual("http://proxy.invalid:8080", settings.proxy,
        "The settings adapter did not trim the proxy value.")
    AssertTrue(settings.use_git, "The settings adapter did not parse the Git flag.")
    AssertEqual("C:\\Tools\\git.exe", settings.git_path,
        "The settings adapter did not trim the Git path.")
    AssertEqual("C:\\Rime\\depot", options["CachePath"],
        "The service options changed the Rabbit-owned cache path.")
    AssertEqual("C:\\Rime", options["RimeDirectory"],
        "The service options changed the Rabbit-owned Rime directory.")
    AssertEqual("https://example.invalid/rppi.json", options["RppiIndexUrl"],
        "The service options lost the RPPI URL.")
    AssertTrue(options["UseGit"], "The service options lost the Git flag.")
}

RabbitRimeDepotSettingsLoadTest() {
    local calls := [], rime := RabbitRimeDepotSettingsRimeProbe(calls)
    local settings := RabbitRimeDepotSettings.Load(rime)
    AssertEqual("https://custom.invalid/index.json", settings.rppi_url,
        "Merged config did not override the default RPPI URL.")
    AssertEqual("http://proxy.invalid:3128", settings.proxy,
        "Merged config did not provide the proxy.")
    AssertTrue(settings.use_git, "Merged config did not provide the Git flag.")
    AssertEqual("C:\\Git\\git.exe", settings.git_path,
        "Merged config did not provide the Git path.")
    AssertEqual("open:rabbit,get:rime_depot/rppi_url,get:rime_depot/proxy," .
        "get_bool:rime_depot/use_git,get:rime_depot/git_path,close:merged",
        RabbitRimeDepotSettingsJoinCalls(calls),
        "The settings adapter did not close the merged config immediately.")
}

RabbitRimeDepotSettingsSaveTest() {
    local calls := [], rime := {}, levers := RabbitRimeDepotSettingsLeversProbe(calls)
    local values := Map(
        "rppi_url", "https://saved.invalid/index.json",
        "proxy", "http://saved.invalid:8080",
        "use_git", true,
        "git_path", "C:\\Saved\\git.exe"
    )
    AssertTrue(RabbitRimeDepotSettings.Save(rime, values, levers),
        "The settings adapter rejected a successful Levers save.")
    AssertEqual(
        "init:rabbit:Rabbit.ControlPanel,load,customize_string:rime_depot/rppi_url=" .
            "https://saved.invalid/index.json,customize_string:rime_depot/proxy=http://saved.invalid:8080," .
            "customize_bool:rime_depot/use_git=1,customize_string:rime_depot/git_path=C:\\Saved\\git.exe," .
            "save,destroy",
        RabbitRimeDepotSettingsJoinCalls(calls),
        "The settings adapter did not write all four Rabbit patch keys.")
}

RabbitRimeDepotSettingsJoinCalls(calls) {
    local result := "", call
    for call in calls {
        result .= (result = "" ? "" : ",") . call
    }
    return result
}

class RabbitRimeDepotSettingsRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    config_open(name) {
        this.calls.Push("open:" . name)
        return "merged"
    }

    config_test_get_string(config, key, &value) {
        this.calls.Push("get:" . key)
        switch key {
            case "rime_depot/rppi_url":
                value := "https://custom.invalid/index.json"
            case "rime_depot/proxy":
                value := "http://proxy.invalid:3128"
            case "rime_depot/git_path":
                value := "C:\\Git\\git.exe"
            default:
                return false
        }
        return true
    }

    config_test_get_bool(config, key, &value) {
        this.calls.Push("get_bool:" . key)
        value := key = "rime_depot/use_git"
        return true
    }

    config_close(config) {
        this.calls.Push("close:" . config)
    }
}

class RabbitRimeDepotSettingsLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    custom_settings_init(config_id, generator_id) {
        this.calls.Push("init:" . config_id . ":" . generator_id)
        return "custom"
    }

    load_settings(settings) {
        this.calls.Push("load")
        return true
    }

    customize_string(settings, key, value) {
        this.calls.Push("customize_string:" . key . "=" . value)
        return true
    }

    customize_bool(settings, key, value) {
        this.calls.Push("customize_bool:" . key . "=" . value)
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
