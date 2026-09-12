# 快速开始

## 下载

玉兔毫可以直接解压运行，不要求管理员权限，也不会安装系统范围的输入法。若你拥有管理员权限并希望获得 Windows 上更完整的 Rime 集成体验，可以比较[小狼毫](https://github.com/rime/weasel)。

在 [Releases](https://github.com/rimeinn/rabbit/releases/latest) 中选择一种发行包：

- `rabbit-v<版本号>.zip`：完整目录，适合源码资源和运行文件一起使用；
- `rabbit-v<版本号>-compiled-x64.exe` 或 `x86.exe`：单文件编译版；
- `latest`：每夜构建版，包含开发中的改动。

也可以使用 Scoop：

```powershell
scoop bucket add siku https://github.com/amorphobia/siku
scoop install siku/rabbit
```

## 首次运行

1. 新建一个有写入权限的独立文件夹。
2. 将压缩包解压到该文件夹；单文件版则直接放入该文件夹。
3. 运行 `Rabbit.exe`。
4. 首次打开控制面板时，在“输入方案与选单”中选择至少一个方案。
5. 点击“完成安装并部署”。

部署完成后，玉兔毫会在通知区域运行。右键托盘图标可以打开设置、用户词典、用户资料同步、用户文件夹和日志文件夹。

## 每次修改后的生效方式

Rime 将配置、方案和词典编译为运行数据。修改配置文件后，通常需要在托盘菜单中选择“重新部署”，或在控制面板点击“应用并重新部署”。仅编辑文件不会立即改变当前会话。

## 用户文件

托盘菜单中的“用户文件夹”会打开当前 Rime 用户目录。常见文件包括：

- `rabbit.custom.yaml`：玉兔毫前端设置；
- `default.custom.yaml`：Rime 通用设置；
- `<方案标识>.custom.yaml`：某个输入方案的覆盖设置；
- 用户词典和学习数据：由 Rime 管理。

升级前建议先备份用户文件夹。卸载便携版时，删除程序目录不会自动删除你另外指定的 Rime 用户目录；删除前请确认是否需要保留词典和学习数据。
