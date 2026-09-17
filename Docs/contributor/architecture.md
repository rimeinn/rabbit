# 架构概览

本文按当前源码说明入口、生命周期和模块边界。类名和文件名以 `Lib/` 中的实现为准；
`Docs/design/runtime-architecture-refactoring.md` 是较完整的实现记录，但其中的阶段描述不应替代当前代码。
控制面板迁入常驻进程及异步部署 worker 的设计与实施记录见
`Docs/design/control-panel-runtime-refactoring.md`。

## 入口与模式分流

`Rabbit.ahk` 是唯一的顶层启动脚本。它不直接实现输入或界面，而是依次完成参数解析、编译资源释放、Rime 动态库
准备，再选择常驻前端、兼容部署器或隔离维护 worker：

```text
Rabbit.ahk
  -> RabbitEntryOptions.Parse(A_Args)
  -> RabbitCompiledResourcePolicy.ExtractIfCompiled()
  -> RabbitRimeBootstrap.Prepare()
  -> RimeApi(rime_path)
       +-- normal               -> RabbitApplication
       +-- --deployer           -> RabbitDeployerApplication
       +-- --deployer-worker    -> RabbitDeployerWorkerApplication
```

`RabbitEntryOptions` 只识别首个参数中的 `--deployer` 和 `--deployer-worker`，并把其余参数交给对应应用解析。
普通模式持有现代设置和输入运行时；`--deployer` 保留旧版设置及外部 `deploy`／`sync` 入口；
`--deployer-worker` 只由 `RabbitDeploymentCoordinator` 启动，不是公开命令行界面。三个模式共享启动入口，
但使用各自的应用对象和参数模型。

`RabbitRimeBootstrap` 的源码模式直接使用 `Lib/librime-ahk/rime.dll`。编译模式会检查 DLL 的文件版本、PE 位数和 API 版本，按顺序尝试程序目录、`LIBRIME_LIB_DIR`、小狼毫安装目录，最后释放内嵌 DLL。修改绑定或编译资源时，应同时查看 `RabbitRimeBootstrapTest.ahk` 和编译资源测试。

## 普通前端生命周期

```text
Rabbit.ahk
  -> RabbitApplication
       -> RabbitSettingsController
       -> RabbitTrayController
       -> RabbitDeploymentCoordinator
       -> RabbitMaintenanceIpcServer
       -> RabbitFrontendRuntime
            -> RabbitCreateTraits / Rime.setup / initialize
            -> RabbitConfigLoader.Load
            -> RabbitCandidateBoxFactory.Create
            -> RabbitInputController
            -> RabbitRuntimeState
            -> RabbitAppearanceController
```

`RabbitApplication.Run()` 解析维护级别和键盘布局并取得应用互斥体，然后创建设置控制器、托盘、部署协调器，
再启动一个 `RabbitFrontendRuntime`。运行时负责初始化 Rime、加载 `rabbit`、`default` 及各输入方案配置，
并组装候选窗、输入控制器、运行时状态和外观控制器。设置窗口、托盘和部署协调器属于常驻应用，输入运行时则可在
维护前停止、完成后以新配置重建。

首次运行时，现代 Windows 直接由 `RabbitSettingsController.ShowInstallation()` 在常驻进程中打开安装页面；
旧版 Windows 才交给 `--deployer legacy-settings` 兼容流程。托盘中的现代设置、词典和同步入口都打开常驻设置窗口。
设置保存、重新部署、同步和现代词典操作交给 `RabbitDeploymentCoordinator`，不退出顶层窗口。

`RabbitAppContext` 保存一次输入运行时的资源。停止运行时时，它依次释放输入热键、定时器、外观消息、候选窗、
状态提示、Rime 会话和 Rime 生命周期，并从常驻托盘解绑。进程退出时，`RabbitApplication` 还会释放 IPC、部署协调器、
设置窗口、托盘和应用互斥体。新增资源必须有明确的所有者和幂等的 `Dispose()` 路径，不能依赖全局析构顺序。

## 候选窗

`RabbitCandidateBoxFactory` 根据系统版本和 `use_legacy_candidate_box` 配置选择后端：`RabbitIsOldWindows()` 为真或配置要求旧版时使用 `LegacyCandidateBox`，否则使用现代的 `CandidateBox`。新功能默认只加入现代后端；旧版后端需要保持原有行为并补充回归测试。

候选展示链路可按职责分为：

| 层次 | 主要模块 | 职责 |
| --- | --- | --- |
| 输入与数据 | `RabbitInput.ahk`、`RabbitCandidatePresentation.ahk` | 从 Rime 获取预编辑、候选、注释和选中状态，并处理提交、翻页和焦点变化 |
| 视口与布局 | `RabbitCandidateViewport.ahk`、`RabbitCandidateBox.ahk` | 计算页范围、“纵向堆叠”／“横向流式”／“竖排文字”布局、浮动预编辑和动画 |
| 绘制与窗口 | `RabbitDirect2D.ahk`、`RabbitLayeredWindow.ahk`、`RabbitShadowSurface.ahk` | 创建字体和绘制资源，合成位图并更新不激活的分层窗口 |
| 兼容后端 | `RabbitLegacyCandidateBox.ahk`、`RabbitLegacyCandidateLayout.ahk` | 为旧版 Windows 保留独立的候选窗和布局路径 |

