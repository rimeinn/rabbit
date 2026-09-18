/*
 * Copyright (c) 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitCommon.ahk

RunTest("misplaced configs receive timestamped backups", RabbitCommonMisplacedConfigBackupTest.Bind())
RunTest("misplaced config backups never overwrite", RabbitCommonMisplacedConfigCollisionTest.Bind())
RunTest("shared user directories retain their configs", RabbitCommonSharedUserDirectoryTest.Bind())

RabbitCommonMisplacedConfigBackupTest() {
    local root := RabbitCommonTestRoot("backup"), shared := root . "\shared", user := root . "\user"
    local timestamp := "20260918150000123", renamed
    try {
        DirCreate(shared)
        DirCreate(user)
        FileAppend("default", user . "\default.yaml", "UTF-8")
        FileAppend("rabbit", user . "\rabbit.yaml", "UTF-8")
        renamed := RabbitCleanMisplacedConfigs(shared, user, timestamp)
        AssertEqual(2, renamed.Length, "The cleanup did not report both misplaced configs.")
        AssertTrue(!FileExist(user . "\default.yaml") && !FileExist(user . "\rabbit.yaml"),
            "A misplaced config remained in the user-data directory.")
        AssertEqual("default", FileRead(user . "\default.yaml." . timestamp, "UTF-8"),
            "The default config backup did not preserve its contents.")
        AssertEqual("rabbit", FileRead(user . "\rabbit.yaml." . timestamp, "UTF-8"),
            "The Rabbit config backup did not preserve its contents.")
    } finally {
        RabbitCommonDeleteTestRoot(root)
    }
}

RabbitCommonMisplacedConfigCollisionTest() {
    local root := RabbitCommonTestRoot("collision"), shared := root . "\shared", user := root . "\user"
    local timestamp := "20260918150000123", existing, renamed
    try {
        DirCreate(shared)
        DirCreate(user)
        existing := user . "\default.yaml." . timestamp
        FileAppend("previous", existing, "UTF-8")
        FileAppend("current", user . "\default.yaml", "UTF-8")
        renamed := RabbitCleanMisplacedConfigs(shared, user, timestamp)
        AssertEqual("previous", FileRead(existing, "UTF-8"),
            "A timestamp collision overwrote an earlier config backup.")
        AssertEqual(1, renamed.Length, "The collision cleanup reported the wrong number of backups.")
        AssertEqual("current", FileRead(user . "\default.yaml." . timestamp . "001", "UTF-8"),
            "A timestamp collision did not create a unique config backup.")
    } finally {
        RabbitCommonDeleteTestRoot(root)
    }
}

RabbitCommonSharedUserDirectoryTest() {
    local root := RabbitCommonTestRoot("same-directory"), config := root . "\default.yaml", renamed
    try {
        DirCreate(root)
        FileAppend("keep", config, "UTF-8")
        renamed := RabbitCleanMisplacedConfigs(root, StrUpper(root), "20260918150000123")
        AssertEqual(0, renamed.Length, "Equal shared/user paths were treated as separate directories.")
        AssertEqual("keep", FileRead(config, "UTF-8"), "A shared config was unexpectedly renamed.")
    } finally {
        RabbitCommonDeleteTestRoot(root)
    }
}

RabbitCommonTestRoot(name) {
    return A_Temp . "\RabbitCommonTest-" . name . "-" . DllCall("GetCurrentProcessId") . "-" . A_TickCount
}

RabbitCommonDeleteTestRoot(root) {
    if DirExist(root) {
        DirDelete(root, true)
    }
}
