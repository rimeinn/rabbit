#Requires AutoHotkey v2.0
#SingleInstance Force

target_gui := Gui("+Hwndtarget_hwnd", "Caret Hook Target " . A_Pid)
target_edit := target_gui.AddEdit("x10 y10 w560 h80", "0123456789abcdefghijklmnopqrstuvwxyz")
target_gui.Show("w580 h110")
target_edit.Focus()
ControlSend("{Home}",, "ahk_id " . target_hwnd)
