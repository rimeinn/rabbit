# 测试

测试分为 Rabbit 自己的单元测试、需要真实 Rime 或 Windows 资源的集成测试，以及两个子模块的独立测试。测试脚本大多是可以直接运行的入口，不通过根目录的统一启动器转发参数。

## 测试结构

| 位置 | 内容 | 特点 |
| --- | --- | --- |
| `tests/support/TestCommon.ahk` | Rabbit 测试共用的 `RunTest`、断言和失败报告 | 适合不依赖真实窗口或外部服务的测试 |
| `tests/unit/RabbitTests.ahk` | 大多数 Rabbit 单元测试的聚合入口 | 覆盖配置、模型、输入、候选数据、生命周期和命令行解析 |
| `tests/unit/RabbitCandidateBoxTest.ahk` | 候选窗布局、后端选择和资源生命周期测试 | 既可整套运行，也支持按参数运行指定场景 |
| `tests/integration/` | 真实 Rime、原生窗口、Direct2D／DirectWrite、字体和设置流程 | 需要按测试准备 DLL、数据和桌面环境 |
| `Lib/librime-ahk/tests/` | librime-ahk 绑定层测试 | 使用子模块自己的 `TestRunner` 和 JUnit 输出 |
| `Lib/RimeDepot/tests/` | RimeDepot 核心和 GUI 测试 | 属于子模块测试，不能混入 Rabbit 的单元测试聚合入口 |

`RunTest` 会逐个执行测试回调并报告 `PASS` 或 `FAIL`；失败报告包含测试名称和可用的错误位置、调用栈，测试入口会以失败状态结束。新增 Rabbit 单元测试时，在最接近被测模块的测试文件中注册 `RunTest`；只有需要改变进程参数或独立资源生命周期时，才新增独立测试入口。

## 单元测试

单元测试使用仓库内的 AutoHotkey 测试入口运行：

```powershell
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitTests.ahk
```

候选窗和 RimeDepot 相关单元测试没有全部并入 `RabbitTests.ahk`，需要单独运行：

```powershell
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitCandidateBoxTest.ahk
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitRimeDepotSettingsTest.ahk
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitRimeDepotWindowTest.ahk
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitSettingsRimeDepotTest.ahk
```

候选窗测试还支持按场景运行，例如：

```powershell
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitCandidateBoxTest.ahk factory-modern
AutoHotkey.exe /ErrorStdOut tests\unit\RabbitCandidateBoxTest.ahk floating-preedit-placement
```

这类参数测试适合验证后端选择、浮动预编辑和旧版兼容路径；`visual-modern` 与 `visual-legacy` 会打开实际候选窗，应在有桌面的交互式会话中运行。

修改绑定层时，单独运行：

```powershell
AutoHotkey.exe /ErrorStdOut Lib\librime-ahk\tests\rime_test_main.ahk
```

该入口使用 librime-ahk 自己的类测试运行器，并在子模块测试目录生成 `junit.xml`。绑定结构、原生函数指针、回调生命周期或 YAML 封装发生变化时，应优先运行它，而不是只运行 Rabbit 的模型测试。

## 集成测试

集成测试会初始化真实 Rime、创建原生窗口或 Direct2D 资源，不能并入普通单元测试入口。根据改动范围选择性运行，例如：

```powershell
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitCandidateBoxGuiTests.ahk visual-modern
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitCandidateBoxGuiTests.ahk visual-legacy
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitDeployerDialogTests.ahk
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitUIStylePreviewTests.ahk
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitSettingsStartupTests.ahk
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitSettingsPersistenceTests.ahk
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitFontFallbackTests.ahk
AutoHotkey.exe /ErrorStdOut tests\integration\RabbitPasswordFieldGuiTests.ahk
```

运行前准备匹配当前 AutoHotkey 位数的 `Lib\librime-ahk\rime.dll`、`Data/` 和可写的 Rime 用户目录。测试中的真实 Rime 通常使用仓库根目录的 `Data/` 与 `Rime/`；运行前应确认它们是专用测试数据，不要让测试修改日常用户词典。涉及候选窗、设置、字体或多显示器行为时，还需要在 Windows 上进行人工检查；GUI 测试不适合无桌面的 CI 环境。

编译资源的 PowerShell 测试由应用 CI 在编译作业中调用；本地具备 Ahk2Exe、对应基程序和 Rime DLL 时也可以单独运行：

```powershell
pwsh -File tests\integration\RabbitCompiledResourcesTests.ps1 `
    -Compiler path\to\Ahk2Exe.exe `
    -Base path\to\AutoHotkey64.exe `
    -RimeDll path\to\rime-x64.dll `
    -Architecture x64
```

它会临时生成编译资源、编译探针并检查共享资源、旧版安装脚本、DLL 选择和错误路径；测试结束后应确认生成文件、环境变量和临时目录均已恢复或被忽略。

## 按改动选择测试

| 改动范围 | 最小建议 |
| --- | --- |
| 配置解析、命令行、纯模型或数据转换 | `tests\unit\RabbitTests.ahk`，必要时运行对应独立单元入口 |
| 候选布局、输入、字体或 Direct2D | 候选窗单元测试，加上对应集成测试和人工候选窗检查 |
| 设置页面、配色、预览、词典或部署 | 对应设置／部署单元测试，加上 `tests\integration\` 中的窗口或持久化测试 |
| librime-ahk API、结构体或回调 | `Lib\librime-ahk\tests\rime_test_main.ahk`，以及受影响的 Rabbit 测试 |
| 编译资源、DLL 搜索、发行包目录 | `RabbitCompiledResourcesTests.ps1`，再检查 x86/x64 产物目录 |
| 仅文档 | `mkdocs build --strict`；不需要运行应用测试 |

应用 CI 当前在 `test-rabbit` 作业中运行 Rabbit 单元聚合入口、RimeDepot 的三个独立单元入口和两个 RimeDepot 测试入口；普通 `tests/integration/` GUI 测试不会因为单元测试通过而自动执行。修改界面、候选窗或部署流程时，不能只以 CI 的单元测试结果代替本地人工回归。

## 测试失败与人工验证

新增单元测试时，按现有测试文件的方式使用测试运行器 `RunTest`，并根据终端中的失败用例和错误信息定位问题。单元测试与集成测试分别运行，集成测试需要额外准备匹配的 Rime DLL、本地数据和窗口环境。

启动 `Rabbit.ahk` 或已编译程序进行人工验证时，按普通应用行为检查输入、托盘、候选窗、设置和部署流程。至少覆盖普通启动、托盘打开设置、重新部署、同步、方案切换和退出；如果改动候选窗，还要分别检查现代后端和配置／系统触发的旧版后端。自动化测试应使用测试脚本已有的隔离和清理逻辑，不要为了测试改动发布入口脚本面向用户的默认异常行为。
