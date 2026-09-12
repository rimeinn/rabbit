# 配置与部署

## 配置文件的分工

玉兔毫前端设置保存在 Rime 用户目录的 `rabbit.custom.yaml` 中。Rime 的输入方案仍由 `schema.yaml` 定义，两者不要混为一谈：

| 文件 | 作用 |
| --- | --- |
| `rabbit.custom.yaml` | 玉兔毫窗口、行为、界面和方案选单设置 |
| `default.custom.yaml` | Rime 通用设置，例如按键和候选数量 |
| `<方案标识>.custom.yaml` | 只对某个输入方案生效的覆盖 |
| `schema.yaml` | 输入编码、翻译器、词典和方案元数据 |

设置窗口会通过 Rime 的配置接口保存这些文件。手动编辑时，请保留已有的 `patch` 内容，把新设置合并进去。

## 一个最小示例

下面的示例将界面语言设为简体中文，使用流式候选窗，并显示高亮候选的提交预览：

```yaml
patch:
  language: zh-CN
  "style/layout/type": flow
  "style/preedit_type": preview
```

修改后重新部署。`style/layout/type` 支持 `stacked`、`flow` 和 `vertical_text`，具体外观见[外观与候选窗](appearance.md)。

## 常用行为设置

常用设置包括：

- `suspend_hotkey`：暂停或恢复玉兔毫的快捷键；
- `show_tips`、`show_tips_time`：切换输入状态时是否显示提示；
- `global_ascii`：是否在不同程序之间共享中西文状态；
- `fix_candidate_box`：一次组字过程中是否保持候选窗位置；
- `bypass_password_fields`：密码输入框是否绕过 Rime；
- `send_by_clipboard_length`：长文本上屏时何时使用剪贴板。

大多数设置也可以在控制面板的“输入与行为”或“应用适配”页面修改。通过设置窗口保存时，玉兔毫会根据改动范围选择需要重新部署的配置。

## 配置失败时

如果重新部署失败，先不要删除用户数据：

1. 从托盘菜单打开“用户文件夹”和“日志文件夹”；
2. 检查 YAML 缩进、冒号和字符串引号；
3. 暂时移除最近增加的覆盖项；
4. 重新部署并确认是否恢复。

仍无法解决时，提交问题时附上玉兔毫版本、Windows 版本、所用方案、复现步骤和相关配置片段。
