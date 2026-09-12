# 外观与候选窗

现代候选窗支持三种布局。可以在设置窗口的“外观 → 排版”中选择，也可以在 `rabbit.custom.yaml` 中设置 `style/layout/type`。

## 堆叠布局

默认布局。候选逐行显示，适合一般的拼音、注音和形码输入。

![堆叠布局](../images/candidate-layouts/stacked.png)

## 流式布局

候选按行横向排列，可以在较宽的屏幕上同时看到更多候选。候选超过一行时会分页显示。

![流式布局](../images/candidate-layouts/flow.png)

![流式布局的多行分页](../images/candidate-layouts/flow_paging.png)

## 竖排文字布局

候选文字从上到下排列。候选列可以从左向右或从右向左排列，由 `style/vertical_text_left_to_right` 控制。

![竖排文字布局：候选列从左向右](../images/candidate-layouts/vertical_text_left_to_right.png)

![竖排文字布局：候选列从右向左](../images/candidate-layouts/vertical_text_right_to_left.png)

## 预编辑内容

现代候选窗和浮动预编辑框支持两种预编辑内容：

- `composition`：显示当前编码；
- `preview`：显示高亮候选的提交预览，预览为空时回退到当前编码。

## 阴影

阴影只扩展到现代候选窗和浮动预编辑框。将 `style/layout/shadow_radius` 设为非零值，再在配色方案中设置非透明的阴影颜色。例如：

```yaml
patch:
  "style/layout/shadow_radius": 8
  "style/layout/shadow_offset_x": 2
  "style/layout/shadow_offset_y": 3
```

半径为零会关闭全部阴影。详细字段和颜色格式见[配色与字体](../scheme/colors-and-fonts.md)。
