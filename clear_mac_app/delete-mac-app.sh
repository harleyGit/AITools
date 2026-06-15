#!/bin/zsh

# 让脚本尽早暴露错误，避免在状态不完整时继续执行：
#   -e：任意命令失败时立即退出。
#   -u：使用未定义变量时报错，方便发现变量名拼写错误。
#   pipefail：管道中任意一段失败时，整个管道视为失败。
# 对于“文件不存在”这类预期内情况，脚本会显式使用 `|| true` 或
# `return 0` 覆盖非零退出码，避免误触发 `set -e`。
set -euo pipefail

# 打印使用说明。把说明集中在函数里，便于 `--help` 和后续可能增加的
# 参数校验共用同一份输出，减少文案不一致。
print_usage() {
  cat <<'EOF'
Usage:
  ./delete-mac-app.sh [AppName]

Examples:
  ./delete-mac-app.sh Chrome
  ./delete-mac-app.sh "Visual Studio Code"

If AppName is omitted, the script will ask for it.

What it removes after confirmation:
  - Matched .app bundle(s)
  - Related preferences, caches, saved state, logs, containers, group containers,
    application support files, crash reports, launch agents, and similar app data

Safety behavior:
  - Everything is moved to Trash, not permanently deleted.
  - Shared or broad matches that may affect other apps or system functionality are
    marked SKIPPED and are never deleted by this script.
  - After running, skipped items are listed with the reason they were preserved.
EOF
}

# 去掉用户输入首尾空白。App 名称经常从 Finder 复制或手动输入，首尾多一个
# 空格会导致匹配失败，因此在真正搜索前统一清理。
#
# 注意：这里使用的是 zsh 的模式语法，不是 POSIX sh 语法。脚本 shebang 已
# 明确指定 zsh，所以 `${value##[[:space:]]#}` 这种写法是有意为之。
trim() {
  local value="$1"
  value="${value##[[:space:]]#}"
  value="${value%%[[:space:]]#}"
  printf '%s' "$value"
}

# 历史辅助函数，保留用于兼容早期版本脚本的写法。它会在参数列表不存在某个
# 项时，以 NUL 分隔形式输出该项。当前主流程已经改用 `dedupe_items` 统一
# 去重，所以这个函数不参与实际删除路径。
append_unique() {
  local item="$1"
  local existing

  [[ -n "$item" ]] || return
  for existing in "$@"; do
    [[ "$existing" == "$item" ]] && return
  done
  printf '%s\0' "$item"
}

# 把目标移动到废纸篓，而不是永久删除。
#
# 为什么不用 `rm -rf`：
#   删除 App 数据风险较高，移动到废纸篓可以给误匹配或误操作留下恢复机会。
#
# 为什么优先使用 `trash` 命令：
#   如果用户安装了 `trash`，它通常能更贴近 Finder 的废纸篓行为。
#
# 为什么 fallback 不再依赖 Finder/AppleScript：
#   某些命令行环境没有 `osascript`，AppleScript 也可能受 GUI 权限限制。
#   直接用 `/bin/mv` 移到 `~/.Trash` 更适合脚本环境。
#
# 如何处理废纸篓重名：
#   如果废纸篓里已有同名文件，就依次追加 `.1`、`.2`，避免覆盖已有内容。
move_to_trash() {
  local target="$1"
  local trash_dir="$HOME/.Trash"
  local target_name="${target:t}"
  local destination="$trash_dir/$target_name"
  local counter=1

  if command -v trash >/dev/null 2>&1; then
    trash "$target"
    return
  fi

  /bin/mkdir -p "$trash_dir"
  while [[ -e "$destination" ]]; do
    destination="$trash_dir/${target_name}.$counter"
    counter=$((counter + 1))
  done

  /bin/mv "$target" "$destination"
}

