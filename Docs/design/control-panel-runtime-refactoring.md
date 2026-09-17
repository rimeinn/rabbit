# 控制面板与部署运行时重构

状态：已实施（阶段 0 - 6）
最后更新：2026-09-16

下文的“背景”和“现状”描述重构前的实现；最终结构与差异以“实施说明”为准。

## 1. 背景

重构前，现代控制面板运行在 `Rabbit.ahk --deployer settings` 进程中。用户从托盘打开设置时，
`RabbitApplication` 会先释放输入热键、Rime 会话、候选窗和托盘运行时，再启动
`RabbitDeployerApplication`。部署器使用 `deployer_initialize()`，不创建输入会话，因此控制面板打开期间
Rabbit 本身不能输入文字。这会直接影响需要文本输入的设置项。

当时的实现还把以下职责放在同一条 deployer 生命周期中：

- 设置窗口和设置模型；
- 完整工作区部署和细粒度配置部署；
- 用户资料同步；
- 用户词典维护；
- 首次安装和返回前端的进程交接。

这使“查看或编辑设置”也必须关闭前端，并让控制面板内的每次重新部署都依赖当前 deployer 进程的
同步 Rime 调用。

## 2. 目标

本次重构要达到以下结果：

1. 从托盘打开现代控制面板时，不退出 `RabbitApplication`，输入法继续正常工作。
2. 控制面板由常驻主进程持有；重复打开时激活已有窗口并切换到指定页面。
3. deployer 只负责必须在部署专用 Rime 生命周期中执行的维护操作，不再持有现代设置 GUI。
4. 重新部署由独立 worker 进程执行；主进程在部署期间短暂停止输入运行时，但保留控制面板窗口。
5. 部署完成或失败后，主进程都能恢复普通 Rime 会话并刷新运行时配置。
6. 为外部命令行部署保留完整 IPC 协调的演进路径。
7. 保留旧版 Windows 的 legacy 设置流程和候选窗回归保护，不要求它们支持新的现代控制面板功能。

## 3. 非目标

- 不让普通 Rime 实例和 deployer Rime 实例同时访问同一个用户数据目录。
- 不在第一阶段实现部署取消；强制终止正在写入构建目录的 worker 风险过高。
- 不保证部署期间仍可输入。输入只在真正部署的短暂维护窗口内暂停。
- 不在本次重构中改变设置字段、候选窗视觉效果或 Rime 配置格式。
- 不把完整命名管道协议作为现代控制面板迁移的前置条件。

## 4. 当前实现与问题边界

### 4.1 当前控制流

```text
托盘 StartSettings()
  -> StartDeployer("settings", page)
  -> RabbitApplication.Shutdown()
  -> 启动 Rabbit.ahk --deployer settings
  -> RabbitApplication 退出
  -> RabbitDeployerApplication.ShowSettings()
  -> RabbitSettingsWindow.WaitClose()
  -> 重新启动普通 RabbitApplication
```

相关实现：

- `Rabbit.ahk` 根据 `--deployer` 在两个应用对象之间分流；
- `RabbitTrayController.StartSettings()` 把现代设置页面路由给 deployer；
- `RabbitApplication.RunDeployer()` 完整关闭前端后启动 deployer；
- `RabbitDeployerApplication.ShowSettings()` 同步持有设置窗口直到关闭；
- `RabbitSettingsWindow.Deploy()` 同步调用 `RabbitDeployerWorkflow`。

### 4.2 互斥职责混合

现有 `RabbitMutex` 使用 `RabbitDeployerMutex` 名称：

- 普通前端在整个生命周期持有它；
- 部署、同步和词典操作又把同名互斥体存在视为维护任务冲突。

因此不能只把 `RabbitSettingsWindow` 移进主进程。否则设置工作流会把自己的前端进程判断为正在部署，
所有维护操作都会失败。

### 4.3 设置模型持有 Rime 资源

部分设置模型在窗口生命周期内长期持有 Levers custom settings、switcher settings 或其他 Rime 句柄。
主进程进入维护态并调用 `finalize()` 前，必须显式释放这些对象。不能依靠窗口关闭、进程退出或
`__Delete()` 的不确定时机。

### 4.4 同步事务假设

现有设置保存流程假定 `Deploy()` 立即返回最终结果，并在成功后清理 dirty 状态。异步化后必须区分：

- 尚未写入配置文件的修改；
- 已保存但尚未部署生效的修改；
- 正在部署的修改；
- 已保存但部署失败、等待重试的修改。

