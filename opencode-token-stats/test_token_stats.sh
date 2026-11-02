#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMP_DIR=$(mktemp -d)
DB_PATH="$TMP_DIR/opencode.db"
trap 'rm -rf "$TMP_DIR"' EXIT

sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE session (
  id TEXT PRIMARY KEY,
  time_created INTEGER NOT NULL
);

CREATE TABLE message (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  time_created INTEGER NOT NULL,
  data TEXT NOT NULL
);

INSERT INTO session VALUES
  ('s0', unixepoch('2026-07-17 12:00:00', 'utc') * 1000),
  ('s1', unixepoch('2026-07-18 12:00:00', 'utc') * 1000),
  ('s2', unixepoch('2026-07-24 12:00:00', 'utc') * 1000);

INSERT INTO message VALUES
  ('m0', 's0', unixepoch('2026-07-17 23:59:59', 'utc') * 1000,
   '{"role":"assistant","cost":9,"tokens":{"input":999,"output":999,"cache":{"read":999,"write":999}},"providerID":"ignored","modelID":"ignored"}'),
  ('m1', 's1', unixepoch('2026-07-18 08:00:00', 'utc') * 1000,
   '{"role":"assistant","cost":0.25,"tokens":{"input":1000,"output":200,"cache":{"read":3000,"write":40}},"providerID":"CM_AI","modelID":"gpt-5.6-sol"}'),
  ('m2', 's1', unixepoch('2026-07-18 09:00:00', 'utc') * 1000,
   '{"role":"user"}'),
  ('m3', 's2', unixepoch('2026-07-24 20:00:00', 'utc') * 1000,
   '{"role":"assistant","cost":0.5,"tokens":{"input":2000,"output":300,"cache":{"read":4000,"write":60}},"providerID":"cm-ai","modelID":"gpt-5.6-sol"}'),
  ('m4', 's2', unixepoch('2026-07-25 00:00:00', 'utc') * 1000,
    '{"role":"assistant","cost":9,"tokens":{"input":999,"output":999,"cache":{"read":999,"write":999}},"providerID":"ignored","modelID":"ignored"}');

CREATE TABLE session_message (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  time_created INTEGER NOT NULL,
  data TEXT NOT NULL
);

INSERT INTO session_message VALUES
  ('m1', 's1', unixepoch('2026-07-18 08:00:00', 'utc') * 1000,
   '{"role":"assistant","cost":0.25,"tokens":{"input":1000,"output":200,"cache":{"read":3000,"write":40}},"model":{"id":"gpt-5.6-sol","providerID":"CM_AI"}}'),
  ('v1', 's2', unixepoch('2026-10-28 08:00:00', 'utc') * 1000,
   '{"role":"assistant","cost":0.1,"tokens":{"input":100,"output":20,"cache":{"read":1000,"write":0}},"model":{"id":"gpt-6-sol","providerID":"openai"}}'),
  ('v2', 's2', unixepoch('2026-11-02 08:00:00', 'utc') * 1000,
   '{"role":"assistant","cost":0.2,"tokens":{"input":200,"output":30,"cache":{"read":2000,"write":0}},"model":{"id":"gpt-6-sol","providerID":"openai"}}');
SQL

assert_contains() {
  local output=$1
  local expected=$2

  if [[ "$output" != *"$expected"* ]]; then
    printf '断言失败，输出中缺少：%s\n\n实际输出：\n%s\n' "$expected" "$output" >&2
    exit 1
  fi
}

assert_row() {
  local output=$1
  local label=$2
  local expected=$3
  if ! printf '%s\n' "$output" | awk -v label="$label" -v expected="$expected" '
    index($0, label) == 1 {
      value = substr($0, length(label) + 1)
      sub(/^[[:space:]]+/, "", value)
      if (index(value, expected) == 1) found = 1
    }
    END { exit !found }
  '; then
    printf '断言失败，列 %s 应以 %s 开头。\n' "$label" "$expected" >&2
    exit 1
  fi
}

week_output=$(OPENCODE_DB_PATH="$DB_PATH" TOKEN_STATS_TODAY=2026-07-24 \
  "$SCRIPT_DIR/opencode_token_stats.sh" "最近一周")

