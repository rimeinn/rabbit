/*
 * Copyright (c) 2023 - 2025 Xuesong Peng <pengxuesong.cn@gmail.com>
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
#Include <RabbitThemesUI>
#Include <Gdip/Gdip_All>

; https://learn.microsoft.com/windows/win32/winmsg/extended-window-styles
global WS_EX_NOACTIVATE := "+E0x8000000"
global WS_EX_COMPOSITED := "+E0x02000000"
global WS_EX_LAYERED    := "+E0x00080000"

class CandidateBox {
    pToken := 0
    gui := 0
    hDC := 0
    pBitmap := 0
    hBitmap := 0
    oBitmap := 0
    pGraphics := 0
    static isHidden := 1

    __New() {
        if !this.pToken {
            this.pToken := Gdip_Startup()
            if !this.pToken {
                MsgBox("GDI+ failed to start.")
                ExitApp
            }
        }
        ; +E0x8080088: WS_EX_NOACTIVATE | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST
        this.gui := Gui("-Caption +E0x8080088 +LastFound -DPIScale +AlwaysOnTop", "CandidateBox")
        this.dpiScale := GUIUtilities.GetMonitorDpiScale()

        this.UpdateUIStyle()
    }

    __Delete() {
        this.ReleaseAll()
    }

    UpdateUIStyle() {
        this.borderWidth := UIStyle.border_width
        this.borderColor := UIStyle.border_color
        this.boxCornerR := UIStyle.corner_radius
        this.hlCornerR := UIStyle.round_corner
        this.lineSpacing := UIStyle.margin_y
        this.padding := UIStyle.margin_x

        this.mainFontHs := this.CreateFontObj(UIStyle.font_face, UIStyle.font_point)
        this.labFontHs := this.CreateFontObj(UIStyle.label_font_face, UIStyle.label_font_point)
        this.commentFontHs := this.CreateFontObj(UIStyle.comment_font_face, UIStyle.comment_font_point)
        ; fallback fonts
        this.emojiFontHs := this.CreateFontObj("Segoe UI Emoji", UIStyle.font_point)
        this.symbolFontHs := this.CreateFontObj("Segoe UI Symbol", UIStyle.font_point)

        ; preedite style
        this.textColor := UIStyle.text_color
        this.backgroundColor := UIStyle.back_color
        this.hlTxtColor := UIStyle.hilited_text_color
        this.hlBgColor := UIStyle.hilited_back_color
        ; candidate style
        this.hlCandTxtColor := UIStyle.hilited_candidate_text_color
        this.hlCandBgColor := UIStyle.hilited_candidate_back_color
        this.candTxtColor := UIStyle.candidate_text_color
        this.candBgColor := UIStyle.candidate_back_color

        ; some color schemes have no these colors
        this.labelColor := UIStyle.label_color
        this.hlLabelColor := UIStyle.hilited_label_color
        this.commentTxtColor := UIStyle.comment_text_color
        this.hlCommentTxtColor := UIStyle.hilited_comment_text_color
    }

    CreateFontObj(name, size) {
        local em2pt := 96.0 / 72.0
        hFamily := Gdip_FontFamilyCreate(name)
        hFont := Gdip_FontCreate(hFamily, size * em2pt * this.dpiScale, regular := 0)
        hFormat := Gdip_StringFormatCreate(0x0001000 | 0x0004000) ; nowrap and noclip
        Gdip_SetStringFormatAlign(hFormat, left := 0) ; left:0, center:1, right:2
        ; vertical align(top:0, center:1, bottom:2)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", hFormat, "int", vCenter := 1)
        return { hFamily: hFamily, hFont: hFont, hFormat: hFormat }
    }

    Build(context, &winW, &winH) { ; build text layout
        local menu := context.menu
        local cands := menu.candidates
        this.num_candidates := menu.num_candidates
        this.hilited_index := menu.highlighted_candidate_index + 1

        GetCompositionText(context.composition, &pre_selected, &selected, &post_selected)
        this.prdSelTxt := pre_selected
        this.prdHlSelTxt := selected
        this.prdHlUnselTxt := post_selected

        local hDC := GetDC(this.gui.Hwnd)
        local pGraphics := Gdip_GraphicsFromHDC(hDC)

        CreateRectF(&RC, 0, 0, 0, 0)
        ; Build preedit layout
        baseX := this.borderWidth + this.padding
        baseY := this.borderWidth + this.lineSpacing
        prdSelTxtSlicedInfo := this.MakeSlicedStrsInfo(pGraphics, baseX, baseY, this.prdSelTxt, this.mainFontHs, &prdSelTxtBoxSize, &RC)
        prdHlSelTxtSize := this.MeasureString(pGraphics, this.prdHlSelTxt, this.mainFontHs, &RC)
        prdHlSelTxtX := baseX + prdSelTxtBoxSize.w + this.padding
        prdHlUnSelTxtSize := this.MeasureString(pGraphics, this.prdHlUnselTxt, this.mainFontHs, &RC)
        prdHlUnSelTxtX := prdHlSelTxtX + prdHlSelTxtSize.w
        this.preeditLayout := {
            selBox: { size: prdSelTxtBoxSize, sliced: prdSelTxtSlicedInfo }, ; prdSelTxt may contains unicode symbols
            hlSelBox: { size: prdHlSelTxtSize, rect: { x: prdHlSelTxtX, y: baseY,
                w: prdHlSelTxtSize.w, h: prdHlSelTxtSize.h } },
            hlUnSelBox: { size: prdHlUnSelTxtSize, rect: { x: prdHlUnSelTxtX, y: baseY, w: prdHlUnSelTxtSize.w, h: prdHlUnSelTxtSize.h } },
            left: baseX,
            top: baseY,
            width: prdSelTxtBoxSize.w + this.padding + prdHlSelTxtSize.w + prdHlUnSelTxtSize.w,
            height: Max(prdSelTxtBoxSize.h, prdHlSelTxtSize.h, prdHlUnSelTxtSize.h)
        }
        this.maxRowWidth := this.preeditLayout.width

        ; Build candidates layout
        totalRowsHeight := this.preeditLayout.height + this.lineSpacing
        baseY := baseY + totalRowsHeight
        this.candidatesLayout := { labels: [], cands: [], comments: [], rows: [] }

        has_label := !!context.select_labels[0]
        select_keys := menu.select_keys
        num_select_keys := StrLen(select_keys)

        ; candidates may contain unicode symbols
        Loop this.num_candidates {
            labelText := String(A_Index)
            if A_Index <= menu.page_size && has_label
                labelText := context.select_labels[A_Index] || labelText
            else if A_Index <= num_select_keys
                labelText := SubStr(select_keys, A_Index, 1)
            labelText := Format(UIStyle.label_format, labelText)
            labelSlicedInfo := this.MakeSlicedStrsInfo(pGraphics, baseX, baseY, labelText, this.labFontHs, &labelBoxSize, &RC)
            this.candidatesLayout.labels.Push({ size: labelBoxSize, sliced: labelSlicedInfo })

            candText := cands[A_Index].text
            candSlicedInfo := this.MakeSlicedStrsInfo(pGraphics, baseX + labelBoxSize.w, baseY, candText, this.mainFontHs, &candBoxSize, &RC)
            this.candidatesLayout.cands.Push({ size: candBoxSize, sliced: candSlicedInfo })

            commentText := cands[A_Index].comment
            commentSlicedInfo := this.MakeSlicedStrsInfo(pGraphics, baseX + labelBoxSize.w + candBoxSize.w, baseY, commentText, this.commentFontHs, &commentBoxSize, &RC)
            this.candidatesLayout.comments.Push({ size: commentBoxSize, sliced: commentSlicedInfo })

            rowRect := {
                x: baseX, y: baseY,
                w: labelBoxSize.w + candBoxSize.w + (commentText ? this.padding * 2 + commentBoxSize.w : 0),
                h: Max(labelBoxSize.h, candBoxSize.h, commentBoxSize.h)
            }
            this.candidatesLayout.rows.Push(rowRect)
            if (rowRect.w > this.maxRowWidth) {
                this.maxRowWidth := rowRect.w
            }
            increment := rowRect.h + this.lineSpacing
            baseY += increment, totalRowsHeight += increment
        }
        totalRowsHeight -= this.lineSpacing ; remove extra line spacing

        Gdip_DeleteGraphics(pGraphics)
        ReleaseDC(hDC, this.gui.Hwnd)

        this.commentOffset := 0
        this.boxWidth := Ceil(this.maxRowWidth) + (this.borderWidth + this.padding) * 2
        if this.boxWidth < UIStyle.min_width {
            this.commentOffset := UIStyle.min_width - this.boxWidth
            this.boxWidth := UIStyle.min_width
        }
        this.boxHeight := Ceil(totalRowsHeight) + (this.borderWidth + this.padding) * 2
        winW := this.boxWidth
        winH := this.boxHeight

        ; get better spacing to align comments
        loop this.num_candidates {
            labelW := this.candidatesLayout.labels[A_Index].size.w
            candW := this.candidatesLayout.cands[A_Index].size.w
            commentW := this.candidatesLayout.comments[A_Index].size.w
            if commentW > 0 {
                alignCommentGap := this.maxRowWidth - labelW - candW - commentW
                for _, info in this.candidatesLayout.comments[A_Index].sliced
                    info.x := info.x + alignCommentGap + this.commentOffset
            }
        }
    }

    Show(x, y) {
        if (this.gui && CandidateBox.isHidden) {
            this.gui.Show("NA")
            CandidateBox.isHidden := 0
        }

        this.hDC := CreateCompatibleDC()
        this.hBitmap := CreateDIBSection(this.boxWidth, this.boxHeight)
        this.oBitmap := SelectObject(this.hDC, this.hBitmap)
        this.pGraphics := Gdip_GraphicsFromHDC(this.hDC)
        Gdip_SetTextRenderingHint(this.pGraphics, AntiAliasGridFit := 3)
        Gdip_SetSmoothingMode(this.pGraphics, AntiAlias := 4)

        ; Draw border
        if (this.borderWidth > 0) {
            pBrushBorder := Gdip_BrushCreateSolid(this.borderColor)
            this.FillRoundedRect(this.pGraphics, pBrushBorder, 0, 0, this.boxWidth, this.boxHeight, this.boxCornerR)
            Gdip_DeleteBrush(pBrushBorder)
        }

        ; Draw background
        pBrushBg := Gdip_BrushCreateSolid(this.backgroundColor)
        bgX := this.borderWidth, bgY := this.borderWidth
        bgW := this.boxWidth - this.borderWidth * 2, bgH := this.boxHeight - this.borderWidth * 2
        bgCornerRadius := this.boxCornerR > this.borderWidth ? this.boxCornerR - this.borderWidth : 0
        this.FillRoundedRect(this.pGraphics, pBrushBg, bgX, bgY, bgW, bgH, bgCornerRadius)
        Gdip_DeleteBrush(pBrushBg)

        ; Draw preedit
        rectShrink := 2
        this.DrawSlicedTexts(this.pGraphics, this.mainFontHs, this.preeditLayout.height, this.preeditLayout.selBox.sliced, this.textColor)
        prdHlSelTxtRc := this.preeditLayout.hlSelBox.rect
        prdHlUnselTxtRc := this.preeditLayout.hlUnSelBox.rect
        if this.prdHlSelTxt {
            pBrsh_hlSelBg := Gdip_BrushCreateSolid(this.hlBgColor)
            Gdip_FillRoundedRectangle(this.pGraphics, pBrsh_hlSelBg, prdHlSelTxtRc.x - rectShrink, prdHlSelTxtRc.y, prdHlSelTxtRc.w, prdHlSelTxtRc.h - rectShrink, this.hlCornerR)
            Gdip_DeleteBrush(pBrsh_hlSelBg)
        }
        this.DrawText(this.pGraphics, this.mainFontHs, this.prdHlSelTxt, prdHlSelTxtRc, this.hlTxtColor)
        this.DrawText(this.pGraphics, this.mainFontHs, this.prdHlUnselTxt, prdHlUnselTxtRc, this.textColor)

        ; Draw candidates
        Loop this.num_candidates {
            rowRect := this.candidatesLayout.rows[A_Index]
            labelFg := this.labelColor
            candFg := this.candTxtColor
            commentFg := this.commentTxtColor
            if (A_Index == this.hilited_index) { ; Draw highlight if selected
                labelFg := this.hlLabelColor
                candFg := this.hlCandTxtColor
                commentFg := this.hlCommentTxtColor
                pBrsh_hlCandBg := Gdip_BrushCreateSolid(this.hlCandBgColor)
                Gdip_FillRoundedRectangle(this.pGraphics, pBrsh_hlCandBg, rowRect.x, rowRect.y, this.maxRowWidth, rowRect.h, this.hlCornerR)
                Gdip_DeleteBrush(pBrsh_hlCandBg)
            }

            this.DrawSlicedTexts(this.pGraphics, this.labFontHs, rowRect.h, this.candidatesLayout.labels[A_Index].sliced, labelFg)
            this.DrawSlicedTexts(this.pGraphics, this.mainFontHs, rowRect.h, this.candidatesLayout.cands[A_Index].sliced, candFg)

            commentLayout := this.candidatesLayout.comments[A_Index]
            if commentLayout.size.w > 0 {
                this.DrawSlicedTexts(this.pGraphics, this.commentFontHs, rowRect.h, commentLayout.sliced, commentFg)
            }
        }

        UpdateLayeredWindow(this.gui.Hwnd, this.hDC, x, y, this.boxWidth, this.boxHeight)
        this.ReleaseDrawingSurface()
    }

    Hide() {
        if (this.gui && !CandidateBox.isHidden) {
            this.gui.Show("Hide")
            CandidateBox.isHidden := 1
        }
    }

    ReleaseFonts() {
        DeleteFont(this.mainFontHs)
        DeleteFont(this.labFontHs)
        DeleteFont(this.commentFontHs)
        DeleteFont(this.emojiFontHs)
        DeleteFont(this.symbolFontHs)

        DeleteFont(fntHs) {
            if (fntHs.hFont)
                Gdip_DeleteFont(fntHs.hFont), fntHs.hFont := 0
            if (fntHs.hFamily)
                Gdip_DeleteFontFamily(fntHs.hFamily), fntHs.hFamily := 0
            if (fntHs.hFormat)
                Gdip_DeleteStringFormat(fntHs.hFormat), fntHs.hFormat := 0
        }
    }

    ReleaseDrawingSurface() {
        if (this.pGraphics) {
            Gdip_DeleteGraphics(this.pGraphics)
            this.pGraphics := 0
        }
        if (this.hDC && this.hBitmap) {
            SelectObject(this.hDC, this.oBitmap), DeleteObject(this.hBitmap)
            DeleteDC(this.hDC)
            this.oBitmap := 0, this.hBitmap := 0
            this.hDC := 0
        }
    }

    ReleaseAll() {
        this.ReleaseFonts()
        this.ReleaseDrawingSurface()

        if (this.pToken) {
            Gdip_Shutdown(this.pToken)
            this.pToken := 0
        }
        if (this.gui) {
            this.gui.Destroy()
        }
    }

    MeasureString(pGraphics, text, fontHs, &RectF) {
        if !text
            return { w: 0, h: 0 }

        rc := Buffer(16)
        DllCall("gdiplus\GdipMeasureString",
            "Ptr", pGraphics,
            "WStr", text,
            "Int", -1,
            "Ptr", fontHs.hFont,
            "Ptr", RectF.Ptr,
            "Ptr", fontHs.hFormat,
            "Ptr", rc.Ptr,
            "UInt*", 0,
            "UInt*", 0,
            "Int")

        return { w: NumGet(rc.Ptr, 8, "Float"), h: NumGet(rc.Ptr, 12, "Float") }
    }

    MakeSymbolsInfo(pGraphics, xOffset, yOffset, sType, cpArr, &symsBoxSize, &RectF) {
        symsInfoArr := []
        totalSymRowW := 0, maxSymRowH := 0
        curX := xOffset, rowY := yOffset
        isEmoji := sType == 2
        loop cpArr.Length {
            curCP := cpArr[A_Index]
            symSize := this.MeasureString(pGraphics, curCP, isEmoji ? this.emojiFontHs : this.symbolFontHs, &RectF)

            totalSymRowW += symSize.w
            if (symSize.h > maxSymRowH)
                maxSymRowH := symSize.h

            symsInfoArr.Push({
                x: curX,
                y: rowY,
                w: symSize.w,
                h: symSize.h,
                isEmoji: isEmoji
            })

            curX += symSize.w
        }

        symsBoxSize := { w: totalSymRowW, h: maxSymRowH }
        return symsInfoArr
    }

    MakeSlicedStrsInfo(pGraphics, xOffset, yOffset, text, fontHs, &textBoxSize, &RC) {
        if !text {
            textBoxSize := { w: 0, h: 0 }
            return []
        }

        ; slice text to pieces by emojis and special Symbols
        pattern := "([\x{1F000}-\x{1FAFF}\x{1F900}-\x{1F9FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{1D400}-\x{1D7FF}\x{200D}\x{FE0F}\x{FE0E}]+)"

        pieces := []
        pos := 1
        while (RegExMatch(text, pattern, &m, pos)) {
            start := m.Pos(1), length := m.Len(1)
            ; group normal text
            if (start > pos) {
                normal := SubStr(text, pos, start - pos)
                if (normal != "")
                    pieces.Push({ sType: 0, value: normal })
            }
            ; group emoji/unicode symbols with codePoints
            cpArr := getCodePoints(m[1])
            if RegExMatch(m[1], "^[\x{1F300}-\x{1FAFF}\x{1F900}-\x{1F9FF}\x{200D}\x{FE0F}\x{FE0E}]$") {
                pieces.Push({ sType: 2, value: cpArr })
            } else {
                pieces.Push({ sType: 1, value: cpArr })
            }

            pos := start + length
        }
        ; group remaining normal text
        if (pos <= StrLen(text)) {
            rest := SubStr(text, pos)
            if (rest != "")
                pieces.Push({ sType: 0, value: rest })
        }

        ; build sliced strings info
        slicedInfo := []
        totalRowW := 0, maxRowH := 0
        curX := xOffset, curY := yOffset
        for i, p in pieces {
            sType := p.sType
            content := p.value
            slicedSize := { w: 0, h: 0 }
            slicedSymsInfo := []
            if sType {
                slicedSymsInfo := this.MakeSymbolsInfo(pGraphics, curX, curY, sType, content, &symsBoxSize, &RC)
                slicedSize := symsBoxSize
            } else {
                slicedSize := this.MeasureString(pGraphics, content, fontHs, &RC)
            }
            totalRowW += slicedSize.w
            if (slicedSize.h > maxRowH)
                maxRowH := slicedSize.h

            slicedInfo.Push({
                x: curX,
                y: curY,
                w: slicedSize.w,
                h: slicedSize.h,
                sType: sType,
                slicedSymsInfo: slicedSymsInfo,
                value: content
            })

            curX += slicedSize.w
        }

        textBoxSize := { w: totalRowW, h: maxRowH }
        return slicedInfo

        getCodePoints(str) {
            arr := []
            i := 1, len := StrLen(str)

            ; only keep first codepoint in pair
            if (i <= len) {
                cp := Ord(SubStr(str, i, 1))
                if (cp >= 0xD800 && cp <= 0xDBFF && i < len) {
                    low := Ord(SubStr(str, i + 1, 1))
                    if (low >= 0xDC00 && low <= 0xDFFF) {
                        arr.Push(Chr(0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)))
                        i += 2
                    } else {
                        arr.Push(Chr(cp))
                        i++
                    }
                } else {
                    arr.Push(Chr(cp))
                    i++
                }
            }

            ; skip ZWJ, VS15/VS16
            while (i <= len) {
                cp := Ord(SubStr(str, i, 1))
                if (cp = 0x200D or cp = 0xFE0F or cp = 0xFE0E) {
                    i++
                    if (i <= len) {
                        cp2 := Ord(SubStr(str, i, 1))
                        if (cp2 >= 0xD800 && cp2 <= 0xDBFF && i < len)
                            i += 2
                        else
                            i++
                    }
                } else {
                    break
                }
            }

            return arr
        }
    }

    DrawText(pGraphics, fontHs, text, textRect, color) {
        this.pBrush := Gdip_BrushCreateSolid(color)
        CreateRectF(&RC, textRect.x, textRect.y, textRect.w, textRect.h)
        Gdip_DrawString(pGraphics, text, fontHs.hFont, fontHs.hFormat, this.pBrush, &RC)
        Gdip_DeleteBrush(this.pBrush)
    }

    DrawSlicedTexts(pGraphics, fontHs, rowMaxH, slicedStrsInfo, color) {
        this.pBrush := Gdip_BrushCreateSolid(color)
        loop slicedStrsInfo.Length {
            info := slicedStrsInfo[A_Index]
            info.h := rowMaxH
            if info.sType
                drawEmojiAndSymbols(this.pGraphics, this.pBrush, info)
            else
                drawNormalText(this.pGraphics, this.pBrush, fontHs, info)
        }
        Gdip_DeleteBrush(this.pBrush)

        drawNormalText(pGraphics, pBrush, fontHs, textInfo) {
            CreateRectF(&RC, textInfo.x, textInfo.y, textInfo.w, textInfo.h)
            Gdip_DrawString(pGraphics, textInfo.value, fontHs.hFont, fontHs.hFormat, pBrush, &RC)
        }

        drawEmojiAndSymbols(pGraphics, pBrush, textInfo) {
            cpArr := textInfo.value
            uSymsMaxH := textInfo.h
            uSymsInfo := textInfo.slicedSymsInfo
            loop cpArr.Length {
                CreateRectF(&RC, uSymsInfo[A_Index].x, uSymsInfo[A_Index].y, uSymsInfo[A_Index].w, uSymsMaxH)
                if uSymsInfo[A_Index].isEmoji
                    Gdip_DrawString(pGraphics, cpArr[A_Index], this.emojiFontHs.hFont, this.emojiFontHs.hFormat, pBrush, &RC)
                else { ; is unicode Symbols
                    Gdip_DrawString(pGraphics, cpArr[A_Index], this.symbolFontHs.hFont, this.symbolFontHs.hFormat, pBrush, &RC)
                }
            }
        }
    }

    FillRoundedRect(pGraphics, pBrush, x, y, w, h, r) {
        if (r <= 0) {
            Gdip_FillRectangle(pGraphics, pBrush, x, y, w, h)
        } else {
            Gdip_FillRoundedRectangle(pGraphics, pBrush, x, y, w, h, r)
        }
    }
}

class LegacyCandidateBox {
    static dbg := false
    static gui := 0
    static border := LegacyCandidateBox.dbg ? "+border" : 0

    __New() {
        this.UpdateUIStyle()
    }

    UpdateUIStyle() {
        ; alpha not supported
        del_opaque(color) {
            return color & 0xffffff
        }
        LegacyCandidateBox.text_color := del_opaque(UIStyle.text_color)
        LegacyCandidateBox.back_color := del_opaque(UIStyle.back_color)
        LegacyCandidateBox.candidate_text_color := del_opaque(UIStyle.candidate_text_color)
        LegacyCandidateBox.candidate_back_color := del_opaque(UIStyle.candidate_back_color)
        LegacyCandidateBox.label_color := del_opaque(UIStyle.label_color)
        LegacyCandidateBox.comment_text_color := del_opaque(UIStyle.comment_text_color)
        LegacyCandidateBox.hilited_text_color := del_opaque(UIStyle.hilited_text_color)
        LegacyCandidateBox.hilited_back_color := del_opaque(UIStyle.hilited_back_color)
        LegacyCandidateBox.hilited_candidate_text_color := del_opaque(UIStyle.hilited_candidate_text_color)
        LegacyCandidateBox.hilited_candidate_back_color := del_opaque(UIStyle.hilited_candidate_back_color)
        LegacyCandidateBox.hilited_label_color := del_opaque(UIStyle.hilited_label_color)
        LegacyCandidateBox.hilited_comment_text_color := del_opaque(UIStyle.hilited_comment_text_color)

        LegacyCandidateBox.base_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.text_color, LegacyCandidateBox.back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.candidate_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.candidate_text_color, LegacyCandidateBox.candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.label_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.label_color, LegacyCandidateBox.candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.comment_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.comment_text_color, LegacyCandidateBox.candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.hilited_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.hilited_text_color, LegacyCandidateBox.hilited_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.hilited_candidate_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.hilited_candidate_text_color, LegacyCandidateBox.hilited_candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.hilited_label_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.hilited_label_color, LegacyCandidateBox.hilited_candidate_back_color, LegacyCandidateBox.border)
        LegacyCandidateBox.hilited_comment_opt := Format("c{:x} Background{:x} {}", LegacyCandidateBox.hilited_comment_text_color, LegacyCandidateBox.hilited_candidate_back_color, LegacyCandidateBox.border)

        LegacyCandidateBox.base_font_opt := Format("s{} q5", UIStyle.font_point)
        LegacyCandidateBox.label_font_opt := Format("s{} q5", UIStyle.label_font_point)
        LegacyCandidateBox.comment_font_opt := Format("s{} q5", UIStyle.comment_font_point)

        if LegacyCandidateBox.gui {
            LegacyCandidateBox.gui.BackColor := LegacyCandidateBox.back_color
            LegacyCandidateBox.gui.MarginX := UIStyle.margin_x
            LegacyCandidateBox.gui.MarginY := UIStyle.margin_y

            if HasProp(LegacyCandidateBox.gui, "pre") && LegacyCandidateBox.gui.pre
                LegacyCandidateBox.gui.pre.Opt(LegacyCandidateBox.base_opt)
            if HasProp(LegacyCandidateBox.gui, "sel") && LegacyCandidateBox.gui.sel
                LegacyCandidateBox.gui.sel.Opt(LegacyCandidateBox.hilited_opt)
            if HasProp(LegacyCandidateBox.gui, "post") && LegacyCandidateBox.gui.post
                LegacyCandidateBox.gui.post.Opt(LegacyCandidateBox.base_opt)
        }
    }

    Build(context, &width, &height) {
        if !LegacyCandidateBox.gui || !LegacyCandidateBox.gui.built
            LegacyCandidateBox.gui := LegacyCandidateBox.BoxGui(context)
        else
            LegacyCandidateBox.gui.Update(context)
        width := LegacyCandidateBox.gui.max_width
        height := LegacyCandidateBox.gui.max_height
    }

    Show(x, y) {
        LegacyCandidateBox.gui.Show(Format("AutoSize NA x{} y{}", x, y))
    }

    Hide() {
        if LegacyCandidateBox.gui && HasMethod(LegacyCandidateBox.gui, "Show")
            LegacyCandidateBox.gui.Show("Hide")
    }

    class BoxGui extends Gui {
        built := false
        __New(context, &pre?, &sel?, &post?, &menu?) {
            super.__New(, , this)

            menu := context.menu
            local cands := menu.candidates
            local num_candidates := menu.num_candidates
            local hilited_index := menu.highlighted_candidate_index + 1
            local composition := context.composition
            GetCompositionText(composition, &pre, &sel, &post)

            this.Opt(Format("-DPIScale -Caption +Owner +AlwaysOnTop {} {} {}", WS_EX_NOACTIVATE, WS_EX_COMPOSITED, WS_EX_LAYERED))
            this.BackColor := LegacyCandidateBox.back_color
            this.SetFont(LegacyCandidateBox.base_font_opt, UIStyle.font_face)
            this.MarginX := UIStyle.margin_x
            this.MarginY := UIStyle.margin_y
            this.num_candidates := num_candidates
            this.has_comment := false

            ; build preedit
            this.max_width := 0
            this.preedit_height := 0
            local head_position := Format("x{} y{} section {}", this.MarginX, this.MarginY, LegacyCandidateBox.border)
            local position := head_position
            if pre {
                this.pre := this.AddText(position, pre)
                this.pre.Opt(LegacyCandidateBox.base_opt)
                position := Format("x+{} ys {}", this.MarginX, LegacyCandidateBox.border)
                this.pre.GetPos(, , &w, &h)
                this.preedit_height := max(this.preedit_height, h)
                this.pre_width := w
                this.max_width += (w + this.MarginX)
            }
            if sel {
                this.sel := this.AddText(position, sel)
                this.sel.Opt(LegacyCandidateBox.hilited_opt)
                position := Format("x+{} ys {}", this.MarginX, LegacyCandidateBox.border)
                this.sel.GetPos(, , &w, &h)
                this.preedit_height := max(this.preedit_height, h)
                this.sel_width := w
                this.max_width += (w + this.MarginX)
            }
            if post {
                this.post := this.AddText(position, post)
                this.post.Opt(LegacyCandidateBox.base_opt)
                this.post.GetPos(, , &w, &h)
                this.preedit_height := max(this.preedit_height, h)
                this.post_width := w
                this.max_width += w
            }

            ; build candidates
            this.max_label_width := 0
            this.max_candidate_width := 0
            this.max_comment_width := 0
            this.candidate_height := 0
            local has_label := !!context.select_labels[0]
            local select_keys := menu.select_keys
            local num_select_keys := StrLen(select_keys)
            loop num_candidates {
                position := Format("xs y+{} section {}", this.MarginY, LegacyCandidateBox.border)
                local label_text := String(A_Index)
                if A_Index <= menu.page_size && has_label
                    label_text := context.select_labels[A_Index]
                else if A_Index <= num_select_keys
                    label_text := SubStr(select_keys, A_Index, 1)
                label_text := Format(UIStyle.label_format, label_text)
                this.SetFont(LegacyCandidateBox.label_font_opt, UIStyle.label_font_face)
                local label := this.AddText(Format("Right {} vL{}", position, A_Index), label_text)
                label.GetPos(, , &w, &h1)
                this.max_label_width := max(this.max_label_width, w + this.MarginX)

                position := Format("x+{} ys {}", this.MarginX, LegacyCandidateBox.border)
                this.SetFont(LegacyCandidateBox.base_font_opt, UIStyle.font_face)
                local candidate := this.AddText(Format("{} vC{}", position, A_Index), cands[A_Index].text)
                candidate.GetPos(, , &w, &h2)
                this.max_candidate_width := max(this.max_candidate_width, w + this.MarginX)

                if comment_text := cands[A_Index].comment
                    this.has_comment := true
                this.SetFont(LegacyCandidateBox.comment_font_opt, UIStyle.comment_font_face)
                local comment := this.AddText(Format("{} vM{}", position, A_Index), comment_text)
                comment.GetPos(, , &w, &h3)
                comment.Opt(Format("c{:x}", LegacyCandidateBox.comment_text_color))
                comment.Visible := this.has_comment
                this.max_comment_width := max(this.max_comment_width, w)
                this.candidate_height := max(this.candidate_height, h1, h2, h3)

                if A_Index == hilited_index {
                    label.Opt(LegacyCandidateBox.hilited_label_opt)
                    candidate.Opt(LegacyCandidateBox.hilited_candidate_opt)
                    comment.Opt(LegacyCandidateBox.hilited_comment_opt)
                } else {
                    label.Opt(LegacyCandidateBox.label_opt)
                    candidate.Opt(LegacyCandidateBox.candidate_opt)
                    comment.Opt(LegacyCandidateBox.comment_opt)
                }
            }

            ; adjust width height
            local list_width := this.max_label_width + this.max_candidate_width + this.has_comment * this.max_comment_width
            local box_width := max(UIStyle.min_width, list_width)
            if box_width > this.max_width && HasProp(this, "post") && this.post
                this.post.Move(, , this.post_width + box_width - this.max_width)
            this.max_width := max(box_width, this.max_width)
            if this.max_width > list_width {
                this.max_candidate_width += this.max_width - list_width
                loop num_candidates
                    this["C" . A_Index].Move(, , this.max_candidate_width)
            }
            local y := 2 * this.MarginY + this.preedit_height
            loop num_candidates {
                local x := this.MarginX
                this["L" . A_Index].Move(x, y, this.max_label_width)
                this["L" . A_Index].GetPos(, , , &h)
                local max_h := h
                x += this.max_label_width
                this["C" . A_Index].Move(x, y, this.max_candidate_width)
                this["C" . A_Index].GetPos(, , , &h)
                max_h := max(max_h, h)
                x += this.max_candidate_width
                this["M" . A_Index].Move(x, y, this.max_comment_width)
                this["M" . A_Index].GetPos(, , , &h)
                max_h := max(max_h, h)
                y += (max_h + this.MarginY)
            }
            this.max_height := y
            this.max_width += (2 * this.MarginX)

            this.built := true
        }

        Update(context) {
            local fake_gui := LegacyCandidateBox.BoxGui(context, &pre, &sel, &post, &menu)
            local num_candidates := menu.num_candidates
            local hilited_index := menu.highlighted_candidate_index + 1
            this.SetFont(LegacyCandidateBox.base_font_opt, UIStyle.font_face)
            this.num_candidates := max(this.num_candidates, num_candidates)
            this.max_width := fake_gui.max_width
            this.max_height := fake_gui.max_height

            ; reset preedit
            if pre {
                if !HasProp(this, "pre") || !this.pre
                    this.pre := this.AddText(, pre)
                this.pre.Value := fake_gui.pre.Value
                fake_gui.pre.GetPos(&x, &y, &w, &h)
                this.pre.Move(x, y, w, h)
            }
            if HasProp(this, "pre") && this.pre
                this.pre.Visible := !!pre
            if sel {
                if !HasProp(this, "sel") || !this.sel
                    this.sel := this.AddText(, sel)
                this.sel.Value := fake_gui.sel.Value
                fake_gui.sel.GetPos(&x, &y, &w, &h)
                this.sel.Move(x, y, w, h)
            }
            if HasProp(this, "sel") && this.sel
                this.sel.Visible := !!sel
            if post {
                if !HasProp(this, "post") || !this.post
                    this.post := this.AddText(, post)
                this.post.Value := fake_gui.post.Value
                fake_gui.post.GetPos(&x, &y, &w, &h)
                this.post.Move(x, y, w, h)
            }
            if HasProp(this, "post") && this.post
                this.post.Visible := !!post

            ; reset candidates
            loop this.num_candidates {
                if A_Index > num_candidates {
                    this["L" . A_Index].Visible := false
                    this["C" . A_Index].Visible := false
                    this["M" . A_Index].Visible := false
                    continue
                }
                local fake_label := fake_gui["L" . A_Index]
                local fake_candidate := fake_gui["C" . A_Index]
                local fake_comment := fake_gui["M" . A_Index]
                this.SetFont(LegacyCandidateBox.label_font_opt, UIStyle.label_font_face)
                try
                    local label := this["L" . A_Index]
                catch
                    local label := this.AddText(Format("vL{}", A_Index), fake_label.Value)
                this.SetFont(LegacyCandidateBox.base_font_opt, UIStyle.font_face)
                try
                    local candidate := this["C" . A_Index]
                catch
                    local candidate := this.AddText(Format("vC{}", A_Index), fake_candidate.Value)
                this.SetFont(LegacyCandidateBox.comment_font_opt, UIStyle.comment_font_face)
                try
                    local comment := this["M" . A_Index]
                catch
                    local comment := this.AddText(Format("vM{}", A_Index), fake_comment.Value)
                label.Value := fake_label.Value
                fake_label.GetPos(&x, &y, &w, &h)
                label.Move(x, y, w, h)
                candidate.Value := fake_candidate.Value
                fake_candidate.GetPos(&x, &y, &w, &h)
                candidate.Move(x, y, w, h)
                comment.Value := fake_comment.Value
                fake_comment.GetPos(&x, &y, &w, &h)
                comment.Move(x, y, w, h)

                if A_Index == hilited_index {
                    label.Opt(LegacyCandidateBox.hilited_label_opt)
                    candidate.Opt(LegacyCandidateBox.hilited_candidate_opt)
                    comment.Opt(LegacyCandidateBox.hilited_comment_opt)
                } else {
                    label.Opt(LegacyCandidateBox.label_opt)
                    candidate.Opt(LegacyCandidateBox.candidate_opt)
                    comment.Opt(LegacyCandidateBox.comment_opt)
                }
                local visible := (A_Index <= num_candidates)
                label.Visible := visible
                candidate.Visible := visible
                comment.Visible := (fake_gui.has_comment && visible)
            }

            fake_gui.GetPos(, , &width, &height)
            this.Move(, , width, height)
        }
    }
}

GetCompositionText(composition, &pre_selected, &selected, &post_selected) {
    pre_selected := ""
    selected := ""
    post_selected := ""
    if not preedit := composition.preedit
        return false

    static cursor_text := "‸" ; or 𝙸
    static cursor_size := StrPut(cursor_text, "UTF-8") - 1 ; do not count tailing null

    local preedit_length := StrPut(preedit, "UTF-8")
    local selected_start := composition.sel_start
    local selected_end := composition.sel_end

    local preedit_buffer ; insert caret text into preedit text if applicable
    if 0 <= composition.cursor_pos and composition.cursor_pos <= preedit_length {
        preedit_buffer := Buffer(preedit_length + cursor_size, 0)
        local temp_preedit := Buffer(preedit_length, 0)
        StrPut(preedit, temp_preedit, "UTF-8")
        local src := temp_preedit.Ptr
        local tgt := preedit_buffer.Ptr
        Loop composition.cursor_pos {
            byte := NumGet(src, A_Index - 1, "Char")
            NumPut("Char", byte, tgt, A_Index - 1)
        }
        src := src + composition.cursor_pos
        tgt := tgt + composition.cursor_pos
        StrPut(cursor_text, tgt, "UTF-8")
        tgt := tgt + cursor_size
        Loop preedit_length - composition.cursor_pos {
            byte := NumGet(src, A_Index - 1, "Char")
            NumPut("Char", byte, tgt, A_Index - 1)
        }
        preedit_length := preedit_length + cursor_size
        if selected_start >= composition.cursor_pos
            selected_start := selected_start + cursor_size
        if selected_end > composition.cursor_pos
            selected_end := selected_end + cursor_size
    } else {
        preedit_buffer := Buffer(preedit_length, 0)
        StrPut(preedit, preedit_buffer, "UTF-8")
    }

    if 0 <= selected_start and selected_start < selected_end and selected_end <= preedit_length {
        pre_selected := StrGet(preedit_buffer, selected_start, "UTF-8")
        selected := StrGet(preedit_buffer.Ptr + selected_start, selected_end - selected_start, "UTF-8")
        post_selected := StrGet(preedit_buffer.Ptr + selected_end, "UTF-8")
        return true
    } else {
        pre_selected := StrGet(preedit_buffer, "UTF-8")
        return false
    }
}
