# 构建与发布

Rabbit 的应用构建和文档发布是两个独立的 GitHub Actions 工作流。资源清单和工作流中的路径共同决定哪些内容
会进入用户下载的包或编译版。

## 应用工作流关系

`.github/workflows/ci.yaml` 将依赖准备、源码包、测试、编译版和发布拆成多个作业：

```text
prepare-autohotkey-binaries ─┬─> build-rabbit ────────┬─> nightly / release
                              ├─> test-rabbit          │
prepare-dependency ───────────┴─> build-rabbit-compiled┘
```

其中：

- `prepare-autohotkey-binaries` 准备 AutoHotkey v2.0.19 的 x86/x64 解释器、Ahk2Exe 和图标；
- `prepare-dependency` 准备 x86/x64 的 librime DLL，并用东风破生成 `Data/`，再复制仓库源配置 `schemas/rabbit.yaml`；
- `build-rabbit` 生成脚本版 Rabbit 和包含 `Data/` 的完整压缩包；
- `test-rabbit` 使用 x64 AutoHotkey 运行 Rabbit 单元测试和 RimeDepot 测试；
- `build-rabbit-compiled` 按 x86/x64 矩阵生成编译资源、编译 `Rabbit.ahk` 并验证编译版的资源和 DLL 启动路径。

当前 nightly 作业的 `needs` 直接依赖 `build-rabbit` 和 `build-rabbit-compiled`；`test-rabbit` 是独立的测试作业，不应把 nightly 产物理解为它的直接下游。修改工作流依赖时，要明确是要改变测试阻断规则，还是只调整产物生成顺序。

## 应用构建触发条件

应用工作流位于 `.github/workflows/ci.yaml`：

- 普通分支推送会触发应用构建，除非改动全部属于纯文档路径；
- `v*` 标签用于正式版构建；
- `master` 分支成功后更新 `latest` nightly；
- `dev` 分支成功后更新 `dev-nightly`；
- `workflow_dispatch` 保留手动运行入口。

路径过滤只作用于推送事件；手动运行工作流时，应按完整 CI 运行处理。应用 CI 的路径列表会排除普通 `Docs/**`、文档配置和文档依赖，但会重新纳入 README 及 `Docs/images/candidate-layouts/**`，因为这些文件属于分发资源。

纯文档页面、文档配置和文档依赖不会触发应用构建。根目录 `README.md` 和
`Docs/images/candidate-layouts/` 中的候选窗截图属于分发资源，因此它们的改动会触发应用构建。

## 文档发布

文档工作流位于 `.github/workflows/docs.yaml`：

- 文档 Pull Request 执行 `mkdocs build --strict`；
- 推送到 `master` 后构建 `dist/docs` 并部署 GitHub Pages；
- 文档工作流不会编译 Rabbit，也不会创建 nightly。

GitHub Pages 的发布来源需要在仓库设置中选择 GitHub Actions。构建结果不提交到仓库。

文档工作流使用 Python 3.12 和 `requirements-docs.txt` 中锁定的 MkDocs 版本，先执行 `mkdocs build --strict`，再把 `dist/docs` 上传为 Pages artifact。只有推送到 `master` 或在 `master` 上手动运行时才执行部署作业；Pull Request 只构建和检查。

## 分发资源清单

编译版资源由 `scripts/compiled-resource-manifest.json` 描述。当前清单包含：

- `Data/` 和 `Locales/`；
- README 使用的候选窗截图；
- `README.md` 和 `LICENSE`；
- 编译版需要的东风破安装脚本入口。

资源清单中的 `destination` 是运行时释放后的路径。README 中的截图路径必须与这里保持一致，否则 GitHub 页面、
完整包和编译版会出现不同结果。

`Data/` 不属于仓库中的稳定源目录，而是依赖准备作业生成的发布数据目录。源配置改动应修改 `schemas/rabbit.yaml`，
再由 CI 重新生成并打包 `Data/rabbit.yaml`；不要把本地生成的 `Data/` 或 Rime 用户目录提交回来。

新增资源时，先判断它属于哪一类：

| 资源类型 | 放置位置 | 需要修改应用构建吗 |
| --- | --- | --- |
| 仅文档站使用的图片 | `Docs/images/` | 不需要 |
| README 和分发包共同使用的图片 | 当前为 `Docs/images/candidate-layouts/` | 需要更新清单和路径过滤 |
| 应用运行时资源 | `Data/`、`assets/` 或清单指定路径 | 需要 |

不要把整个 `Docs/` 目录加入编译资源清单。Markdown 页面由 Pages 单独发布，避免把站点源文件无意间嵌入应用。

编译资源生成器会把清单中的文件写入 `RabbitCompiledResources.ahk`，编译版首次运行时再由
`RabbitCompiledResourcePolicy` 按版本标记释放到程序目录。修改清单后，至少检查一次未编译源码运行和一次对应位数的编译资源测试，确认源码不会意外依赖生成文件。

## 正式版注意事项

正式版标签应遵循仓库现有的签名策略。已推送的标签不要为了重建产物而删除、强制移动或改成未签名标签；若签名
环境不可用，应先修复签名环境或取得明确的替代方案批准。

发布前至少检查：

1. `mkdocs build --strict` 通过；
2. 资源清单中的每个源文件都存在；
3. README 中的图片在仓库页面和本地解压目录中都能打开；
4. 修改程序后运行对应的单元测试和集成测试；
5. x86 和 x64 的源码包、完整包及编译版都使用正确位数的 DLL 和资源；
6. 不提交 `dist/`、生成的 `RabbitCompiledResources.ahk` 或 DLL。
