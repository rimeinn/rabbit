/*
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

#Include <RabbitUIStyle>
#Include <Direct2D\Direct2D>

class CandidatePreview {
	hBitmap := 0

	__New(ctrl) {
		this.imgCtrl := ctrl
		this.d2d := Direct2D()
		this.dpiScale := this.d2d.GetDesktopDpiScale()
	}

	__Delete() {
		if this.hBitmap
			DllCall("DeleteObject", "UPtr", this.hBitmap), this.hBitmap := 0
	}

	Build(theme, &calcW, &calcH) {
		this.borderWidth := UIStyle.border_width
		this.borderColor := UIStyle.border_color
		this.boxCornerR := UIStyle.corner_radius
		this.hlCornerR := UIStyle.round_corner
		this.lineSpacing := UIStyle.margin_y
		this.padding := UIStyle.margin_x

		; only use one font to preview
		this.fontName := theme.HasOwnProp("font_face") ? theme.font_face : UIStyle.font_face
		this.fontSize := theme.HasOwnProp("font_point") ? theme.font_point : UIStyle.font_point
		this.fontSize *= (em2pt := (96.0 / 72.0))
		; preedite style
		this.borderColor := theme.border_color
		this.textColor := theme.text_color
		this.backgroundColor := theme.back_color
		this.hlTxtColor := theme.hilited_text_color
		this.hlBgColor := theme.hilited_back_color
		; candidate style
		this.hlCandTxtColor := theme.hilited_candidate_text_color
		this.hlCandBgColor := theme.hilited_candidate_back_color
		this.candTxtColor := theme.candidate_text_color
		this.candBgColor := theme.candidate_back_color

		this.prdSelSize := this.d2d.GetMetrics("RIME", this.fontName, this.fontSize)
		this.prdHlSize := this.d2d.GetMetrics("shu ru fa", this.fontName, this.fontSize)
		this.candSize := this.d2d.GetMetrics("1. 输入法", this.fontName, this.fontSize)
		this.maxRowWidth := this.prdSelSize.w + this.padding + this.prdHlSize.w
		this.previewWidth := Ceil(this.maxRowWidth) + this.padding * 2 + this.borderWidth * 2
		this.previewHeight := Ceil((this.candSize.h + this.lineSpacing) * 6) + this.lineSpacing * 2 + this.borderWidth * 2 - this.lineSpacing ; Remove last line spacing
		calcW := this.previewWidth
		calcH := this.previewHeight
	}

	Render(candsArray, selIndex) {
		d2d1WicRt := this.d2d.SetRenderTarget("wic", this.previewWidth, this.previewHeight)
		this.d2d.BeginDraw()

		if (this.borderWidth > 0) {
			; Draw outer border as filled rounded rectangle (border color)
			this.d2d.FillRoundedRectangle(0, 0, this.previewWidth, this.previewHeight, this.boxCornerR, this.boxCornerR, this.borderColor)
			; Draw inner background next
			bgX := this.borderWidth, bgY := this.borderWidth
			bgW := this.previewWidth - this.borderWidth * 2
			bgH := this.previewHeight - this.borderWidth * 2
			bgR := this.boxCornerR > this.borderWidth ? this.boxCornerR - this.borderWidth : 0
			this.d2d.FillRoundedRectangle(bgX, bgY, bgW, bgH, bgR, bgR, this.backgroundColor)
		} else {
			this.d2d.FillRoundedRectangle(0, 0, this.previewWidth, this.previewHeight, this.boxCornerR, this.boxCornerR, this.backgroundColor)
		}

		; Draw preedit
		currentY := this.padding + this.borderWidth
		prdSelTextRect := {text: "RIME", x: this.padding + this.borderWidth, y: currentY, w: this.prdSelSize.w, h: this.prdSelSize.h }
		prdHlTextRect := {text: "shu ru fa", x: this.padding + this.borderWidth + this.padding + this.prdSelSize.w, y: currentY, w: this.prdHlSize.w, h: this.prdHlSize.h }
		; highlight background for preedit selection
		this.d2d.FillRoundedRectangle(prdHlTextRect.x, prdHlTextRect.y, prdHlTextRect.w, prdHlTextRect.h,
				this.hlCornerR, this.hlCornerR, this.hlBgColor)
		this.d2d.DrawText(prdSelTextRect.text, prdSelTextRect.x, prdSelTextRect.y, this.fontSize, this.textColor, this.fontName)
		this.d2d.DrawText(prdHlTextRect.text, prdHlTextRect.x, prdHlTextRect.y, this.fontSize, this.hlTxtColor, this.fontName)
		currentY += Max(this.prdSelSize.h, this.prdHlSize) + this.lineSpacing


		; Draw candidates
		for i, candidate in candsArray {
			candFg := this.candTxtColor
			if (A_Index == selIndex) { ; Draw highlight if selected
				candFg := this.hlCandTxtColor
				highlightX := this.borderWidth + this.padding / 2
				highlightY := currentY - this.lineSpacing / 2
				highlightW := this.previewWidth - this.borderWidth * 2 - this.padding
				highlightH := this.candSize.h + this.lineSpacing
				this.d2d.FillRoundedRectangle(highlightX, highlightY, highlightW, highlightH, this.hlCornerR, this.hlCornerR, this.hlCandBgColor)
			}

			textToDraw := i . ". " . candidate
			candidateRowRect := { x: this.padding + this.borderWidth, y: currentY, w: this.maxRowWidth, h: this.candSize.h }
			this.d2d.DrawText(textToDraw, candidateRowRect.x, candidateRowRect.y, this.fontSize, candFg, this.fontName)
			currentY += this.candSize.h + this.lineSpacing
		}
		this.d2d.EndDraw()

		if this.hBitmap := d2d1WicRt.GetHBitmapFromWICBitmap() {
			; Replace preview image with hBitmap
			SendMessage(STM_SETIMAGE := 0x0172, IMAGE_BITMAP := 0, this.hBitmap, this.imgCtrl.Hwnd)
			DllCall("DeleteObject", "UPtr", this.hBitmap)
			this.d2d.Clear()
		}
	}
}

class ThemesGUI {
	__New(result) {
		this.result := result
		this.preset_color_schemes := Map()
		this.colorSchemeMap := Map()
		this.previewFontName := UIStyle.font_face
		this.previewFontSize := UIStyle.font_point
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
		this.preset_color_schemes := this.GetPresetStylesMap()
		local colorChoices := []
		for key, preset in this.preset_color_schemes {
			colorChoices.Push(preset["name"])
			this.colorSchemeMap[preset["name"]] := key
		}
		this.gui.Add("Text", "x10 y10", "主题：").GetPos(, , , &titleH)
		this.titleH := titleH

		this.themeListBox := this.gui.AddListBox("r15 w" . this.themeListBoxW . " -Multi", colorChoices)
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
		if !this.colorSchemeMap.Has(ctrl.Text)
			return

		this.currentTheme := this.colorSchemeMap[ctrl.Text]
		this.SetPreviewCandsBox(this.currentTheme, this.previewFontName, this.previewFontSize)
	}

	OnSetFont(*) {
		fontGui := Gui("AlwaysOnTop +Owner" this.gui.Hwnd, "字体选择")
		fontGui.SetFont("s10")

		fontGui.AddText("x10 y10", "字体名称：")
		fontChoice := fontGui.AddDropDownList("x+10 yp-4 w180 hp r10", GUIUtilities.GetFontArray())
		fontChoice.Text := this.previewFontName

		fontGui.AddText("x+30 y10", "大小：")
		fontSizeEdit := fontGui.Add("Edit", "x+0 yp-6 w60 Limit2 Number")
		fontGui.AddUpDown("Range10-20", this.previewFontSize)

		okBtn := fontGui.AddButton("x10 yp+30 w120", "确定")
		fontGui.AddButton("x+150 yp w120", "取消").OnEvent("Click", (*) => fontGui.Destroy())

		okBtn.OnEvent("Click", (*) => (
			this.previewFontName := fontChoice.Text,
			this.previewFontSize := fontSizeEdit.Value,
			this.SetPreviewCandsBox(this.currentTheme, this.previewFontName, this.previewFontSize),
			fontGui.Destroy()
		))

		fontGui.Show()
	}

	OnConfirm(*) {
		global rime
		if rime and config := rime.config_open("rabbit") {
			rime.config_set_string(config, "style/color_scheme", this.currentTheme)
			rime.config_set_int(config, "style/font_point", this.previewFontSize)
			rime.config_set_string(config, "style/font_face", this.previewFontName)
			UIStyle.Update(config, init := true)
			rime.config_close(config)
			this.result.yes := true
		}

		this.gui.Hide()
	}

	SetPreviewCandsBox(theme, fontName, fontSize) {
		this.previewStyle := this.GetThemeColor(theme)
		this.previewStyle.font_face := fontName
		this.previewStyle.font_point := fontSize
		this.candidateBox.Build(this.previewStyle, &candidateBoxW, &candidateBoxH)
		previewCandsBoxX := this.gui.MarginX + this.themeListBoxW + this.previewGroupOffset + Round((this.previewGroupW - candidateBoxW) / 2)
		previewCandsBoxY := this.gui.MarginY + this.titleH + Round((this.previewGroupH - candidateBoxH) / 2)
		this.previewImg.Move(previewCandsBoxX, previewCandsBoxY, candidateBoxW, candidateBoxH)
		this.candidateBox.Render(this.candsArray, 1)
	}

	GetPresetStylesMap() {
		local presetStylesMap := Map()
		global rime
		if rime and config := rime.config_open("rabbit") {
			if iter := rime.config_begin_map(config, "preset_color_schemes") {
				while rime.config_next(iter) {
					styleMap := Map()
					theme := StrLower(iter.key)
					if name := rime.config_get_string(config, "preset_color_schemes/" . theme . "/name") {
						styleMap["name"] := name
						UIStyle.UpdateColor(config, theme)
					}
					styleMap["border_color"] := UIStyle.border_color
					styleMap["text_color"] := UIStyle.text_color
					styleMap["back_color"] := UIStyle.back_color
					styleMap["hilited_text_color"] := UIStyle.hilited_text_color
					styleMap["hilited_back_color"] := UIStyle.hilited_back_color
					styleMap["hilited_candidate_text_color"] := UIStyle.hilited_candidate_text_color
					styleMap["hilited_candidate_back_color"] := UIStyle.hilited_candidate_back_color
					styleMap["candidate_text_color"] := UIStyle.candidate_text_color
					styleMap["candidate_back_color"] := UIStyle.candidate_back_color
					presetStylesMap[theme] := styleMap
				}
				rime.config_end(iter)
			}
			; restore UIStyle
			UIStyle.Update(config, init := true)
			rime.config_close(config)
		}
		return presetStylesMap
	}

	GetThemeColor(selTheme) {
		style := this.preset_color_schemes[selTheme]
		return {
			border_color: style["border_color"],
			text_color: style["text_color"],
			back_color: style["back_color"],
			hilited_text_color: style["hilited_text_color"],
			hilited_back_color: style["hilited_back_color"],
			hilited_candidate_text_color: style["hilited_candidate_text_color"],
			hilited_candidate_back_color: style["hilited_candidate_back_color"],
			candidate_text_color: style["candidate_text_color"],
			candidate_back_color: style["candidate_back_color"],
		}
	}
}

Class GUIUtilities {
	static GetFontArray() {
		static fontArr
		if isSet(fontArr)
			return fontArr

		sFont := Buffer(128, 0)
		NumPut("UChar", 1, sFont, 23)
		DllCall("EnumFontFamiliesEx", "ptr", DllCall("GetDC", "ptr", 0), "ptr", sFont.Ptr, "ptr", CallbackCreate(EnumFontProc), "ptr", ObjPtr(fontMap := Map()), "uint", 0)

		fontArr := Array()
		for key, value in fontMap
			fontArr.Push(SubStr(key, 2)) ; remove "@"
		return fontArr

		EnumFontProc(lpFont, lpntme, textFont, lParam) {
			font := StrGet(lpFont + 28, "UTF-16")
			ObjFromPtrAddRef(lParam)[font] := ""
			return true
		}
	}

	static GetMonitorDpiScale() {
		hr := DllCall(
			"Shcore.dll\GetDpiForMonitor",
			"ptr", hMonitor := DllCall("MonitorFromPoint", "int64", 0, "uint", 2, "ptr"),
			"int", MDT_EFFECTIVE_DPI := 0,
			"uint*", &dpiX := 0,
			"uint*", &dpiY := 0
		)

		if (hr != 0)
			return 1

		return dpiX / 96
	}
}
