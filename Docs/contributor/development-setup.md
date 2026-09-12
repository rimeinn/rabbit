# 开发环境

## 获取源码

玉兔毫使用 Git 子模块提供 Rime 绑定、方案下载器和东风破资源。克隆仓库后初始化全部子模块：

```powershell
git submodule update --init --recursive
```

开发和 CI 以 AutoHotkey v2.0.19 为基线。源码运行还需要匹配当前 AutoHotkey 位数的 `rime.dll`、Rime 共享数据和用户数据；如果需要准备 Rime 数据或运行东风破脚本，还需要 Git for Windows 提供的 Bash 或可用的 WSL 环境。

三个子模块的职责不同：

| 路径 | 作用 | 修改原则 |
| --- | --- | --- |
| `Lib/librime-ahk` | librime 的 AutoHotkey 绑定及测试 | 绑定层改动应在子模块中独立提交，并更新子模块指针 |
| `Lib/RimeDepot` | 方案目录下载和安装服务 | 应用层适配放在 Rabbit 仓库；不要把应用逻辑写入子模块 |
| `plum` | 东风破安装脚本和资源 | 只有确实需要更新上游脚本时才修改 |

查看状态时同时检查主仓库和子模块：

```powershell
git status --short --branch
git submodule status --recursive
```

## 运行源码

在仓库根目录执行：

```powershell
AutoHotkey.exe Rabbit.ahk
AutoHotkey.exe Rabbit.ahk --deployer
AutoHotkey.exe Rabbit.ahk --deployer deploy
```

`Rabbit.ahk` 是唯一的顶层入口。不带参数时启动普通前端；第一个参数是 `--deployer` 时进入部署器模式，后续参数再由部署器解析。常用形式如下：

| 命令 | 作用 |
| --- | --- |
| `Rabbit.ahk` | 启动普通前端；默认执行部分维护 |
| `Rabbit.ahk --maintenance none` | 启动普通前端，但跳过启动维护 |
| `Rabbit.ahk --maintenance full` | 启动普通前端并执行完整维护 |
| `Rabbit.ahk --deployer` | 打开设置窗口 |
| `Rabbit.ahk --deployer settings appearance` | 打开设置窗口的指定页面 |
| `Rabbit.ahk --deployer deploy` | 执行完整 Rime 部署后退出 |
| `Rabbit.ahk --deployer sync` | 同步 Rime 用户数据后退出 |
| `Rabbit.ahk --deployer legacy-settings` | 显式使用兼容设置流程；普通 `settings` 在旧版 Windows 上也会自动降级到该流程 |

设置页面标识包括 `appearance`、`input-schemes`、`behavior`、`applications`、`dictionary`、`maintenance` 和 `about`。`legacy-settings` 还可以带 `dictionary` 打开旧版词典管理。`--keyboard-layout <数字>` 用于显式传入键盘布局标识；`--install` 只用于首次安装设置流程，`--return-to-rabbit` 用于部署器完成后返回主程序，通常由主程序内部传入。

命令行解析集中在 `Lib/RabbitCommandLine.ahk`。新增参数时要同步更新普通模式和部署器模式的测试，并明确参数属于哪一种模式；`deploy`、`sync` 不能再附加页面标识。

## 运行时目录与依赖

普通源码运行使用 `Lib/librime-ahk/rime.dll`。`RabbitRimeBootstrap` 在编译版中才会按版本、位数和 API 兼容性选择程序目录、`LIBRIME_LIB_DIR`、小狼毫安装目录或内嵌 DLL；不要用不匹配位数的 DLL 代替测试依赖。

Rabbit 将 Rime 数据分为共享数据和用户数据：

| 路径或设置 | 作用 |
| --- | --- |
| 程序目录 `Data/` | 共享数据、内置方案和预设配置，由构建流程准备 |
| 用户数据目录 | 保存 `rabbit.custom.yaml`、`default.custom.yaml`、用户词典、部署结果和学习数据 |
| `%TEMP%\rime.rabbit\` | Rime 日志目录 |

用户数据目录按以下顺序确定：程序目录存在 `.portable` 时使用程序目录下的 `Rime/`；否则读取 `HKCU\Software\Rime\Rabbit` 的 `RimeUserDir`；注册表设置无效时回退到程序目录下的 `Rime/`。运行测试或手动调试前，先确认当前用户目录没有被其他正在运行的 Rabbit 实例占用。

`Data/`、`Rime/`、DLL、图标和编译资源是生成或运行时文件，均不应提交。需要准备一套可运行环境时，可以使用发行包中的 `Data/`，并在隔离的用户目录中初始化 Rime；不要把个人用户数据复制回仓库。

## 编译辅助文件

源码运行不需要生成编译资源。编译单文件版本时，按照根目录 README 和 CI 脚本准备 `Data/`、图标、对应位宽的 Rime DLL，然后使用 `scripts/compiled-resource-manifest.json` 生成 `Lib/RabbitCompiledResources.ahk`：

```powershell
pwsh -File .github/scripts/generate-compiled-resources.ps1 `
    -ManifestPath scripts/compiled-resource-manifest.json `
    -OutputPath Lib/RabbitCompiledResources.ahk `
    -RimeDllPath path/to/rime.dll -Architecture x64
```

生成文件和测试产生的临时目录受 `.gitignore` 排除。修改资源清单时，同时检查源文件、编译版释放路径和 `RabbitCompiledResourcePolicy` 的提取行为；不要直接编辑生成的 `RabbitCompiledResources.ahk`。

## 代码边界

- `Rabbit.ahk` 只负责启动和模式分流；普通模式与 `--deployer` 模式分别进入对应应用类；
- 运行时状态、输入、候选窗、设置和部署逻辑放在 `Lib/` 的专门模块中；
- 新候选窗功能只面向现代候选窗；旧版候选窗需要回归保护；
- 不要把应用改动混入 `Lib/librime-ahk`、`Lib/RimeDepot` 或 `plum` 子模块；
- 每个模块声明自己的直接 `#Include` 依赖，不依赖入口脚本碰巧提供的包含顺序；
- 修改 UI、候选窗、托盘或部署行为时，同时更新对应测试和文档；
- 涉及配置字段时，同时检查 `schemas/rabbit.yaml`、配置快照、设置界面、默认值和用户文档；
- 涉及资源路径时，同时检查 `scripts/compiled-resource-manifest.json`、工作流路径过滤和编译版释放后的路径。
