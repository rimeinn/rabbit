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

#Include RabbitDialogPlacement.ahk
#Include RabbitSchemaSettingsModel.ahk
#Include RabbitWindowTheme.ahk

#Include RabbitI18n.ahk

class RabbitSchemaSettingsDialog extends Gui {
    static CONTENT_SCROLL_LINE := 32
    static MAX_DIALOG_HEIGHT := 720
    static MIN_DIALOG_HEIGHT := 360
    static WM_VSCROLL := 0x0115
    static WM_MOUSEWHEEL := 0x020A
    static SB_VERT := 1
    static SB_LINEUP := 0
    static SB_LINEDOWN := 1
    static SB_PAGEUP := 2
    static SB_PAGEDOWN := 3
    static SB_THUMBPOSITION := 4
    static SB_THUMBTRACK := 5
    static SB_TOP := 6
    static SB_BOTTOM := 7
    static SB_ENDSCROLL := 8
    static SIF_RANGE := 0x0001
    static SIF_PAGE := 0x0002
    static SIF_POS := 0x0004
    static SIF_TRACKPOS := 0x0010
    static SW_SCROLLCHILDREN := 0x0001
    static SW_INVALIDATE := 0x0002
    static SW_ERASE := 0x0004

    __New(
        owner,
        model,
        schema_name := "",
        dark_mode_reader := RabbitIsUserDarkMode,
        theme_factory := RabbitWindowThemeController
    ) {
        local groups, labels := [], initial_dark_mode := false, maximum_dialog_height
        local content_x, content_width, content_y := 18, header_height := 0
        local status_y, buttons_y, max_content_height, title := model.manifest.title
        if HasMethod(theme_factory, "Prepare") {
            initial_dark_mode := !!theme_factory.Prepare()
        }
        if schema_name {
            title .= " - " . schema_name
        }
        groups := model.manifest.groups
        if !(groups is Array) || !groups.Length {
            throw Error(RabbitI18n.Text("models.schema_settings_manifest_invalid", Map(
                "file", model.manifest.file_path
            )))
        }
        super.__New("+Owner" . owner.Hwnd . " -MinimizeBox -MaximizeBox -Resize", title, this)
        this.owner_window := owner
        this.model := model
        this.groups := groups
        this.theme_factory := theme_factory
        this.dark_mode_reader := dark_mode_reader
        this.result := 0
        this.disposed := false
        this.visible := false
        this.current_group_index := 1
        this.group_list := 0
        this.content_anchor := 0
        this.field_controls := Map()
        this.content_control_hwnds := Map()
        this.draft_values := Map()
        this.outer_muted_controls := []
        this.content_muted_controls := []
        this.content_gui := 0
        this.content_window_theme := 0
        this.content_scroll_y := 0
        this.content_scroll_max := 0
        this.content_virtual_height := 0
        this.content_scroll_callback := this.OnContentVScroll.Bind(this)
        this.content_wheel_callback := this.OnContentMouseWheel.Bind(this)
        for field_id, value in model.values {
            this.draft_values[field_id] := value
        }
        this.group_navigation_visible := groups.Length > 1
        this.dialog_width := this.group_navigation_visible ? 700 : 560
        content_x := this.group_navigation_visible ? 204 : 20
        content_width := this.dialog_width - content_x - 20
        this.content_x := content_x
        this.content_width := content_width
        this.MarginX := 20
        this.MarginY := 18
        if initial_dark_mode {
            this.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )
        if model.manifest.description {
            this.AddOuterMutedText("x20 y" . content_y . " w" . (this.dialog_width - 40) . " h34",
                model.manifest.description)
            header_height := 46
        }
        this.content_y := content_y + header_height
        maximum_dialog_height := this.CalculateMaximumDialogHeight()
        max_content_height := maximum_dialog_height - this.content_y - 92
        this.content_height := this.CalculateContentHeight(Max(180, max_content_height))
        status_y := this.content_y + this.content_height + 8
        buttons_y := status_y + 30
        this.dialog_height := buttons_y + 50
        if this.group_navigation_visible {
            for group in groups {
                labels.Push(group.label)
            }
            this.group_list := this.AddListBox(
                "x20 y" . this.content_y . " w164 h" . this.content_height,
                labels
            )
            this.group_list.Choose(1)
            this.group_list.OnEvent("Change", (*) => this.OnGroupChanged())
        }
        this.content_anchor := this.AddText(
            "x" . this.content_x . " y" . this.content_y . " w1 h1 Hidden",
            ""
        )
        this.status := this.AddText("x20 y" . status_y . " w" . (this.dialog_width - 40) . " h24 cRed", "")
        this.save_button := this.AddButton(
            "x" . (this.dialog_width - 188) . " y" . buttons_y . " w80 h32 Default +0x2000",
            RabbitI18n.Text("common.ok")
        )
        this.save_button.OnEvent("Click", (*) => this.SaveSettings())
        this.cancel_button := this.AddButton(
            "x" . (this.dialog_width - 100) . " y" . buttons_y . " w80 h32 +0x2000",
            RabbitI18n.Text("common.cancel")
        )
        this.cancel_button.OnEvent("Click", (*) => this.Dispose())
        this.OnEvent("Close", (*) => this.Dispose())
        this.OnEvent("Escape", (*) => this.Dispose())

        this.window_theme := theme_factory(this, dark_mode_reader)
        this.window_theme.RegisterError(this.status)
        if this.group_list {
            this.window_theme.RegisterSurface(this.group_list)
        }
        if this.outer_muted_controls.Length {
            this.window_theme.RegisterMuted(this.outer_muted_controls*)
        }
        this.window_theme.Register()
        this.CreateContentPanel()
    }

