# macOS 通用软件卸载器

根据软件的真实应用包和 Bundle ID，清理应用本体及 macOS 常见残留数据。适用于大多数以 `.app` 形式安装的软件。

## 直接输入软件名并自动清理

```bash
cd /Users/huanggang/HGFiles/Code/GitHub/AISkills/macos-app-uninstaller
./scripts/uninstall_macos_app.sh "Visual Studio Code"
```

也可以传入应用路径：

```bash
./scripts/uninstall_macos_app.sh "Firefox"

./scripts/uninstall_macos_app.sh "/Applications/Firefox.app"
```

不传名称时，脚本会提示输入：

```bash
./scripts/uninstall_macos_app.sh
```

示例交互：

```text
请输入要卸载的软件名或 .app 路径：Firefox
已识别：Firefox
Bundle ID：org.mozilla.firefox
```

## 仅预览、不删除

```bash
./scripts/uninstall_macos_app.sh --dry-run "Firefox"
```

## 脚本会自动：
- 查找软件 .app
- 读取真实 Bundle ID
- 停止关联进程和启动项
- 清理缓存、日志、偏好设置、容器和 Application Support
- 清理 LaunchAgent、LaunchDaemon 和辅助程序
- 删除应用本体
- 遇到系统文件时弹出 macOS 管理员授权窗口
- 密码由 macOS 处理，脚本不会读取或保存

## 权限提示

仅当目标目录需要更高权限时会尝试弹出 macOS 管理员授权窗口。某些无图形终端环境无法完成授权，此时请在本机交互终端重新运行。密码由 macOS 处理，脚本不会读取或保存。

## 清理范围

- 应用 `.app`
- `Application Support`
- `Caches`
- `Preferences`
- `HTTPStorages`、`WebKit`
- `Saved Application State`
- 沙盒 `Containers`
- 应用包内同一 Bundle ID 命名空间下的辅助程序数据
- Cookies、ByHost 偏好和诊断报告
- 日志和崩溃报告
- 用户及系统 LaunchAgent/LaunchDaemon
- PrivilegedHelperTools 中与 Bundle ID 明确关联的辅助程序

脚本不会删除“文稿”“下载”等目录中的普通用户文件。

## 磁盘扫描与残留清理（独立 Shell 脚本）

脚本是 `scripts/scan_app_junk.sh`，使用 macOS 自带 `/bin/bash` 3.2、`find`、`stat`、`du` 和 `PlistBuddy`，**不需要 Python、Homebrew 或管理员权限**。默认只读；任何清理都必须明确加上 `--execute`。

### 1. 只读扫描

```bash
cd /Users/huanggang/HGFiles/Code/GitHub/AISkills/macos-app-uninstaller

# 不指定时间：扫描全部符合目录规则的候选，不删除
./scripts/scan_app_junk.sh

# 指定时间：仅列出整个目标最近 30 天都未更新的项目
./scripts/scan_app_junk.sh --days 30

# 只看 90 天以上未更新的项目，并保存完整报告
./scripts/scan_app_junk.sh --days 90 > "$HOME/Desktop/app-junk-report.txt"

# 查看参数帮助
./scripts/scan_app_junk.sh --help
```

**不带 `--days` = 全部时间**，不是默认 30 天；带 `--days N` 只列出最近 N 天没有更新的候选。报告逐项显示类别、路径和 `du` 估算占用（KB），并汇总候选大小。占用不等于一定能释放的空间。

### 2. 清理缓存和日志

```bash
# 清理 90 天以上未更新的用户缓存/日志
./scripts/scan_app_junk.sh --days 90 --execute

# 不限时间：清理扫描到的全部候选缓存/日志，包含仍在使用的应用缓存
./scripts/scan_app_junk.sh --execute

# 只清理扫描清单中的一个缓存目录
./scripts/scan_app_junk.sh --execute --select "$HOME/Library/Caches/com.example.app"
```

交互终端中需输入 `DELETE` 确认；对于经你核准的普通缓存/日志，非交互环境可额外使用 `--yes`，例如 `./scripts/scan_app_junk.sh --days 90 --execute --yes`。**务必先只读查看清单**：普通缓存即使目前在使用，也可能被删除并重新生成。CocoaPods/Yarn/Homebrew 等开发依赖缓存、系统服务缓存、应用迁移缓存、诊断报告及单项不小于 256 MB 的缓存被标为“重要或大体积缓存/诊断”，**不会被普通 `--execute` 自动删除**；下载的安装包、应用副本及疑似卸载应用数据也不会自动删除。

