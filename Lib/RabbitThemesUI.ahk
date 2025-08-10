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

class ThemesGUI {
	__New(color_schemes) {
		this.preset_color_schemes := color_schemes
		this.colorSchemeMap := Map()
		this.previewFontName := "Microsoft YaHei UI"
		this.previewFontSize := 12
		this.themeListBoxW := 400
		this.previewGroupW := 300
		this.previewGroupH := 418
		this.currentTheme := "aqua"
		this.gui := Gui("+LastFound +OwnDialogs -DPIScale +AlwaysOnTop", "选择主题")
		this.gui.SetFont("s10", "Microsoft YaHei UI")
		this.Build()
	}

	Show() {
		this.gui.Show("AutoSize")
	}

	Build() {
		this.gui.Add("Text", "x10 y10", "主题：")
		colorChoices := []
		for key, preset in this.preset_color_schemes {
			colorChoices.Push(preset["name"])
			this.colorSchemeMap[preset["name"]] := key
		}
		themeListBox := this.gui.AddListBox("r15 w" . this.themeListBoxW . " -Multi", colorChoices)
		themeListBox.Choose(1)
		themeListBox.OnEvent("Change", this.OnChangeColorScheme.Bind(this))
		this.gui.AddGroupBox("x+20 yp-8 w" . this.previewGroupW . " h" . this.previewGroupH . " Section", "预览")

		this.currentTheme := this.colorSchemeMap[themeListBox.Text]
		colorOpt := this.GetThemeColor(this.currentTheme)
		highlightColorOpt := this.GetThemeColor(this.currentTheme, isHighlight := true)

		this.preeditTxt := " [shu ru fa]" ; ‸
		this.selCandsTxt := " 1.  输入法"
		this.candidateTxt := " 2.  输入`n 3.  数`n 4.  书`n 5.  输"
		p := this.GetPreviewCandsBoxRect()
		pX := p[1], pY := p[2], pW := p[3], pRowH := p[4]

		this.previewGuiPreedit := this.gui.AddText(
			Format("xp+{:d} yp+{:d} w{:d} h{:d} {:s}", pX, pY, pW, pRowH, colorOpt),
			this.preeditTxt
		)
		this.previewGuiSelCand := this.gui.AddText(
			Format("xp yp+{:d} w{:d} h{:d} {:s}", pRowH, pW, pRowH, highlightColorOpt),
			this.selCandsTxt
		)
		this.previewGuiCands := this.gui.AddText(
			Format("xp yp+{:d} w{:d} h{:d} {:s}", pRowH, pW, pRowH * 4, colorOpt),
			this.candidateTxt
		)
		this.SetPreviewCandsBoxFont()

		this.setFontBtn := this.gui.Add("Button", "x10 ys+440 w160", "设置字体")
		this.confirmBtn := this.gui.Add("Button", "x+400 ys+440 w160", "确定")
		this.setFontBtn.OnEvent("Click", this.OnSetFont.Bind(this))
		this.confirmBtn.OnEvent("Click", this.OnConfirm.Bind(this))
	}

	OnChangeColorScheme(ctrl, info) {
		if !this.colorSchemeMap.Has(ctrl.Text)
			return

		this.currentTheme := this.colorSchemeMap[ctrl.Text]
		this.previewGuiPreedit.Opt(this.GetThemeColor(this.currentTheme))
		this.previewGuiSelCand.Opt(this.GetThemeColor(this.currentTheme, darken := true))
		this.previewGuiCands.Opt(this.GetThemeColor(this.currentTheme))
	}

