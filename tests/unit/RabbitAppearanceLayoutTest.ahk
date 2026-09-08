#Requires AutoHotkey v2.0
#Include ..\support\TestCommon.ahk
#Include ..\..\Lib\RabbitSettingsWindow.ahk

RunTest("appearance groups contain their localized controls", TestAppearanceGroupBounds)

TestAppearanceGroupBounds() {
    local locale, window := 0, dialog := 0, field, controls, group, name, measure
    local x, y, w, h, gx, gy, gw, gh, text_width, label_x, label_width, edit_x, status_y
    try {
        for locale in ["zh-CN", "en-US", "ja-JP", "zh-HK", "zh-TW"] {
            RabbitI18n.Initialize(A_ScriptDir . "\..\..\locales", locale)
            window := RabbitSettingsWindow(0, true)
            window.appearance_tabs.Choose(4)
            window.OnAppearanceTabChanged()
            AssertTrue(window.appearance_floating_preedit.Visible,
                "Opening the preedit tab first did not initialize its controls.")
            AssertTrue(!window.appearance_font.Visible, "The preedit tab exposed typography controls.")
            window.appearance_tabs.Choose(2)
            window.OnAppearanceTabChanged()
            AssertTrue(window.appearance_font.Visible, "The typography tab did not show fonts.")
            AssertTrue(!HasProp(window, "appearance_font_group")
                && !HasProp(window, "appearance_layout_group")
                && !HasProp(window, "appearance_preedit_group"), "Redundant tab groups remain.")
            for name in ["font", "preedit_font", "label_font", "comment_font", "label_format",
                "font_point", "label_font_point", "comment_font_point"] {
                controls := window.%"appearance_" . name . "_label"%
                AssertTrue(controls.Visible, locale . ": font label is hidden: " . name)
                measure := window.AddText("Hidden", controls.Text)
                measure.GetPos(, , &text_width)
                controls.GetPos(&label_x, , &label_width)
                window.%"appearance_" . name%.GetPos(&edit_x)
                AssertTrue(label_width >= text_width && label_x + label_width <= edit_x,
                    locale . ": font label is clipped or overlaps its input: " . name)
            }
            measure := window.AddText("Hidden", window.appearance_advanced_font.Text)
            measure.GetPos(, , &text_width)
            window.appearance_advanced_font.GetPos(&x, , &w)
            window.appearance_label_format.GetPos(&edit_x, , &label_width)
            AssertTrue(w >= text_width + 24 && edit_x + label_width + 12 <= x,
                locale . ": advanced font button lacks text space or overlaps the input.")
            AssertTrue(!window.appearance_floating_preedit.Visible,
                "The typography tab exposed floating preedit controls.")
            AssertTrue(!window.appearance_layout_type.Visible, "The font tab exposed layout controls.")
            window.appearance_tabs.Choose(3)
            window.OnAppearanceTabChanged()
            AssertTrue(window.appearance_layout_type.Visible, "The layout tab did not show its controls.")
            AssertTrue(!window.appearance_font.Visible, "The layout tab exposed font controls.")
            window.appearance_tabs.GetPos(&gx, &gy, &gw, &gh)
            window.appearance_shadow_radius.GetPos(&x, &y, &w, &h)
            AssertTrue(y + h + 8 <= gy + gh, "The layout group lacks bottom padding.")
            window.appearance_tabs.Choose(4)
            window.OnAppearanceTabChanged()
            AssertTrue(window.GetPageWindowHeight() * 1.5 + 48 <= 1040,
                "The appearance window exceeds a 1080p work area at 150% scale.")
            window.appearance_tabs.GetPos(&gx, &gy, &gw, &gh)
            window.appearance_status.GetPos(, &status_y)
            AssertTrue(gy + gh < status_y, locale . ": preedit group overlaps the status line.")
            window.appearance_preedit_hint.GetPos(, &y, , &h)
            AssertTrue(y + h <= gy + gh, locale . ": fallback hint is outside the preedit group.")
            for name in ["preedit_margin_x", "preedit_margin_y", "preedit_border_width",
                "preedit_corner_radius", "preedit_round_corner", "floating_opacity", "floating_height"] {
                controls := window.%"appearance_" . name%
                controls.GetPos(&x, &y, &w, &h)
                AssertTrue(x >= gx && y >= gy && x + w <= gx + gw && y + h <= gy + gh,
                    locale . ": preedit field outside its group: " . name)
                controls := window.%"appearance_" . name . "_label"%
                controls.GetPos(&label_x, , &label_width)
                measure := window.AddText("Hidden", controls.Text)
                measure.GetPos(, , &text_width)
                AssertTrue(text_width <= label_width && label_x + label_width <= x,
                    locale . ": clipped preedit label: " . name)
            }
            dialog := RabbitColorSchemeDialog(window, RabbitColorScheme.CreateDefault("test", "Test"))
            for field in RabbitColorScheme.EDITABLE_COLOR_FIELDS {
                group := field.group = "window" ? dialog.window_group : dialog.candidate_group
                group.GetPos(&gx, &gy, &gw, &gh)
                controls := dialog.color_controls[field.key]
                controls.edit.GetPos(&x, &y, &w, &h)
                AssertTrue(x >= gx && y >= gy && x + w <= gx + gw && y + h <= gy + gh,
                    locale . ": color field outside its group: " . field.key)
                controls.label.GetPos(&label_x, , &label_width)
                measure := dialog.AddText("Hidden", controls.label.Text)
                measure.GetPos(, , &text_width)
                controls.swatch.GetPos(&edit_x)
                AssertTrue(text_width <= label_width && label_x + label_width <= edit_x,
                    locale . ": clipped color label: " . field.key)
            }
            for field in RabbitColorScheme.EDITABLE_COLOR_FIELDS {
                if field.key = "hilited_back_color" {
                    AssertEqual("window", field.group,
                        "The highlighted preedit background belongs to the window group.")
                }
            }
            dialog.Dispose()
            dialog := 0
            window.Dispose()
            window := 0
        }
    } finally {
        if dialog {
            dialog.Dispose()
        }
        if window {
            window.Dispose()
        }
        RabbitI18n.Initialize(A_ScriptDir . "\..\..\locales", "zh-CN")
    }
}
