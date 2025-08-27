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
#Include <Gdip_All>

class CandidatePreview {
	borderWidth := 2
	cornerRadius := 4
	lineSpacing := 6
	padding := 8

	pToken := 0
	pBitmap := 0
	hBitmap := 0
	pGraphics := 0
	hFont := 0
	hFormat := 0

	__New(ctrl, theme, &calcW, &calcH) {
		if !this.pToken {
			this.pToken := Gdip_Startup()
			if !this.pToken {
				MsgBox("GDI+ failed to start.")
				ExitApp
			}
		}
		this.imgCtrl := ctrl
		this.dpiSacle := GUIUtilities.GetMonitorDpiScale()
		; only use one font to preview
		this.fontName := theme.HasOwnProp("font_face") ? theme.font_face : UIStyle.font_face
		this.fontSize := theme.HasOwnProp("font_point") ? theme.font_point : UIStyle.font_point
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
		this.CalcSize(&calcW, &calcH)
	}

	__Delete() {
		this.ReleaseAll()
	}

	CalcSize(&calcW, &calcH) {
		this.hFamily := Gdip_FontFamilyCreate(this.fontName)
		this.hFont := Gdip_FontCreate(this.hFamily, this.fontSize * this.dpiSacle, regular := 0)
		this.hFormat := Gdip_StringFormatCreate(0x0001000 | 0x0004000)
		Gdip_SetStringFormatAlign(this.hFormat, left := 0) ; left:0, center:1, right:2

		hDC := GetDC(this.imgCtrl.Hwnd)
		pGraphics := Gdip_GraphicsFromHDC(hDC)

		CreateRectF(&RC, 0, 0, 0, 0)
		this.prdSelSize := this.MeasureString(pGraphics, "RIME", this.hFont, this.hFormat, &RC)
		this.prdHlSize := this.MeasureString(pGraphics, "shu ru fa", this.hFont, this.hFormat, &RC)
		this.candSize := this.MeasureString(pGraphics, "1. 输入法", this.hFont, this.hFormat, &RC)

		this.maxRowWidth := this.prdSelSize.w + this.padding + this.prdHlSize.w
		totalHeight := (this.prdSelSize.h + this.lineSpacing) * 6

		Gdip_DeleteGraphics(pGraphics)
		ReleaseDC(hDC, this.imgCtrl.Hwnd)

		this.previewWidth := Ceil(this.maxRowWidth) + this.padding * 2 + this.borderWidth * 2
		this.previewHeight := Ceil(totalHeight) + this.padding * 2 + this.borderWidth * 2 - this.lineSpacing ; Remove last line spacing
		calcW := this.previewWidth
		calcH := this.previewHeight
	}

	Render(candsArray, selIndex) {
		; Create a bitmap in memory that matches the size of preview
		this.pBitmap := Gdip_CreateBitmap(this.previewWidth, this.previewHeight)
		this.pGraphics := Gdip_GraphicsFromImage(this.pBitmap)
		Gdip_SetSmoothingMode(this.pGraphics, AntiAlias := 4)

		; Draw border
		if (this.borderWidth > 0) {
			pBrushBorder := Gdip_BrushCreateSolid(this.borderColor)
			this.FillRoundedRect(this.pGraphics, pBrushBorder, 0, 0, this.previewWidth, this.previewHeight, this.cornerRadius)
			Gdip_DeleteBrush(pBrushBorder)
		}

		; Draw background
		pBrushBg := Gdip_BrushCreateSolid(this.backgroundColor)
		bgX := this.borderWidth
		bgY := this.borderWidth
		bgW := this.previewWidth - this.borderWidth * 2
		bgH := this.previewHeight - this.borderWidth * 2
		bgCornerRadius := this.cornerRadius > this.borderWidth ? this.cornerRadius - this.borderWidth : 0
		this.FillRoundedRect(this.pGraphics, pBrushBg, bgX, bgY, bgW, bgH, bgCornerRadius)
		Gdip_DeleteBrush(pBrushBg)

		; Draw preedit
		currentY := this.padding + this.borderWidth
		prdSelTextRect := { x: this.padding + this.borderWidth, y: currentY, w: this.prdSelSize.w, h: this.prdSelSize.h }
		prdHlTextRect := { x: this.padding * 2 + this.prdSelSize.w, y: currentY, w: this.prdHlSize.w, h: this.prdHlSize.h }
		this.DrawText(this.pGraphics, "RIME", prdSelTextRect, this.textColor)
		pBrsh_hlBg := Gdip_BrushCreateSolid(this.hlBgColor)
		Gdip_FillRoundedRectangle(this.pGraphics, pBrsh_hlBg, prdHlTextRect.x, prdHlTextRect.y, prdHlTextRect.w, prdHlTextRect.h - 2, r := 2)
		Gdip_DeleteBrush(pBrsh_hlBg)
		this.DrawText(this.pGraphics, "shu ru fa", prdHlTextRect, this.hlTxtColor)
		currentY += this.prdSelSize.h + this.lineSpacing

		; Draw candidates
		for i, candidate in candsArray {
			textColor := this.candTxtColor
			if (i == selIndex) { ; Draw highlight if selected
				textColor := this.hlCandTxtColor
				pBrsh_hlCandBg := Gdip_BrushCreateSolid(this.hlCandBgColor)
				highlightX := this.borderWidth + this.padding / 2
				highlightY := currentY - this.lineSpacing / 2
				highlightW := this.previewWidth - this.borderWidth * 2 - this.padding
				highlightH := this.candSize.h + this.lineSpacing
				Gdip_FillRoundedRectangle(this.pGraphics, pBrsh_hlCandBg, highlightX, highlightY, highlightW, highlightH, r := 4)
				Gdip_DeleteBrush(pBrsh_hlCandBg)
			}

			textToDraw := i . ". " . candidate
			candidateRowRect := { x: this.padding + this.borderWidth, y: currentY, w: this.maxRowWidth, h: this.candSize.h }
			this.DrawText(this.pGraphics, textToDraw, candidateRowRect, textColor)
			currentY += this.candSize.h + this.lineSpacing
		}

		; Replace preview image with hBitmap
		this.hBitmap := Gdip_CreateHBITMAPFromBitmap(this.pBitmap)
		SendMessage(STM_SETIMAGE := 0x0172, IMAGE_BITMAP := 0, this.hBitmap, this.imgCtrl.Hwnd)

		this.ReleaseDrawingSurface()
	}

