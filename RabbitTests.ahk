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

#Requires AutoHotkey v2.0
#SingleInstance Off

#Include <RabbitCandidateBoxFactory>
#Include <RabbitCandidatePresentation>
#Include <RabbitDeployerApplication>
#Include <RabbitShutdown>

#Include tests\RabbitCandidatePresentationTest.ahk
#Include tests\RabbitCandidateBoxTest.ahk
#Include tests\RabbitUIStyleSnapshotTest.ahk
#Include tests\RabbitConfigSnapshotTest.ahk
#Include tests\RabbitAppContextTest.ahk
#Include tests\RabbitApplicationTest.ahk
#Include tests\RabbitInputControllerTest.ahk
#Include tests\RabbitShutdownTest.ahk
#Include tests\RabbitDeployerContextTest.ahk
#Include tests\RabbitDeployerWorkflowTest.ahk

ExitApp()
