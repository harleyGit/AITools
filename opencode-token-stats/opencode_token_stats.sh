#!/usr/bin/env bash

# OpenCode Token 使用量查询脚本。
#
# 数据来源：OpenCode 的 SQLite 数据库 message 表。每条消息的 data 字段是
# JSON，其中包含 tokens、cost、modelID 等统计信息。脚本按消息创建时间筛选，
# 因此查询某一天或任意日期范围时，只统计区间内真正产生的 Token。
#
# 兼容性：
# - macOS BSD date：使用 date -j/-v
# - Linux GNU date：使用 date -d
#
# 开启严格模式：命令失败、未定义变量或管道中任意命令失败时立即退出，避免
# 数据库查询失败后仍输出看似正常但实际错误的零值报表。
set -euo pipefail

# 输出命令行帮助。使用单引号 heredoc，防止帮助文本中的特殊字符被 Shell 展开。
usage() {
  cat <<'EOF'
用法：
  opencode_token_stats.sh "最近一周"
  opencode_token_stats.sh "今天"
  opencode_token_stats.sh "昨天"
  opencode_token_stats.sh "2026-07-20"
  opencode_token_stats.sh "2026-07-18 至 2026-07-24"
  opencode_token_stats.sh --start 2026-07-18 --end 2026-07-24

选项：
  --db PATH       指定 OpenCode SQLite 数据库
  --start DATE    开始日期，包含当天
  --end DATE      结束日期，包含当天
  -h, --help      显示帮助

不传时间参数时，脚本会提示输入查询时间。
EOF
}

# 向标准错误输出统一格式的错误信息，并以非零状态结束程序。
die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

# 验证日期是否严格符合 YYYY-MM-DD，且操作系统 date 命令能够解析该日期。
is_date() {
  [[ ${1:-} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date_to_epoch "$1" >/dev/null 2>&1
}

# 将某个本地自然日的 00:00:00 转为 Unix 秒级时间戳。
# OpenCode 数据库使用毫秒时间戳，调用方会再乘以 1000。
date_to_epoch() {
  local value=$1

  if date -j -f '%Y-%m-%d %H:%M:%S' "$value 00:00:00" '+%s' >/dev/null 2>&1; then
    date -j -f '%Y-%m-%d %H:%M:%S' "$value 00:00:00" '+%s'
  else
    date -d "$value 00:00:00" '+%s'
  fi
}

# 在指定自然日上增加或减少天数，并保持 YYYY-MM-DD 输出格式。
# 例如：shift_date 2026-07-24 -6 -> 2026-07-18。
shift_date() {
  local value=$1
  local days=$2
  local modifier=$days

  if (( days >= 0 )); then
    modifier="+$days"
  fi

  if date -j -v"${modifier}"d -f '%Y-%m-%d' "$value" '+%Y-%m-%d' >/dev/null 2>&1; then
    date -j -v"${modifier}"d -f '%Y-%m-%d' "$value" '+%Y-%m-%d'
  else
    date -d "$value $days day" '+%Y-%m-%d'
  fi
}

# 给整数添加千位分隔符，便于阅读大 Token 数值。
# 例如：1239079 -> 1,239,079。
format_integer() {
  awk -v number="${1:-0}" 'BEGIN {
    number = sprintf("%.0f", number)
    sign = ""
    if (number ~ /^-/) {
      sign = "-"
      sub(/^-/, "", number)
    }
    result = ""
    while (length(number) > 3) {
      result = "," substr(number, length(number) - 2) result
      number = substr(number, 1, length(number) - 3)
    }
    print sign number result
  }'
}

# 将较大数值换算成中文近似单位。精确值仍会保留，此函数只生成辅助说明。
# 例如：1035334 -> 约 103.53 万。
format_approx() {
  awk -v number="${1:-0}" 'BEGIN {
    if (number >= 100000000) printf "约 %.2f 亿", number / 100000000
    else if (number >= 10000) printf "约 %.2f 万", number / 10000
    else printf "%d", number
  }'
}

# Token 少于一万时只显示精确值；达到一万后同时显示精确值和中文近似值。
format_token_value() {
  local number=${1:-0}
  local exact
  local approximate

  exact=$(format_integer "$number")
  approximate=$(format_approx "$number")
  if (( number >= 10000 )); then
    printf '%s（%s）' "$exact" "$approximate"
  else
    printf '%s' "$exact"
  fi
}

