# 文档贡献

## 文档目录

公开文档源文件位于 `Docs/`，按读者分为 `user/`、`scheme/`、`contributor/` 和 `reference/`。现有的架构重构、功能实现记录保留在根目录，作为贡献者的设计记录。

文档页面使用 Markdown。用户可见的说明使用中文；代码标识、配置路径、命令和上游 API 保留原文。

## 页面组织与导航

站点配置位于 `mkdocs.yml`：`Docs/` 是源目录，`dist/docs` 是生成目录，导航由 `nav` 显式维护。新增页面后必须把它加入对应读者章节的导航，否则文件虽然存在，用户仍无法从站点菜单进入。

| 章节 | 面向读者 | 内容边界 |
| --- | --- | --- |
| `user/` | 普通用户 | 按发布包和已安装程序说明操作、目录和故障处理 |
| `scheme/` | 方案开发者 | 按发布后的玉兔毫目录说明 `Data/`、`Rime/` 和 `rabbit.custom.yaml` 的配合方式 |
| `contributor/` | 代码和文档贡献者 | 可以引用仓库源文件、子模块、测试入口和工作流 |
| `reference/` | 所有读者 | 术语、版本、兼容性等相对稳定的参考信息 |

普通用户和方案开发者不应被引导去修改仓库源文件；涉及默认配置时，发布包路径是程序目录中的 `Data/rabbit.yaml`，仓库中的 `schemas/rabbit.yaml` 只在贡献者文档解释构建来源时使用。涉及个人设置时，优先说明用户目录中的 `rabbit.custom.yaml`。

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

本地预览时优先从站点导航进入页面，同时检查页面内的相对链接、代码块和图片；不要只打开磁盘上的 Markdown 文件判断链接是否有效。页面间链接使用相对于源文件的路径，例如用户页面引用共享图片时使用 `../images/...`。

## README 与共享图片

根目录的 `README.md` 同时承担 GitHub 项目首页和分发包说明书的角色。README 中的候选窗截图使用
`Docs/images/candidate-layouts/` 路径，这个路径需要同时在 GitHub、完整压缩包和编译版释放后的目录中有效，
不要改成只对文档站有效的绝对路径，也不要复制出第二份同名图片。

`Docs/` 中的 Markdown 页面只供文档站构建；编译版是否嵌入某个文件由资源清单单独决定。目前只有 README
和候选窗截图属于共享分发资源。新增仅供 Pages 使用的截图可以放在 `Docs/images/`；新增会被用户下载包
或编译版使用的资源时，还要同步更新资源清单、应用打包路径和应用 CI 的路径过滤规则。

README 不是文档站的详细手册。README 保留下载、基本使用、分发目录和必要的构建提示；新增的操作说明、配置解释和开发背景应放在对应的 Pages 页面，并从 README 或首页提供入口即可。

## 多语言资源

界面翻译源文件位于 `Locales/`。`Locales/zh-CN.ini` 是完整的中文基准；`Lib/RabbitLocaleFallback.ahk` 是由它生成的内置回退目录，不要手动编辑生成文件。修改中文源文件后运行：

```powershell
AutoHotkey.exe /ErrorStdOut scripts\generate_locale_fallback.ahk
```

新增语言时，在 `Locales/` 中添加带有 `[meta]`、`locale` 和 `language_name` 的 `<语言代码>.ini`，并使用稳定的 `snake_case` 消息键。运行 `tests\unit\RabbitI18nTest.ahk` 和 `tests\unit\RabbitLocalizationTest.ahk` 检查键、占位符、回退和设置界面；`Locales/*.ini` 会进入源码包和编译版，因此翻译文件改动会触发应用 CI，`Locales/README.md` 则属于文档例外。

## 发布流程

`.github/workflows/docs.yaml` 只监听文档目录、文档配置和文档依赖。推送到 `master` 后，它会构建静态站并部署到 GitHub Pages；文档 Pull Request 只执行构建检查，不部署。

应用工作流对同一批文件使用 `paths-ignore`。因此仅文档改动不会构建程序、运行应用测试或更新 nightly；同一提交若同时修改程序文件，应用 CI 仍会运行。

## 提交前检查

推荐按以下顺序检查：

1. 确认页面放在正确的读者目录，新增页面已加入 `mkdocs.yml` 的 `nav`；
2. 用 `mkdocs serve` 浏览修改页面，检查相对链接、图片和表格；
3. 运行 `mkdocs build --strict`，处理所有构建错误和警告；
4. 用 `git diff --check` 检查空白字符，并确认 `dist/docs` 等生成物没有进入差异；
5. 如果改动 README、共享图片或工作流，按[构建与发布](release-process.md)重新检查分发边界。
