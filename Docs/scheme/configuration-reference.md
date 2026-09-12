# 前端配置参考

默认值和字段注释以仓库中的 [`schemas/rabbit.yaml`](https://github.com/rimeinn/rabbit/blob/master/schemas/rabbit.yaml) 为准。下表列出方案开发和用户定制最常用的字段；没有列出的字段仍可能在设置窗口中可用。

## 根级设置

| 路径 | 默认值 | 说明 |
| --- | --- | --- |
| `language` | `auto` | 界面语言；需要重新部署 |
| `show_tips` | `true` | 是否显示输入状态提示 |
| `show_tips_time` | `1200` | 状态提示时长，单位为毫秒 |
| `suspend_hotkey` | `null` | 暂停／恢复快捷键 |
| `global_ascii` | `false` | 是否在程序之间共享中西文状态 |
| `fix_candidate_box` | `false` | 组字时保持候选窗位置 |
| `use_legacy_candidate_box` | `false` | 请求使用旧版候选窗；旧版 Windows 会自动使用 |
| `bypass_password_fields` | `true` | 密码输入框绕过 Rime |
| `send_by_clipboard_length` | `8` | 长度达到阈值时通过剪贴板上屏 |

`send_by_clipboard_length` 的特殊值为：`0` 表示始终使用剪贴板，负数表示不使用剪贴板，正数表示达到指定长度后使用。

## 外观设置

| 路径 | 默认值 | 说明 |
| --- | --- | --- |
| `style/color_scheme` | `aqua` | 浅色模式配色方案标识 |
| `style/color_scheme_dark` | `null` | 深色模式配色；为空时跟随浅色配色 |
| `style/preedit_type` | `composition` | 预编辑显示编码或高亮候选 |
| `style/floating_preedit` | `false` | 是否显示浮动预编辑框 |
| `style/font_face` | `Microsoft YaHei UI` | 候选文字字体及后备字体 |
| `style/font_point` | `14` | 候选文字字号 |
| `style/layout/type` | `stacked` | `stacked`、`flow` 或 `vertical_text` |
| `style/layout/flow_rows` | `5` | 流式布局的展开页数 |
| `style/layout/min_width` | `160` | 堆叠布局最小宽度 |
| `style/layout/min_height` | `160` | 竖排布局最小高度 |

## 阴影设置

| 路径 | 范围 | 说明 |
| --- | --- | --- |
| `style/layout/shadow_radius` | `0–64` | 阴影半径，零表示关闭 |
| `style/layout/shadow_offset_x` | `-128–128` | 水平偏移，正值向右 |
| `style/layout/shadow_offset_y` | `-128–128` | 垂直偏移，正值向下 |

阴影颜色位于配色方案中：`shadow_color`、`hilited_shadow_color`、`hilited_candidate_shadow_color` 和 `candidate_shadow_color`。半径非零且颜色不透明度非零时才会显示。