# 自动寻找 OpenCode 数据库，优先级从高到低如下：
# 1. 命令行 --db 保存到 DB_PATH 的路径
# 2. OPENCODE_DB_PATH 环境变量
# 3. opencode db path 返回的当前数据库
# 4. macOS/Linux 常见数据目录中的 opencode.db 或 sessions.db
find_database() {
  local candidate

  if [[ -n ${DB_PATH:-} ]]; then
    [[ -f "$DB_PATH" ]] || die "数据库不存在：$DB_PATH"
    return
  fi

  if [[ -n ${OPENCODE_DB_PATH:-} ]]; then
    DB_PATH=$OPENCODE_DB_PATH
    [[ -f "$DB_PATH" ]] || die "数据库不存在：$DB_PATH"
    return
  fi

  if command -v opencode >/dev/null 2>&1; then
    candidate=$(opencode db path 2>/dev/null || true)
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      DB_PATH=$candidate
      return
    fi
  fi

  for candidate in \
    "$HOME/.local/share/opencode/opencode.db" \
    "$HOME/.local/share/opencode/sessions.db" \
    "$HOME/Library/Application Support/opencode/opencode.db" \
    "$HOME/Library/Application Support/opencode/sessions.db"; do
    if [[ -f "$candidate" ]]; then
      DB_PATH=$candidate
      return
    fi
  done

  die "未找到 OpenCode 数据库。可使用 --db PATH 指定数据库。"
}

# 将中文时间表达式解析成包含首尾两天的日期范围。
# 支持：最近一周、最近 N 天、今天、昨天、单个日期、日期至日期。
# TOKEN_STATS_TODAY 仅用于自动化测试固定“今天”，正常执行时无需设置。
parse_range() {
  local expression=${1:-}
  local normalized

  TODAY=${TOKEN_STATS_TODAY:-$(date '+%Y-%m-%d')}
  is_date "$TODAY" || die "TOKEN_STATS_TODAY 不是有效日期：$TODAY"

  normalized=$(printf '%s' "$expression" | tr -d ' ')
  case "$normalized" in
    最近一周|近一周|最近7天|近7天)
      START_DATE=$(shift_date "$TODAY" -6)
      END_DATE=$TODAY
      RANGE_TITLE='最近 7 天'
      ;;
    今天|今日)
      START_DATE=$TODAY
      END_DATE=$TODAY
      RANGE_TITLE='当天'
      ;;
    昨天|昨日)
      START_DATE=$(shift_date "$TODAY" -1)
      END_DATE=$START_DATE
      RANGE_TITLE='当天'
      ;;
    最近[0-9]*天|近[0-9]*天)
      local days
      days=$(printf '%s' "$normalized" | tr -cd '0-9')
      [[ -n "$days" && "$days" -gt 0 ]] || die "天数必须大于 0"
      START_DATE=$(shift_date "$TODAY" "$((1 - days))")
      END_DATE=$TODAY
      RANGE_TITLE="最近 $days 天"
      ;;
    *至*|*到*)
      normalized=${normalized/到/至}
      START_DATE=${normalized%%至*}
      END_DATE=${normalized#*至}
      RANGE_TITLE='指定时间段'
      ;;
    *)
      START_DATE=$normalized
      END_DATE=$normalized
      RANGE_TITLE='当天'
      ;;
  esac

  is_date "$START_DATE" || die "开始日期无效：${START_DATE}，请使用 YYYY-MM-DD"
  is_date "$END_DATE" || die "结束日期无效：${END_DATE}，请使用 YYYY-MM-DD"
  (( $(date_to_epoch "$START_DATE") <= $(date_to_epoch "$END_DATE") )) || \
    die "开始日期不能晚于结束日期"
}

# 初始化命令行参数。POSITIONAL 保存未使用 -- 开头的自然语言时间表达式。
DB_PATH=''
START_DATE=''
END_DATE=''
RANGE_TITLE='指定时间段'
START_OPTION=''
END_OPTION=''
POSITIONAL=()

