#!/bin/bash

set -o pipefail

MODE="execute"
if [[ "${1:-}" == "--dry-run" ]]; then
  MODE="dry-run"
  shift
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
用法：
  uninstall_macos_app.sh "软件名"             自动卸载并清理
  uninstall_macos_app.sh "/路径/软件.app"     按应用路径卸载
  uninstall_macos_app.sh --dry-run "软件名"   只预览
  uninstall_macos_app.sh                     交互输入软件名并自动卸载

需要删除系统文件时会弹出 macOS 管理员授权窗口。
EOF
  exit 0
fi

QUERY="${1:-}"
if [[ -z "$QUERY" ]]; then
  if [[ ! -t 0 ]]; then
    echo "错误：非交互环境必须提供软件名或 .app 路径。" >&2
    exit 2
  fi
  read -r -p "请输入要卸载的软件名或 .app 路径：" QUERY
fi
[[ -n "$QUERY" ]] || { echo "错误：软件名不能为空。" >&2; exit 2; }

ORIGINAL_HOME="${TARGET_USER_HOME:-$HOME}"
TARGET_UID="${TARGET_USER_UID:-$(stat -f %u "$ORIGINAL_HOME" 2>/dev/null || id -u)}"

find_apps() {
  local query="$1"
  if [[ "$query" == *.app && -d "$query" ]]; then
    printf '%s\n' "$query"
    return
  fi

  local wanted="${query%.app}.app"
  find /Applications "$ORIGINAL_HOME/Applications" \
    -maxdepth 3 -type d -iname "$wanted" -prune -print 2>/dev/null
}

mapfile_compat() {
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && APP_CANDIDATES+=("$line")
  done
}

APP_CANDIDATES=()
mapfile_compat < <(find_apps "$QUERY")

if [[ "${#APP_CANDIDATES[@]}" -eq 0 ]]; then
  echo "错误：未在 /Applications 或 ~/Applications 找到“$QUERY”。" >&2
  echo "请传入准确软件名或完整 .app 路径。" >&2
  exit 1
fi

if [[ "${#APP_CANDIDATES[@]}" -gt 1 ]]; then
  if [[ ! -t 0 ]]; then
    echo "错误：找到多个候选，请改用完整 .app 路径：" >&2
    printf '  %s\n' "${APP_CANDIDATES[@]}" >&2
    exit 1
  fi
  echo "找到多个应用："
  select selected in "${APP_CANDIDATES[@]}"; do
    [[ -n "$selected" ]] && { APP_PATH="$selected"; break; }
  done
else
  APP_PATH="${APP_CANDIDATES[0]}"
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || { echo "错误：应用缺少 Info.plist：$APP_PATH" >&2; exit 1; }

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST" 2>/dev/null || true
}

BUNDLE_ID="$(plist_value CFBundleIdentifier)"
APP_NAME="$(plist_value CFBundleDisplayName)"
[[ -n "$APP_NAME" ]] || APP_NAME="$(plist_value CFBundleName)"
[[ -n "$APP_NAME" ]] || APP_NAME="$(basename "$APP_PATH" .app)"
[[ -n "$BUNDLE_ID" ]] || { echo "错误：无法读取 Bundle ID，已中止以避免误删。" >&2; exit 1; }

BUNDLE_IDS=("$BUNDLE_ID")
while IFS= read -r child_plist; do
  child_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$child_plist" 2>/dev/null || true)
  case "$child_id" in
    "$BUNDLE_ID".*)
      duplicate=0
      for known_id in "${BUNDLE_IDS[@]}"; do
        [[ "$known_id" == "$child_id" ]] && duplicate=1
      done
      [[ "$duplicate" -eq 1 ]] || BUNDLE_IDS+=("$child_id")
      ;;
  esac
done < <(find "$APP_PATH/Contents" -name Info.plist -maxdepth 8 -print 2>/dev/null)

USER_TARGETS=("$APP_PATH")
SYSTEM_TARGETS=()

add_if_exists() {
  local scope="$1" path="$2"
  [[ -e "$path" || -L "$path" ]] || return 0
  local existing
  if [[ "$scope" == "user" ]]; then
    for existing in "${USER_TARGETS[@]}"; do [[ "$existing" == "$path" ]] && return 0; done
    USER_TARGETS+=("$path")
  else
    for existing in "${SYSTEM_TARGETS[@]}"; do [[ "$existing" == "$path" ]] && return 0; done
    SYSTEM_TARGETS+=("$path")
  fi
}

