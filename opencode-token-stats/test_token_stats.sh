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
SQL

assert_contains() {
  local output=$1
  local expected=$2

  if [[ "$output" != *"$expected"* ]]; then
    printf '断言失败，输出中缺少：%s\n\n实际输出：\n%s\n' "$expected" "$output" >&2
    exit 1
  fi
}

week_output=$(OPENCODE_DB_PATH="$DB_PATH" TOKEN_STATS_TODAY=2026-07-24 \
  "$SCRIPT_DIR/opencode_token_stats.sh" "最近一周")

assert_contains "$week_output" '2026-07-18 至 2026-07-24'
assert_contains "$week_output" $'输入 Token\t3,000'
assert_contains "$week_output" $'输出 Token\t500'
assert_contains "$week_output" $'缓存读取 Token\t7,000'
assert_contains "$week_output" $'缓存写入 Token\t100'
assert_contains "$week_output" $'输入 + 输出\t3,500'
assert_contains "$week_output" $'包含缓存读取和写入的总处理量\t10,600'
assert_contains "$week_output" '会话数：2'
assert_contains "$week_output" '消息数：3'
assert_contains "$week_output" '主要使用模型：gpt-5.6-sol'
assert_contains "$week_output" '记录成本：$0.75'

day_output=$(OPENCODE_DB_PATH="$DB_PATH" TOKEN_STATS_TODAY=2026-07-24 \
  "$SCRIPT_DIR/opencode_token_stats.sh" "2026-07-18")

assert_contains "$day_output" '2026-07-18'
assert_contains "$day_output" $'输入 Token\t1,000'
assert_contains "$day_output" '会话数：1'
assert_contains "$day_output" '消息数：2'

range_output=$(OPENCODE_DB_PATH="$DB_PATH" \
  "$SCRIPT_DIR/opencode_token_stats.sh" --start 2026-07-24 --end 2026-07-24)

assert_contains "$range_output" $'输入 Token\t2,000'
assert_contains "$range_output" $'输出 Token\t300'

printf '全部测试通过。\n'
