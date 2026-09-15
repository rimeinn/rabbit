# 测试

Rabbit 现在使用一个轻量的仓库内测试入口。测试文件按资源边界分类，入口会逐文件启动 AutoHotkey 子进程，因此一个测试文件的窗口、热键或原生资源不会污染其他文件。现有 `RunTest`、断言和直接运行方式仍然保留。

## 测试结构

| 位置 | 内容 | 运行边界 |
| --- | --- | --- |
| `tests/unit/` | 纯模型、配置、数据转换和可控的业务逻辑 | 默认套件；不依赖真实 Rime 或人工窗口 |
| `tests/component/` | Rabbit 模块与 Windows 原生资源、窗口、字体或 Direct2D 的组合 | 独立进程；按改动选择性运行 |
| `tests/integration/` | 真实 Rime、部署、持久化和跨模块流程 | 需要 DLL、测试数据和桌面环境 |
| `tests/packaging/` | 编译资源、嵌入资源生命周期和编译后 DLL 选择 | 需要 Ahk2Exe、对应 base 和 Rime DLL；按 x86/x64 单独运行 |
| `tests/manual/` | 候选窗和设置预览等需要人工观察的测试 | 不属于默认或 `all` 套件 |
| `tests/benchmark/` | 性能探针 | 单独运行，不作为功能测试 |
| `tests/support/` | `RabbitTestPlan`、`RabbitTestRunner` 和兼容的 `RabbitTestCommon` | 测试基础设施 |
| `Lib/*/tests/` | 子模块自己的测试 | 保持子模块边界，由 Rabbit 入口提供可发现的适配项 |

`tests/unit/RabbitTests.ahk` 仍然是旧的聚合入口，供现有脚本和用户兼容使用；新的统一入口不会再依赖它的 include 列表。新增测试只需放入最合适的目录并使用 `RunTest` 注册，不需要修改聚合文件。

## 统一入口

查看可发现的测试：

```powershell
AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk --list
```

默认运行单元测试；也可以按套件、名称、标签筛选，并生成 CI 可消费的 JUnit 报告：

```powershell
AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk
AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk --suite component
AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk --suite integration
AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk --suite all --filter Settings
AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk --suite manual --tag visual
AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk --suite unit --junit tests\results\unit.xml
```

`--suite all` 包含 unit、component、integration 和 submodule，但排除 packaging、manual、benchmark。每个测试文件有独立的超时边界，默认 120 秒，可用 `--timeout 30000` 覆盖。标签可用 `--tag ci`、`--tag gui` 或 `--tag visual` 筛选；标签只决定选择，不改变测试的进程隔离边界。

当前标签按测试资源和运行环境表达：`unit/headless/ci`、`component/windows`、`gui`、`integration/rime`、`packaging/compiled/ci`、`manual/visual` 和 `benchmark/performance`；RimeDepot 与子模块适配项还带有 `rimedepot`、`submodule` 等标签。

候选窗测试的参数场景仍然可以直接运行：

```powershell
AutoHotkey.exe /ErrorStdOut tests\component\RabbitCandidateBoxTest.ahk factory-modern
AutoHotkey.exe /ErrorStdOut tests\component\RabbitCandidateBoxTest.ahk floating-preedit-placement
```

## 单元、组件和集成测试

单元测试适合快速验证纯逻辑。组件测试可能创建原生窗口、字体或 Direct2D 资源；集成测试还会初始化真实 Rime。运行后者前准备匹配当前 AutoHotkey 位数的 `Lib\librime-ahk\rime.dll`、专用 `Data/` 和可写的 Rime 用户目录。GUI 测试需要交互式桌面，不能以无桌面 CI 的通过作为人工视觉回归的替代。

修改绑定层时，继续使用 librime-ahk 自己的入口：

```powershell
AutoHotkey.exe /ErrorStdOut Lib\librime-ahk\tests\rime_test_main.ahk
```

RimeDepot 的核心和 GUI 测试也保留其子模块入口；它们不会混入 Rabbit 的 unit 聚合。

编译资源测试已迁移为 `packaging` 套件；生成嵌入资源的底层脚本仍然是 PowerShell，本地可这样运行：

```powershell
AutoHotkey.exe /ErrorStdOut tests\RabbitTestMain.ahk --suite packaging `
    --compiler path\to\Ahk2Exe.exe `
    --base path\to\AutoHotkey64.exe `
    --rime-dll path\to\rime-x64.dll `
    --architecture x64
```

它会临时生成编译资源、编译探针并检查共享资源、旧版安装脚本、DLL 选择和错误路径；结束后会恢复生成的 Rabbit include 和环境变量，隔离的编译产物位于 `dist/`。

## 按改动选择测试

| 改动范围 | 最小建议 |
| --- | --- |
| 配置解析、命令行、纯模型或数据转换 | `tests\RabbitTestMain.ahk --suite unit --filter <name>` |
| 候选布局、输入、字体或 Direct2D | 对应 unit/component 测试，加上 manual 预览和人工候选窗检查 |
| 设置页面、配色、预览、词典或部署 | 对应 component 测试，再按需运行 integration 或 manual |
| librime-ahk API、结构体或回调 | `Lib\librime-ahk\tests\rime_test_main.ahk`，以及受影响的 Rabbit 测试 |
| 编译资源、DLL 搜索、发行包目录 | `tests\RabbitTestMain.ahk --suite packaging ... --architecture x86/x64` |
| 仅文档 | `mkdocs build --strict`；不需要运行应用测试 |

应用 CI 的 `test-rabbit` 作业使用统一入口运行 Rabbit 的 unit 套件和需要保留的 RimeDepot 测试；编译构建作业则在 x86/x64 矩阵中运行 `packaging` 套件。普通 component/integration GUI 测试不会因为 unit 通过而自动执行。修改界面、候选窗或部署流程时，不能只以 CI 的 unit 结果代替本地人工回归。

## 测试失败与人工验证

新增单元测试时，按现有测试文件的方式使用测试运行器 `RunTest`，并根据终端中的失败用例和错误信息定位问题。单元测试与集成测试分别运行，集成测试需要额外准备匹配的 Rime DLL、本地数据和窗口环境。

启动 `Rabbit.ahk` 或已编译程序进行人工验证时，按普通应用行为检查输入、托盘、候选窗、设置和部署流程。至少覆盖普通启动、托盘打开设置、重新部署、同步、方案切换和退出；如果改动候选窗，还要分别检查现代后端和配置／系统触发的旧版后端。自动化测试应使用测试脚本已有的隔离和清理逻辑，不要为了测试改动发布入口脚本面向用户的默认异常行为。
