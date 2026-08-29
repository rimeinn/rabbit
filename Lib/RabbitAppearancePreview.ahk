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

#Include RabbitCandidateBox.ahk
#Include RabbitPopupPlacement.ahk

class RabbitAppearancePreview {
    static REFRESH_INTERVAL := 100

    __New(owner, candidate_box_factory := CandidateBox) {
        this.owner := owner
        this.candidate_box_factory := candidate_box_factory
        this.candidate_box := 0
        this.caret_gui := 0
        this.style := 0
        this.enabled := false
        this.visible := false
        this.disposed := false
        this.owner_bounds_key := ""
        this.refresh_callback := this.Refresh.Bind(this)
    }

    __Delete() {
        this.Dispose()
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        SetTimer(this.refresh_callback, 0)
        this.HideWindows()
        this.candidate_box := 0
        if this.caret_gui {
            this.caret_gui.Destroy()
            this.caret_gui := 0
        }
        this.owner := 0
    }

    Render(style) {
        this.AssertNotDisposed()
        this.style := style
        this.enabled := true
        if !this.IsOwnerReady() {
            return false
        }
        this.ShowPreview()
        SetTimer(this.refresh_callback, RabbitAppearancePreview.REFRESH_INTERVAL)
        return true
    }

    Hide() {
        if this.disposed {
            return
        }
        this.enabled := false
        SetTimer(this.refresh_callback, 0)
        this.HideWindows()
    }

    HideWindows() {
        if this.candidate_box {
            this.candidate_box.Hide()
        }
        if this.caret_gui {
            this.caret_gui.Hide()
        }
        this.visible := false
    }

    Refresh() {
        try {
            if this.disposed || !this.enabled || !this.style {
                return
            }
            if !this.IsOwnerReady() || !WinActive("ahk_id " . this.owner.Hwnd) {
                this.HideWindows()
                return
            }
            local bounds := this.GetOwnerBounds()
            local bounds_key := this.GetBoundsKey(bounds)
            if !this.visible || bounds_key != this.owner_bounds_key {
                this.ShowPreview(bounds)
            }
        } catch as err {
            this.HideWindows()
            if this.owner && HasProp(this.owner, "appearance_status") {
                this.owner.appearance_status.Value := "无法显示预览：" . err.Message
            }
        }
    }

    ShowPreview(bounds := 0) {
        local box_height, box_width, candidate_position, caret_height, caret_width
        local client_top, content_bottom, group_height, group_width, max_width, monitor_info, position
        local presentation := RabbitAppearancePreview.CreatePresentation(this.style)
        if !bounds {
            bounds := this.GetOwnerBounds()
        }
        if !bounds {
            this.HideWindows()
            return false
        }
        monitor_info := RabbitPopupPlacement.GetWorkAreaAt(
            (bounds.left + bounds.right) / 2,
            (bounds.top + bounds.bottom) / 2
        )
        max_width := monitor_info ? monitor_info.work.right - monitor_info.work.left : 0
        this.EnsureCandidateBox()
        if this.style.floating_preedit {
            caret_width := Max(1, Round(2 * this.candidate_box.dpiScale))
            caret_height := Max(1, Round(24 * this.candidate_box.dpiScale))
            this.candidate_box.BuildFloatingPresentation(
                presentation,
                0,
                0,
                caret_width,
                caret_height,
                &box_width,
                &box_height,
                max_width
            )
            group_width := caret_width + Max(box_width, this.candidate_box.floating_preedit.box_width)
            group_height := Max(caret_height, this.candidate_box.floating_preedit.box_height)
                + RabbitPopupPlacement.GAP + box_height
        } else {
            this.candidate_box.BuildPresentation(presentation, &box_width, &box_height, max_width)
            group_width := box_width
            group_height := box_height
        }
        position := RabbitPopupPlacement.PlaceOutsideRect(
            bounds,
            group_width,
            group_height,
            monitor_info
        )
        client_top := this.GetOwnerClientTop()
        if IsNumber(client_top) {
            position := RabbitAppearancePreview.AlignBesidePositionToClient(
                position,
                client_top,
                group_width,
                group_height,
                monitor_info
            )
        }
        if this.style.floating_preedit {
            this.candidate_box.BuildFloatingPresentation(
                presentation,
                position.x,
                position.y,
                caret_width,
                caret_height,
                &box_width,
                &box_height,
                max_width
            )
            content_bottom := this.candidate_box.GetPopupAnchorBottom(position.y + caret_height)
            candidate_position := RabbitPopupPlacement.PlaceBelowCaret(
                position.x,
                position.y,
                caret_width,
                caret_height,
                box_width,
                box_height,
                monitor_info,
                content_bottom
            )
            this.ShowCaret(position.x, position.y, caret_width, caret_height)
            this.candidate_box.SetFlowAnimationAnchor(candidate_position.above)
            this.candidate_box.Show(candidate_position.x, candidate_position.y)
        } else {
            if this.caret_gui {
                this.caret_gui.Hide()
            }
            this.candidate_box.SetFlowAnimationAnchor(HasProp(position, "above") && position.above)
            this.candidate_box.Show(position.x, position.y)
        }
        this.owner_bounds_key := this.GetBoundsKey(bounds)
        this.visible := true
        return true
    }

