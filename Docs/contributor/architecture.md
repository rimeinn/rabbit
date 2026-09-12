# 架构概览

本文按当前源码说明入口、生命周期和模块边界。类名和文件名以 `Lib/` 中的实现为准；
`Docs/runtime-architecture-refactoring.md` 是较完整的实现记录，但其中的阶段描述不应替代当前代码。

## 入口与模式分流

`Rabbit.ahk` 是唯一的顶层启动脚本。它不直接实现输入或界面，而是依次完成参数解析、编译资源释放、Rime 动态库准备，再选择普通前端或部署器应用：

```text
Rabbit.ahk
  -> RabbitEntryOptions.Parse(A_Args)
  -> RabbitCompiledResourcePolicy.ExtractIfCompiled()
  -> RabbitRimeBootstrap.Prepare()
  -> RimeApi(rime_path)
       +-- normal       -> RabbitApplication
       +-- --deployer   -> RabbitDeployerApplication
```

只有第一个参数是 `--deployer` 时才进入部署器模式；该参数会从传给应用的参数中移除。普通模式和部署器模式因此共享同一个启动入口，但拥有各自的应用对象、Rime 生命周期和参数解析器。

`RabbitRimeBootstrap` 的源码模式直接使用 `Lib/librime-ahk/rime.dll`。编译模式会检查 DLL 的文件版本、PE 位数和 API 版本，按顺序尝试程序目录、`LIBRIME_LIB_DIR`、小狼毫安装目录，最后释放内嵌 DLL。修改绑定或编译资源时，应同时查看 `RabbitRimeBootstrapTest.ahk` 和编译资源测试。

## 普通前端生命周期

```text
Rabbit.ahk
  -> RabbitApplication
       -> RabbitCreateTraits
       -> Rime.setup / initialize
       -> RabbitConfigLoader.Load
       -> RabbitCandidateBoxFactory.Create
       -> RabbitInputController
       -> RabbitRuntimeState
       -> RabbitTrayController
       -> RabbitAppearanceController
```

`RabbitApplication.Run()` 先解析维护级别和键盘布局，创建互斥体并初始化 Rime；随后加载 `rabbit`、`default` 及各输入方案配置，构建配置快照和候选窗。候选窗、输入控制器、运行时状态、托盘和外观控制器都在这里组装，但具体行为属于各自模块。

首次运行时，如果用户目录缺少必要的配置，主程序会启动同一个 `Rabbit.ahk` 的 `--deployer` 模式完成安装设置；部署器结束后按维护级别和键盘布局参数重新启动普通模式。托盘中的设置、词典和部署动作也采用相同的独立进程交接路径。

`RabbitAppContext` 保存普通前端的进程级资源。退出时由 `RabbitApplication` 先解除托盘消息和托盘对象，再由上下文释放输入热键、运行时定时器、外观消息、候选窗、状态提示、Rime 会话、Rime 实例和互斥体。新增资源必须有明确的所有者和幂等的 `Dispose()` 路径，不能依赖全局析构顺序。

## 候选窗

`RabbitCandidateBoxFactory` 根据系统版本和 `use_legacy_candidate_box` 配置选择后端：`RabbitIsOldWindows()` 为真或配置要求旧版时使用 `LegacyCandidateBox`，否则使用现代的 `CandidateBox`。新功能默认只加入现代后端；旧版后端需要保持原有行为并补充回归测试。

候选展示链路可按职责分为：

| 层次 | 主要模块 | 职责 |
| --- | --- | --- |
| 输入与数据 | `RabbitInput.ahk`、`RabbitCandidatePresentation.ahk` | 从 Rime 获取预编辑、候选、注释和选中状态，并处理提交、翻页和焦点变化 |
| 视口与布局 | `RabbitCandidateViewport.ahk`、`RabbitCandidateBox.ahk` | 计算页范围、堆叠／流式／竖排布局、浮动预编辑和动画 |
| 绘制与窗口 | `RabbitDirect2D.ahk`、`RabbitLayeredWindow.ahk`、`RabbitShadowSurface.ahk` | 创建字体和绘制资源，合成位图并更新不激活的分层窗口 |
| 兼容后端 | `RabbitLegacyCandidateBox.ahk`、`RabbitLegacyCandidateLayout.ahk` | 为旧版 Windows 保留独立的候选窗和布局路径 |

