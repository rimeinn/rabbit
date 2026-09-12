# 开发环境

## 获取源码

玉兔毫使用 Git 子模块提供 Rime 绑定、方案下载器和东风破资源。克隆仓库后初始化全部子模块：

```powershell
git submodule update --init --recursive
```

开发和 CI 以 AutoHotkey v2.0.19 为基线。运行源码还需要匹配架构的 `rime.dll` 和本地 Rime 数据；没有这些文件时，可以先阅读不依赖 Rime 的单元测试和模型代码。

## 运行源码

在仓库根目录执行：

```powershell
AutoHotkey.exe Rabbit.ahk
AutoHotkey.exe RabbitDeployer.ahk
```

源码运行不需要生成编译资源。编译单文件版本时，按照根目录 README 和 CI 脚本准备 `Data/`、图标、对应位宽的 Rime DLL，再生成 `Lib/RabbitCompiledResources.ahk`。

## 代码边界

- `Rabbit.ahk` 和 `RabbitDeployer.ahk` 保持启动流程清晰；
- 运行时状态、输入、候选窗、设置和部署逻辑放在 `Lib/` 的专门模块中；
- 新候选窗功能只面向现代候选窗；旧版候选窗需要回归保护；
- 不要把应用改动混入 `Lib/librime-ahk`、`Lib/RimeDepot` 或 `plum` 子模块；
- 修改 UI、候选窗、托盘或部署行为时，同时更新对应测试和文档。
