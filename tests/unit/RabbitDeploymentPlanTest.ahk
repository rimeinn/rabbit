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

#Include ..\support\RabbitTestCommon.ahk
#Include ..\..\Lib\RabbitDeploymentPlan.ahk

RunTest("deployment plan stable serialization", TestDeploymentPlanSerialization.Bind())
RunTest("deployment plan serialization round trip", TestDeploymentPlanRoundTrip.Bind())
RunTest("deployment plan rejects invalid serialization", TestDeploymentPlanRejectsInvalidSerialization.Bind())

TestDeploymentPlanSerialization() {
    local plan := RabbitDeploymentPlan.SchemaConfig("zeta")
        .Merge(RabbitDeploymentPlan.FullRedeploy())
        .Merge(RabbitDeploymentPlan.DefaultConfig())
        .Merge(RabbitDeploymentPlan.SchemaConfig("alpha"))
    AssertEqual(
        "v1|rabbit|default|workspace|schema:alpha|schema:zeta",
        plan.Serialize(),
        "The deployment plan serialization changed with insertion order."
    )
    AssertEqual("v1", RabbitDeploymentPlan().Serialize(), "The empty deployment plan was not stable.")
}

TestDeploymentPlanRoundTrip() {
    local serialized := "v1|rabbit|default|workspace|schema:alpha|schema:demo.schema"
    local plan := RabbitDeploymentPlan.Parse(serialized)
    AssertTrue(plan.rabbit_config_changed, "The Rabbit config flag was lost.")
    AssertTrue(plan.default_config_changed, "The default config flag was lost.")
    AssertTrue(plan.full_workspace_required, "The workspace flag was lost.")
    AssertTrue(plan.schema_config_ids.Has("alpha"), "A schema ID was lost.")
    AssertTrue(plan.schema_config_ids.Has("demo.schema"), "A dotted schema ID was lost.")
    AssertEqual(serialized, plan.Serialize(), "The deployment plan did not round trip.")
}

TestDeploymentPlanRejectsInvalidSerialization() {
    AssertThrows(
        RabbitDeploymentPlan.Parse.Bind("v2|rabbit"),
        "The deployment plan accepted an unknown version."
    )
    AssertThrows(
        RabbitDeploymentPlan.Parse.Bind("v1|unknown"),
        "The deployment plan accepted an unknown entry."
    )
    AssertThrows(
        RabbitDeploymentPlan.Parse.Bind("v1|schema:..\\escape"),
        "The deployment plan accepted an invalid schema ID."
    )
}