	OnSetFont(*) {
		fontGui := Gui("AlwaysOnTop +Owner" this.gui.Hwnd, "字体选择")
		fontGui.SetFont("s10")

		fontGui.Add("Text", "x10 y10", "字体名称：")
		fontChoice := fontGui.AddDropDownList("x+10 yp-4 w180 hp r10", GUIUtilities.GetFontArray())
		fontChoice.Text := this.previewFontName

		fontGui.Add("Text", "x+30 y10", "大小：")
		fontSizeEdit := fontGui.Add("Edit", "x+0 yp-6 w60 Limit2 Number")
		fontGui.Add("UpDown", "Range8-20", this.previewFontSize)

		okBtn := fontGui.Add("Button", "x10 yp+30 w120", "确定")
		fontGui.Add("Button", "x+150 yp w120", "取消").OnEvent("Click", (*) => fontGui.Destroy())

		okBtn.OnEvent("Click", (*) => (
			this.previewFontName := fontChoice.Text,
			this.previewFontSize := fontSizeEdit.Value,
			this.SetPreviewCandsBoxFont(),
			this.SetPreviewCandsBoxSize(),
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
			UIStyle.Update(config, true)
			rime.config_close(config)
            box.UpdateUIStyle()
		}

		this.gui.Hide()
	}

	GetPreviewCandsBoxRect(refClient := false) {
		previewTxtDim := GUIUtilities.GetTextDim(this.selCandsTxt, this.previewFontName, this.previewFontSize)
		previewCandsBoxW := previewTxtDim[1] + 30
		previewCandsBoxRowH := previewTxtDim[2] + 4
		previewCandsBoxX := Round((this.previewGroupW - previewCandsBoxW) / 2)
		previewCandsBoxY := Round((this.previewGroupH - previewCandsBoxRowH * 6) / 2)
		if refClient {
			previewCandsBoxX := previewCandsBoxX + this.themeListBoxW + 30
			previewCandsBoxY := previewCandsBoxY + 40
		}
		return [previewCandsBoxX, previewCandsBoxY, previewCandsBoxW, previewCandsBoxRowH]
	}

	SetPreviewCandsBoxFont() {
		fontSizeOpt := "s" . this.previewFontSize
		this.previewGuiPreedit.SetFont(fontSizeOpt, this.previewFontName)
		this.previewGuiSelCand.SetFont(fontSizeOpt, this.previewFontName)
		this.previewGuiCands.SetFont(fontSizeOpt, this.previewFontName)
	}

	SetPreviewCandsBoxSize() {
		p := this.GetPreviewCandsBoxRect(refClient := true)
		newX := p[1], newY := p[2], newW := p[3], newRowH := p[4]
		this.previewGuiPreedit.Move(newX, newY, newW, newRowH)
		this.previewGuiSelCand.Move(newX, newY + newRowH, newW, newRowH)
		this.previewGuiCands.Move(newX, newY + newRowH * 2, newW, newRowH * 4)
	}

	GetThemeColor(selTheme, isHighlight := false) {
		style := this.preset_color_schemes[selTheme]
		text_color := UIStyle.ParseColor(style["text_color"], "abgr", 0xff000000) & 0xffffff
		back_color := UIStyle.ParseColor(style["back_color"], "abgr", 0xffeceeee) & 0xffffff
		if isHighlight
			back_color := DarkenColor(back_color, 15)

		return Format("c{:x} Background{:x}", text_color, back_color)

		DarkenColor(color, percent) {
			factor := 1 - (percent / 100)

			r := (color >> 16) & 0xFF
			g := (color >> 8) & 0xFF
			b := color & 0xFF

			r := Min(Max(Round(r * factor), 0), 255)
			g := Min(Max(Round(g * factor), 0), 255)
			b := Min(Max(Round(b * factor), 0), 255)

			return (r << 16) | (g << 8) | b
		}
	}
}

Class GUIUtilities {
	static GetTextDim(text, fontName, fontSize) {
		hDC := DllCall("GetDC", "UPtr", 0)
		; fontHeight: Round(fontSize * A_ScreenDPI / 72)
		nHeight := -DllCall("MulDiv", "Int", fontSize, "Int", DllCall("GetDeviceCaps", "UPtr", hDC, "Int", 90), "Int", 72)
		; fontWeight: regular -> 400
		hFont := DllCall("CreateFont", "Int", nHeight, "Int", 0, "Int", 0, "Int", 0, "Int", fontWeight := 400, "UInt", false, "UInt", false, "UInt", false, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "WStr", fontName)
		DllCall("SelectObject", "UPtr", hDC, "UPtr", hFont, "UPtr")
		DllCall("GetTextExtentPoint32", "ptr", hDC, "WStr", text, "Int", StrLen(text), "int64*", &nSize := 0)

		DllCall("DeleteObject", "Uint", hFont)
		DllCall("ReleaseDC", "Uint", 0, "Uint", hDC)

		nWidth := nSize & 0xffffffff
		nHeight := nSize >> 32
		return [nWidth, nHeight]
	}

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
}
