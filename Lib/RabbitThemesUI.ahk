/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 * Copyright (c) 2005 Tim <zerxmega@foxmail.com>
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

#Include <RabbitUIStyleSnapshot>
#Include <Direct2D\Direct2D>

class CandidatePreview {
    hBitmap := 0

    __New(ctrl) {
        this.imgCtrl := ctrl
        this.d2d := Direct2D()
        this.dpiScale := this.d2d.GetDesktopDpiScale()
    }

    __Delete() {
        if this.hBitmap {
            DllCall("DeleteObject", "UPtr", this.hBitmap), this.hBitmap := 0
        }
    }

    Build(style, &calc_width, &calc_height) {
        local em2pt
        this.borderWidth := style.border_width
        this.borderColor := style.border_color
        this.boxCornerR := style.corner_radius
        this.hlCornerR := style.round_corner
        this.lineSpacing := style.margin_y
        this.padding := style.margin_x

        ; only use one font to preview
        this.fontName := style.font_face
        this.fontSize := style.font_point
        this.fontSize *= (em2pt := (96.0 / 72.0))
        ; preedite style
        this.borderColor := style.border_color
        this.textColor := style.text_color
        this.backgroundColor := style.back_color
        this.hlTxtColor := style.hilited_text_color
        this.hlBgColor := style.hilited_back_color
        ; candidate style
        this.hlCandTxtColor := style.hilited_candidate_text_color
        this.hlCandBgColor := style.hilited_candidate_back_color
        this.candTxtColor := style.candidate_text_color
        this.candBgColor := style.candidate_back_color

        this.prdSelSize := this.d2d.GetMetrics("RIME", this.fontName, this.fontSize)
        this.prdHlSize := this.d2d.GetMetrics("shu ru fa", this.fontName, this.fontSize)
        this.candSize := this.d2d.GetMetrics("1. 输入法", this.fontName, this.fontSize)
        this.maxRowWidth := this.prdSelSize.w + this.padding + this.prdHlSize.w
        this.previewWidth := Ceil(this.maxRowWidth) + this.padding * 2 + this.borderWidth * 2
        this.previewHeight := Ceil((this.candSize.h + this.lineSpacing) * 6) + this.lineSpacing * 2 + this.borderWidth * 2 - this.lineSpacing ; Remove last line spacing
        calc_width := this.previewWidth
        calc_height := this.previewHeight
    }

    Render(candidates, selected_index) {
        local wic_render_target, background_x, background_y, background_width, background_height, background_radius
        local current_y, preedit_text_rect, highlighted_preedit_rect, i, candidate, candidate_color
        local highlight_x, highlight_y, highlight_width, highlight_height, text_to_draw, candidate_row_rect
        local STM_SETIMAGE
        local IMAGE_BITMAP
        wic_render_target := this.d2d.SetRenderTarget("wic", this.previewWidth, this.previewHeight)
        this.d2d.BeginDraw()

        if this.borderWidth > 0 {
            ; Draw outer border as filled rounded rectangle (border color)
            this.d2d.FillRoundedRectangle(0, 0, this.previewWidth, this.previewHeight, this.boxCornerR, this.boxCornerR, this.borderColor)
            ; Draw inner background next
            background_x := this.borderWidth, background_y := this.borderWidth
            background_width := this.previewWidth - this.borderWidth * 2
            background_height := this.previewHeight - this.borderWidth * 2
            background_radius := this.boxCornerR > this.borderWidth ? this.boxCornerR - this.borderWidth : 0
            this.d2d.FillRoundedRectangle(background_x, background_y, background_width, background_height, background_radius, background_radius, this.backgroundColor)
        } else {
            this.d2d.FillRoundedRectangle(0, 0, this.previewWidth, this.previewHeight, this.boxCornerR, this.boxCornerR, this.backgroundColor)
        }

        ; Draw preedit
        current_y := this.padding + this.borderWidth
        preedit_text_rect := {text: "RIME", x: this.padding + this.borderWidth, y: current_y, w: this.prdSelSize.w, h: this.prdSelSize.h }
        highlighted_preedit_rect := {text: "shu ru fa", x: this.padding + this.borderWidth + this.padding + this.prdSelSize.w, y: current_y, w: this.prdHlSize.w, h: this.prdHlSize.h }
        ; highlight background for preedit selection
        this.d2d.FillRoundedRectangle(highlighted_preedit_rect.x, highlighted_preedit_rect.y, highlighted_preedit_rect.w, highlighted_preedit_rect.h,
                this.hlCornerR, this.hlCornerR, this.hlBgColor)
        this.d2d.DrawText(preedit_text_rect.text, preedit_text_rect.x, preedit_text_rect.y, this.fontSize, this.textColor, this.fontName)
        this.d2d.DrawText(highlighted_preedit_rect.text, highlighted_preedit_rect.x, highlighted_preedit_rect.y, this.fontSize, this.hlTxtColor, this.fontName)
        current_y += Max(this.prdSelSize.h, this.prdHlSize) + this.lineSpacing


        ; Draw candidates
        for i, candidate in candidates {
            candidate_color := this.candTxtColor
            if A_Index == selected_index { ; Draw highlight if selected
                candidate_color := this.hlCandTxtColor
                highlight_x := this.borderWidth + this.padding / 2
                highlight_y := current_y - this.lineSpacing / 2
                highlight_width := this.previewWidth - this.borderWidth * 2 - this.padding
                highlight_height := this.candSize.h + this.lineSpacing
                this.d2d.FillRoundedRectangle(highlight_x, highlight_y, highlight_width, highlight_height, this.hlCornerR, this.hlCornerR, this.hlCandBgColor)
            }

            text_to_draw := i . ". " . candidate
            candidate_row_rect := { x: this.padding + this.borderWidth, y: current_y, w: this.maxRowWidth, h: this.candSize.h }
            this.d2d.DrawText(text_to_draw, candidate_row_rect.x, candidate_row_rect.y, this.fontSize, candidate_color, this.fontName)
            current_y += this.candSize.h + this.lineSpacing
        }
        this.d2d.EndDraw()

        if (this.hBitmap := wic_render_target.GetHBitmapFromWICBitmap()) {
            ; Replace preview image with hBitmap
            SendMessage(STM_SETIMAGE := 0x0172, IMAGE_BITMAP := 0, this.hBitmap, this.imgCtrl.Hwnd)
            DllCall("DeleteObject", "UPtr", this.hBitmap)
            this.d2d.Clear()
        }
    }
}

