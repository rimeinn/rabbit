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
#Include ..\..\Lib\RabbitCommandLine.ahk

RunTest("Rabbit named command line options", TestRabbitCommandLineOptions.Bind())
RunTest("deployer named command line options", TestDeployerCommandLineOptions.Bind())
RunTest("command line rejects invalid forms", TestCommandLineRejectsInvalidForms.Bind())
RunTest("keyboard layout handle round trip", TestKeyboardLayoutHandleRoundTrip.Bind())
RunTest("Windows command line quoting", TestWindowsCommandLineQuoting.Bind())

TestRabbitCommandLineOptions() {
    local defaults := RabbitApplicationOptions.Parse([])
    AssertEqual(RABBIT_PARTIAL_MAINTENANCE, defaults.maintenance, "Rabbit changed its default maintenance mode.")
    AssertEqual(0, defaults.keyboard_layout, "Rabbit invented a default keyboard layout argument.")

    local options := RabbitApplicationOptions.Parse([
        "--maintenance",
        "none",
        "--keyboard-layout",
        "0x0409",
    ])
    AssertEqual(RABBIT_NO_MAINTENANCE, options.maintenance, "Rabbit parsed the wrong maintenance mode.")
    AssertEqual(0x0409, options.keyboard_layout, "Rabbit parsed the wrong keyboard layout.")
}

TestDeployerCommandLineOptions() {
    local defaults := RabbitDeployerOptions.Parse([])
    AssertEqual("settings", defaults.command, "The deployer did not default to unified settings.")
    AssertEqual("", defaults.target, "The deployer mapped its default command to a named page.")

    local options := RabbitDeployerOptions.Parse([
        "settings",
        "input-schemes",
        "--install",
        "--return-to-rabbit",
        "--keyboard-layout",
        "0x0409",
    ])
    AssertEqual("settings", options.command, "The deployer parsed the wrong command.")
    AssertEqual("input-schemes", options.target, "The deployer parsed the wrong page.")
    AssertTrue(options.installing, "The deployer omitted install mode.")
    AssertTrue(options.return_to_rabbit, "The deployer omitted its return handoff.")
    AssertEqual(0x0409, options.keyboard_layout, "The deployer parsed the wrong keyboard layout.")

    options := RabbitDeployerOptions.Parse(["legacy-settings", "dictionary"])
    AssertEqual("dictionary", options.target, "The deployer rejected the legacy dictionary subcommand.")
}

TestCommandLineRejectsInvalidForms() {
    for args in [
        ["--maintenance", "fast"],
        ["--maintenance", "none", "--maintenance", "full"],
        ["--keyboard-layout"],
        ["obsolete"],
    ] {
        AssertThrows(
            RabbitApplicationOptions.Parse.Bind(args),
            "Rabbit accepted an invalid command line."
        )
    }

    for args in [
        ["configure"],
        ["dict"],
        ["settings", "input-schemes", "extra"],
        ["settings", "behavior", "--install"],
        ["legacy-settings", "dictionary", "--install"],
        ["deploy", "extra"],
        ["sync", "--return-to-rabbit"],
        ["sync", "--keyboard-layout", "0x0409", "--keyboard-layout", "0x0411"],
    ] {
        AssertThrows(
            RabbitDeployerOptions.Parse.Bind(args),
            "RabbitDeployer accepted an invalid command line."
        )
    }
}

TestKeyboardLayoutHandleRoundTrip() {
    local sign_extended_layout := 0xE0200804 - 0x100000000
    local formatted := RabbitFormatKeyboardLayout(sign_extended_layout)
    AssertEqual(
        "0xE0200804",
        formatted,
        "A sign-extended keyboard layout handle was not normalized for the command line."
    )

    local options := RabbitApplicationOptions.Parse([
        "--keyboard-layout",
        formatted,
    ])
    AssertEqual(
        0xE0200804,
        options.keyboard_layout,
        "Rabbit did not preserve a keyboard layout with the high bit set."
    )
}

TestWindowsCommandLineQuoting() {
    AssertEqual('"plain"', RabbitQuoteCommandLineArgument("plain"), "A plain argument was quoted incorrectly.")
    AssertEqual('"two words"', RabbitQuoteCommandLineArgument("two words"), "Whitespace was quoted incorrectly.")
    AssertEqual('""', RabbitQuoteCommandLineArgument(""), "An empty argument was quoted incorrectly.")
    AssertEqual(
        '"C:\path with space\\"',
        RabbitQuoteCommandLineArgument("C:\path with space\"),
        "A trailing backslash was not doubled before the closing quote."
    )
    AssertEqual(
        '"say \"hello\""',
        RabbitQuoteCommandLineArgument('say "hello"'),
        "Embedded quotes were not escaped for CommandLineToArgvW."
    )
}