## 5. 约束与不变量

### 5.1 Rime 生命周期

- 同一用户数据目录在任一时刻只允许普通前端或部署 worker 中的一方持有活动 Rime 生命周期。
- worker 开始 `deployer_initialize()` 前，主进程必须完成 session 销毁和 `finalize()`。
- worker 必须先释放部署互斥体，主进程才能重新初始化普通前端。
- 主进程恢复时必须重新读取配置，而不是复用部署前的快照。

### 5.2 窗口与资源所有权

- `RabbitApplication` 是常驻进程和顶层协调者。
- 设置窗口只能由一个显式控制器持有。
- 普通输入运行时必须能够独立启动、停止并重新创建。
- 设置窗口可以跨一次运行时停止继续存在，但其 Rime 后端模型必须可分离和重建。
- 所有停止、恢复和失败清理操作必须幂等。

### 5.3 可观察错误

- worker 必须用进程退出码和日志报告失败。
- 非入口测试和辅助脚本继续遵守顶层 `try/catch` 规则，不能让 AutoHotkey 异常停在不可见原生对话框中。
- 主进程检测到 worker 异常退出后仍必须尝试恢复普通运行时。

## 6. 目标架构

```text
RabbitApplication
├── RabbitFrontendRuntime
│   ├── 普通 Rime initialize / session
│   ├── 输入控制器、候选窗、状态提示
│   ├── 运行时状态和外观控制器
│   └── Start() / Stop() / Reload()
├── RabbitTrayController
│   ├── 打开设置
│   ├── 提交维护操作
│   └── 显示运行状态
├── RabbitSettingsController
│   ├── 持有唯一 RabbitSettingsWindow
│   ├── 创建设置工作流和页面模型
│   ├── 保存草稿及窗口状态
│   └── PrepareForMaintenance() / ResumeAfterMaintenance()
└── RabbitDeploymentCoordinator
    ├── 合并和提交 RabbitDeploymentPlan
    ├── 协调设置模型与前端运行时停机
    ├── 启动并监视 worker
    └── 恢复运行时并发布最终结果

Rabbit deployer worker
├── RabbitDeployerContext
├── RabbitMaintenanceWorkflow
│   ├── deploy / deploy_config_file
│   ├── sync_user_data
│   └── 需要独占用户数据的词典操作
└── 无现代设置 GUI、无输入会话、无常驻托盘
```

### 6.1 `RabbitFrontendRuntime`

从当前 `RabbitApplication.Run()` 和 `RabbitAppContext` 中抽出可重建的输入运行时。它负责：

- 创建 traits 并执行普通 `setup()`、`initialize()`；
- 执行启动维护并创建 Rime session；
- 加载 `RabbitConfigSnapshot` 和 `RabbitUIStyleSnapshot`；
- 创建候选窗、输入控制器、运行时状态、状态提示和外观控制器；
- 注册及解除热键、定时器和 Windows 消息；
- 按确定顺序销毁 session 并 `finalize()`。

`Stop()` 后对象不能继续暴露旧 session、配置快照或候选窗。恢复时创建新的运行时实例，避免重用已经
进入 disposed 状态的 `RabbitAppContext`。

### 6.2 `RabbitSettingsController`

该控制器取代 `RabbitDeployerApplication.ShowSettings()` 对现代窗口的所有权：

- `Show(page_id)` 创建或激活窗口；
- 窗口已经存在时切换页面，不创建第二个实例；
- GUI 关闭只释放设置资源，不退出应用；
- 语言变化时捕获窗口状态并重建 GUI，但不重启进程；
- 在维护前保存纯 AHK 草稿并释放所有 Rime/Levers 句柄；
- 在恢复后重建模型、刷新已部署值并恢复页面和位置。

控制器不能使用阻塞式 `WinWaitClose()` 作为所有权机制。窗口生命周期改由事件和显式引用管理。

### 6.3 `RabbitDeploymentCoordinator`

协调器维护单一活动操作，建议使用以下状态：

```text
idle
  -> preparing
  -> stopping_runtime
  -> worker_running
  -> resuming_runtime
  -> refreshing_settings
  -> idle
```

另设 `failed_to_resume` 状态，用于 Rime 无法重新初始化时保留控制面板并提示用户重试或退出。

协调器负责：