    EnsureCandidateBox() {
        local factory
        if this.candidate_box {
            this.candidate_box.UpdateStyle(this.style)
            return
        }
        factory := this.candidate_box_factory
        this.candidate_box := factory(this.style)
    }

    ShowCaret(x, y, width, height) {
        if !this.caret_gui {
            this.caret_gui := Gui("-Caption -DPIScale +AlwaysOnTop +ToolWindow +E0x08000000")
            this.caret_gui.BackColor := "606060"
        }
        this.caret_gui.Show(Format("NA x{} y{} w{} h{}", x, y, width, height))
    }

    IsOwnerReady() {
        return this.owner
            && this.owner.Hwnd
            && DllCall("IsWindowVisible", "Ptr", this.owner.Hwnd, "Int")
            && !DllCall("IsIconic", "Ptr", this.owner.Hwnd, "Int")
    }

    GetOwnerBounds() {
        return this.owner ? RabbitPopupPlacement.GetVisibleWindowBounds(this.owner.Hwnd) : 0
    }

    GetOwnerClientTop() {
        local point := Buffer(8, 0)
        if !this.owner || !this.owner.Hwnd
            || !DllCall("ClientToScreen", "Ptr", this.owner.Hwnd, "Ptr", point, "Int") {
            return ""
        }
        return NumGet(point, 4, "Int")
    }

    GetBoundsKey(bounds) {
        return bounds
            ? Format("{}:{}:{}:{}", bounds.left, bounds.top, bounds.right, bounds.bottom)
            : ""
    }

    AssertNotDisposed() {
        if this.disposed {
            throw Error("Appearance preview has been disposed.")
        }
    }

    static CreatePresentation(style) {
        return style.layout_type = "flow"
            ? this.CreateFlowPresentation(style.label_format)
            : this.CreateStandardPresentation(style.label_format)
    }

    static AlignBesidePositionToClient(position, client_top, width, height, monitor_info) {
        local aligned
        if !HasProp(position, "side") || position.side != "right" && position.side != "left" {
            return position
        }
        aligned := RabbitPopupPlacement.ClampToWorkArea(
            position.x,
            client_top,
            width,
            height,
            monitor_info
        )
        aligned.side := position.side
        aligned.above := aligned.y < client_top
        return aligned
    }

    static CreateStandardPresentation(label_format) {
        local texts := ["输入", "书", "数", "树", "输"]
        local comments := ["shū rù", "shū", "shǔ", "shù", "shū"]
        local candidates := []
        for index, text in texts {
            candidates.Push({
                label: this.FormatLabel(label_format, index),
                text: text,
                comment: comments[index],
                highlighted: index = 1,
            })
        }
        return {
            preedit: this.CreatePreedit("玉兔毫", "shu ru", "fa", "after_selection", 0),
            highlighted_index: 1,
            candidates: candidates,
        }
    }

    static CreateFlowPresentation(label_format) {
        local pages := [
            ["输入法", "输入", "书", "数", "树"],
            ["输", "属", "熟", "术", "舒"],
            ["鼠", "叔", "淑", "束", "疏"],
            ["署", "述", "竖", "俞", "蜀"],
            ["梳", "孰", "殊", "姝", "恕"],
        ]
        local candidates := []
        for page_index, page in pages {
            for index, text in page {
                local current := page_index = 2
                candidates.Push({
                    label: current ? this.FormatLabel(label_format, index) : "",
                    text: text,
                    comment: "",
                    highlighted: current && index = 1,
                    preview: !current,
                })
            }
        }
        return {
            preedit: this.CreatePreedit("玉兔毫", "shu", "rufa", "after_selection", 4),
            highlighted_index: 6,
            candidates: candidates,
            flow_page_size: 5,
        }
    }

    static CreatePreedit(before, selected, after, cursor_segment, cursor_offset) {
        return {
            before_selection: before,
            selected: selected,
            after_selection: after,
            cursor: {
                text: "‸",
                segment: cursor_segment,
                offset: cursor_offset,
            },
        }
    }

    static FormatLabel(label_format, index) {
        try {
            return Format(label_format, index . "")
        } catch {
            return index . ". "
        }
    }
}