class ThemesGUI {
    __New(result, style) {
        this.result := result
        this.preset_color_schemes := Map()
        this.colorSchemeMap := Map()
        this.previewFontName := style.font_face
        this.previewFontSize := style.font_point
        this.themeListBoxW := 400
        this.previewGroupW := 300
        this.previewGroupH := 418
        this.previewGroupOffset := 20
        this.currentTheme := "aqua"
        this.candsArray := ["输入法", "输入", "数", "书", "输"]
        this.gui := Gui("+LastFound +OwnDialogs -DPIScale +AlwaysOnTop", "选择主题")
        this.gui.MarginX := 10
        this.gui.MarginY := 10
        this.gui.SetFont("s10", "Microsoft YaHei UI")
        this.Build()
    }

    Build() {
        local key, preset, title_height
        this.preset_color_schemes := this.GetPresetStylesMap()
        local color_choices := []
        for key, preset in this.preset_color_schemes {
            color_choices.Push(preset["name"])
            this.colorSchemeMap[preset["name"]] := key
        }
        this.gui.Add("Text", "x10 y10", "主题：").GetPos(, , , &title_height)
        this.titleH := title_height

        this.themeListBox := this.gui.AddListBox("r15 w" . this.themeListBoxW . " -Multi", color_choices)
        this.themeListBox.Choose(1)
        this.themeListBox.OnEvent("Change", this.OnChangeColorScheme.Bind(this))
        this.gui.AddGroupBox(Format("x+{:d} yp-8 w{:d} h{:d} Section", this.previewGroupOffset, this.previewGroupW, this.previewGroupH), "预览")
        ; 0xE(SS_BITMAP) or 0x4E (Bitmap and Resizable, but text is unclear)
        this.previewImg := this.gui.AddPicture("xp+50 yp+50 w180 h300 0xE BackgroundWhite")
        this.candidateBox := CandidatePreview(this.previewImg)

        this.currentTheme := this.colorSchemeMap[this.themeListBox.Text]
        this.SetPreviewCandsBox(this.currentTheme, this.previewFontName, this.previewFontSize)

        this.setFontBtn := this.gui.AddButton("x10 ys+440 w160", "设置字体")
        this.confirmBtn := this.gui.AddButton("x+400 ys+440 w160", "确定")
        this.setFontBtn.OnEvent("Click", this.OnSetFont.Bind(this))
        this.confirmBtn.OnEvent("Click", this.OnConfirm.Bind(this))
    }

    Show() {
        this.gui.Show("AutoSize")
    }

    OnChangeColorScheme(ctrl, info) {
        if !this.colorSchemeMap.Has(ctrl.Text) {
            return
        }
        this.currentTheme := this.colorSchemeMap[ctrl.Text]
        this.SetPreviewCandsBox(this.currentTheme, this.previewFontName, this.previewFontSize)
    }