    CalculateMaximumDialogHeight() {
        local monitor, monitor_info, work_height := RabbitSchemaSettingsDialog.MAX_DIALOG_HEIGHT
        monitor := MonitorManage.MonitorFromWindow(this.owner_window.Hwnd, MONITOR_DEFAULTTONEAREST)
        if monitor && (monitor_info := MonitorManage.GetMonitorInfo(monitor)) {
            work_height := Floor(monitor_info.work.height() * 0.8)
        }
        return Max(
            RabbitSchemaSettingsDialog.MIN_DIALOG_HEIGHT,
            Min(RabbitSchemaSettingsDialog.MAX_DIALOG_HEIGHT, work_height)
        )
    }

    CalculateContentHeight(maximum_height) {
        local field, group, group_height, height := 0
        for group in this.groups {
            group_height := group.description ? 40 : 12
            for field in this.model.manifest.fields {
                if field.group != group.id {
                    continue
                }
                group_height += field.type = "boolean" ? 28 : 30
                if field.description {
                    group_height += 34
                }
                group_height += 6
            }
            height := Max(height, group_height + 8)
        }
        return Min(maximum_height, Max(180, height))
    }

    AddOuterMutedText(options, value) {
        local control := this.AddText(options, value)
        this.outer_muted_controls.Push(control)
        return control
    }

    OnGroupChanged() {
        return this.SelectGroup(this.group_list.Value)
    }

    SelectGroup(index) {
        if index < 1 || index > this.groups.Length {
            return false
        }
        this.CaptureCurrentGroupValues()
        this.current_group_index := index
        if this.group_list && this.group_list.Value != index {
            this.group_list.Choose(index)
        }
        this.CreateContentPanel()
        return true
    }

    CreateContentPanel() {
        local factory, group := this.groups[this.current_group_index]
        local initial_dark_mode := this.window_theme.dark_mode, y := 12
        this.DestroyContentPanel()
        this.field_controls := Map()
        this.content_control_hwnds := Map()
        this.content_muted_controls := []
        this.content_gui := Gui("+Parent" . this.Hwnd . " -Caption +0x200000", "")
        this.content_gui.MarginX := 12
        this.content_gui.MarginY := 12
        if initial_dark_mode {
            this.content_gui.BackColor := RabbitWindowThemeController.DARK_BACKGROUND
        }
        this.content_gui.SetFont(
            "s10" . (initial_dark_mode ? " c" . RabbitWindowThemeController.DARK_TEXT : ""),
            "Microsoft YaHei UI"
        )
        if group.description {
            this.AddContentMutedText("x12 y" . y . " w" . (this.content_width - 24) . " h30", group.description)
            y += 40
        }
        for field in this.model.manifest.fields {
            if field.group = group.id {
                y := this.AddField(field, y)
            }
        }
        this.content_virtual_height := y + 8
        factory := this.theme_factory
        this.content_window_theme := factory(this.content_gui, this.dark_mode_reader)
        if this.content_muted_controls.Length {
            this.content_window_theme.RegisterMuted(this.content_muted_controls*)
        }
        this.content_window_theme.Register()
        this.content_gui.Show(this.ContentPanelOptions() . " Hide")
        this.ConfigureContentScroll()
        if this.visible {
            this.ShowContentPanel()
        }
    }

