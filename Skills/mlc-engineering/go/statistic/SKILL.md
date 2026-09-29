---
name: statistic
description: 仅在 MLC_GO 的 statistic 消费者、视频统计、Redis generation 分片计数、Kafka offset 水位或 ClickHouse 对账任务中使用，指导统计一致性变更与验证。
---

# MLC 统计链路

项目不变量以根 `AGENTS.md` 的 Statistic 约束为准，不另存默认配置；通用安全与验证见 [Go 入口](../SKILL.md) 和 [测试](../../common/testing/SKILL.md)。以下路径相对 MLC_GO 根目录，配置与协议须核对当前实现。

## 链路核对
1. 阅读 `internal/consumer/statistic/hg_statistic_consumer.go` 及同目录 `hg_redis_counter.go`、`hg_reconciler.go`，追踪消费、错误传播、分片、水位和对账。
2. 对照 `deployments/clickhouse/001_statistic_events.sql` 的事件与聚合口径，按当前 generation、shard、hash tag 建立写入/去重矩阵。
3. 绘制权威写入、投影更新、失败重放和 offset 提交顺序；追踪 Lua 参数及实现，不因接口或旧注释含 EventID 就认定按 EventID 去重。
4. 分开推演相同 delivery 重放与同 EventID 不同 offset，对比 Redis 水位和 ClickHouse 精确聚合，分析漂移而非隐藏差异或在线改值。

## 验证重点
- 重复 delivery、乱序 offset、同 EventID 不同 offset、权威写失败、Redis 写失败后的重放。
- 不同 generation、分片隔离、Redis 缺失值及 ClickHouse 聚合延迟。
- `make statistic-acceptance` 的真实写入授权要求见项目 `AGENTS.md`；执行前明确隔离环境、topic、group、generation 和清理范围，不修改生产统计值来让测试通过。
