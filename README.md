# 🐇️玉兔毫

由 [AutoHotkey](https://www.autohotkey.com/) 实现的 [Rime 输入法引擎](https://github.com/rime/librime)前端

[![Download](https://img.shields.io/github/v/release/rimeinn/rabbit)](https://github.com/rimeinn/rabbit/releases/latest)
[![Build Status](https://github.com/rimeinn/rabbit/actions/workflows/ci.yaml/badge.svg)](https://github.com/rimeinn/rabbit/actions/workflows/ci.yaml)
[![Telegram Group Chat](https://telegram-badge.vercel.app/api/telegram-badge?channelId=@rime_rabbit)](https://t.me/rime_rabbit)
[![License](https://img.shields.io/github/license/rimeinn/rabbit)](LICENSE)
[![GitHub Repo stars](https://img.shields.io/github/stars/rimeinn/rabbit?style=flat)](https://github.com/rimeinn/rabbit/stargazers)

## 下载体验

> [!NOTE]
> 发现程序漏洞请在 [Issues](https://github.com/rimeinn/rabbit/issues/new/choose) 反馈。使用问题可以在 [Discussions](https://github.com/rimeinn/rabbit/discussions) 讨论，或者加入 [Telegram 群聊](https://t.me/rime_rabbit)。

### 通过发布页面下载

正式发行版会在 [Release](https://github.com/rimeinn/rabbit/releases) 页面的 Assets 中，下载最新的 `rabbit-v<版本号>.zip`，解压到一个新建文件夹，运行 `Rabbit.exe` 即可。

每夜构建版可在 [`latest`](https://github.com/rimeinn/rabbit/releases/tag/latest) 页面下载。

### 通过 [scoop](https://scoop.sh/) 安装

```PowerShell
scoop bucket add siku https://github.com/amorphobia/siku
# 正式发行版
scoop install siku/rabbit
# 每夜构建版
scoop install siku/rabbit-nightly
```

## 脚本编译

本仓库提供*源码形式的玉兔毫脚本*以及*仅修改主图标的 AutoHotkey 可执行文件*，用户可根据需要自行编译为可执行文件以及压缩。编译方式可参照 AutoHotkey 的[官方文档](https://www.autohotkey.com/docs/v2/Scripts.htm#ahk2exe)。

编译并使用 `upx` 压缩后，64 位的可执行文件大小可减少为 `Rabbit.exe` - 约 570+ KB, `RabbitDeployer.exe` - 约 560+ KB。

## 目录结构

<details>
<summary>点击展开</summary>

> 以下描述的*可删除*、*编译后可删除*指的是删除后不影响使用，若要再次分发脚本或编译后的可执行文件，需遵守 [GPL-3.0 开源许可](LICENSE)。

```
rabbit/
├─ Data/                预设方案以及必要配置，内容删除后可能无法正常使用，若用户目录包含所有必要文件，可删除
├─ Lib/                 玉兔毫运行依赖脚本库，编译后可删除
|  ├─ librime-ahk       Rime 引擎的 AutoHotkey 绑定，编译后可删除
|  |  ├─ rime.dll       Rime 引擎的动态库，若本机已安装小狼毫，可删除；若没有安装小狼毫，需要 a. 保留在此，或 b. 放到主目录，或 c. 放到环境变量 "LIBRIME_LIB_DIR" 指定的目录
|  |  ├─ ...            librime-ahk 库的其他脚本，编译后可删除
|  ├─ ...               其他依赖，编译后可删除
├─ plum/                若使用东风破，将被安装到此路径
├─ Rime/                Rime 用户文件夹，运行后会自动生成；可修改注册表 "HKEY_CURRENT_USER\Software\Rime\Rabbit" 中的 "RimeUserDir" 来指定不同的用户文件夹
├─ LICENSE              开源许可，可删除
├─ Rabbit.ahk           玉兔毫主程序脚本
├─ Rabbit.exe           AutoHotkey 可执行文件，若本机已安装 AutoHotkey 或已编译，可删除
├─ RabbitDeployer.ahk   玉兔毫部署应用脚本
├─ README.md            本文件，可删除
├─ rime-install.bat     东风破批处理脚本，删除后无法从设定中调用东风破
```

</details>

## 使用的开源项目

- [librime](https://github.com/rime/librime)
- [librime-ahk](https://github.com/rimeinn/librime-ahk)
- [AHK-Direct2D](https://github.com/rawbx/AHK-Direct2D)
- [OpenCC](https://github.com/BYVoid/OpenCC)
- [GetCaretPos](https://github.com/Descolada/AHK-v2-libraries)
- [GetCaretPosEx](https://github.com/Tebayaki/AutoHotkeyScripts/tree/main/lib/GetCaretPosEx)
- [东风破](https://github.com/rime/plum)
- [小狼毫](https://github.com/rime/weasel)

以及一些代码片段，在注释中注明了来源链接

## 已知问题

- 某些情况无法获得输入光标的坐标；这只会影响候选框定位，候选框会回退到鼠标位置。Rabbit 不会仅因 caret 探测失败而禁用输入，而是根据当前焦点控件判断输入目标。
- Windows 文件资源管理器的文件视图、桌面图标区和任务栏非编辑控件会透传普通文本按键，以保留系统的按字母定位等行为；资源管理器地址栏、搜索框和重命名框仍可使用 Rabbit 输入。
- Rabbit 会根据 UI Automation 的 `IsPassword` 属性及原生编辑框的密码字符自动识别通用密码框；聚焦密码框时会临时停止拦截普通输入热键，让物理按键直接交给目标程序，离开后自动恢复。可在 `rabbit.custom.yaml` 中将 `bypass_password_fields` 设为 `false` 关闭此行为。
- 桌面版 QQ 密码框具有[防键盘钩子机制](https://blog.csdn.net/muyedongfeng/article/details/49308993)（[页面存档备份](https://web.archive.org/web/20240907052640/https://blog.csdn.net/muyedongfeng/article/details/49308993)）；上述自动绕过尚未在 QQ 中验证。若 QQ 的自绘密码框未暴露标准密码属性，仍需右键点击任务栏图标禁用/启用玉兔毫，或设置 `suspend_hotkey` 快捷键手动切换。
- 在 Windows 7 中打开玉兔毫时可能会造成系统一段时间无响应，需等待初始化完成，原因未知
