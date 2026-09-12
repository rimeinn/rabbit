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

## 错误可观察性

测试入口必须通过现有测试运行器或顶层 `try/catch` 输出异常消息、位置和调用栈，并以非零状态退出。不能把不可见的 AutoHotkey 原生错误对话框当作测试结果。

应用启动脚本保留面向最终用户的默认异常行为；若需要在自动化中测试它们，应使用单独的可观察异常边界，而不是修改已发布的入口脚本。