输入模块只产生候选展示所需的数据，候选后端负责布局、绘制、定位和命中测试。修改候选窗时，应先确认现代后端的布局和资源契约，再用旧版构建、定位和提交路径做回归。

## 配置与状态

`RabbitConfigLoader` 从 Rime 读取前端配置、默认按键和各方案按键，生成 `RabbitConfigSnapshot` 与 `RabbitUIStyleSnapshot`。普通运行时控制器读取快照，不应在输入回调中随意修改共享配置对象。Windows 主题变化由 `RabbitAppearanceController` 重新读取样式并更新候选窗和状态提示。

设置窗口通过 Rime Levers 的自定义设置接口读写用户配置，而不是修改程序目录中的共享 `Data/`。
`RabbitDeploymentPlan` 将变更分为 `rabbit.yaml`、`default.yaml`、单个方案和完整工作区等部署范围；设置页面只提交
自己负责的变更。`RabbitSettingsController` 在维护前释放后端配置句柄，`RabbitDeploymentCoordinator` 停止输入运行时、
启动隔离 worker，完成后重建运行时并刷新仍然打开的设置窗口。

## 设置与维护进程

现代设置窗口由 `RabbitApplication` 中的 `RabbitSettingsController` 持有。重复打开时会激活同一个窗口并切换页面；
维护期间窗口保留 HWND 和草稿，但暂时释放 Rime／Levers 后端模型，运行时恢复后重新绑定。

维护和兼容路径如下：

| 入口 | 工作流 |
| --- | --- |
| 常驻设置窗口 | 编辑配置并向 `RabbitDeploymentCoordinator` 提交部署、同步或词典操作 |
| `--deployer-worker deploy` | 按序列化的 `RabbitDeploymentPlan` 在隔离 Rime 生命周期中部署 |
| `--deployer-worker sync` | 在隔离 Rime 生命周期中同步用户资料 |
| `--deployer-worker dictionary` | 执行备份、恢复、导入或导出词典 |
| `--deployer deploy`／`sync` | 通过 IPC 优先委托常驻前端；没有常驻端点时独立执行维护 |
| `--deployer legacy-settings [dictionary]` | 使用旧版 Windows 的兼容设置或词典管理流程 |

worker 由 `RabbitDeployerWorkerApplication` 和 `RabbitMaintenanceWorkflow` 执行，不创建现代设置 GUI 或普通托盘。
协调器通过进程句柄轮询完成状态；worker 退出后，无论操作成功与否都尝试恢复输入运行时。外部 `deploy`／`sync`
使用带请求 ID、随机令牌和发送者 PID 校验的 `RabbitMaintenanceIpcServer`，避免与活动前端并发初始化 Rime。
`RabbitDeployerApplication` 只保留兼容流程和无常驻前端时的独立维护回退；`settings` 命令已不再有效。

## 模块边界与扩展方式

按功能查找代码时可从以下入口开始：

| 功能 | 入口模块 | 相关实现 |
| --- | --- | --- |
| 启动与退出 | `Rabbit.ahk`、`RabbitApplication.ahk`、`RabbitFrontendRuntime.ahk` | 参数、互斥体、可重启输入运行时和退出清理 |
| 输入处理 | `RabbitInput.ahk` | 热键、焦点监视、密码框绕过、提交和候选更新 |
| 托盘与状态 | `RabbitTrayMenu.ahk`、`RabbitRuntimeState.ahk`、`RabbitStatusTip.ahk` | 菜单、状态标签、维护提示和状态窗口 |
| 设置与部署 | `RabbitSettingsController.ahk`、`RabbitDeploymentCoordinator.ahk`、`RabbitMaintenanceWorkflow.ahk` | 常驻设置、Levers、自定义配置、部署计划和 worker 协调 |
| 跨进程维护 | `RabbitMaintenanceIpc.ahk`、`RabbitDeployerWorkerApplication.ahk` | 外部请求、worker 参数、隔离维护和结果回传 |
| Rime 与资源 | `RabbitRimeBootstrap.ahk`、`RabbitCompiledResourcePolicy.ahk` | DLL 选择、编译资源释放和版本标记 |
| 外观与绘制 | `RabbitUIStyle*.ahk`、`RabbitDirect2D.ahk`、`RabbitFontSpec.ahk` | 样式快照、配色、字体、DPI 和绘制资源 |

每个模块必须声明直接 `#Include` 依赖，不要依赖入口脚本的包含顺序。实质性的新类单独放置文件；跨模块协作优先通过构造函数传递 Rime、模型或窗口依赖，避免新增隐式全局状态。涉及配置字段时，沿着“源配置／快照／设置读写／部署计划／测试／文档”整条链路检查；涉及资源时，确认异常、取消、重复打开和退出路径都能释放资源。

更细的所有权、生命周期和缺陷记录见[运行时架构重构记录](../design/runtime-architecture-refactoring.md)。
控制面板和部署边界的设计与实施记录见[控制面板与部署运行时重构](../design/control-panel-runtime-refactoring.md)。
这些记录描述实现过程或设计计划，不是面向普通用户的 API 承诺。
