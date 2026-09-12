# 文档贡献

## 文档目录

公开文档源文件位于 `Docs/`，按读者分为 `user/`、`scheme/`、`contributor/` 和 `reference/`。现有的架构重构、功能实现记录保留在根目录，作为贡献者的设计记录。

文档页面使用 Markdown。用户可见的说明使用中文；代码标识、配置路径、命令和上游 API 保留原文。

## 本地预览

文档工具链独立于 Rabbit 程序。准备 Python 环境后执行：

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements-docs.txt
.venv\Scripts\mkdocs.exe serve
```

浏览 `http://127.0.0.1:8000/`。提交前运行严格构建，检查导航引用和构建警告：

```powershell
.venv\Scripts\mkdocs.exe build --strict
```

构建目录是 `dist/docs`，已由仓库的 `dist` 忽略规则排除，不应提交生成文件。

## README 与共享图片

根目录的 `README.md` 同时承担 GitHub 项目首页和分发包说明书的角色。README 中的候选窗截图使用
`Docs/images/candidate-layouts/` 路径，这个路径需要同时在 GitHub、完整压缩包和编译版释放后的目录中有效，
不要改成只对文档站有效的绝对路径，也不要复制出第二份同名图片。

`Docs/` 中的 Markdown 页面只供文档站构建；编译版是否嵌入某个文件由资源清单单独决定。目前只有 README
和候选窗截图属于共享分发资源。新增仅供 Pages 使用的截图可以放在 `Docs/images/`；新增会被用户下载包
或编译版使用的资源时，还要同步更新资源清单、应用打包路径和应用 CI 的路径过滤规则。

## 发布流程

`.github/workflows/docs.yaml` 只监听文档目录、文档配置和文档依赖。推送到 `master` 后，它会构建静态站并部署到 GitHub Pages；文档 Pull Request 只执行构建检查，不部署。

应用工作流对同一批文件使用 `paths-ignore`。因此仅文档改动不会构建程序、运行应用测试或更新 nightly；同一提交若同时修改程序文件，应用 CI 仍会运行。
