# 配色与字体

## 配色方案

配色方案位于 `preset_color_schemes` 下。用户应在设置窗口中复制内置方案后编辑副本，或在 `rabbit.custom.yaml` 中选择自定义方案标识。

颜色字段遵循方案的 `color_format`。常见格式为 `argb` 和 `abgr`；不要在不确认格式的情况下直接交换红蓝通道。

在设置界面中，颜色使用 `#RRGGBB` 或 `#AARRGGBB` 表示。手写 YAML 时，仓库示例使用 `0x` 前缀，例如半透明黑色可以写成：

```yaml
preset_color_schemes:
  my_scheme:
    name: 我的配色
    author: 作者
    color_format: argb
    back_color: 0xfff7f7f7
    text_color: 0xff202020
    hilited_candidate_back_color: 0xff3366cc
    hilited_candidate_text_color: 0xffffffff
    shadow_color: 0x50000000
```

配色方案标识只能使用小写字母、数字、下划线和连字符。内置方案是只读的，复制后再修改。

## 阴影颜色

四种阴影颜色分别对应窗口、编码高亮、普通候选和高亮候选。缺省值 `0x00000000` 是完全透明色，不会启用阴影；阴影半径也必须是非零值。

阴影只新增到现代候选窗和浮动预编辑框，旧版候选窗只保证兼容运行。

## 字体后备

现代候选窗支持按顺序指定后备字体，也可以限制 Unicode 范围。例如：

```yaml
font_face: "Microsoft YaHei UI, Segoe UI Emoji"
```

需要精确控制字符覆盖范围时，在设置窗口的“高级字体设置”中添加字体、字重、字形和 Unicode 范围。先确认目标字体已经安装，并在不同 DPI 下检查候选文字、注释和 Emoji 的高度是否一致。