- 拒绝或合并重复提交；
- 在启动 worker 前冻结会写配置的控件；
- 调用设置控制器释放后端模型；
- 完整停止普通输入运行时；
- 启动 worker 并保存 PID/进程句柄；
- 用短周期定时器检查完成状态，不阻塞 GUI 事件循环；
- 读取退出码后恢复输入运行时；
- 即使 worker 失败也执行恢复；
- 把结果回传给设置窗口、托盘提示和日志。

## 7. 进程与互斥设计

### 7.1 拆分互斥体

至少引入两个具有单一职责的互斥体：

| 名称 | 持有者 | 生命周期 | 用途 |
| --- | --- | --- | --- |
| `RabbitApplicationMutex` | 常驻主进程 | 主进程完整生命周期 | 防止多个前端实例 |
| `RabbitDeploymentMutex` | worker | 单次维护操作 | 防止多个部署／同步任务并发 |

普通前端不再长期持有部署互斥体。前端启动或恢复前检查部署锁；若 worker 尚未释放，则延迟恢复。

worker 的顺序必须是：

```text
获取 RabbitDeploymentMutex
  -> deployer_initialize
  -> 执行操作
  -> finalize
  -> 释放 RabbitDeploymentMutex
  -> 退出
```

### 7.2 复用同一个可执行文件

第一阶段继续复用 `Rabbit.ahk`/编译后的 `Rabbit.exe`，增加专用 worker 模式。例如：

```text
Rabbit.exe /force --deployer-worker deploy --rabbit-config --workspace
```

源码模式在 AutoHotkey 命令行中把 `/force` 放在脚本路径之前。`/force` 只用于明确的 worker 启动；
常驻前端仍由 `RabbitApplicationMutex` 保证单实例。

worker 参数应直接表达维护操作，不再接受 `settings [page]`。细粒度部署计划至少要能序列化：

- `rabbit_config_changed`；
- `default_config_changed`；
- `full_workspace_required`；
- 重复的 `schema_config_id`。

所有 schema ID 继续使用 `RabbitDeploymentPlan` 的白名单校验，不能把未经验证的路径传给 worker。

## 8. 异步部署与 IPC

### 8.1 第一阶段：父进程监督 worker

托盘和控制面板发起的操作不需要双向 IPC：

1. 主进程已知要执行的 plan；
2. 主进程保存设置并进入维护准备；
3. 主进程停止自己的普通 Rime 运行时；
4. 主进程用 `Run(..., &pid)` 启动 worker；
5. 主进程用定时器和进程句柄等待 worker 结束；
6. 主进程取得退出码并恢复普通运行时。

这一阶段已经满足现代控制面板的核心需求：窗口不关闭，GUI 不被同步等待阻塞，只有真正部署期间暂停输入。

### 8.2 第二阶段：外部请求 IPC

完整 IPC 用于外部启动的部署命令，而不是控制面板迁移的前置条件。推荐协议为：

```text
外部命令
  -> 查找常驻 Rabbit IPC 窗口
  -> 提交经过校验的维护请求
  -> 常驻 Rabbit 成为 coordinator
  -> 常驻 Rabbit 启动 worker
  -> 返回已接受／忙／参数错误
```

这样仍由主进程决定何时停止和恢复运行时，worker 不需要反向控制 GUI。AutoHotkey 初版可使用隐藏 GUI 加
`WM_COPYDATA`；消息必须包含协议版本、操作类型、请求 ID 和随机令牌，并验证发送者 PID。若以后需要大量
进度数据、取消或跨完整性级别通信，再评估命名管道。

如果没有发现常驻主进程，外部 worker 可以获取部署锁并以独立模式完成操作；若部署锁存在，则返回忙，
不得与未知前端实例同时初始化 Rime。

### 8.3 结果与恢复兜底

进程退出码是最低限度结果通道：

- `0`：操作成功；
- 非零：操作失败，详细原因写入 Rabbit 日志；
- 无法读取退出码或进程异常消失：按失败处理。

主进程不能依赖 worker 的“完成消息”才恢复。即使以后加入 IPC，也必须保留进程句柄监视作为崩溃兜底。

## 9. 设置保存事务

### 9.1 状态定义

控制面板需要把现有单一 dirty 概念拆开：

| 状态 | 含义 | UI 行为 |
| --- | --- | --- |
| `dirty` | 控件值尚未写入用户配置 | 启用“应用” |
| `activation_pending` | 已写入配置，但尚未成功部署 | 显示“已保存，等待生效”并允许重试 |
| `deploying` | worker 正在执行 | 禁用会修改配置或重复部署的操作 |
| `active` | 最新保存内容已部署并重新加载 | 显示成功状态 |