输入模块只产生候选展示所需的数据，候选后端负责布局、绘制、定位和命中测试。修改候选窗时，应先确认现代后端的布局和资源契约，再用旧版构建、定位和提交路径做回归。

## 配置与状态

`RabbitConfigLoader` 从 Rime 读取前端配置、默认按键和各方案按键，生成 `RabbitConfigSnapshot` 与 `RabbitUIStyleSnapshot`。普通运行时控制器读取快照，不应在输入回调中随意修改共享配置对象。Windows 主题变化由 `RabbitAppearanceController` 重新读取样式并更新候选窗和状态提示。

设置窗口通过 Rime Levers 的自定义设置接口读写用户配置，而不是修改程序目录中的共享 `Data/`。`RabbitDeploymentPlan` 将变更分为 `rabbit.yaml`、`default.yaml` 和完整工作区三种部署范围；设置页面只提交自己负责的变更，部署工作由 `RabbitDeployerWorkflow` 统一执行。

## 部署器

`Rabbit.ahk --deployer` 创建 `RabbitDeployerApplication`，再创建独立的 `RabbitDeployerContext` 和 `RabbitDeployerWorkflow`。部署器负责设置页面、重新部署、词典管理、资料同步和方案管理；它不复用普通前端的会话、托盘或上下文全局状态。

部署器的主要路径如下：

| 命令 | 工作流 |
| --- | --- |
| `settings [page]` | 打开现代设置窗口；页面包括外观、输入方案、行为、应用、词典、维护和关于 |
| `legacy-settings [dictionary]` | 使用兼容设置流程，或打开旧版词典管理 |
| `deploy` | 创建完整工作区部署计划并调用 Rime 部署 |
| `sync` | 同步用户数据并等待维护线程结束 |

设置窗口内部按页面懒加载模型和对话框；外观预览、输入方案下载和 RimeDepot 子窗口都有自己的资源释放路径。部署器完成后若要求返回主程序，会退出当前进程，再以普通模式启动 `Rabbit.ahk --maintenance ... --keyboard-layout ...`。

## 模块边界与扩展方式

按功能查找代码时可从以下入口开始：

| 功能 | 入口模块 | 相关实现 |
| --- | --- | --- |
| 启动与退出 | `Rabbit.ahk`、`RabbitApplication.ahk` | 参数、互斥体、Rime 初始化、退出清理 |
| 输入处理 | `RabbitInput.ahk` | 热键、焦点监视、密码框绕过、提交和候选更新 |
| 托盘与状态 | `RabbitTrayMenu.ahk`、`RabbitRuntimeState.ahk`、`RabbitStatusTip.ahk` | 菜单、状态标签、维护提示和状态窗口 |
| 设置与部署 | `RabbitSettingsWindow.ahk`、`RabbitDeployerWorkflow.ahk` | 设置页面、Levers、自定义配置和部署计划 |
| Rime 与资源 | `RabbitRimeBootstrap.ahk`、`RabbitCompiledResourcePolicy.ahk` | DLL 选择、编译资源释放和版本标记 |
| 外观与绘制 | `RabbitUIStyle*.ahk`、`RabbitDirect2D.ahk`、`RabbitFontSpec.ahk` | 样式快照、配色、字体、DPI 和绘制资源 |

每个模块必须声明直接 `#Include` 依赖，不要依赖入口脚本的包含顺序。实质性的新类单独放置文件；跨模块协作优先通过构造函数传递 Rime、模型或窗口依赖，避免新增隐式全局状态。涉及配置字段时，沿着“源配置／快照／设置读写／部署计划／测试／文档”整条链路检查；涉及资源时，确认异常、取消、重复打开和退出路径都能释放资源。

更细的所有权、生命周期和缺陷记录见[运行时架构重构记录](../runtime-architecture-refactoring.md)。这些记录描述实现过程，不是面向普通用户的 API 承诺。