# 使用管理员权限把目标移动到当前用户废纸篓。
#
# 这个函数只在普通移动失败、且用户明确同意授权后调用。它不会自动尝试 sudo，
# 避免脚本在用户没有心理准备时弹出密码输入或提升权限。
#
# 为什么仍然移动到当前用户的 `~/.Trash`：
#   这样用户可以在自己的废纸篓里看到被移动的项目，必要时还能恢复。
#
# 为什么最后要 `chown`：
#   `sudo mv` 移动后的文件可能保持 root 或原 owner。把废纸篓内目标重新归属
#   给当前用户，可以避免用户之后无法从废纸篓恢复或清空。
move_to_trash_with_sudo() {
  local target="$1"
  local trash_dir="$HOME/.Trash"
  local target_name="${target:t}"
  local destination="$trash_dir/$target_name"
  local counter=1

  if ! command -v sudo >/dev/null 2>&1; then
    echo "  sudo is not available in this environment."
    return 1
  fi

  /bin/mkdir -p "$trash_dir"
  while [[ -e "$destination" ]]; do
    destination="$trash_dir/${target_name}.$counter"
    counter=$((counter + 1))
  done

  sudo /bin/mv "$target" "$destination"
  sudo /usr/sbin/chown -R "$USER" "$destination" 2>/dev/null || true
}

# 记录一个已经发现、且当前真实存在的候选路径。
#
# risk 表示处理策略：
#   normal：认为可以在用户确认后移动到废纸篓。
#   skip：可能被其他 App、扩展、后台服务或系统功能共享，本脚本只说明不删除。
#
# reason 会和路径一起保存，最终输出时用于解释“为什么选中”或“为什么保留”。
# macOS 的应用数据路径经常只显示 bundle id，单看路径不一定能看出用途，
# 所以保留原因对安全确认很重要。
add_existing_path() {
  local risk="$1"
  local path="$2"
  local reason="$3"

  # 很多候选路径是可选的。例如并非所有 App 都有 WebKit 数据、LaunchAgent
  # 或崩溃日志。路径不存在属于正常情况，因此返回成功，避免触发 `set -e`。
  [[ -e "$path" ]] || return 0
  item_paths+=("$path")
  item_risks+=("$risk")
  item_reasons+=("$reason")
}

# 在指定 Library 目录里按“名称包含 app_name”做较宽泛的匹配。
#
# 参数说明：
#   risk：发现后使用的处理策略，传给 `add_existing_path`。
#   dir：要扫描的目录。
#   maxdepth：最多扫描几层，避免在巨大的 Library 目录里深度递归。
#   reason：展示给用户看的说明。
#
# 为什么需要名称匹配：
#   有些 App 的数据目录不用 bundle id 命名，而是使用市场名称、公司名称或
#   简写。只靠 bundle id 会漏掉这些目录。
#
# 为什么限制 maxdepth：
#   `~/Library` 下可能有大量文件，深度扫描会慢，也会增加误匹配概率。
collect_name_matches() {
  local risk="$1"
  local dir="$2"
  local maxdepth="$3"
  local reason="$4"
  local base

  # 不同 macOS 版本或不同用户环境下，某些 Library 子目录可能不存在。
  [[ -d "$dir" ]] || return

  # 使用 `find -print0` 和 `read -d ''`，可以安全处理包含空格、换行、中文
  # 或其他特殊字符的路径。
  while IFS= read -r -d '' path; do
    base="${path:t}"
    # `${var:l}` 是 zsh 的小写转换。这里故意使用模糊匹配，例如输入 Chrome
    # 可以匹配 Google Chrome。真正删除前仍会展示完整清单并要求确认。
    if [[ "${base:l}" == *"${app_name:l}"* ]]; then
      add_existing_path "$risk" "$path" "$reason"
    fi
  done < <(find "$dir" -maxdepth "$maxdepth" -mindepth 1 -print0 2>/dev/null)
}

# 在指定目录里收集“文件名以 bundle id 开头”的路径。
#
# 这种前缀匹配比普通名称模糊匹配更窄，适合处理 macOS 或 helper 工具生成的
# 后缀文件，例如：
#   com.vendor.App.crash
#   com.vendor.App.helper
collect_prefix_matches() {
  local risk="$1"
  local dir="$2"
  local prefix="$3"
  local reason="$4"
  local base

  [[ -d "$dir" ]] || return

  while IFS= read -r -d '' path; do
    base="${path:t}"
    if [[ "$base" == "$prefix"* ]]; then
      add_existing_path "$risk" "$path" "$reason"
    fi
  done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
}