部署失败不能把已经成功写盘的值重新标成未保存。失败后保留相应的 `RabbitDeploymentPlan`，用户可重试，
也可以继续编辑并把新 plan 合并进去。

### 9.2 异步调用契约

当前返回同步整数的 `Deploy(plan)` 应改成提交接口，例如：

```text
Submit(plan, completion_callback) -> accepted
```

保存流程变为：

```text
校验全部页面
  -> 写入用户配置
  -> 计算并合并 RabbitDeploymentPlan
  -> 标记 activation_pending
  -> 提交协调器
  -> 返回 GUI 事件循环
  -> 完成回调更新页面状态
```

第一版在 `deploying` 期间禁用编辑和维护按钮。计划合并和部署期间继续编辑可以在状态机稳定后单独实现。

## 10. 设置模型的维护态切换

`RabbitSettingsWindow` 或其控制器需要提供两个明确阶段。

### 10.1 `PrepareForMaintenance()`

- 阻止新页面懒加载和新子对话框打开；
- 结束或拒绝正在运行的 RimeDepot 安装操作；
- 捕获页面、选项卡、窗口位置和必要的纯值草稿；
- 关闭依赖 Rime 的子窗口；
- Dispose appearance、switcher、behavior、application、dictionary 和 schema 模型；
- 清空缓存的 Rime 配置、Levers settings 和迭代器引用；
- 保留顶层设置 GUI，并显示维护遮罩或状态文字。

### 10.2 `ResumeAfterMaintenance()`

- 基于新的普通 Rime 实例重建设置工作流；
- 按需重建当前页面模型，不强制加载所有页面；
- 重新读取已部署的配置和候选预览；
- 恢复页面、选项卡、窗口位置及仍有意义的草稿；
- 根据 worker 结果更新 `activation_pending`；
- 解除维护遮罩和控件冻结。

若语言设置在部署后发生变化，由设置控制器捕获状态并重建 GUI；这属于窗口内部重建，不退出主进程。

## 11. 维护操作范围

### 11.1 部署

所有 `deploy()`、`deploy_config_file()` 和 schema 部署进入 worker。设置页只负责保存配置并生成 plan。

### 11.2 用户资料同步

`sync_user_data()` 和等待维护线程也进入 worker。控制面板保留同步按钮和进度状态，但不在主进程的普通
Rime 生命周期中直接执行同步。

### 11.3 用户词典

现代词典 GUI 留在主进程。需要独占用户数据或调用 Levers 用户词典修改 API 的备份、恢复、导入和导出
应逐步转换为维护任务。仅仅读取词典列表是否可在普通初始化下安全进行，需要通过 focused integration
test 确认；在确认前按维护操作处理更安全。

### 11.4 RimeDepot

目录浏览、网络下载和设置编辑继续由主进程窗口负责。安装完成后的配置刷新和部署统一提交给
`RabbitDeploymentCoordinator`。部署期间不能保留仍在使用旧 Rime 模型的 RimeDepot 子窗口。

### 11.5 首次安装

首次安装是特殊状态：部署前可能没有可用 build 或输入 session。主进程仍可持有安装设置窗口，但
`RabbitFrontendRuntime` 可以处于 `not_ready`，直到首次 worker 成功完成部署。成功后在同一主进程中启动
普通运行时；取消安装时沿用现有明确的退出或最小部署策略。

## 12. 失败处理

| 失败点 | 必须行为 |
| --- | --- |
| 设置写盘失败 | 不停止输入运行时，不启动 worker，保留 dirty |
| 设置模型无法释放 | 中止维护，恢复控件，不启动 worker |
| 普通运行时停止失败 | 不启动 worker；记录错误并进入可恢复状态 |
| worker 无法启动 | 立即尝试恢复普通运行时，保留 activation pending |
| worker 部署失败 | 释放部署锁并退出；主进程仍恢复普通运行时 |
| worker 崩溃 | 主进程通过进程句柄检测，按失败恢复 |
| 主进程在部署期间退出 | worker 继续完成；结束时不假定父进程仍存在 |
| 恢复普通 Rime 失败 | 控制面板保持打开，显示严重错误并提供重试／退出 |
| 第二次部署请求到达 | 返回 busy；第一版不并发运行 worker |

