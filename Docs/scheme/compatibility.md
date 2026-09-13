# 与玉兔毫配合

玉兔毫负责把 Rime 的结果显示在 Windows 上；输入方案负责定义“如何把编码转换成候选”。方案开发时，应先使用标准 Rime 配置完成编码、词典和翻译逻辑，再按需增加玉兔毫支持的前端设置。

## 文件分工

一个方案通常包含 `schema.yaml`、词典和其他资源。玉兔毫的窗口和交互设置不应写入方案逻辑，而应写入用户目录中的 `rabbit.custom.yaml`。

方案可以提供 `schema/name`、`schema/schema_id`、`schema/icon` 等元数据；用户是否启用它，则由玉兔毫的方案选单设置决定。

## 前端专属设置

以下内容属于玉兔毫前端契约：

- `style/layout/*`：候选窗布局和几何参数；
- `style/*_font_*`：字体和字号；
- `style/color_scheme*`：浅色／深色配色方案；
- `style/preedit_type`、`style/floating_preedit`：预编辑显示；
- 根级行为项：输入状态、候选位置、剪贴板上屏和密码框处理。

这些设置应通过 `rabbit.custom.yaml` 的 `patch` 节点覆盖，不要直接修改程序目录中的默认 `Data/rabbit.yaml`。

## 方案设置声明

方案作者可随方案提供 `<schema_id>.rabbit.ini`，声明玉兔毫“方案设置”窗口可编辑的字段。它仅描述界面，
不包含 custom 补丁；用户修改后由玉兔毫写入用户目录的 `<schema_id>.custom.yaml`。

声明可定义 `boolean`、`integer`、`number`、`string` 和 `enum` 标量字段。字段路径不能使用 `+`、`-`、
`@after`、`@N` 等顺序型补丁语法。若没有专用声明，玉兔毫使用 Data 中的
`schema.rabbit-fallback.ini`。

字段较多时，用 `[group.<id>]` 分组，并在每个字段中指定 `group = <id>`。组和字段均按 ini 中的声明
顺序显示；多个组显示为左侧导航，单个组省略导航且内容区域可滚动。

~~~ini
[meta]
format = 1
title = 方案设置

[group.translator]
label = 翻译器

[field.enable_completion]
group = translator
path = translator/enable_completion
type = boolean
label = 启用补全
~~~

## 建议的兼容测试

发布方案前，至少在以下场景测试：

1. 普通文本编辑器中的中文输入；
2. 中西文切换和方案切换；
3. 候选翻页、注释和长候选；
4. 重新部署后重新启动玉兔毫；
5. 不同字号、字体和系统缩放下的候选窗。

如果方案依赖特定的前端行为，请在方案 README 中明确说明玉兔毫版本和需要的 `rabbit.custom.yaml` 设置。
