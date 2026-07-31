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
    d2d := 0
    disposed := false

    __New(ctrl) {
        this.imgCtrl := ctrl
        this.d2d := Direct2D()
        this.dpiScale := this.d2d.GetDesktopDpiScale()
    }

    __Delete() {
        this.Dispose()
    }

    Dispose() {
        local old_bitmap
        if this.disposed {
            return
        }
        this.disposed := true
        if this.hBitmap {
            old_bitmap := 0
            try old_bitmap := SendMessage(0x0172, 0, 0, this.imgCtrl.Hwnd)
            if old_bitmap {
                DllCall("DeleteObject", "UPtr", old_bitmap)
                if old_bitmap == this.hBitmap {
                    this.hBitmap := 0
                }
            }
        }
        if this.hBitmap {
            DllCall("DeleteObject", "UPtr", this.hBitmap)
            this.hBitmap := 0
        }
        this.d2d := 0
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
        this.previewHeight := Ceil((this.candSize.h + this.lineSpacing) * 6) + this.lineSpacing * 2
            + this.borderWidth * 2 - this.lineSpacing ; Remove last line spacing
        calc_width := this.previewWidth
        calc_height := this.previewHeight
    }

    Render(candidates, selected_index) {
        local wic_render_target, background_x, background_y, background_width, background_height, background_radius
        local current_y, preedit_text_rect, highlighted_preedit_rect, i, candidate, candidate_color
        local highlight_x, highlight_y, highlight_width, highlight_height, text_to_draw, candidate_row_rect
        local new_bitmap, old_bitmap
        local STM_SETIMAGE
        local IMAGE_BITMAP
        wic_render_target := this.d2d.SetRenderTarget("wic", this.previewWidth, this.previewHeight)
        this.d2d.BeginDraw()

        if this.borderWidth > 0 {
            ; Draw outer border as filled rounded rectangle (border color)
            this.d2d.FillRoundedRectangle(
                0,
                0,
                this.previewWidth,
                this.previewHeight,
                this.boxCornerR,
                this.boxCornerR,
                this.borderColor
            )
            ; Draw inner background next
            background_x := this.borderWidth, background_y := this.borderWidth
            background_width := this.previewWidth - this.borderWidth * 2
            background_height := this.previewHeight - this.borderWidth * 2
            background_radius := this.boxCornerR > this.borderWidth ? this.boxCornerR - this.borderWidth : 0
            this.d2d.FillRoundedRectangle(
                background_x,
                background_y,
                background_width,
                background_height,
                background_radius,
                background_radius,
                this.backgroundColor
            )
        } else {
            this.d2d.FillRoundedRectangle(
                0,
                0,
                this.previewWidth,
                this.previewHeight,
                this.boxCornerR,
                this.boxCornerR,
                this.backgroundColor
            )
        }

        ; Draw preedit
        current_y := this.padding + this.borderWidth
        preedit_text_rect := {
            text: "RIME",
            x: this.padding + this.borderWidth,
            y: current_y,
            w: this.prdSelSize.w,
            h: this.prdSelSize.h
        }
        highlighted_preedit_rect := {
            text: "shu ru fa",
            x: this.padding + this.borderWidth + this.padding + this.prdSelSize.w,
            y: current_y,
            w: this.prdHlSize.w,
            h: this.prdHlSize.h
        }
        ; highlight background for preedit selection
        this.d2d.FillRoundedRectangle(
            highlighted_preedit_rect.x,
            highlighted_preedit_rect.y,
            highlighted_preedit_rect.w,
            highlighted_preedit_rect.h,
            this.hlCornerR,
            this.hlCornerR,
            this.hlBgColor
        )
        this.d2d.DrawText(
            preedit_text_rect.text,
            preedit_text_rect.x,
            preedit_text_rect.y,
            this.fontSize,
            this.textColor,
            this.fontName
        )
        this.d2d.DrawText(
            highlighted_preedit_rect.text,
            highlighted_preedit_rect.x,
            highlighted_preedit_rect.y,
            this.fontSize,
            this.hlTxtColor,
            this.fontName
        )
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
                this.d2d.FillRoundedRectangle(
                    highlight_x,
                    highlight_y,
                    highlight_width,
                    highlight_height,
                    this.hlCornerR,
                    this.hlCornerR,
                    this.hlCandBgColor
                )
            }

            text_to_draw := i . ". " . candidate
            candidate_row_rect := {
                x: this.padding + this.borderWidth,
                y: current_y,
                w: this.maxRowWidth,
                h: this.candSize.h
            }
            this.d2d.DrawText(
                text_to_draw,
                candidate_row_rect.x,
                candidate_row_rect.y,
                this.fontSize,
                candidate_color,
                this.fontName
            )
            current_y += this.candSize.h + this.lineSpacing
        }
        this.d2d.EndDraw()

        if (new_bitmap := wic_render_target.GetHBitmapFromWICBitmap()) {
            ; Replace preview image with hBitmap
            old_bitmap := SendMessage(
                STM_SETIMAGE := 0x0172,
                IMAGE_BITMAP := 0,
                new_bitmap,
                this.imgCtrl.Hwnd
            )
            if old_bitmap {
                DllCall("DeleteObject", "UPtr", old_bitmap)
            }
            this.hBitmap := new_bitmap
            this.d2d.Clear()
        }
    }
}