不自动强制结束超时 worker。可以显示持续时间和日志位置；只有将来确认可安全取消的阶段才增加取消操作。

## 13. 分阶段实施计划

### 阶段 0：行为固化和接口准备

- 为托盘设置路由、deployer 交接顺序和设置窗口所有权补充现状测试。
- 为 `RabbitDeploymentPlan` 增加稳定序列化／解析测试。
- 记录普通模式和 deployer 模式的 Rime 调用顺序。
- 保持用户可见行为不变。

完成标准：现状链路及失败清理都有可观察测试，后续重构不会靠进程退出掩盖资源泄漏。

### 阶段 1：设置窗口迁入主进程

- 新增 `RabbitSettingsController`。
- 将现代 `settings` 和页面路由从 `RabbitDeployerApplication` 移到 `RabbitApplication`。
- 托盘构造函数分别接收设置回调和维护回调，不再用一个 `deployer_callback` 承担所有动作。
- 删除现代窗口的 `WaitClose()` 所有权方式，实现重复打开激活和切页。
- 暂时保留 legacy 设置的原进程交接。

完成标准：打开控制面板后可在设置文本框中继续使用 Rabbit 输入，关闭设置不会重启前端。

### 阶段 2：拆分工作流和互斥体

- 将模型工厂和设置读写迁到 `RabbitSettingsWorkflow`。
- 将部署、同步和独占词典操作迁到 `RabbitMaintenanceWorkflow`。
- 引入 application/deployment 两个独立互斥体。
- `RabbitDeployerApplication` 不再接受现代 `settings` 命令。

完成标准：普通前端持有应用锁但不持有部署锁；纯设置读取不会触发 deployer 生命周期。

### 阶段 3：可重启的前端运行时

- 抽出 `RabbitFrontendRuntime`。
- 让托盘和设置控制器在运行时对象更换后仍然存活。
- 实现 Stop、重新创建、失败回滚和幂等 Dispose。
- 重新初始化后刷新托盘 schema、候选样式、热键和状态提示。

完成标准：测试可以在同一主进程中执行 `Start -> Stop -> Start -> Stop`，且没有重复热键、消息或计时器。

### 阶段 4：父进程监督的异步 worker

- 增加 `--deployer-worker` 参数和 plan 参数。
- 使用 `/force` 启动同一程序的独立 worker 实例。
- 用进程句柄和定时器异步取得退出结果。
- 实现 coordinator 状态机和托盘／控制面板状态更新。
- 覆盖完整部署、细粒度部署和同步。

完成标准：部署时控制面板 HWND 保持不变；操作结束后 Rabbit 恢复输入；worker 失败也能恢复。

### 阶段 5：设置模型挂起与异步事务

- 实现 `PrepareForMaintenance()` 和 `ResumeAfterMaintenance()`。
- 将同步返回值流程改成 completion callback。
- 引入 `activation_pending`，正确处理保存成功、部署失败。
- 迁移用户词典和 RimeDepot 后续部署路径。
- 保留语言变化后的窗口状态重建。

完成标准：任意现代设置页面可触发重新部署而不关闭顶层窗口；失败后可重试且不会丢失草稿。

### 阶段 6：外部请求 IPC 与恢复加固

- 增加带版本和发送者验证的维护请求端点。
- 外部部署命令优先委托给常驻主进程协调。
- 加入父进程消失、worker 孤儿退出和应用重启恢复测试。
- 评估是否需要比 `WM_COPYDATA` 更强的命名管道协议。

完成标准：外部部署不会与活动前端并发初始化 Rime；无前端时仍可独立部署。

每个阶段单独提交并完成 focused tests。不得为了测试临时关闭 caret hook 后把覆盖残留在 diff 中。

### 实施说明

阶段 0 - 6 已按上述顺序完成。最终实现保留一个常驻 `RabbitApplication` 作为设置窗口和维护操作的
所有者，以独立 `RabbitFrontendRuntime` 承担可停止、可恢复的输入运行时，并由
`RabbitDeploymentCoordinator` 监督隔离的 deployer worker。外部 `deploy`／`sync` 命令通过带版本、
请求 ID、随机令牌和发送者 PID 校验的 `WM_COPYDATA` 端点提交；常驻端点不存在但应用互斥体仍被持有时，
请求返回忙而不会并发初始化 Rime。

