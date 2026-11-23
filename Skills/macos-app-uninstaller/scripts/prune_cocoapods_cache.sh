#!/bin/bash
# macOS /bin/bash 3.2; CocoaPods Release versions and External snapshots only.
set -o pipefail

usage() {
  cat <<'EOF'
用法：
  prune_cocoapods_cache.sh                 只读预览：保留每组最新 3 项及最近 15 天全部项目
  prune_cocoapods_cache.sh --execute       确认后清理；报告默认写入 ~/Desktop
  prune_cocoapods_cache.sh --execute --yes  非交互运行（请先预览）
  prune_cocoapods_cache.sh --keep 2        每个 Pod 的 Release/External 各至少保留 2 项
  prune_cocoapods_cache.sh --days 15       最近 N 天内有改动的项目无条件保留
  prune_cocoapods_cache.sh --report PATH   额外指定输出日志路径

Release 的目录名是版本-校验后缀；External 是哈希快照，无法保证对应语义版本。
按最近改动时间优先排序：最近 N 天的目录及其文件全部保留，
然后从较新的剩余目录补足到 --keep 项（默认 3）；因此近期项目超过 3 项时全保留。
EOF
}
die() { printf '错误：%s\n' "$*" >&2; exit 2; }

MODE=preview
KEEP=3
DAYS=15
YES=0
CACHE="$HOME/Library/Caches/CocoaPods/Pods"
REPORT=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --execute) MODE=execute; shift ;;
    --yes) YES=1; shift ;;
    --keep) [[ $# -ge 2 ]] || die "--keep 需要 2 或 3"; KEEP="$2"; shift 2 ;;
    --days) [[ $# -ge 2 ]] || die "--days 需要正整数"; DAYS="$2"; shift 2 ;;
    --report) [[ $# -ge 2 ]] || die "--report 需要路径"; REPORT="$2"; shift 2 ;;
    # Isolated fixture tests only; never point this at project Pods folders.
    --cache) [[ $# -ge 2 ]] || die "--cache 需要目录"; CACHE="$2"; shift 2 ;;
    *) die "未知参数：$1" ;;
  esac
done
[[ "$KEEP" == 2 || "$KEEP" == 3 ]] || die "--keep 仅支持 2 或 3"
[[ "$DAYS" =~ ^[1-9][0-9]*$ ]] || die "--days 必须是正整数"
[[ "$MODE" == execute || "$YES" -eq 0 ]] || die "--yes 需要 --execute"
[[ -d "$CACHE" && ! -L "$CACHE" ]] || die "缓存目录不存在或是符号链接：$CACHE"
CACHE="$(cd "$CACHE" && pwd -P)" || exit 1
[[ -d "$CACHE/Release" && -d "$CACHE/External" && -d "$CACHE/Specs" ]] ||
  die "未知的 CocoaPods 缓存结构，拒绝清理：$CACHE"
for part in Release External Specs; do
  [[ ! -L "$CACHE/$part" ]] || die "缓存结构包含符号链接：$CACHE/$part"
done
for part in Release External; do
  [[ ! -L "$CACHE/Specs/$part" ]] || die "podspec 目录是符号链接：$CACHE/Specs/$part"
done

if [[ -z "$REPORT" ]]; then
  [[ -d "$HOME/Desktop" ]] || die "桌面目录不存在：$HOME/Desktop"
  TEMP_REPORT="$(mktemp "$HOME/Desktop/cocoapods-cache-$(date '+%Y%m%d-%H%M%S').XXXXXX")" ||
    die "无法在桌面创建报告"
  REPORT="$TEMP_REPORT.log"
  mv -- "$TEMP_REPORT" "$REPORT" || die "无法生成桌面日志"
else
  [[ "$REPORT" == /* ]] || die "--report 必须是绝对路径"
  [[ ! -L "$REPORT" ]] || die "报告文件不能是符号链接"
  [[ -d "${REPORT%/*}" ]] || die "报告目录不存在"
fi

valid_component() { [[ "$1" =~ ^[A-Za-z0-9_.+-]+$ && "$1" != "." && "$1" != ".." ]]; }
recent() { [[ -n "$(find "$1" -mtime "-$DAYS" -print -quit 2>/dev/null)" ]]; }
size_kb() { du -sk "$1" 2>/dev/null | awk 'NR==1 {print $1}'; }
fingerprint() { stat -f '%d:%i:%m' "$1" 2>/dev/null; }

main() {
  local before_kb after_kb before_free after_free records list kind pod version name
  local is_recent stamp kept reason kb spec expected deleted=0 retained=0 failed=0
  local deleted_kb=0 specs_deleted=0 groups=0
  before_kb="$(size_kb "$CACHE")"
  before_free="$(df -Pk "$CACHE" 2>/dev/null | awk 'NR==2 {print $4}')"
  printf '模式：%s；每个 Pod 的 Release/External 各至少保留 %s 项，最近 %s 天内有改动的项全部保留。\n' \
    "$MODE" "$KEEP" "$DAYS"
  printf '缓存位置：%s\n' "$CACHE"
  printf '清理前磁盘占用：%s KB\n' "$before_kb"
  printf '报告路径：%s\n' "$REPORT"

  # Build a fixed plan before the first deletion: no on-the-fly decision changes.
  PLAN="$(mktemp "${TMPDIR:-/private/tmp}/cocoapods-plan.XXXXXX")" || return 1
  trap 'rm -f -- "$PLAN"' EXIT
  for kind in Release External; do
    while IFS= read -r -d '' pod; do
      name="${pod##*/}"
      if ! valid_component "$name" || [[ -L "$pod" ]]; then
        printf '跳过不规则 Pod 目录：%s\n' "$pod"
        continue
      fi
      if [[ -L "$CACHE/Specs/$kind/$name" ]]; then
        printf '跳过带符号链接 podspec 的 Pod：%s\n' "$pod"
        continue
      fi
      groups=$((groups + 1))
      list="$(mktemp "${TMPDIR:-/private/tmp}/cocoapods-group.XXXXXX")" || return 1
      while IFS= read -r -d '' version; do
        if ! valid_component "${version##*/}" || [[ -L "$version" ]]; then
          printf '跳过不规则版本目录：%s\n' "$version"
          continue
        fi
        stamp="$(stat -f '%m' "$version" 2>/dev/null)" || continue
        spec="$CACHE/Specs/$kind/$name/${version##*/}.podspec.json"
        is_recent=0
        if recent "$version" || { [[ -f "$spec" && ! -L "$spec" ]] && recent "$spec"; }; then
          is_recent=1
        fi
        printf '%s\t%s\t%s\n' "$is_recent" "$stamp" "$version" >> "$list"
      done < <(find "$pod" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

      kept=0
      while IFS=$'\t' read -r is_recent stamp version; do
        [[ -d "$version" && ! -L "$version" ]] || continue
        spec="$CACHE/Specs/$kind/$name/${version##*/}.podspec.json"
        if [[ "$is_recent" -eq 1 ]]; then
          reason="保留：最近 $DAYS 天有改动"
          kept=$((kept + 1))
        elif [[ "$kept" -lt "$KEEP" ]]; then
          reason="保留：较新的 ${KEEP} 项"
          kept=$((kept + 1))
        else
          reason="计划删除"
        fi
        if [[ "$reason" == "计划删除" ]]; then
          kb="$(size_kb "$version")"
          [[ "$kb" =~ ^[0-9]+$ ]] || { printf '跳过无法计量的项目：%s\n' "$version"; continue; }
          # Fixed plan: version path, inode/mtime, matching spec path, size (tab-delimited).
          expected="$(fingerprint "$version")"
          printf '%s\t%s\t%s\t%s\n' "$version" "$expected" "$spec" "$kb" >> "$PLAN"
          printf '待删 [%s/%s] %s KB | %s\n' "$kind" "$name" "$kb" "$version"
        else
          retained=$((retained + 1))
          printf '%s [%s/%s] %s\n' "$reason" "$kind" "$name" "$version"
        fi
      done < <(sort -t $'\t' -k1,1nr -k2,2nr "$list")
      rm -f -- "$list"
    done < <(find "$CACHE/$kind" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  done

  records="$(wc -l < "$PLAN" | tr -d ' ')"
  awk -F '\t' -v count="$records" -v retained="$retained" -v groups="$groups" \
    '{sum+=$4} END {
      printf "计划汇总：Pod 分组 %d，保留 %d 项，计划删除 %d 项，预计 %.1f MB (%.2f GB)。\n",
        groups, retained, count, sum/1024, sum/1048576
    }' "$PLAN"
  [[ "$MODE" == execute && "$records" -gt 0 ]] || return 0
  if [[ "$YES" -ne 1 ]]; then
    [[ -t 0 ]] || { echo "非交互执行需 --yes（先预览）" >&2; return 2; }
    read -r -p "输入 DELETE 删除计划中的旧缓存：" answer
    [[ "$answer" == DELETE ]] || { echo "已取消，未删除。"; return 1; }
  fi

  while IFS=$'\t' read -r version expected spec kb; do
    pod="${version%/*}"
    case "$pod" in "$CACHE/Release/"*|"$CACHE/External/"*) ;; *) printf '跳过越界路径：%s\n' "$version"; failed=$((failed + 1)); continue ;; esac
    if [[ ! -d "$version" || -L "$version" || -L "$pod" || "$(fingerprint "$version")" != "$expected" ]] ||
       recent "$version" || { [[ -f "$spec" ]] && recent "$spec"; }; then
      printf '跳过已变更或近期使用的项目：%s\n' "$version"
      failed=$((failed + 1))
      continue
    fi
    if rm -rf -- "$version" 2>/dev/null ||
       { [[ -d "$version" && ! -L "$version" ]] &&
         [[ -z "$(find "$version" \( -type l -o -type f ! -name '.DS_Store' \) -print -quit 2>/dev/null)" ]] &&
         { printf '仅发现 .DS_Store 残余，安全重试：%s\n' "$version"; rm -rf -- "$version"; }; }; then
      printf '已删除 [%s] %s KB | %s\n' "${pod##*/}" "$kb" "$version"
      deleted=$((deleted + 1))
      deleted_kb=$((deleted_kb + kb))
      # Only delete exact, matching cached metadata (never the central Specs repo).
      if [[ -f "$spec" && ! -L "$spec" && ! -L "${spec%/*}" &&
            "$spec" == "$CACHE/Specs/"* ]] &&
         ! recent "$spec" && rm -f -- "$spec"; then
        specs_deleted=$((specs_deleted + 1))
      fi
    else
      printf '删除失败：%s\n' "$version" >&2
      failed=$((failed + 1))
    fi
  done < "$PLAN"
  after_kb="$(size_kb "$CACHE")"
  after_free="$(df -Pk "$CACHE" 2>/dev/null | awk 'NR==2 {print $4}')"
  awk -v deleted="$deleted" -v failed="$failed" -v spec="$specs_deleted" \
    -v planned="$deleted_kb" -v before="$before_kb" -v after="$after_kb" \
    -v free_before="$before_free" -v free_after="$after_free" 'BEGIN {
      printf "执行汇总：删除 %d 项缓存和 %d 个对应 podspec；失败/跳过 %d 项。\n", deleted, spec, failed
      printf "已删除目标估算：%.1f MB (%.2f GB)。\n", planned/1024, planned/1048576
      if (before ~ /^[0-9]+$/ && after ~ /^[0-9]+$/)
        printf "缓存目录实际缩减：%.1f MB (%.2f GB)。\n", (before-after)/1024, (before-after)/1048576
      if (free_before ~ /^[0-9]+$/ && free_after ~ /^[0-9]+$/)
        printf "磁盘可用空间变化：%+.1f MB (%+.2f GB)（APFS 快照和后台写入可能影响结果）。\n",
          (free_after-free_before)/1024, (free_after-free_before)/1048576
    }'
  [[ "$failed" -eq 0 ]]
}

main "$@" 2>&1 | tee "$REPORT"
