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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

class RabbitConfigToolTip {
    static ICC_WIN95_CLASSES := 0x000000FF
    static TTS_ALWAYSTIP := 0x01
    static TTS_NOPREFIX := 0x02
    static TTF_IDISHWND := 0x0001
    static TTF_SUBCLASS := 0x0010
    static TTM_ADDTOOLW := 0x0400 + 50
    static TTM_UPDATETIPTEXTW := 0x0400 + 57
    static tooltips := Map()

    static Format(config_id, path) {
        return config_id . " · " . path
    }

    static Apply(config_id, path, controls*) {
        local control, text := this.Format(config_id, path)
        for control in controls {
            if control {
                this.Attach(control, text)
            }
        }
        return text
    }

    static GetText(control) {
        return this.GetTextByHwnd(control.Gui.Hwnd, control.Hwnd)
    }

    static GetTextByHwnd(owner_hwnd, control_hwnd) {
        if !this.tooltips.Has(owner_hwnd) {
            return ""
        }
        local tooltip := this.tooltips[owner_hwnd]
        return tooltip.texts.Has(control_hwnd) ? StrGet(tooltip.texts[control_hwnd], "UTF-16") : ""
    }

    static Attach(control, text) {
        local child_hwnd, owner_hwnd
        owner_hwnd := control.Gui.Hwnd
        this.AttachHwnd(owner_hwnd, control.Gui, control.Hwnd, text)
        if control.Type = "ComboBox" && (child_hwnd := DllCall(
            "User32\GetWindow",
            "Ptr",
            control.Hwnd,
            "UInt",
            5,
            "Ptr"
        )) {
            this.AttachHwnd(owner_hwnd, control.Gui, child_hwnd, text)
        }
    }

    static AttachHwnd(owner_hwnd, owner, control_hwnd, text) {
        local info, text_buffer, tooltip
        tooltip := this.GetOrCreate(owner_hwnd, owner)
        text_buffer := Buffer((StrLen(text) + 1) * 2, 0)
        StrPut(text, text_buffer, "UTF-16")
        info := this.CreateToolInfo(owner_hwnd, control_hwnd, text_buffer)
        if tooltip.texts.Has(control_hwnd) {
            DllCall(
                "User32\SendMessageW",
                "Ptr",
                tooltip.hwnd,
                "UInt",
                this.TTM_UPDATETIPTEXTW,
                "Ptr",
                0,
                "Ptr",
                info,
                "Ptr"
            )
        } else {
            if !DllCall(
                "User32\SendMessageW",
                "Ptr",
                tooltip.hwnd,
                "UInt",
                this.TTM_ADDTOOLW,
                "Ptr",
                0,
                "Ptr",
                info,
                "Ptr"
            ) {
                throw OSError()
            }
        }
        tooltip.texts[control_hwnd] := text_buffer
    }

    static GetOrCreate(owner_hwnd, owner) {
        local init, tooltip
        if this.tooltips.Has(owner_hwnd) {
            tooltip := this.tooltips[owner_hwnd]
            if DllCall("User32\IsWindow", "Ptr", tooltip.hwnd, "Int") {
                return tooltip
            }
            this.tooltips.Delete(owner_hwnd)
        }
        init := Buffer(8, 0)
        NumPut("UInt", init.Size, init, 0)
        NumPut("UInt", this.ICC_WIN95_CLASSES, init, 4)
        if !DllCall("Comctl32\InitCommonControlsEx", "Ptr", init) {
            throw OSError()
        }
        tooltip := {
            hwnd: DllCall(
                "User32\CreateWindowExW",
                "UInt",
                0x00000008,
                "Str",
                "tooltips_class32",
                "Ptr",
                0,
                "UInt",
                0x80000000 | this.TTS_ALWAYSTIP | this.TTS_NOPREFIX,
                "Int",
                -2147483648,
                "Int",
                -2147483648,
                "Int",
                -2147483648,
                "Int",
                -2147483648,
                "Ptr",
                owner_hwnd,
                "Ptr",
                0,
                "Ptr",
                0,
                "Ptr",
                0,
                "Ptr"
            ),
            texts: Map(),
        }
        if !tooltip.hwnd {
            throw OSError()
        }
        this.tooltips[owner_hwnd] := tooltip
        owner.OnEvent("Close", RabbitConfigToolTip.DisposeGui.Bind(owner_hwnd))
        return tooltip
    }

    static CreateToolInfo(owner_hwnd, control_hwnd, text_buffer) {
        local info := Buffer(A_PtrSize = 8 ? 72 : 48, 0)
        local offset := 8
        NumPut("UInt", info.Size, info, 0)
        NumPut("UInt", this.TTF_IDISHWND | this.TTF_SUBCLASS, info, 4)
        NumPut("Ptr", owner_hwnd, info, offset)
        offset += A_PtrSize
        NumPut("Ptr", control_hwnd, info, offset)
        offset += A_PtrSize + 16
        NumPut("Ptr", 0, info, offset)
        offset += A_PtrSize
        NumPut("Ptr", text_buffer.Ptr, info, offset)
        return info
    }

    static DisposeGui(owner_hwnd, args*) {
        if !RabbitConfigToolTip.tooltips.Has(owner_hwnd) {
            return
        }
        local tooltip := RabbitConfigToolTip.tooltips[owner_hwnd]
        RabbitConfigToolTip.tooltips.Delete(owner_hwnd)
        if DllCall("User32\IsWindow", "Ptr", tooltip.hwnd, "Int") {
            DllCall("User32\DestroyWindow", "Ptr", tooltip.hwnd)
        }
    }
}
