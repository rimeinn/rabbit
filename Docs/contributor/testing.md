# 测试

## 单元测试

单元测试使用仓库内的 AutoHotkey 测试入口运行：

```powershell
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitTests.ahk
```

修改绑定层时，单独运行：

```powershell
AutoHotkey.exe /ErrorStdOut Lib\librime-ahk\tests\rime_test_main.ahk
```

## 集成测试

集成测试会初始化真实 Rime、创建原生窗口或 Direct2D 资源，不能并入普通单元测试入口。根据改动范围选择性运行，例如：

```powershell
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitDeployerDialogTests.ahk
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitUIStylePreviewTests.ahk
```

运行前准备匹配的 `rime.dll` 和本地 Rime 数据。涉及候选窗、设置、字体或多显示器行为时，还需要在 Windows 上进行人工检查。

## 测试失败与人工验证

新增单元测试时，按现有测试文件的方式使用测试运行器 `RunTest`，并根据终端中的失败用例和错误信息定位问题。单元测试与集成测试分别运行，集成测试需要额外准备匹配的 Rime DLL、本地数据和窗口环境。

启动 `Rabbit.ahk` 或已编译程序进行人工验证时，按普通应用行为检查输入、托盘、候选窗、设置和部署流程。自动化测试应使用测试脚本已有的隔离和清理逻辑，不要为了测试改动发布入口脚本面向用户的默认异常行为。
