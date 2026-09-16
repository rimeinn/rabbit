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
 */

#Include RabbitCommandLine.ahk
#Include RabbitCommon.ahk
#Include RabbitDeployerContext.ahk
#Include RabbitMaintenanceWorkflow.ahk

class RabbitDeployerWorkerApplication {
    __New(rime_api) {
        this.context := RabbitDeployerContext(rime_api)
        this.workflow := 0
        this.shutting_down := false
    }

    Run(args) {
        local options, result := 1
        try {
            options := RabbitWorkerOptions.Parse(args)
            this.context.Initialize()
            this.workflow := this.CreateWorkflow()
            switch options.operation {
                case "deploy":
                    result := this.workflow.Deploy(options.plan)
                case "sync":
                    result := this.workflow.SyncUserData()
                case "dictionary":
                    result := this.workflow.RunDictionary(
                        options.dictionary_action,
                        options.dictionary_name,
                        options.path
                    )
            }
        } catch as err {
            RabbitError(
                err.Message . (err.Stack ? "`r`n" . err.Stack : ""),
                Format("RabbitDeployerWorkerApplication.ahk:{}", A_LineNumber)
            )
            result := 1
        } finally {
            try {
                this.Shutdown()
            } catch as err {
                RabbitError(
                    err.Message . (err.Stack ? "`r`n" . err.Stack : ""),
                    Format("RabbitDeployerWorkerApplication.ahk:{}", A_LineNumber)
                )
                result := 1
            }
        }
        this.ExitApplication(result)
        return result
    }

    ExitApplication(code) {
        ExitApp(code)
    }

    CreateWorkflow() {
        return RabbitMaintenanceWorkflow(this.context.rime, false)
    }

    Shutdown() {
        if this.shutting_down {
            return
        }
        this.shutting_down := true
        this.context.Dispose()
    }
}
