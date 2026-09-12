# 架构概览

## 主程序

```text
Rabbit.ahk
  -> RabbitApplication
       -> RabbitAppContext
            -> Rime 会话与进程资源
            -> 配置和 UI 样式快照
            -> 输入、托盘、运行时状态
            -> 现代或旧版候选窗
```

`RabbitApplication` 负责启动流程和顶层回调；`RabbitAppContext` 持有进程级资源，并在退出时按顺序释放输入热键、定时器、候选窗、Rime 会话和互斥体。

## 候选窗

候选窗工厂根据系统版本和配置选择现代或旧版后端。现代候选窗使用 Direct2D／WIC 绘制，支持堆叠、流式和竖排布局；旧版候选窗保留较老 Windows 的兼容路径。

输入模块只产生候选展示所需的数据，候选后端负责布局、绘制、定位和命中测试。新的候选功能应先确认现代后端的契约，再补充旧版回归测试。

## 部署器

`Rabbit.ahk` 负责入口分流：普通启动创建 `RabbitApplication`，传入 `--deployer` 后创建 `RabbitDeployerApplication`。部署器负责重新部署、词典管理、资料同步、方案管理和设置工作流。部署器与主程序拥有独立的 Rime 生命周期，不能假设主程序的全局状态已经存在。

更细的所有权、生命周期和缺陷记录见[运行时架构重构记录](../runtime-architecture-refactoring.md)。这些记录描述实现过程，不是面向普通用户的 API 承诺。