collect_exact_targets() {
  local home="$ORIGINAL_HOME"
  local path current_id

  for path in \
    "$home/Library/Application Support/$APP_NAME" \
    "$home/Library/Caches/$APP_NAME" \
    "$home/Library/Logs/$APP_NAME"; do
    add_if_exists user "$path"
  done

  for current_id in "${BUNDLE_IDS[@]}"; do
    for path in \
      "$home/Library/Application Support/$current_id" \
      "$home/Library/Caches/$current_id" \
      "$home/Library/Preferences/$current_id.plist" \
      "$home/Library/HTTPStorages/$current_id" \
      "$home/Library/HTTPStorages/$current_id.binarycookies" \
      "$home/Library/WebKit/$current_id" \
      "$home/Library/Saved Application State/$current_id.savedState" \
      "$home/Library/Containers/$current_id" \
      "$home/Library/Cookies/$current_id.binarycookies" \
      "$home/Library/Logs/$current_id"; do
      add_if_exists user "$path"
    done

    while IFS= read -r path; do add_if_exists user "$path"; done < <(
      find "$home/Library/Preferences/ByHost" "$home/Library/LaunchAgents" \
        -maxdepth 1 \( -name "$current_id" -o -name "$current_id.*" \) -print 2>/dev/null
    )
  done

  while IFS= read -r path; do add_if_exists user "$path"; done < <(
    find "$home/Library/Preferences" \
      -maxdepth 1 \( -name "$BUNDLE_ID" -o -name "$BUNDLE_ID.*" \) -print 2>/dev/null
    find "$home/Library/Application Support/CrashReporter" "$home/Library/Logs/DiagnosticReports" \
      -maxdepth 1 \( -name "$BUNDLE_ID.*" -o -name "${APP_NAME}_*" \) -print 2>/dev/null
  )

  while IFS= read -r path; do add_if_exists user "$path"; done < <(
    find "$home/Library/Application Support/com.apple.sharedfilelist" \
      -maxdepth 4 -iname "$BUNDLE_ID.sfl*" -print 2>/dev/null
  )

  for path in \
    "/Library/Application Support/$APP_NAME" \
    "/Library/Application Support/$BUNDLE_ID" \
    "/Library/Caches/$BUNDLE_ID" \
    "/Library/Preferences/$BUNDLE_ID.plist" \
    "/Library/Logs/$APP_NAME"; do
    add_if_exists system "$path"
  done

  for current_id in "${BUNDLE_IDS[@]}"; do
    while IFS= read -r path; do add_if_exists system "$path"; done < <(
      find /Library/LaunchAgents /Library/LaunchDaemons /Library/PrivilegedHelperTools \
        -maxdepth 1 \( -name "$current_id" -o -name "$current_id.*" \) -print 2>/dev/null
    )
  done

  if [[ "$APP_PATH" == /Applications/* ]]; then
    local rebuilt=()
    for path in "${USER_TARGETS[@]}"; do
      if [[ "$path" == "$APP_PATH" ]]; then
        add_if_exists system "$path"
      else
        rebuilt+=("$path")
      fi
    done
    USER_TARGETS=("${rebuilt[@]}")
  fi
}

collect_exact_targets

echo "已识别：$APP_NAME"
echo "应用路径：$APP_PATH"
echo "Bundle ID：$BUNDLE_ID"
if [[ "${#BUNDLE_IDS[@]}" -gt 1 ]]; then
  echo "关联子 Bundle："
  printf '  %s\n' "${BUNDLE_IDS[@]:1}"
fi
echo "将清理以下明确关联项目："
if [[ "${#USER_TARGETS[@]}" -gt 0 ]]; then
  printf '  [用户] %s\n' "${USER_TARGETS[@]}"
else
  echo "  [用户]（无）"
fi
if [[ "${#SYSTEM_TARGETS[@]}" -gt 0 ]]; then
  printf '  [系统] %s\n' "${SYSTEM_TARGETS[@]}"
else
  echo "  [系统]（无）"
fi

if [[ "$MODE" == "dry-run" ]]; then
  echo "预览完成，未做修改。"
  exit 0
fi

NEEDS_ADMIN=0
if [[ "$(id -u)" -ne 0 ]]; then
  for target in "${SYSTEM_TARGETS[@]}"; do
    if [[ ! -w "$(dirname "$target")" ]]; then
      NEEDS_ADMIN=1
      break
    fi
  done
fi

if [[ "$NEEDS_ADMIN" -eq 1 ]]; then
  echo "需要管理员权限，正在请求 macOS 授权窗口…"
  osascript - "$0" "$QUERY" "$ORIGINAL_HOME" "$TARGET_UID" <<'APPLESCRIPT'
on run argv
  set scriptPath to item 1 of argv
  set appQuery to item 2 of argv
  set userHome to item 3 of argv
  set userID to item 4 of argv
  set commandText to "/usr/bin/env TARGET_USER_HOME=" & quoted form of userHome & " TARGET_USER_UID=" & quoted form of userID & " /bin/bash " & quoted form of scriptPath & " " & quoted form of appQuery
  do shell script commandText with administrator privileges
end run
APPLESCRIPT
  exit $?
fi

echo "正在停止相关进程和启动项…"
launchctl bootout "gui/$TARGET_UID" "$ORIGINAL_HOME/Library/LaunchAgents/$BUNDLE_ID.plist" 2>/dev/null || true
for target in "${SYSTEM_TARGETS[@]}"; do
  case "$target" in
    /Library/LaunchDaemons/*) launchctl bootout system "$target" 2>/dev/null || true ;;
    /Library/LaunchAgents/*) launchctl bootout "gui/$TARGET_UID" "$target" 2>/dev/null || true ;;
  esac
done
while read -r pid executable; do
  case "$executable" in
    "$APP_PATH"/Contents/*) kill -TERM "$pid" 2>/dev/null || true ;;
  esac
done < <(ps -axo pid=,comm=)

deleted=0
failed=0
for target in "${USER_TARGETS[@]}" "${SYSTEM_TARGETS[@]}"; do
  if rm -rf -- "$target"; then
    echo "已删除：$target"
    deleted=$((deleted + 1))
  else
    echo "删除失败：$target" >&2
    failed=$((failed + 1))
  fi
done

echo "完成：删除 $deleted 项，失败 $failed 项。"
[[ "$failed" -eq 0 ]]