当前请求只包含小型一次性维护计划，不传输进度流，也不支持强制取消，因此命名管道没有带来足够收益，
暂不引入。worker 的进程句柄仍是完成和崩溃检测的权威通道；父进程提前退出时，worker 独立完成并释放
部署锁，后续 Rabbit 实例可以重新启动。

## 14. 测试计划

### 14.1 单元测试

- 设置入口只创建一个窗口并能切页、激活。
- coordinator 的所有状态迁移、重复提交和失败回滚。
- worker 命令行解析与 `RabbitDeploymentPlan` 往返。
- application/deployment 互斥体互不干扰。
- worker 退出前释放部署锁，前端释放后才能恢复。
- 设置保存失败不启动维护；部署失败保留 activation pending。
- runtime 多次 Start/Stop 不重复注册热键、OnMessage 或定时器。

### 14.2 组件测试

- 设置窗口在运行时 detach/rebind 后保持 HWND、页面和选项卡。
- 持久 Levers 模型在 finalize 前全部 Dispose。
- 语言切换只重建设置 GUI，不退出主进程。
- 旧版 Windows 路由仍使用 legacy 设置流程。

### 14.3 集成测试

- 使用匹配的 `rime.dll` 执行普通初始化、worker 部署和普通恢复。
- 完整部署、rabbit/default/schema 细粒度部署和同步。
- worker 返回失败、启动失败、异常退出和长时间运行。
- 部署后新配置被输入运行时、候选窗和托盘实际加载。
- 首次安装从无 build 状态进入可输入状态。

所有 AutoHotkey 集成入口必须使用仓库规定的可观察异常边界。

### 14.4 人工验收

- 打开控制面板，在所有文本输入设置中使用 Rabbit 输入。
- 控制面板打开期间切换应用、方案、中英文状态和候选操作。
- 从设置页和托盘分别重新部署，确认窗口不关闭或跳动。
- 部署完成后立即输入，确认新配置生效。
- 部署失败后确认输入恢复、草稿保留、重试可用。
- 检查 Windows 10/11、多显示器、不同缩放及现代/legacy 候选后端回归。

## 15. 最终验收标准

- 打开现代控制面板不再退出或重启 Rabbit。
- 控制面板打开期间输入功能持续可用。
- deployer worker 不创建现代设置 GUI。
- 普通 Rime 与 deployer Rime 不同时活动。
- 用户点击重新部署时顶层控制面板窗口保持存在。
- 部署成功、失败和 worker 崩溃后都能恢复输入运行时。
- 已保存但部署失败的设置有明确状态且可重试。
- 托盘、设置、同步、词典和首次安装路径拥有明确且可测试的资源所有者。
- legacy 设置和候选窗没有行为回归。

## 16. 无 IPC 的退路

如果完整 IPC 暂时无法实现，阶段 4 的父进程监督模式已经足以解决控制面板问题：父进程主动停止
运行时、启动 worker、监视 PID 并自行恢复，不需要 worker 反向发送消息。

如果连可重启运行时也无法可靠实现，最后退路才是退出交接：退出前持久化页面、选项卡、窗口位置、
草稿和 pending plan，部署完成后用恢复令牌重启 Rabbit 并重新打开控制面板。这只能提供状态连续性，
不能保留真实窗口，应视为临时兼容方案，而不是目标架构。

不建议默认在同一进程中依次执行普通 `finalize()`、`deployer_initialize()`、部署、再次普通
`initialize()`。librime 和插件包含进程级状态；除非重复切换和异常路径得到充分验证，独立 worker 的隔离更安全。

## 17. 相关设计记录与上游依据

- [运行时架构重构](runtime-architecture-refactoring.md)：此前完成的运行时所有权、资源释放和快照重构记录。
- [小狼毫式配色阴影支持](weasel-style-shadows.md)：现代候选窗阴影功能的设计与实现记录。
- [librime `rime_api.h`](https://github.com/rime/librime/blob/master/src/rime_api.h)：普通初始化、维护线程和
  deployer 初始化 API 的正式定义。
- [小狼毫 `Configurator.cpp`](https://github.com/rime/weasel/blob/master/WeaselDeployer/Configurator.cpp)：
  部署锁、前端维护态、独立 deployer 和恢复服务的参考实现。
- [AutoHotkey v2 命令行文档](https://doggy8088.github.io/AutoHotkeyDocs/docs/Scripts.htm)：编译脚本支持
  `/force` 并允许显式启动独立 worker 实例。