	ReleaseFont() {
		if (this.hFont)
			Gdip_DeleteFont(this.hFont)
		if (this.hFamily)
			Gdip_DeleteFontFamily(this.hFamily)
		if (this.hFormat)
			Gdip_DeleteStringFormat(this.hFormat)
	}

	ReleaseDrawingSurface() {
		if (this.pGraphics) {
			Gdip_DeleteGraphics(this.pGraphics)
			this.pGraphics := 0
		}
		if (this.pBitmap) {
			Gdip_DisposeImage(this.pBitmap)
			this.pBitmap := 0
		}
		if (this.hBitmap) {
			DeleteObject(this.hBitmap)
			this.hBitmap := 0
		}
	}

	ReleaseAll() {
		this.ReleaseFont()
		this.ReleaseDrawingSurface()

		if (this.pToken) {
			Gdip_Shutdown(this.pToken)
			this.pToken := 0
		}
	}

	MeasureString(pGraphics, text, hFont, hFormat, &RectF) {
		rc := Buffer(16)
		; !Notice, this way gets incorrect dim in test
		; dim := Gdip_MeasureString(pGraphics, text, hFont, hFormat, &rc)
		; rect := StrSplit(dim, "|")
		; return { w: Round(rect[3]), h: Round(rect[4]) }

		DllCall("gdiplus\GdipMeasureString",
			"Ptr", pGraphics,
			"WStr", text,
			"Int", -1,
			"Ptr", hFont,
			"Ptr", RectF.Ptr,
			"Ptr", hFormat,
			"Ptr", rc.Ptr,
			"UInt*", 0,
			"UInt*", 0,
			"Int")

		return { x: NumGet(rc.Ptr, 0, "Float"), y: NumGet(rc.Ptr, 4, "Float"),
			w: NumGet(rc.Ptr, 8, "Float"), h: NumGet(rc.Ptr, 12, "Float") }
	}

	DrawText(pGraphics, text, textRect, color) {
		this.pBrush := Gdip_BrushCreateSolid(color)
		CreateRectF(&RC, textRect.x, textRect.y, textRect.w, textRect.h)
		Gdip_DrawString(pGraphics, text, this.hFont, this.hFormat, this.pBrush, &RC)
		Gdip_SetTextRenderingHint(this.pGraphics, AntiAlias := 4)
		Gdip_DeleteBrush(this.pBrush)
	}

	FillRoundedRect(pGraphics, pBrush, x, y, w, h, r) {
		if (r <= 0) {
			Gdip_FillRectangle(pGraphics, pBrush, x, y, w, h)
		} else {
			Gdip_FillRoundedRectangle(pGraphics, pBrush, x, y, w, h, r)
		}
	}
}

class ThemesGUI {
	__New() {
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
			box.UpdateUIStyle()
		}

		this.gui.Hide()
	}

	SetPreviewCandsBox(theme, fontName, fontSize) {
		this.previewStyle := this.GetThemeColor(theme)
		this.previewStyle.font_face := fontName
		this.previewStyle.font_point := fontSize
		candidateBox := CandidatePreview(this.previewImg, this.previewStyle, &candidateBoxW, &candidateBoxH)
		previewCandsBoxX := this.gui.MarginX + this.themeListBoxW + this.previewGroupOffset + Round((this.previewGroupW - candidateBoxW) / 2)
		previewCandsBoxY := this.gui.MarginY + this.titleH + Round((this.previewGroupH - candidateBoxH) / 2)
		this.previewImg.Move(previewCandsBoxX, previewCandsBoxY, candidateBoxW, candidateBoxH)
		candidateBox.Render(this.candsArray, 1)
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