    DestroyContentPanel() {
        if this.content_gui {
            OnMessage(RabbitSchemaSettingsDialog.WM_VSCROLL, this.content_scroll_callback, 0)
            OnMessage(RabbitSchemaSettingsDialog.WM_MOUSEWHEEL, this.content_wheel_callback, 0)
        }
        try {
            if this.content_window_theme {
                this.content_window_theme.Dispose()
            }
        } finally {
            this.content_window_theme := 0
            if this.content_gui {
                this.content_gui.Destroy()
                this.content_gui := 0
            }
        }
    }

    AddField(field, y) {
        local control, control_width := this.content_width - 196
        if field.type = "boolean" {
            control := this.content_gui.AddCheckbox("x12 y" . y . " w" . (this.content_width - 24) . " h24", field.label)
            control.Value := this.draft_values[field.id]
            this.TrackContentControl(control)
            this.field_controls[field.id] := control
            y += 28
        } else {
            control := this.content_gui.AddText("x12 y" . y . " w170 h24 +0x200", field.label)
            this.TrackContentControl(control)
            if field.type = "enum" {
                control := this.content_gui.AddDropDownList("x184 y" . y . " w" . control_width, field.options)
                control.Text := this.draft_values[field.id]
            } else {
                control := this.content_gui.AddEdit(
                    "x184 y" . y . " w" . control_width . " r1 -Multi",
                    this.draft_values[field.id]
                )
            }
            this.TrackContentControl(control)
            this.field_controls[field.id] := control
            y += 30
        }
        if field.description {
            this.AddContentMutedText("x12 y" . y . " w" . (this.content_width - 24) . " h30", field.description)
            y += 34
        }
        return y + 6
    }

    AddContentMutedText(options, value) {
        local control := this.content_gui.AddText(options, value)
        this.TrackContentControl(control)
        this.content_muted_controls.Push(control)
        return control
    }

    TrackContentControl(control) {
        this.content_control_hwnds[control.Hwnd] := true
        return control
    }

    CaptureCurrentGroupValues() {
        local control, field
        if !this.field_controls.Count {
            return
        }
        for field in this.model.manifest.fields {
            if field.group != this.groups[this.current_group_index].id {
                continue
            }
            control := this.field_controls[field.id]
            this.draft_values[field.id] := field.type = "boolean" ? !!control.Value
                : field.type = "enum" ? control.Text : control.Value
        }
    }

    ContentPanelOptions() {
        local bounds, origin
        if this.content_anchor && (bounds := RabbitDialogPlacement.GetWindowBounds(this.content_anchor.Hwnd)) {
            origin := Point()
            if DllCall("User32\ClientToScreen", "Ptr", this.Hwnd, "Ptr", origin, "Int") {
                return "x" . (bounds.left - origin.x) . " y" . (bounds.top - origin.y)
                    . " w" . this.content_width . " h" . this.content_height
            }
        }
        return "x" . this.content_x . " y" . this.content_y
            . " w" . this.content_width . " h" . this.content_height
    }

    ShowContentPanel() {
        if this.content_gui {
            this.content_gui.Show(this.ContentPanelOptions() . " NA")
        }
    }

    ConfigureContentScroll() {
        this.content_scroll_y := 0
        this.content_scroll_max := Max(0, this.content_virtual_height - this.content_height)
        this.SetContentScrollInfo()
    }

    SetContentScrollInfo() {
        local info
        if !this.content_gui {
            return
        }
        info := Buffer(28, 0)
        NumPut("UInt", info.Size, info, 0)
        NumPut(
            "UInt",
            RabbitSchemaSettingsDialog.SIF_RANGE | RabbitSchemaSettingsDialog.SIF_PAGE
                | RabbitSchemaSettingsDialog.SIF_POS,
            info,
            4
        )
        NumPut("Int", 0, info, 8)
        NumPut("Int", Max(0, this.content_virtual_height - 1), info, 12)
        NumPut("UInt", this.content_height, info, 16)
        NumPut("Int", this.content_scroll_y, info, 20)
        DllCall("User32\SetScrollInfo", "Ptr", this.content_gui.Hwnd, "Int", RabbitSchemaSettingsDialog.SB_VERT,
            "Ptr", info, "Int", true)
        DllCall(
            "User32\ShowScrollBar",
            "Ptr",
            this.content_gui.Hwnd,
            "Int",
            RabbitSchemaSettingsDialog.SB_VERT,
            "Int",
            this.content_scroll_max > 0
        )
        OnMessage(RabbitSchemaSettingsDialog.WM_VSCROLL, this.content_scroll_callback)
        OnMessage(RabbitSchemaSettingsDialog.WM_MOUSEWHEEL, this.content_wheel_callback)
    }