# 根据 CFBundleIdentifier 收集和 App 强相关的数据路径。
#
# macOS App 通常会声明类似 `com.google.Chrome` 的 CFBundleIdentifier。很多
# 应用数据不是按 Finder 里的显示名称保存，而是按这个 bundle id 保存。例如
# “Google Chrome.app”的大量数据会保存在 `com.google.Chrome` 相关目录下。
#
# 这里把候选路径分成两类：
#   safe_roots：通常只属于当前 App，可作为 normal 项展示给用户确认删除。
#   high_risk_roots：可能被同厂商 App、扩展、同步服务或后台工具共享。
#
# 注意：变量名仍叫 high_risk_roots，是为了表达“这些路径风险高”；实际加入
# 清单时会标记为 skip，也就是只说明、不删除。
add_bundle_id_paths() {
  local bundle_id="$1"
  local app_base="$2"
  local safe_roots high_risk_roots root

  [[ -n "$bundle_id" ]] || return

  # 常见的用户级和系统级 App 数据位置：
  #
  # Preferences：
  #   用户偏好设置，通常是 plist 文件。
  # Caches：
  #   可重建缓存，通常随 App 删除是安全的。
  # Saved Application State：
  #   macOS 用于恢复窗口和会话状态的数据。
  # Application Scripts：
  #   沙盒 App 的脚本和自动化权限相关文件。
  # HTTPStorages/WebKit/Cookies：
  #   WebView、内嵌浏览器、登录态、Cookie 或网络存储。
  # Logs/CrashReporter：
  #   日志和崩溃诊断文件。
  # Containers：
  #   App 沙盒容器；当目录名精确等于 bundle id 时，通常属于该 App。
  # Application Support：
  #   数据库、配置库、下载资源、索引、用户数据等支持文件。
  # LaunchAgents/LaunchDaemons/PrivilegedHelperTools：
  #   后台启动项、守护进程或特权 helper。脚本会展示给用户确认后才处理。
  safe_roots=(
    "$HOME/Library/Preferences/$bundle_id.plist"
    "$HOME/Library/Preferences/ByHost/$bundle_id"
    "$HOME/Library/Caches/$bundle_id"
    "$HOME/Library/Saved Application State/$bundle_id.savedState"
    "$HOME/Library/Application Scripts/$bundle_id"
    "$HOME/Library/HTTPStorages/$bundle_id"
    "$HOME/Library/WebKit/$bundle_id"
    "$HOME/Library/Cookies/$bundle_id.binarycookies"
    "$HOME/Library/Logs/$bundle_id"
    "$HOME/Library/Containers/$bundle_id"
    "$HOME/Library/Application Support/$bundle_id"
    "$HOME/Library/LaunchAgents/$bundle_id.plist"
    "$HOME/Library/LaunchDaemons/$bundle_id.plist"
    "/Library/LaunchAgents/$bundle_id.plist"
    "/Library/LaunchDaemons/$bundle_id.plist"
  )

  # Group Containers 是共享容器，可能保存同一厂商多个 App、扩展、同步组件
  # 或后台服务共用的数据。即使名称看起来和当前 App 相关，也不应由本脚本
  # 自动删除，所以统一标记为 skip。
  high_risk_roots=(
    "$HOME/Library/Group Containers/$bundle_id"
    "$HOME/Library/Group Containers/*$bundle_id*"
  )

  for root in "${safe_roots[@]}"; do
    add_existing_path "normal" "$root" "Bundle ID match: $bundle_id"
  done

  # `${~root}(N)` 是 zsh 写法：
  #   ${~root}：把变量里的通配符当作模式展开。
  #   (N)：启用 null-glob，没匹配时返回空列表，而不是报错。
  # 这里用于展开第二个 Group Containers 通配符模式。
  for root in "${high_risk_roots[@]}"; do
    for expanded in ${~root}(N); do
      add_existing_path "skip" "$expanded" "Shared container match: may affect other apps from the same vendor/account"
    done
  done

  collect_prefix_matches "normal" "$HOME/Library/Application Support/CrashReporter" "$bundle_id" "Crash report match: $bundle_id"
  collect_prefix_matches "normal" "/Library/PrivilegedHelperTools" "$bundle_id" "Privileged helper match: $bundle_id"
}