    OnSetFont(*) {
        local font_gui, font_choice, font_size_edit, ok_button
        font_gui := Gui("AlwaysOnTop +Owner" . this.gui.Hwnd, "字体选择")
        font_gui.SetFont("s10")

        font_gui.AddText("x10 y10", "字体名称：")
        font_choice := font_gui.AddDropDownList("x+10 yp-4 w180 hp r10", GUIUtilities.GetFontArray())
        font_choice.Text := this.previewFontName

        font_gui.AddText("x+30 y10", "大小：")
        font_size_edit := font_gui.Add("Edit", "x+0 yp-6 w60 Limit2 Number")
        font_gui.AddUpDown("Range10-20", this.previewFontSize)

        ok_button := font_gui.AddButton("x10 yp+30 w120", "确定")
        font_gui.AddButton("x+150 yp w120", "取消").OnEvent("Click", (*) => font_gui.Destroy())

        ok_button.OnEvent("Click", (*) => (
            this.previewFontName := font_choice.Text,
            this.previewFontSize := font_size_edit.Value,
            this.SetPreviewCandsBox(this.currentTheme, this.previewFontName, this.previewFontSize),
            font_gui.Destroy()
        ))

        font_gui.Show()
    }

    OnConfirm(*) {
        local config
        global rime
        if rime &&(config := rime.config_open("rabbit")) {
            rime.config_set_string(config, "style/color_scheme", this.currentTheme)
            rime.config_set_int(config, "style/font_point", this.previewFontSize)
            rime.config_set_string(config, "style/font_face", this.previewFontName)
            rime.config_close(config)
            this.result.yes := true
        }

        this.gui.Hide()
    }

    SetPreviewCandsBox(theme, fontName, fontSize) {
        local candidate_box_width, candidate_box_height, preview_box_x, preview_box_y
        this.previewStyle := this.GetThemeColor(theme).With({
            font_face: fontName,
            font_point: fontSize
        })
        this.candidateBox.Build(this.previewStyle, &candidate_box_width, &candidate_box_height)
        preview_box_x := this.gui.MarginX + this.themeListBoxW + this.previewGroupOffset + Round((this.previewGroupW - candidate_box_width) / 2)
        preview_box_y := this.gui.MarginY + this.titleH + Round((this.previewGroupH - candidate_box_height) / 2)
        this.previewImg.Move(preview_box_x, preview_box_y, candidate_box_width, candidate_box_height)
        this.candidateBox.Render(this.candsArray, 1)
    }

    GetPresetStylesMap() {
        local config, iter, style_map, theme, name
        local preset_styles_map := Map()
        global rime
        if rime &&(config := rime.config_open("rabbit")) {
            if (iter := rime.config_begin_map(config, "preset_color_schemes")) {
                while rime.config_next(iter) {
                    style_map := Map()
                    theme := StrLower(iter.key)
                    if (name := rime.config_get_string(config, "preset_color_schemes/" . theme . "/name")) {
                        style_map["name"] := name
                        style_map["style"] := RabbitUIStyleSnapshot.FromConfig(rime, config, false, theme)
                    }
                    preset_styles_map[theme] := style_map
                }
                rime.config_end(iter)
            }
            rime.config_close(config)
        }
        return preset_styles_map
    }

    GetThemeColor(selected_theme) {
        return this.preset_color_schemes[selected_theme]["style"]
    }
}

Class GUIUtilities {
    static GetFontArray() {
        static font_array
        local font_buffer, font_map, key, value

        if IsSet(font_array) {
            return font_array
        }
        font_buffer := Buffer(128, 0)
        NumPut("UChar", 1, font_buffer, 23)
        DllCall("EnumFontFamiliesEx", "ptr", DllCall("GetDC", "ptr", 0), "ptr", font_buffer.Ptr, "ptr", CallbackCreate(EnumFontProc), "ptr", ObjPtr(font_map := Map()), "uint", 0)

        font_array := Array()
        for key, value in font_map {
            font_array.Push(SubStr(key, 2)) ; Remove leading "@".
        }
        return font_array

        EnumFontProc(lpFont, lpntme, textFont, lParam) {
            local font
            font := StrGet(lpFont + 28, "UTF-16")
            ObjFromPtrAddRef(lParam)[font] := ""
            return true
        }
    }

    static GetMonitorDpiScale() {
        local hr, hMonitor, MDT_EFFECTIVE_DPI, dpiX, dpiY

        hr := DllCall(
            "Shcore.dll\GetDpiForMonitor",
            "ptr", hMonitor := DllCall("MonitorFromPoint", "int64", 0, "uint", 2, "ptr"),
            "int", MDT_EFFECTIVE_DPI := 0,
            "uint*", &dpiX := 0,
            "uint*", &dpiY := 0
        )

        if hr != 0 {
            return 1
        }
        return dpiX / 96
    }
}
