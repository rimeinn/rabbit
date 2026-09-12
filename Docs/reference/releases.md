# 版本与发布

## 正式版

正式版使用 `v<版本号>` 标签触发应用 CI，构建 x86／x64 完整包和编译包，并上传到 [GitHub Releases](https://github.com/rimeinn/rabbit/releases)。

## 每夜构建

`master` 分支的构建结果发布到 `latest`，`dev` 分支的构建结果发布到 `dev-nightly`。每夜构建适合验证开发中的功能，不等同于正式版。

## 文档发布

文档站使用独立的 GitHub Pages 工作流。仅修改文档时，应用 CI 和 nightly 不会运行；文档站仍会在 `master` 上重新构建并发布。修改程序和文档的同一提交会同时触发应用 CI 与文档构建。

文档内容当前跟随 `master`，正式版特有的历史行为请以对应 Release 的源码和说明为准。
