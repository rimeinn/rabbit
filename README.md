# 🐇️玉兔毫

由 [AutoHotkey](https://www.autohotkey.com/) 实现的 [Rime 输入法引擎](https://github.com/rime/librime)前端

[![Download](https://img.shields.io/github/v/release/rimeinn/rabbit)](https://github.com/rimeinn/rabbit/releases/latest)
[![Build Status](https://github.com/rimeinn/rabbit/actions/workflows/ci.yaml/badge.svg)](https://github.com/rimeinn/rabbit/actions/workflows/ci.yaml)
[![Telegram Group Chat](https://telegram-badge.vercel.app/api/telegram-badge?channelId=@rime_rabbit)](https://t.me/rime_rabbit)
[![License](https://img.shields.io/github/license/rimeinn/rabbit)](LICENSE)
![GitHub Repo stars](https://img.shields.io/github/stars/rimeinn/rabbit?style=flat)

## 下载体验

> [!NOTE]
> 发现程序漏洞请在 [Issues](https://github.com/rimeinn/rabbit/issues/new/choose) 反馈。使用问题可以在 [Discussions](https://github.com/rimeinn/rabbit/discussions) 讨论，或者加入 [Telegram 群聊](https://t.me/rime_rabbit)。

### Release 版

发行版会在 [Release 页面](https://github.com/rimeinn/rabbit/releases) 的 Assets 中，下载最新的 `rabbit-v<版本号>.zip`，解压到一个新建文件夹，运行 `Rabbit.exe` 即可。

#### 通过 [scoop](https://scoop.sh/) 安装

```PowerShell
scoop bucket add siku https://github.com/amorphobia/siku
scoop install siku/rabbit
```

### 每夜构建版本 (Nightly)

每夜构建版本可在 [`latest` 标签](https://github.com/rimeinn/rabbit/releases/tag/latest)页面下载。

## 脚本编译

本仓库提供*源码形式的玉兔毫脚本*以及*仅修改主图标的 AutoHotkey 可执行文件*，用户可根据需要自行编译为可执行文件以及压缩。编译方式可参照 AutoHotkey 的[官方文档](https://www.autohotkey.com/docs/v2/Scripts.htm#ahk2exe)。

编译并使用 `upx` 压缩后，64 位的可执行文件大小可减少为 `Rabbit.exe` - 约 570+ KB, `RabbitDeployer.exe` - 约 560+ KB。

## 目录结构

> [!NOTE]
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

## 使用的开源项目

- [librime](https://github.com/rime/librime)
- [OpenCC](https://github.com/BYVoid/OpenCC)
- [AHKv2-Gdip](https://github.com/buliasz/AHKv2-Gdip)
- [librime-ahk](https://github.com/rimeinn/librime-ahk)
- [GetCaretPos](https://github.com/Descolada/AHK-v2-libraries)
- [GetCaretPosEx](https://github.com/Tebayaki/AutoHotkeyScripts/tree/main/lib/GetCaretPosEx)
- [东风破](https://github.com/rime/plum)
- [小狼毫](https://github.com/rime/weasel)

以及一些代码片段，在注释中注明了来源链接

## 已知问题

- 候选框图形界面较为简陋，有闪烁等问题
- 某些情况无法获得输入光标的坐标
- 桌面版 QQ 的密码输入框无法使用：[QQ密码输入框（防键盘钩子）原理分析](https://blog.csdn.net/muyedongfeng/article/details/49308993)，
（[页面存档备份](https://web.archive.org/web/20240907052640/https://blog.csdn.net/muyedongfeng/article/details/49308993)，存于互联网档案馆），可右键点击任务栏图标选择禁用/启用玉兔毫，或是在 `rabbit.custom.yaml` 里设置 `suspend_hotkey` 指定快捷键来禁用/启用玉兔毫
- 在 Windows 7 中打开玉兔毫时可能会造成系统一段时间无响应，需等待初始化完成，原因未知