脚本打印每个已删除路径及大小，并输出按 `du` 估算的 **MB、GB** 总量和执行前后 `df` 显示的可用空间变化。两者可能不同：APFS 快照、硬链接/克隆、正在写入的文件或应用立即重新生成缓存都会影响实际值。失败或未删除的路径不计入“已删除”。

实际输出示例（2026-11-23 的一次运行）：

```text
已删除：19228 KB | /Users/huanggang/Library/Caches/.lingma
...
完成：删除 32 项，失败或跳过 0 项；按目标文件估算释放 34.3 MB (0.03 GB)。
磁盘可用空间变化：+29.9 MB (+0.03 GB)；APFS 快照、缓存重建等可能影响此数值。
```

这次的**完整删除路径、全部未删除路径、大小及具体风险**记录在 `reports/cleanup-2026-11-23.md`；清理后需要继续检查时，重新运行不带 `--execute` 的扫描命令。注意已运行的应用可能立即重建少量缓存或日志。

### 3. 单独清理下载的安装包或应用副本

```bash
./scripts/scan_app_junk.sh --execute --include-downloads \
  --select "$HOME/Downloads/Example-Installer.dmg"
```

支持 `~/Downloads` 顶层的 `.dmg`、`.pkg`、`.mpkg`、`.app.zip`、`.app`，只有被扫描列出的精确完整路径才能选择。`.app` 可能是唯一运行中的应用，不要仅凭“它在下载目录”就删除。**必须在交互终端输入 `DELETE`；`--yes` 对此类别无效。**

### 4. 核实后单独清理疑似卸载残留

```bash
./scripts/scan_app_junk.sh --execute --include-data \
  --select "$HOME/Library/Application Support/com.example.removed"
```

只报告 `~/Library/Application Support`、`~/Library/Containers`、`~/Library/HTTPStorages` 顶层 Bundle ID 形状的目录/文件。如果未匹配到扫描到的应用 Bundle ID，它**只是疑似**残留：软件可能装在其他位置、使用另一 Bundle ID，或者数据由其他仍在运行的软件共用。先核实来源，再在交互终端逐项输入 `DELETE`；不支持批量清理或 `--yes`。

### 5. 按路径清理“重要或大体积缓存/诊断”

```bash
# 示例：仅在退出 Trae 并核实缓存可重新获取后，单独清理其缓存
./scripts/scan_app_junk.sh --execute --include-review \
  --select "$HOME/Library/Caches/Trae"

# 示例：只清理一个经核实不再需要的旧诊断报告目录
./scripts/scan_app_junk.sh --execute --include-review \
  --select "$HOME/Library/Logs/DiagnosticReports"
```

务必先核实具体目录是否有离线依赖、软件迁移数据、故障诊断日志或重新下载成本。只有目录仍出现在当前扫描结果中，才能通过 `--select` 选中；在交互终端输入 `DELETE` 确认，不能加 `--yes`。普通缓存如只想清理单项，则直接 `--execute --select '完整路径'`。

**CocoaPods 是特例**：不要用通用扫描器对 `~/Library/Caches/CocoaPods` 整目录清理；请使用下方的 CocoaPods 专用版本裁剪脚本。

### 扫描范围、安全限制和验证

- 应用索引来自 `/Applications`、`~/Applications`、`/System/Applications`、`~/Downloads` 中的 `.app/Contents/Info.plist`。
- 缓存与日志只扫描当前用户 `~/Library/Caches` 和 `~/Library/Logs` 的**顶层项目**；不会清理 `com.apple.*`、`org.freedesktop.*` 项。其他系统服务缓存、重要开发缓存及大体积缓存仍会列出供核实，但默认不删。
- 不扫描其他账号、整块磁盘、`/Library` 系统目录、用户文稿、项目代码或主目录中的隐藏文件；因此不能保证找出所有残留。
- 跳过符号链接。删除前复查路径是否仍在限定目录、是否变更；权限不足时跳过并报告失败，不自动提权。
- 可以连续使用多个 `--select`；选中安装包或应用数据时仍需对应的 `--include-downloads` / `--include-data`，且必须人工确认。
- 查看退出状态、删除/跳过计数并再次执行只读扫描，以核对实际清理结果。

