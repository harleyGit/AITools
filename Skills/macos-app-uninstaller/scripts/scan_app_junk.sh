#!/bin/bash
# macOS /bin/bash 3.2 compatible. No Python, Homebrew or administrator rights required.
set -o pipefail

usage() {
  cat <<'EOF'
用法：
  scan_app_junk.sh                         扫描全部候选（默认只读，无时间限制）
  scan_app_junk.sh --days 30               只列出最近 30 天未更新的候选
  scan_app_junk.sh --execute               清理扫描到的用户缓存/日志；交互确认
  scan_app_junk.sh --execute --yes          非交互清理用户缓存/日志
  scan_app_junk.sh --execute --days 90 --select "/完整/路径"
  scan_app_junk.sh --execute --include-downloads --select "/完整/安装包路径"
  scan_app_junk.sh --execute --include-data --select "/完整/应用数据路径"
  scan_app_junk.sh --execute --include-review --select "/完整/高风险缓存路径"

不提供 --days 表示全部，不代表会自动删除用户数据或下载的应用。
--include-downloads、--include-data、--include-review 必须配合 --select 指定本次扫描中的路径，
且只能在交互终端输入 DELETE 确认；--yes 只适用于缓存/日志。
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 2; }

MODE=scan
DAYS=
YES=0
INCLUDE_DOWNLOADS=0
INCLUDE_DATA=0
INCLUDE_REVIEW=0
SCAN_HOME="$HOME"
APP_ROOTS=()
SELECTIONS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --days) [[ $# -ge 2 ]] || die "--days 缺少天数"; DAYS="$2"; shift 2 ;;
    --execute) MODE=execute; shift ;;
    --yes) YES=1; shift ;;
    --include-downloads) INCLUDE_DOWNLOADS=1; shift ;;
    --include-data) INCLUDE_DATA=1; shift ;;
    --include-review) INCLUDE_REVIEW=1; shift ;;
    --select) [[ $# -ge 2 ]] || die "--select 缺少完整路径"; SELECTIONS+=("$2"); shift 2 ;;
    # Testing and advanced use only: restrict scans to a separate home/app tree.
    --home) [[ $# -ge 2 ]] || die "--home 缺少路径"; SCAN_HOME="$2"; shift 2 ;;
    --app-root) [[ $# -ge 2 ]] || die "--app-root 缺少路径"; APP_ROOTS+=("$2"); shift 2 ;;
    *) die "未知参数：$1" ;;
  esac
done

[[ -z "$DAYS" || "$DAYS" =~ ^[1-9][0-9]*$ ]] || die "--days 必须是正整数"
[[ -d "$SCAN_HOME" && ! -L "$SCAN_HOME" ]] || die "用户目录不存在或是符号链接：$SCAN_HOME"
SCAN_HOME="$(cd "$SCAN_HOME" && pwd -P)" || exit 1
for ((s=0; s<${#SELECTIONS[@]}; s++)); do
  selection="${SELECTIONS[$s]}"
  [[ "$selection" == /* ]] || die "--select 必须使用完整绝对路径：$selection"
  resolved_parent="$(cd "${selection%/*}" 2>/dev/null && pwd -P)" ||
    die "--select 的父目录不存在：$selection"
  SELECTIONS[$s]="$resolved_parent/${selection##*/}"
done
[[ "$MODE" == execute || ( "$YES" -eq 0 && "$INCLUDE_DOWNLOADS" -eq 0 && "$INCLUDE_DATA" -eq 0 && "$INCLUDE_REVIEW" -eq 0 && "${#SELECTIONS[@]}" -eq 0 ) ]] ||
  die "清理选项必须配合 --execute"
[[ "$INCLUDE_DOWNLOADS" -eq 0 && "$INCLUDE_DATA" -eq 0 && "$INCLUDE_REVIEW" -eq 0 || "${#SELECTIONS[@]}" -gt 0 ]] ||
  die "安装包、应用数据和高风险缓存必须使用 --select 逐项指定"
[[ "$YES" -eq 0 || ( "$INCLUDE_DOWNLOADS" -eq 0 && "$INCLUDE_DATA" -eq 0 && "$INCLUDE_REVIEW" -eq 0 ) ]] ||
  die "--yes 不能用于安装包、应用数据或高风险缓存"

if [[ "${#APP_ROOTS[@]}" -eq 0 ]]; then
  APP_ROOTS=(/Applications "$SCAN_HOME/Applications" /System/Applications "$SCAN_HOME/Downloads")
fi

INSTALLED_IDS=()
while IFS= read -r -d '' app; do
  identifier=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
    "$app/Contents/Info.plist" 2>/dev/null) || continue
  [[ -n "$identifier" ]] && INSTALLED_IDS+=("$(printf '%s' "$identifier" | tr '[:upper:]' '[:lower:]')")
done < <(
  for root in "${APP_ROOTS[@]}"; do
    [[ -d "$root" ]] || continue
    find "$root" -maxdepth 5 \( -type d -o -type l \) -name '*.app' -prune -print0 2>/dev/null
  done
)

is_app_id() {
  local name="$1"
  # Conservative identifier shape: three segments, no spaces or wildcard matching.
  [[ "$name" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_.-]+$ ]] || return 1
  case "$name" in com.apple.*|org.freedesktop.*) return 1 ;; esac
  return 0
}

installed_match() {
  local name id
  name="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  for id in "${INSTALLED_IDS[@]}"; do
    case "$name" in "$id"|"$id".*) return 0 ;; esac
    case "$id" in "$name".*) return 0 ;; esac
  done
  return 1
}

old_enough() {
  [[ -z "$DAYS" ]] && return 0
  # No recent file OR directory anywhere in this candidate (symlinks are not followed).
  [[ -z "$(find "$1" -mtime "-$DAYS" -print -quit 2>/dev/null)" ]]
}

CANDIDATES=()
CATEGORIES=()
SIZES=()
IDENTITIES=()
TOTAL_KB=0

add_candidate() {
  local path="$1" category="$2" kb fingerprint
  [[ -e "$path" && ! -L "$path" ]] || return 0
  [[ -d "$path" || -f "$path" ]] || return 0
  old_enough "$path" || return 0
  fingerprint="$(stat -f '%d:%i:%m' "$path" 2>/dev/null)" || return 0
  kb="$(du -sk "$path" 2>/dev/null | awk 'NR==1 {print $1}')" || return 0
  [[ "$kb" =~ ^[0-9]+$ ]] || return 0
  if [[ "$category" == cache ]]; then
    case "${path##*/}" in
      CocoaPods|Yarn|Homebrew|Google|LarkShell|*.BundleMigration|\
      familycircled|FamilyCircle|GeoServices|PassKit|CloudKit|GameKit|Animoji|\
      JetPackCache|mbuseragent|AMSDataMigratorTool|askpermissiond|SiriTTS|\
      TemporaryItems|INSTALLATION|ms-playwright-go|node-gyp|pip|typescript|\
      org.swift.swiftpm|swift-frontend|BuildService|prebuild|bun|\
      flutter_engine|vscode-cpptools|SwiftLint|DiagnosticReports|\
      Baseband|CoreSimulator|PhotosSearch.aapbz)
        category=review ;;
    esac
    # Large caches can hide downloaded resources, migration data or local build artifacts.
    [[ "$kb" -lt 262144 ]] || category=review
  fi
  CANDIDATES+=("$path")
  CATEGORIES+=("$category")
  SIZES+=("$kb")
  IDENTITIES+=("$fingerprint")
  TOTAL_KB=$((TOTAL_KB + kb))
}

for root in "$SCAN_HOME/Library/Caches" "$SCAN_HOME/Library/Logs"; do
  [[ -d "$root" && ! -L "$root" ]] || continue
  while IFS= read -r -d '' path; do
    name="${path##*/}"
    case "$name" in com.apple.*|org.freedesktop.*) continue ;; esac
    add_candidate "$path" cache
  done < <(find "$root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
done

for root in "$SCAN_HOME/Library/Application Support" "$SCAN_HOME/Library/Containers" "$SCAN_HOME/Library/HTTPStorages"; do
  [[ -d "$root" && ! -L "$root" ]] || continue
  while IFS= read -r -d '' path; do
    name="${path##*/}"
    is_app_id "$name" || continue
    installed_match "$name" && continue
    add_candidate "$path" data
  done < <(find "$root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
done

root="$SCAN_HOME/Downloads"
if [[ -d "$root" && ! -L "$root" ]]; then
  while IFS= read -r -d '' path; do
    lower="$(printf '%s' "${path##*/}" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
      *.dmg|*.pkg|*.mpkg|*.app.zip|*.app) add_candidate "$path" download ;;
    esac
  done < <(find "$root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
fi

if [[ -z "$DAYS" ]]; then
  echo "扫描范围：全部时间（只限当前用户的标准应用目录）"
else
  echo "扫描范围：最近 $DAYS 天未更新的项目（只限当前用户的标准应用目录）"
fi
echo "识别到 ${#INSTALLED_IDS[@]} 个应用 Bundle ID。"
for ((i=0; i<${#CANDIDATES[@]}; i++)); do
  case "${CATEGORIES[$i]}" in
    cache) label="缓存/日志" ;;
    review) label="重要或大体积缓存/诊断（需人工核实）" ;;
    data) label="疑似卸载残留（仅供核实）" ;;
    download) label="下载的安装包或应用（仅供核实）" ;;
  esac
  printf '[%s] %s KB | %s\n' "$label" "${SIZES[$i]}" "${CANDIDATES[$i]}"
done
printf '合计 %s 项，约 %s KB（磁盘占用估算，不代表均可安全删除）。\n' \
  "${#CANDIDATES[@]}" "$TOTAL_KB"

if [[ "$MODE" != execute ]]; then
  echo "只读扫描完成；未删除文件。"
  exit 0
fi

TARGETS=()
SENSITIVE=0
for selection in "${SELECTIONS[@]}"; do
  found=0
  for ((i=0; i<${#CANDIDATES[@]}; i++)); do
    if [[ "$selection" == "${CANDIDATES[$i]}" ]]; then
      found=1
      case "${CATEGORIES[$i]}" in
        data) [[ "$INCLUDE_DATA" -eq 1 ]] || die "应用数据需要 --include-data：$selection"; SENSITIVE=1 ;;
        download) [[ "$INCLUDE_DOWNLOADS" -eq 1 ]] || die "安装包需要 --include-downloads：$selection"; SENSITIVE=1 ;;
        review) [[ "$INCLUDE_REVIEW" -eq 1 ]] || die "高风险缓存需要 --include-review：$selection"; SENSITIVE=1 ;;
      esac
      break
    fi
  done
  [[ "$found" -eq 1 ]] || die "所选路径不在本次扫描中：$selection"
done
for ((i=0; i<${#CANDIDATES[@]}; i++)); do
  if [[ "${#SELECTIONS[@]}" -gt 0 ]]; then
    found=0
    for selection in "${SELECTIONS[@]}"; do
      [[ "$selection" == "${CANDIDATES[$i]}" ]] && found=1
    done
    [[ "$found" -eq 1 ]] || continue
  else
    [[ "${CATEGORIES[$i]}" == cache ]] || continue
  fi
  TARGETS+=("$i")
done

[[ "${#TARGETS[@]}" -gt 0 ]] || { echo "无符合要求的清理目标。"; exit 0; }
printf '将清理 %s 项；注意缓存可能需要软件重新下载或构建。\n' "${#TARGETS[@]}"
if [[ "$SENSITIVE" -eq 1 && ! -t 0 ]]; then
  die "高风险缓存/安装包/疑似残留数据只能在交互终端确认，不支持无人值守删除"
fi
if [[ "$YES" -eq 0 ]]; then
  [[ -t 0 ]] || die "非交互终端请为缓存/日志使用 --yes；敏感数据须在交互终端操作"
  read -r -p "输入 DELETE 确认删除上述目标：" answer
  [[ "$answer" == DELETE ]] || { echo "已取消，未删除。"; exit 1; }
fi

removed=0
failed=0
removed_kb=0
before_free="$(df -Pk "$SCAN_HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
for i in "${TARGETS[@]}"; do
  path="${CANDIDATES[$i]}"
  parent="${path%/*}"
  # Revalidate direct-child whitelist, symlink ancestors, existence and inode/mtime.
  case "$parent" in
    "$SCAN_HOME/Library/Caches"|"$SCAN_HOME/Library/Logs"|"$SCAN_HOME/Library/Application Support"|\
    "$SCAN_HOME/Library/Containers"|"$SCAN_HOME/Library/HTTPStorages"|"$SCAN_HOME/Downloads") ;;
    *) echo "跳过异常路径：$path" >&2; failed=$((failed + 1)); continue ;;
  esac
  current="$(stat -f '%d:%i:%m' "$path" 2>/dev/null)" || current=
  if [[ -z "$current" || "$current" != "${IDENTITIES[$i]}" || -L "$path" || -L "$parent" || \
        -L "$SCAN_HOME/Library" ]] || ! old_enough "$path"; then
    echo "跳过已变更或不安全的目标：$path" >&2
    failed=$((failed + 1))
    continue
  fi
  if rm -rf -- "$path"; then
    printf '已删除：%s KB | %s\n' "${SIZES[$i]}" "$path"
    removed=$((removed + 1))
    removed_kb=$((removed_kb + ${SIZES[$i]}))
  else
    printf '删除失败：%s\n' "$path" >&2
    failed=$((failed + 1))
  fi
done
after_free="$(df -Pk "$SCAN_HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
awk -v items="$removed" -v failed="$failed" -v kb="$removed_kb" \
  -v before="$before_free" -v after="$after_free" 'BEGIN {
  printf "完成：删除 %d 项，失败或跳过 %d 项；按目标文件估算释放 %.1f MB (%.2f GB)。\n", items, failed, kb/1024, kb/1048576
  if (before ~ /^[0-9]+$/ && after ~ /^[0-9]+$/) {
    delta = after - before
    printf "磁盘可用空间变化：%+.1f MB (%+.2f GB)；APFS 快照、缓存重建等可能影响此数值。\n", delta/1024, delta/1048576
  }
}'
[[ "$failed" -eq 0 ]]