# 去重候选项。
#
# 同一个路径可能通过 bundle id 和名称匹配被发现多次。这里保留第一次发现时
# 的分类和原因，避免最终确认清单重复、难读。
dedupe_items() {
  local paths=() risks=() reasons=()
  local i seen_key
  typeset -A seen

  for i in {1..${#item_paths[@]}}; do
    seen_key="${item_paths[$i]}"
    [[ -n "${seen[$seen_key]:-}" ]] && continue
    seen[$seen_key]=1
    paths+=("${item_paths[$i]}")
    risks+=("${item_risks[$i]}")
    reasons+=("${item_reasons[$i]}")
  done

  item_paths=("${paths[@]}")
  item_risks=("${risks[@]}")
  item_reasons=("${reasons[@]}")
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

# App 名称支持两种输入方式：
#   1. 作为命令行参数传入。
#   2. 不传参数时由脚本交互式询问。
#
# `${*:-}` 会把所有参数拼成一个字符串，因此即使用户没有加引号运行：
#   ./delete-mac-app.sh Visual Studio Code
# 脚本也会尽量把它理解成一个完整 App 名称。仍然建议用户对带空格名称加引号。
app_name="${*:-}"
if [[ -z "$app_name" ]]; then
  printf "Enter app name to delete: "
  read -r app_name || app_name=""
fi

app_name="$(trim "$app_name")"
if [[ -z "$app_name" ]]; then
  echo "No app name provided."
  exit 1
fi

search_dirs=(
  "/Applications"
  "$HOME/Applications"
)

# 第一步先找真正安装的 `.app` 包。这样做的原因是 `.app/Contents/Info.plist`
# 中的 CFBundleIdentifier 是后续定位配置、缓存、容器数据的关键线索。
app_matches=()
for dir in "${search_dirs[@]}"; do
  [[ -d "$dir" ]] || continue

  while IFS= read -r -d '' app_path; do
    app_base="${app_path:t:r}"
    # 对 Finder 中显示的 App 名称做大小写不敏感的模糊匹配。输入越宽泛，匹配
    # 结果可能越多，所以后续一定会先展示清单并要求确认。
    if [[ "${app_base:l}" == *"${app_name:l}"* ]]; then
      app_matches+=("$app_path")
    fi
  done < <(find "$dir" -maxdepth 2 -type d -name "*.app" -print0 2>/dev/null)
done

if (( ${#app_matches[@]} == 0 )); then
  echo "No app matched: $app_name"
  echo "Searched: ${search_dirs[*]}"
  exit 1
fi

echo "Matched app(s):"
for i in {1..${#app_matches[@]}}; do
  echo "  [$i] ${app_matches[$i]}"
done

item_paths=()
item_risks=()
item_reasons=()

# 尽量读取 CFBundleIdentifier，因为 macOS 的应用数据通常按 bundle id 存放，
# 而不是按 Finder 里看到的 App 名称存放。
#
# 同时保留 app_base，是因为有些 App 的 Application Support 或缓存目录会使用
# 市场名称、品牌名或简称，名称扫描仍然是有价值的兜底策略。
bundle_ids=()
app_bases=()
for app_path in "${app_matches[@]}"; do
  app_base="${app_path:t:r}"
  # `defaults read` 可能因为 App 包异常、Info.plist 缺失或字段不存在而失败。
  # 这种失败不应中断脚本；即使没有 bundle id，也仍然可以展示 App 本体和
  # 名称匹配发现的候选数据。
  bundle_id="$(defaults read "$app_path/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  bundle_id="$(trim "$bundle_id")"

  app_bases+=("$app_base")
  [[ -n "$bundle_id" ]] && bundle_ids+=("$bundle_id")

  add_existing_path "normal" "$app_path" "Application bundle"
  add_bundle_id_paths "$bundle_id" "$app_base"
done

# 名称匹配兜底扫描。大多数用户级数据目录标记为 normal，但 Group Containers
# 属于共享容器，始终标记为 skip，只说明不删除。
collect_name_matches "normal" "$HOME/Library/Application Support" 2 "Name match in Application Support"
collect_name_matches "normal" "$HOME/Library/Caches" 1 "Name match in Caches"
collect_name_matches "normal" "$HOME/Library/Logs" 2 "Name match in Logs"
collect_name_matches "normal" "$HOME/Library/Saved Application State" 1 "Name match in Saved Application State"
collect_name_matches "normal" "$HOME/Library/Preferences" 1 "Name match in Preferences"
collect_name_matches "skip" "$HOME/Library/Group Containers" 1 "Name match in shared Group Containers; may affect other apps"

dedupe_items

# 执行任何移动操作前，先展示完整计划：
#   NORMAL：用户确认后会移动到废纸篓。
#   SKIPPED：可能影响其他 App 或功能，本脚本不会删除，只说明保留原因。
echo
echo "Items selected for removal:"
normal_count=0
skip_count=0
for i in {1..${#item_paths[@]}}; do
  risk_label="NORMAL"
  if [[ "${item_risks[$i]}" == "skip" ]]; then
    risk_label="SKIPPED"
    skip_count=$((skip_count + 1))
  else
    normal_count=$((normal_count + 1))
  fi
  echo "  [$i] [$risk_label] ${item_paths[$i]}"
  echo "      ${item_reasons[$i]}"
done

echo
echo "Summary: $normal_count removable item(s), $skip_count skipped item(s)."
echo "Removable items will be moved to Trash, not permanently deleted."
if (( skip_count > 0 )); then
  echo "Skipped items may affect other apps or system functionality, so this script will not delete them."
fi

# 删除前必须显式确认。默认答案是 No，直接回车不会删除任何内容。
printf "Move NORMAL items to Trash? [y/N] "
read -r normal_answer || normal_answer=""
case "${normal_answer:l}" in
  y|yes) delete_normal=true ;;
  *) delete_normal=false ;;
esac

if [[ "$delete_normal" != true ]]; then
  echo "Nothing selected for deletion."
  if (( skip_count > 0 )); then
    echo
    echo "Skipped items preserved because they may affect other apps or functionality:"
    # 即使用户选择不删除，也输出保留项，方便用户知道为什么还有相关文件留在磁盘。
    for i in {1..${#item_paths[@]}}; do
      if [[ "${item_risks[$i]}" == "skip" ]]; then
        echo "  - ${item_paths[$i]}"
        echo "    ${item_reasons[$i]}"
      fi
    done
  fi
  exit 0
fi

echo
for i in {1..${#item_paths[@]}}; do
  should_delete=false
  # 只有 normal 项会被删除，而且必须已经得到用户确认。当前策略下 skip 项永远
  # 不会删除；如果未来增加新策略，默认也应保持保守。
  if [[ "${item_risks[$i]}" != "skip" && "$delete_normal" == true ]]; then
    should_delete=true
  fi

  # SKIPPED 项即使在用户确认删除 NORMAL 项后，也仍然只保留不删除，避免破坏
  # 其他 App、扩展、同步服务或后台功能。
  if [[ "$should_delete" != true ]]; then
    echo "Preserved: ${item_paths[$i]}"
    echo "  Reason: ${item_reasons[$i]}"
    continue
  fi

  if [[ ! -e "${item_paths[$i]}" ]]; then
    # 扫描和删除之间，路径可能被其他进程或用户操作删除。把它当作无害跳过。
    echo "Skipped missing path: ${item_paths[$i]}"
    continue
  fi

  echo "Moving to Trash: ${item_paths[$i]}"
  # 移动某个项目可能因为权限不足失败，例如普通用户移动 /Applications 下的
  # 系统级 App。失败时记录原因并继续处理后续项目，避免一个权限问题阻断
  # 其他可清理的用户级缓存或配置文件。
  if ! move_to_trash "${item_paths[$i]}"; then
    echo "Failed to move to Trash: ${item_paths[$i]}"
    echo "  Reason: permission denied or target is protected."
    echo "  This item may require administrator permission."
    printf "Grant administrator permission and try this item again? [y/N] "
    read -r permission_answer || permission_answer=""
    case "${permission_answer:l}" in
      y|yes)
        echo "Retrying with administrator permission: ${item_paths[$i]}"
        if move_to_trash_with_sudo "${item_paths[$i]}"; then
          echo "Moved with administrator permission: ${item_paths[$i]}"
        else
          echo "Failed even with administrator permission: ${item_paths[$i]}"
          echo "  You may need to remove it manually from Finder or System Settings."
        fi
        ;;
      *)
        echo "Skipped because administrator permission was not granted: ${item_paths[$i]}"
        ;;
    esac
    continue
  fi
done

if (( skip_count > 0 )); then
  echo
  echo "Skipped items preserved because they may affect other apps or functionality:"
  # 删除完成后再次汇总保留项，使最终终端输出自洽，方便复制到记录或反馈里。
  for i in {1..${#item_paths[@]}}; do
    if [[ "${item_risks[$i]}" == "skip" ]]; then
      echo "  - ${item_paths[$i]}"
      echo "    ${item_reasons[$i]}"
    fi
  done
fi

echo "Finished. Open Trash if you want to restore or permanently delete the removed item(s)."