    OnContentVScroll(w_param, l_param, msg, hwnd) {
        local request, target := this.content_scroll_y
        if !this.content_gui || hwnd != this.content_gui.Hwnd {
            return
        }
        request := w_param & 0xFFFF
        switch request {
            case RabbitSchemaSettingsDialog.SB_LINEUP:
                target -= RabbitSchemaSettingsDialog.CONTENT_SCROLL_LINE
            case RabbitSchemaSettingsDialog.SB_LINEDOWN:
                target += RabbitSchemaSettingsDialog.CONTENT_SCROLL_LINE
            case RabbitSchemaSettingsDialog.SB_PAGEUP:
                target -= this.content_height
            case RabbitSchemaSettingsDialog.SB_PAGEDOWN:
                target += this.content_height
            case RabbitSchemaSettingsDialog.SB_THUMBPOSITION, RabbitSchemaSettingsDialog.SB_THUMBTRACK:
                target := this.GetContentTrackPosition()
            case RabbitSchemaSettingsDialog.SB_TOP:
                target := 0
            case RabbitSchemaSettingsDialog.SB_BOTTOM:
                target := this.content_scroll_max
            case RabbitSchemaSettingsDialog.SB_ENDSCROLL:
                return 0
            default:
                return
        }
        this.ScrollContentTo(target)
        return 0
    }

    GetContentTrackPosition() {
        local info := Buffer(28, 0)
        NumPut("UInt", info.Size, info, 0)
        NumPut("UInt", RabbitSchemaSettingsDialog.SIF_TRACKPOS, info, 4)
        if !DllCall(
            "User32\GetScrollInfo",
            "Ptr",
            this.content_gui.Hwnd,
            "Int",
            RabbitSchemaSettingsDialog.SB_VERT,
            "Ptr",
            info,
            "Int"
        ) {
            return this.content_scroll_y
        }
        return NumGet(info, 24, "Int")
    }

    OnContentMouseWheel(w_param, l_param, msg, hwnd) {
        local delta
        if !this.content_gui || !this.content_scroll_max
            || hwnd != this.content_gui.Hwnd && !this.content_control_hwnds.Has(hwnd) {
            return
        }
        delta := (w_param >> 16) & 0xFFFF
        if delta & 0x8000 {
            delta -= 0x10000
        }
        if !delta {
            return 0
        }
        this.ScrollContentTo(
            this.content_scroll_y - Round(delta * RabbitSchemaSettingsDialog.CONTENT_SCROLL_LINE / 120)
        )
        return 0
    }

    ScrollContentTo(position) {
        local target := Min(Max(position, 0), this.content_scroll_max)
        if target = this.content_scroll_y {
            return
        }
        DllCall(
            "User32\ScrollWindowEx",
            "Ptr",
            this.content_gui.Hwnd,
            "Int",
            0,
            "Int",
            this.content_scroll_y - target,
            "Ptr",
            0,
            "Ptr",
            0,
            "Ptr",
            0,
            "Ptr",
            0,
            "UInt",
            RabbitSchemaSettingsDialog.SW_SCROLLCHILDREN | RabbitSchemaSettingsDialog.SW_INVALIDATE
                | RabbitSchemaSettingsDialog.SW_ERASE
        )
        this.content_scroll_y := target
        this.SetContentScrollInfo()
    }

    ShowModal() {
        local hwnd := this.Hwnd
        RabbitDialogPlacement.ShowOnOwnerMonitor(this, this.owner_window.Hwnd, "w" . this.dialog_width
            . " h" . this.dialog_height)
        this.visible := true
        this.ShowContentPanel()
        WinWaitClose("ahk_id " . hwnd)
        return this.result
    }

    SaveSettings() {
        try {
            this.CaptureCurrentGroupValues()
            this.result := this.model.NormalizeValues(this.draft_values)
            this.Dispose()
            return true
        } catch as err {
            this.status.Value := err.Message
            return false
        }
    }

    Dispose() {
        if this.disposed {
            return
        }
        this.disposed := true
        this.visible := false
        try {
            this.DestroyContentPanel()
            if this.window_theme {
                this.window_theme.Dispose()
                this.window_theme := 0
            }
        } finally {
            try this.Destroy()
        }
    }
}
