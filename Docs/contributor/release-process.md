# 构建与发布

Rabbit 的应用构建和文档发布是两个独立的 GitHub Actions 工作流。资源清单和工作流中的路径共同决定哪些内容
会进入用户下载的包或编译版。

## 应用构建触发条件

应用工作流位于 `.github/workflows/ci.yaml`：

- 普通分支推送会触发应用构建，除非改动全部属于纯文档路径；
- `v*` 标签用于正式版构建；
- `master` 分支成功后更新 `latest` nightly；
- `dev` 分支成功后更新 `dev-nightly`；
- `workflow_dispatch` 保留手动运行入口。

纯文档页面、文档配置和文档依赖不会触发应用构建。根目录 `README.md` 和
`Docs/images/candidate-layouts/` 中的候选窗截图属于分发资源，因此它们的改动会触发应用构建。

## 文档发布

文档工作流位于 `.github/workflows/docs.yaml`：

- 文档 Pull Request 执行 `mkdocs build --strict`；
- 推送到 `master` 后构建 `dist/docs` 并部署 GitHub Pages；
- 文档工作流不会编译 Rabbit，也不会创建 nightly。

GitHub Pages 的发布来源需要在仓库设置中选择 GitHub Actions。构建结果不提交到仓库。

## 分发资源清单

编译版资源由 `scripts/compiled-resource-manifest.json` 描述。当前清单包含：

- `Data/` 和 `Locales/`；
- README 使用的候选窗截图；
- `README.md` 和 `LICENSE`；
- 编译版需要的东风破安装脚本入口。

资源清单中的 `destination` 是运行时释放后的路径。README 中的截图路径必须与这里保持一致，否则 GitHub 页面、
完整包和编译版会出现不同结果。

新增资源时，先判断它属于哪一类：

| 资源类型 | 放置位置 | 需要修改应用构建吗 |
| --- | --- | --- |
| 仅文档站使用的图片 | `Docs/images/` | 不需要 |
| README 和分发包共同使用的图片 | 当前为 `Docs/images/candidate-layouts/` | 需要更新清单和路径过滤 |
| 应用运行时资源 | `Data/`、`assets/` 或清单指定路径 | 需要 |

不要把整个 `Docs/` 目录加入编译资源清单。Markdown 页面由 Pages 单独发布，避免把站点源文件无意间嵌入应用。

## 正式版注意事项

正式版标签应遵循仓库现有的签名策略。已推送的标签不要为了重建产物而删除、强制移动或改成未签名标签；若签名
环境不可用，应先修复签名环境或取得明确的替代方案批准。

发布前至少检查：

1. `mkdocs build --strict` 通过；
2. 资源清单中的每个源文件都存在；
3. README 中的图片在仓库页面和本地解压目录中都能打开；
4. 修改程序后运行对应的单元测试和集成测试；
5. 不提交 `dist/`、生成的 `RabbitCompiledResources.ahk` 或 DLL。
