---
name: go
description: 当任务涉及 Go 开发、HTTP/RPC、并发、数据访问、消息投影或性能优化时使用，按任务选择 Go 专题方法，不强制加载全部技能。
---

# Go 方法入口

项目事实、版本、入口、命名及业务不变量以当前工程根 `AGENTS.md` 和实际配置为准；本目录不预设 router、ORM、工具链或容量。

## 按需选择

| 任务 | 专题 |
| --- | --- |
| 业务逻辑、错误、context、模型、性能 | [development](development/SKILL.md) |
| HTTP/RPC、DTO、鉴权、幂等、限流 | [api](api/SKILL.md) |
| goroutine、channel、锁、工作池、退出 | [concurrency](concurrency/SKILL.md) |
| 缓存、TTL、锁、Lua、Cluster | [redis](redis/SKILL.md) |
| SQL、索引、事务、分页、批处理 | [mysql](mysql/SKILL.md) |
| 消息生产消费、offset、重平衡 | [kafka](kafka/SKILL.md) |
| 分析存储、摄入、物化聚合、去重 | [clickhouse](clickhouse/SKILL.md) |
| MLC_GO 统计投影和对账 | [statistic](statistic/SKILL.md) |
| MLC_GO 弹幕写入、历史及实时副本 | [danmaku](danmaku/SKILL.md) |

跨层任务只叠加实际涉及的专题。通用方法按任务引用 [工程实施](../common/engineering-workflow/SKILL.md)、[审查](../common/code-review/SKILL.md)、[安全](../common/security/SKILL.md)、[测试](../common/testing/SKILL.md)；交付与提交引用 [dev_general_skill](../../dev_general_skill/SKILL.md)。各专题沿用这些公共规则，不复制流程。
