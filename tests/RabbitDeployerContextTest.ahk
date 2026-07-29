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

#Include <RabbitDeployerContext>
#Include <RabbitUIStyleSettings>

RunTest("deployer context lifecycle", TestDeployerContextLifecycle.Bind())
RunTest("partial deployer context disposal", TestPartialDeployerContextDisposal.Bind())
RunTest("UI style settings ownership", TestUIStyleSettingsOwnership.Bind())
RunTest("old Windows preview stays lazy", TestOldWindowsPreviewStaysLazy.Bind())
RunTest("supported Windows preview creation", TestSupportedWindowsPreviewCreation.Bind())

TestDeployerContextLifecycle() {
    local calls := []
    local context := RabbitDeployerContext(RabbitDeployerRimeProbe(calls))

    context.Initialize()
    context.Initialize()
    context.Dispose()
    context.Dispose()

    AssertEqual(
        "setup,deployer_initialize,finalize",
        JoinDeployerCalls(calls),
        "The deployer context did not initialize and finalize Rime exactly once."
    )
}

TestPartialDeployerContextDisposal() {
    local calls := []
    local context := RabbitDeployerContext(RabbitDeployerRimeProbe(calls))

    context.Dispose()

    AssertEqual(
        "",
        JoinDeployerCalls(calls),
        "A partial deployer context finalized Rime before initialization."
    )
}

TestUIStyleSettingsOwnership() {
    local calls := []
    local levers := RabbitUIStyleLeversProbe(calls)
    local settings := UIStyleSettings(RabbitDeployerRimeProbe(calls), levers)

    settings.Dispose()
    settings.Dispose()

    AssertEqual(
        "settings_init,settings_destroy",
        JoinDeployerCalls(calls),
        "UI style settings did not release their custom settings exactly once."
    )
}

TestOldWindowsPreviewStaysLazy() {
    local calls := []
    local dialog := UIStyleSettingsDialog(
        RabbitUIStyleDialogSettingsProbe(),
        true,
        RabbitCreatePreviewProbe.Bind(calls)
    )

    try {
        AssertEqual(
            "",
            JoinDeployerCalls(calls),
            "The old-Windows style page constructed a preview."
        )
        AssertEqual(0, dialog.candidate_box, "The old-Windows style page retained a preview.")
    } finally {
        dialog.Dispose()
    }
}

TestSupportedWindowsPreviewCreation() {
    local calls := []
    local dialog := UIStyleSettingsDialog(
        RabbitUIStyleDialogSettingsProbe(),
        false,
        RabbitCreatePreviewProbe.Bind(calls)
    )

    try {
        AssertEqual(
            "preview",
            JoinDeployerCalls(calls),
            "The supported style page did not construct exactly one preview."
        )
    } finally {
        dialog.Dispose()
    }
    AssertEqual(
        "preview,preview_dispose",
        JoinDeployerCalls(calls),
        "The style page did not dispose its preview."
    )
}

RabbitCreatePreviewProbe(calls, ctrl) {
    calls.Push("preview")
    return RabbitUIStylePreviewProbe(calls)
}

JoinDeployerCalls(calls) {
    local result := ""
    for call in calls {
        result .= (result ? "," : "") . call
    }
    return result
}

class RabbitDeployerRimeProbe {
    __New(calls) {
        this.calls := calls
    }

    setup(traits) {
        this.calls.Push("setup")
    }

    deployer_initialize(traits) {
        this.calls.Push("deployer_initialize")
    }

    finalize() {
        this.calls.Push("finalize")
    }
}

class RabbitUIStyleLeversProbe {
    __New(calls) {
        this.calls := calls
    }

    custom_settings_init(config_id, generator_id) {
        this.calls.Push("settings_init")
        return 42
    }

    custom_settings_destroy(settings) {
        this.calls.Push("settings_destroy")
    }
}

class RabbitUIStyleDialogSettingsProbe {
    GetActiveColorScheme() {
        return ""
    }

    GetPresetColorSchemes() {
        return []
    }
}

class RabbitUIStylePreviewProbe {
    __New(calls) {
        this.calls := calls
    }

    Dispose() {
        this.calls.Push("preview_dispose")
    }
}