在本机临时目录测试扫描器的扫描、限时筛选、实际删除和敏感数据保护（测试只操作新建临时文件）：

```bash
bash tests/test_scan_app_junk.sh
```

## CocoaPods 缓存按版本裁剪（单独脚本）

`~/Library/Caches/CocoaPods/Pods` 可能有大量项目依赖缓存。**不要**使用通用扫描器的 `--include-review --select "$HOME/Library/Caches/CocoaPods"` 整目录清除；改用 `scripts/prune_cocoapods_cache.sh` 保留近期缓存。脚本只需要 macOS 自带的 Bash/`find`/`stat`/`du`/`sort`/`awk`，不需要 Python 或 CocoaPods CLI。

实际目录：`Pods/Release/<Pod>/<版本-校验后缀>` 与 `Pods/External/<Pod>/<哈希快照>`。External 的目录名是来源/哈希缓存键，**不是可靠的语义版本号**；脚本仍按每个 Pod 分组保留最新快照。`Pods/Specs/<Release|External>/<Pod>/<同名条目>.podspec.json` 只有当对应缓存目录被成功删除且 podspec 本身也非近期文件时才会删除；不修改 `Pods/VERSION` 或其他内容。

**保留规则，按优先级执行：**

1. 对每个 Pod 的 `Release` 和 `External` 分别处理；最近 **15 天**内目录**或其内部任何文件**有改动，或者对应 podspec 最近改动，整项保留。
2. 按缓存目录修改时间从新到旧排序，从其余旧项目中补足到每组**至少 3 项**（可用 `--keep 2` 指定至少 2 项）。
3. 如果近期缓存已有 4 项，即使超过 3 项也全部保留；如果一组不足 3 项则全部保留。
4. 只有其余过旧条目列为删除候选；执行时还会检查路径、改动时间及最近 15 天的文件，变更的项目跳过。

例如：某 Pod 有 5 个缓存，其中 1 项在 15 天内有改动，则保留该项和按修改时间排序较新的另外 2 项，删除最旧的 2 项。

### 预览、执行与桌面日志

```bash
cd /Users/huanggang/HGFiles/Code/GitHub/AISkills/macos-app-uninstaller

# 只读预览：默认保留最近 15 天及每组至少 3 项
./scripts/prune_cocoapods_cache.sh

# 确认预览后执行；终端要求输入 DELETE
./scripts/prune_cocoapods_cache.sh --execute

# 无交互终端，已检查预览且明确授权后执行
./scripts/prune_cocoapods_cache.sh --execute --yes

# 自定义保留数与近期时长：最近 20 天全部保留，每组至少 2 项
./scripts/prune_cocoapods_cache.sh --days 20 --keep 2
./scripts/prune_cocoapods_cache.sh --days 20 --keep 2 --execute

# 指定日志完整路径（默认自动生成到 ~/Desktop）
./scripts/prune_cocoapods_cache.sh --report "$HOME/Desktop/my-cocoapods-preview.log"
```

**每次运行（包括只读预览）都会生成桌面日志**：`~/Desktop/cocoapods-cache-年月日-时分秒.随机字符.log`。日志包含每条保留/计划删除/实际删除的路径、Pod 分组、大小、原因，以及汇总 MB/GB、`du` 目录缩减量和 `df` 磁盘可用空间变化。报告可能有几千行，可按关键词搜索 `计划汇总`、`执行汇总`、`跳过`。也可用 `--report` 指定路径；此选项会覆盖同名已有文件，请用新文件名。

删除这些缓存后，以前的项目可能需要联网重新下载旧版 Pod 或外部 Git 依赖；如果依赖仓库已下线，旧工程的离线编译可能失败。**先预览、确认旧工程可接受此风险**。脚本不更改项目里的 `Podfile`、`Podfile.lock`、`Pods/` 或源码，只处理当前用户 CocoaPods 的缓存目录。

测试（仅使用新建的临时目录，真实执行测试数据的删除）：

```bash
bash tests/test_prune_cocoapods_cache.sh
```