# 解析明确选项和位置参数。--start 与 --end 必须成对使用。
while (($#)); do
  case "$1" in
    --db)
      (($# >= 2)) || die '--db 缺少路径'
      DB_PATH=$2
      shift 2
      ;;
    --start)
      (($# >= 2)) || die '--start 缺少日期'
      START_OPTION=$2
      shift 2
      ;;
    --end)
      (($# >= 2)) || die '--end 缺少日期'
      END_OPTION=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      die "未知选项：$1"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# sqlite3 是唯一必需的数据库客户端。数据库位置随后按既定优先级自动发现。
command -v sqlite3 >/dev/null 2>&1 || die '未安装 sqlite3'
find_database

# 明确的 --start/--end 优先于自然语言位置参数；两者都没有时进入交互输入。
if [[ -n "$START_OPTION" || -n "$END_OPTION" ]]; then
  [[ -n "$START_OPTION" && -n "$END_OPTION" ]] || die '--start 和 --end 必须同时使用'
  START_DATE=$START_OPTION
  END_DATE=$END_OPTION
  RANGE_TITLE='指定时间段'
  is_date "$START_DATE" || die "开始日期无效：$START_DATE"
  is_date "$END_DATE" || die "结束日期无效：$END_DATE"
  (( $(date_to_epoch "$START_DATE") <= $(date_to_epoch "$END_DATE") )) || \
    die '开始日期不能晚于结束日期'
elif ((${#POSITIONAL[@]})); then
  parse_range "${POSITIONAL[*]}"
else
  printf '请输入查询时间（例如：最近一周、2026-07-20、2026-07-18 至 2026-07-24）：'
  IFS= read -r expression
  parse_range "$expression"
fi

# 当前 OpenCode 数据结构必须包含 message 表。提前检查可给出比 SQLite 更清晰的错误。
TABLE_EXISTS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='message';")
[[ "$TABLE_EXISTS" == '1' ]] || die "数据库中没有 message 表：$DB_PATH"

# SQL 使用左闭右开区间 [开始日 00:00, 结束日次日 00:00)，这样开始和结束
# 日期都完整包含，同时不会误计结束日期次日零点之后的消息。
START_MS=$(( $(date_to_epoch "$START_DATE") * 1000 ))
END_EXCLUSIVE=$(shift_date "$END_DATE" 1)
END_MS=$(( $(date_to_epoch "$END_EXCLUSIVE") * 1000 ))

# 汇总 SQL：
# - ranged：只保留时间范围内的消息
# - totals：计算消息、会话、各类 Token 和成本
# - session_totals：按会话汇总总处理量
# - ranked/session_stats：使用窗口函数计算每个会话 Token 的平均值和中位数
# JSON 字段可能不存在（例如用户消息没有 tokens），统一用 COALESCE 按 0 处理。
SUMMARY_SQL=$(cat <<SQL
WITH ranged AS (
  SELECT session_id, data
  FROM message
  WHERE time_created >= $START_MS AND time_created < $END_MS
), totals AS (
  SELECT
    COUNT(*) AS messages,
    COUNT(DISTINCT session_id) AS sessions,
    COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.input'), 0)), 0) AS input_tokens,
    COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.output'), 0)), 0) AS output_tokens,
    COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.cache.read'), 0)), 0) AS cache_read,
    COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.cache.write'), 0)), 0) AS cache_write,
    COALESCE(SUM(COALESCE(json_extract(data, '$.cost'), 0)), 0) AS cost
  FROM ranged
), session_totals AS (
  SELECT session_id,
    SUM(COALESCE(json_extract(data, '$.tokens.input'), 0)
      + COALESCE(json_extract(data, '$.tokens.output'), 0)
      + COALESCE(json_extract(data, '$.tokens.cache.read'), 0)
      + COALESCE(json_extract(data, '$.tokens.cache.write'), 0)) AS tokens
  FROM ranged
  GROUP BY session_id
), ranked AS (
  SELECT tokens, ROW_NUMBER() OVER (ORDER BY tokens) AS row_num, COUNT(*) OVER () AS row_count
  FROM session_totals
), session_stats AS (
  SELECT
    COALESCE(AVG(tokens), 0) AS average_tokens,
    COALESCE(AVG(CASE WHEN row_num IN ((row_count + 1) / 2, (row_count + 2) / 2) THEN tokens END), 0) AS median_tokens
  FROM ranked
)
SELECT messages, sessions, input_tokens, output_tokens, cache_read, cache_write,
  printf('%.4f', cost), printf('%.0f', average_tokens), printf('%.0f', median_tokens)
FROM totals CROSS JOIN session_stats;
SQL
)

IFS=$'\t' read -r MESSAGES SESSIONS INPUT_TOKENS OUTPUT_TOKENS CACHE_READ CACHE_WRITE COST AVG_TOKENS MEDIAN_TOKENS \
  <<<"$(sqlite3 -separator $'\t' "$DB_PATH" "$SUMMARY_SQL")"

# 主要模型按 input + output + cache read 的处理量排序。lower(model) 用于合并
# 仅大小写不同的模型 ID，最终保留数据库中实际记录的模型名称用于展示。
MODEL_SQL=$(cat <<SQL
SELECT
  COALESCE(json_extract(data, '$.modelID'), 'unknown') AS model,
  COUNT(*) AS messages,
  COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.input'), 0)), 0) AS input_tokens,
  COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.output'), 0)), 0) AS output_tokens,
  COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.cache.read'), 0)), 0) AS cache_read
FROM message
WHERE time_created >= $START_MS AND time_created < $END_MS
  AND json_extract(data, '$.modelID') IS NOT NULL
GROUP BY lower(model)
ORDER BY input_tokens + output_tokens + cache_read DESC
LIMIT 1;
SQL
)

MODEL_ROW=$(sqlite3 -separator $'\t' "$DB_PATH" "$MODEL_SQL")
if [[ -n "$MODEL_ROW" ]]; then
  IFS=$'\t' read -r MAIN_MODEL MODEL_MESSAGES MODEL_INPUT MODEL_OUTPUT MODEL_CACHE_READ <<<"$MODEL_ROW"
else
  MAIN_MODEL='无'
  MODEL_MESSAGES=0
  MODEL_INPUT=0
  MODEL_OUTPUT=0
  MODEL_CACHE_READ=0
fi

# “输入 + 输出”代表非缓存 Token；“总处理量”还包含缓存读取和缓存写入。
INPUT_OUTPUT=$((INPUT_TOKENS + OUTPUT_TOKENS))
TOTAL_PROCESSED=$((INPUT_OUTPUT + CACHE_READ + CACHE_WRITE))

if [[ "$START_DATE" == "$END_DATE" ]]; then
  DISPLAY_RANGE=$START_DATE
else
  DISPLAY_RANGE="${START_DATE} 至 ${END_DATE}"
fi

# 输出总览。使用制表符分隔列，终端可直接查看，也方便重定向到文本文件。
printf '\n%s Token 使用量（%s）\n\n' "$RANGE_TITLE" "$DISPLAY_RANGE"
printf '类型\tToken 数量\n'
printf '%s\t%s\n' '输入 Token' "$(format_token_value "$INPUT_TOKENS")"
printf '%s\t%s\n' '输出 Token' "$(format_token_value "$OUTPUT_TOKENS")"
printf '%s\t%s\n' '缓存读取 Token' "$(format_token_value "$CACHE_READ")"
printf '%s\t%s\n' '缓存写入 Token' "$(format_token_value "$CACHE_WRITE")"
printf '%s\t%s\n' '输入 + 输出' "$(format_token_value "$INPUT_OUTPUT")"
printf '%s\t%s\n' '包含缓存读取和写入的总处理量' "$(format_token_value "$TOTAL_PROCESSED")"

printf '\n其他数据：\n'
printf -- '- 会话数：%s\n' "$(format_integer "$SESSIONS")"
printf -- '- 消息数：%s\n' "$(format_integer "$MESSAGES")"
printf -- '- 平均每个会话：%s Token，包含缓存读取和写入\n' "$(format_token_value "$AVG_TOKENS")"
printf -- '- Token 中位数：%s/会话\n' "$(format_token_value "$MEDIAN_TOKENS")"
printf -- '- 记录成本：$%.2f\n' "$COST"
printf -- '- 主要使用模型：%s，消息 %s，输入 %s、输出 %s、缓存读取 %s\n' \
  "$MAIN_MODEL" "$(format_integer "$MODEL_MESSAGES")" "$(format_token_value "$MODEL_INPUT")" \
  "$(format_token_value "$MODEL_OUTPUT")" "$(format_token_value "$MODEL_CACHE_READ")"

# 每日明细使用 SQLite localtime 将 Unix 时间转换为本地自然日，避免 UTC 日期
# 与用户所在时区的日期不一致。
printf '\n每日明细：\n'
printf '日期\t输入\t输出\t缓存读取\t缓存写入\t总处理量\n'

DAILY_SQL=$(cat <<SQL
SELECT
  date(time_created / 1000, 'unixepoch', 'localtime') AS day,
  COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.input'), 0)), 0) AS input_tokens,
  COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.output'), 0)), 0) AS output_tokens,
  COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.cache.read'), 0)), 0) AS cache_read,
  COALESCE(SUM(COALESCE(json_extract(data, '$.tokens.cache.write'), 0)), 0) AS cache_write
FROM message
WHERE time_created >= $START_MS AND time_created < $END_MS
GROUP BY day
ORDER BY day;
SQL
)

while IFS=$'\t' read -r DAY DAY_INPUT DAY_OUTPUT DAY_CACHE_READ DAY_CACHE_WRITE; do
  [[ -n "$DAY" ]] || continue
  DAY_TOTAL=$((DAY_INPUT + DAY_OUTPUT + DAY_CACHE_READ + DAY_CACHE_WRITE))
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$DAY" \
    "$(format_integer "$DAY_INPUT")" "$(format_integer "$DAY_OUTPUT")" \
    "$(format_integer "$DAY_CACHE_READ")" "$(format_integer "$DAY_CACHE_WRITE")" \
    "$(format_integer "$DAY_TOTAL")"
done < <(sqlite3 -separator $'\t' "$DB_PATH" "$DAILY_SQL")

# 最后显示实际读取的数据库和统计口径，便于核对多版本或多目录安装情况。
printf '\n统计数据库：%s\n' "$DB_PATH"
printf '统计口径：按消息创建时间计算区间内实际产生的 Token；起止日期均包含。\n'
