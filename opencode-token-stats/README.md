# OpenCode Token 使用量查询

通过 Shell 脚本查询 OpenCode 在某一天、最近若干天或指定日期范围内实际产生的 Token，并输出中文汇总、主要模型和每日明细。

脚本位置：

```text
/Users/huanggang/HGFiles/Code/GitHub/AISkills/opencode-token-stats/opencode_token_stats.sh
```

## 快速开始

```bash
cd /Users/huanggang/HGFiles/Code/GitHub/AISkills/opencode-token-stats
./opencode_token_stats.sh "最近一周"
```

## 文件

- `opencode_token_stats.sh`：查询脚本
- `test_token_stats.sh`：自动化测试
- `README.md`：使用说明

## 依赖

- macOS 或支持 GNU `date` 的系统
- `sqlite3`
- OpenCode CLI，或可直接访问 OpenCode SQLite 数据库

检查依赖：

```bash
command -v sqlite3
command -v opencode
opencode db path
```

脚本按以下顺序查找数据库：

1. `--db PATH`
2. 环境变量 `OPENCODE_DB_PATH`
3. `opencode db path`
4. `~/.local/share/opencode/opencode.db`
5. `~/Library/Application Support/opencode/opencode.db`

如果数据库不在默认位置，可以通过 `--db` 或 `OPENCODE_DB_PATH` 指定。

## 使用方法

进入脚本目录：

```bash
cd /Users/huanggang/HGFiles/Code/GitHub/AISkills/opencode-token-stats
```

查询最近一周，包含今天在内的最近 7 个自然日：

```bash
./opencode_token_stats.sh "最近一周"
```

查询今天或昨天：

```bash
./opencode_token_stats.sh "今天"
./opencode_token_stats.sh "昨天"
```

查询某一天：

```bash
./opencode_token_stats.sh "2026-07-20"
```

查询指定日期范围，开始和结束日期都包含：

```bash
./opencode_token_stats.sh "2026-07-18 至 2026-07-24"
```

也可以使用明确选项：

```bash
./opencode_token_stats.sh --start 2026-07-18 --end 2026-07-24
```

查询最近任意天数：

```bash
./opencode_token_stats.sh "最近30天"
```

不传参数时会进入输入提示：

```bash
./opencode_token_stats.sh
```

指定数据库：

```bash
./opencode_token_stats.sh --db "$HOME/.local/share/opencode/opencode.db" "最近一周"
```

查看完整帮助：

```bash
./opencode_token_stats.sh --help
```

将报表保存为文件：

```bash
./opencode_token_stats.sh "最近一周" > token-report.txt
```

通过环境变量指定数据库：

```bash
OPENCODE_DB_PATH="$HOME/.local/share/opencode/opencode.db" \
  ./opencode_token_stats.sh "最近一周"
```

## 支持的时间输入

| 输入 | 含义 |
|---|---|
| `最近一周`、`近一周` | 包含今天在内的最近 7 个自然日 |
| `最近7天`、`近7天` | 包含今天在内的最近 7 个自然日 |
| `最近30天` | 包含今天在内的最近 30 个自然日 |
| `今天`、`今日` | 今天 00:00 至次日 00:00 |
| `昨天`、`昨日` | 昨天 00:00 至今天 00:00 |
| `2026-07-20` | 指定自然日 |
| `2026-07-18 至 2026-07-24` | 包含首尾日期的时间段 |
| `2026-07-18 到 2026-07-24` | 与“至”写法相同 |

日期必须使用 `YYYY-MM-DD` 格式。

## 输出内容

报表包含：

- 输入 Token
- 输出 Token
- 缓存读取 Token
- 缓存写入 Token
- 输入与输出 Token 合计
- 包含缓存读取和写入的总处理量
- 会话数和消息数
- 每个会话的平均 Token 与中位数
- 记录成本
- 主要使用模型及其 Token
- 按自然日拆分的 Token 明细

## 输出示例

```text
最近 7 天 Token 使用量（2026-07-18 至 2026-07-24）

类型                            Token 数量
输入 Token                      1,035,334（约 103.53 万）
输出 Token                      75,425（约 7.54 万）
缓存读取 Token                  11,128,320（约 1112.83 万）
缓存写入 Token                  0
输入 + 输出                     1,110,759（约 111.08 万）
包含缓存读取和写入的总处理量      12,239,079（约 1223.91 万）

其他数据：
- 会话数：18
- 消息数：281
- 平均每个会话：679,949（约 67.99 万）Token，包含缓存读取和写入
- Token 中位数：47,936（约 4.79 万）/会话
- 记录成本：$0.00
- 主要使用模型：gpt-5.6-sol
```

## 统计口径

统计按 `message.time_created` 的本地时间筛选消息，并从消息 JSON 的以下字段聚合：

| JSON 字段 | 含义 |
|---|---|
| `$.tokens.input` | 输入 Token |
| `$.tokens.output` | 输出 Token |
| `$.tokens.cache.read` | 缓存读取 Token |
| `$.tokens.cache.write` | 缓存写入 Token |
| `$.cost` | 消息记录成本 |
| `$.modelID` | 使用模型 |

时间范围使用左闭右开区间。例如查询 `2026-07-18 至 2026-07-24`，实际范围是：

```text
[2026-07-18 00:00:00, 2026-07-25 00:00:00)
```

因此首尾日期都完整包含，但不会把 7 月 25 日零点及之后的数据算入。

指定日期范围时只计算该范围内实际产生的消息 Token，不会把跨日期会话的全部 Token 错算进来。这与 `opencode stats --days N` 可能采用的会话汇总口径不同，所以结果不一定完全一致。

计算公式：

```text
输入 + 输出 = input + output
总处理量 = input + output + cache read + cache write
```

会话平均值和中位数均基于查询区间内每个会话实际产生的总处理量。

## 运行测试

```bash
./test_token_stats.sh
```

测试会创建临时 SQLite 数据库，不会修改真实 OpenCode 数据。

也可以进行 Shell 语法检查：

```bash
bash -n opencode_token_stats.sh test_token_stats.sh
```

## 常见问题

### 未找到数据库

先查看 OpenCode 当前数据库路径：

```bash
opencode db path
```

再明确指定：

```bash
./opencode_token_stats.sh --db "/实际路径/opencode.db" "最近一周"
```

### 数据库中没有 message 表

说明指定的 SQLite 文件不是当前脚本支持的 OpenCode 数据库，或者 OpenCode 数据结构发生了变化。可以执行以下命令检查：

```bash
sqlite3 "$(opencode db path)" '.tables'
```

### 查询结果为 0

确认以下事项：

- 查询日期是否正确
- 实际读取的数据库路径是否正确
- OpenCode 是否在该时间范围内产生过消息
- 系统时区是否与预期一致

脚本输出末尾会显示实际使用的数据库路径和统计口径。

### 权限不足

确保脚本具有执行权限：

```bash
chmod +x opencode_token_stats.sh test_token_stats.sh
```
