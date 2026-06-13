# clear_mac_app 使用说明

`delete-mac-app.sh` 用于在 macOS 上按 App 名称卸载应用，并清理该 App 的常见配置、缓存和应用数据。

## 使用方式

进入脚本目录：

```bash
cd /Users/ganghuang/HGFiles/GitHub/AITools/clear_mac_app
```

赋予执行权限：

```bash
chmod +x ./delete-mac-app.sh
```

按名称删除 App：

```bash
./delete-mac-app.sh Chrome
```

名称包含空格时使用引号：

```bash
./delete-mac-app.sh "Visual Studio Code"
```

也可以不带参数运行，脚本会提示输入 App 名称：

```bash
./delete-mac-app.sh
```

查看帮助：

```bash
./delete-mac-app.sh --help
```

## 删除范围

脚本会搜索 `/Applications` 和 `~/Applications` 中匹配名称的 `.app`。

确认后，脚本会把可安全归属到该 App 的项目移动到废纸篓，包括：

- App 本体
- 偏好设置
- 缓存
- Application Support 数据
- Saved Application State
- Containers
- 日志
- WebKit 数据
- HTTPStorages
- Cookies
- Application Scripts
- LaunchAgents
- LaunchDaemons
- PrivilegedHelperTools
- 崩溃日志

脚本不会直接永久删除文件，只会移动到废纸篓。

## 不会删除的项目

如果某些配置或数据可能影响其他软件、扩展、后台服务、同步功能或同厂商其他 App，脚本会标记为 `SKIPPED`，并且不会删除。

常见跳过项目包括：

- `~/Library/Group Containers` 中的共享容器
- 通过名称匹配到但可能属于共享功能的数据
- 可能被多个 App 共用的账号、同步、扩展或 helper 相关数据

执行脚本后，这些被跳过的项目会在输出中列出，并说明保留原因。

## 执行流程

脚本会先显示匹配到的 App 和相关数据清单。

清单中的项目分两类：

- `NORMAL`：确认后会移动到废纸篓
- `SKIPPED`：不会删除，只会说明原因

只有输入 `y` 或 `yes` 后，`NORMAL` 项才会被移动到废纸篓。

如果输入其他内容或直接回车，脚本不会删除任何内容。

## 注意事项

输入的 App 名称越宽泛，匹配结果越多。例如 `Code` 可能匹配多个带有 Code 的 App 或数据目录。

执行前请仔细检查脚本列出的清单。

如果误删了普通项目，可以从废纸篓恢复。