assert_contains "$week_output" '2026-07-18 至 2026-07-24'
assert_row "$week_output" '输入 Token' '3,000'
assert_row "$week_output" '输出 Token' '500'
assert_row "$week_output" '缓存读取 Token' '7,000'
assert_row "$week_output" '缓存写入 Token' '100'
assert_row "$week_output" '输入 + 输出' '3,500'
assert_row "$week_output" '包含缓存读取和写入的总处理量' '10,600'
assert_contains "$week_output" '会话数：2'
assert_contains "$week_output" '消息数：3'
assert_contains "$week_output" '主要使用模型：gpt-5.6-sol'
assert_contains "$week_output" '记录成本：$0.75'

day_output=$(OPENCODE_DB_PATH="$DB_PATH" TOKEN_STATS_TODAY=2026-07-24 \
  "$SCRIPT_DIR/opencode_token_stats.sh" "2026-07-18")

assert_contains "$day_output" '2026-07-18'
assert_row "$day_output" '输入 Token' '1,000'
assert_contains "$day_output" '会话数：1'
assert_contains "$day_output" '消息数：2'

range_output=$(OPENCODE_DB_PATH="$DB_PATH" \
  "$SCRIPT_DIR/opencode_token_stats.sh" --start 2026-07-24 --end 2026-07-24)

assert_row "$range_output" '输入 Token' '2,000'
assert_row "$range_output" '输出 Token' '300'

# 迁移后的消息应计入汇总和每日明细；没有记录的日期不显示。
gap_output=$(OPENCODE_DB_PATH="$DB_PATH" \
  "$SCRIPT_DIR/opencode_token_stats.sh" --start 2026-07-24 --end 2026-07-27)
assert_contains "$gap_output" '2026-07-25'
if [[ "$gap_output" == *'2026-07-26  '* || "$gap_output" == *'2026-07-27  '* || \
      "$gap_output" == *$'日期\t输入'* ]]; then
  printf '断言失败：每日明细未转为终端对齐的列。\n' >&2
  exit 1
fi

v2_output=$(OPENCODE_DB_PATH="$DB_PATH" \
  "$SCRIPT_DIR/opencode_token_stats.sh" --start 2026-10-25 --end 2026-11-02)
assert_row "$v2_output" '输入 Token' '300'
assert_contains "$v2_output" '消息数：2'
assert_contains "$v2_output" '2026-10-28'
assert_contains "$v2_output" '2026-11-02'
assert_contains "$v2_output" '总使用 Token：3,350'
assert_contains "$v2_output" '主要使用模型：gpt-6-sol'
if [[ "$v2_output" == *'按提供方汇总'* ]]; then
  printf '断言失败：报表应合并所有提供方。\n' >&2
  exit 1
fi
if [[ "$v2_output" == *'2026-10-26  '* || "$v2_output" == *'2026-10-27  '* ]]; then
  printf '断言失败：无消息的日期不应显示。\n' >&2
  exit 1
fi

# OpenCode 自身通过 OPENCODE_DB 指定的数据库也能被自动发现。
env_output=$(OPENCODE_DB_PATH='' OPENCODE_DB="$DB_PATH" \
  "$SCRIPT_DIR/opencode_token_stats.sh" --start 2026-07-18 --end 2026-07-18)
assert_row "$env_output" '输入 Token' '1,000'

# 仅存在新表的数据库仍应能生成报表。
sqlite3 "$TMP_DIR/v2-only.db" <<'SQL'
CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, data TEXT);
INSERT INTO session_message VALUES
  ('v1', 's1', unixepoch('2026-11-02 08:00:00', 'utc') * 1000,
   '{"role":"assistant","tokens":{"input":7,"output":3,"cache":{"read":11,"write":0}},"model":{"id":"gpt-6-sol","providerID":"openai"}}');
SQL
v2_only_output=$(
  "$SCRIPT_DIR/opencode_token_stats.sh" --db "$TMP_DIR/v2-only.db" --start 2026-11-02 --end 2026-11-02
)
assert_contains "$v2_only_output" '总使用 Token：21'

printf '全部测试通过。\n'
