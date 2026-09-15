#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\..\Lib\RabbitConfigToolTip.ahk

try {
    Main()
} catch as err {
    FileAppend("Uncaught exception: " . err.Message . "`n  at " . err.What . "`n  " . err.Line
        . "`nStack:`n" . err.Stack . "`n", "*")
    ExitApp(1)
}

Main() {
    global tooltip_probe_window
    tooltip_probe_window := Gui("-MaximizeBox -MinimizeBox", "Rabbit tooltip probe")
    tooltip_probe_window.SetFont("s10", "Microsoft YaHei UI")
    tooltip_probe_window.AddText("xm ym w340", "将鼠标悬停在下方控件上，等待系统提示出现：")
    local control := tooltip_probe_window.AddCheckbox("xm y+12 w340 h28", "测试配置路径提示")
    RabbitConfigToolTip.Apply("default", "punctuator/use_space", control)
    tooltip_probe_window.AddText("xm y+16 w340 cGray", "预期提示：default · punctuator/use_space")
    tooltip_probe_window.OnEvent("Close", (*) => ExitApp())
    tooltip_probe_window.Show("w380 h150")
}
