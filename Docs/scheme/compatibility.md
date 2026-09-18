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
当共享目录与用户目录不同时，`default.yaml` 和 `rabbit.yaml` 由 librime 与玉兔毫分别在共享目录中维护；用户应通过
`default.custom.yaml` 和 `rabbit.custom.yaml` 定制。玉兔毫会在启动时以及下载方案后检查用户目录，若发现这两个完整配置文件，
会将其保留并重命名为 `<name>.yaml.<timestamp>`，避免覆盖共享目录中的配置。

## 方案设置声明

方案作者可随方案提供 `<schema_id>.rabbit.ini`，声明玉兔毫“方案设置”窗口可编辑的字段。它仅描述界面，
不包含 custom 补丁；用户修改后由玉兔毫写入用户目录的 `<schema_id>.custom.yaml`。

声明可定义 `boolean`、`integer`、`number`、`string`、`file` 和 `enum` 标量字段，以及有序列表和专用结构字段。
`file` 保存相对于 Rime 用户目录的正斜线路径；文件选择器只接受用户目录内已有的文件，不保存绝对路径或 `..`。
可选的 `extensions = ico|png` 用作选择器过滤提示，不限制已有配置值的扩展名。例如：

~~~ini
[field.tray_icon]
group = general
path = schema/icon
type = file
label = 托盘图标
default =
extensions = ico|png
~~~

有序列表和专用结构字段包括：

- `list`：仅包含字符串的有序列表；
- `key_binding_list`：仅用于 `key_binder/bindings`，使用玉兔毫的专用按键绑定编辑器。

- `punctuator_map`：仅用于 `punctuator/full_shape`、`punctuator/half_shape` 和 `punctuator/symbols`，使用标点映射编辑器；
- `recognizer_patterns`：仅用于 `recognizer/patterns`，使用识别模式编辑器，每项由标签和正则表达式组成。
- `switch_list`：仅用于 `switches`，使用方案选项编辑器。每项可以是一个开关，或一组互斥选项。
- `engine_lists`：仅用于 `engine`，在同一页编辑处理器、分段器、翻译器和过滤器四条列表。

候选选单常用字段包括 `menu/page_size`（整数）、`menu/alternative_select_labels`（字符串列表）、
`menu/alternative_select_keys`（可打印 ASCII 字符组成的字符串）和 `menu/page_down_cycle`（布尔值）。

没有 `<schema_id>.rabbit.ini` 时，玉兔毫提供的通用 fallback 包含所有适合作为方案覆盖的通用输入配置，
按“常规”“开关”“引擎”“候选选单”“中西文切换”“按键绑定”“标点”和“识别器”分组。
“常规”包含方案名称和托盘图标；全局 `switcher` 设置不属于方案设置。

专用映射字段由玉兔毫整体维护：编辑后写入完整映射表，并清除同路径的精确覆盖及嵌套补丁；“还原方案默认”会移除完整覆盖和所有嵌套补丁。
`recognizer_patterns` 不在玉兔毫中预先校验正则表达式，最终语法由 librime 的 Boost.Regex 处理。

`switch_list` 同样由玉兔毫整体维护：编辑后写入完整的 `switches` 列表，并清除同路径的精确覆盖及嵌套补丁；“还原方案默认”会移除完整覆盖和所有嵌套补丁。
开关项使用 `name`、`states` 和可选的 `abbrev`、`reset`；互斥选项组使用 `options`、`states` 和可选的 `abbrev`、`reset`。未知字段会在编辑时保留。

例如：

~~~ini
[field.switches]
group = translator
path = switches
type = switch_list
label = 方案选项
~~~

`list`、`key_binding_list` 和 `engine_lists` 字段可选 `rows = N` 来指定显示的条目行数。玉兔毫仅接受 1 到 10；未设置、
非整数或超出范围时都使用默认的 3 行。`engine_lists` 会将该行数同步应用到四个列表，并按实际高度调整页面。`switch_list`
的左右两栏高度由专用编辑器自动计算，不支持 `rows`。

`engine_lists` 将 `engine/processors`、`engine/segmentors`、`engine/translators` 和 `engine/filters` 作为一个完整配置项。
每一项都是 `string`，并可使用 Rime 的 `<engine_type>@<engine_name>` 表达式。例如：

~~~ini
[field.engines]
group = engines
path = engine
type = engine_lists
label = 引擎列表
~~~

列表由玉兔毫整体维护：仅在用户实际修改后写入完整列表；“还原方案默认”会移除该列表的完整覆盖及同路径的
`+`、`-`、`@…` 增量补丁。`engine_lists` 的还原操作会同时恢复四条引擎列表。方案作者不应为同一路径同时声明列表和其子字段，也不应让两个字段的路径互为祖先或后代；
这些冲突会使 custom 配置的所有权不明确。

字段路径不能使用 `+`、`-`、`@after`、`@N` 等顺序型补丁语法。`record_list` 保留给未来支持的通用记录列表，
当前不是有效类型。若没有专用声明，玉兔毫使用 Data 中的 `schema.rabbit-fallback.ini`。

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

[field.candidate_labels]
group = translator
path = menu/alternative_select_labels
type = list
label = 候选序号
rows = 4

[field.bindings]
group = translator
path = key_binder/bindings
type = key_binding_list
label = 按键绑定
rows = 3
~~~

## 建议的兼容测试

发布方案前，至少在以下场景测试：

1. 普通文本编辑器中的中文输入；
2. 中西文切换和方案切换；
3. 候选翻页、注释和长候选；
4. 重新部署后重新启动玉兔毫；
5. 不同字号、字体和系统缩放下的候选窗。

如果方案依赖特定的前端行为，请在方案 README 中明确说明玉兔毫版本和需要的 `rabbit.custom.yaml` 设置。
