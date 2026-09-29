---
name: danmaku
description: 仅在 MLC_GO 视频弹幕 video_danmaku、danmaku 消费者、Outbox、实时广播、WebSocket 票据或弹幕历史分页任务中使用，检查权威写入、幂等和实时副本边界。
---

# MLC 弹幕链路

项目不变量以根 `AGENTS.md` 的 Danmaku 约束为准，不另存默认配置；通用安全与验证见 [Go 入口](../SKILL.md) 和 [测试](../../common/testing/SKILL.md)。以下路径相对 MLC_GO 根目录。

## 链路核对
1. 阅读 `internal/modules/video_danmaku/service/hg_video_danmaku_service.go`、`internal/modules/video_danmaku/repository/hg_video_danmaku_repository.go` 和 `internal/consumer/danmaku/hg_danmaku_consumer.go`，追踪事务、Outbox、广播、存储及 offset 提交。
2. 按当前 topic、幂等键和配置推演新建、重复请求、载荷冲突、提交未知和广播失败，区分权威写入与副本成功边界。
3. 对比 HTTP 与分析存储游标的排序键/决胜键、时间窗及限额，检查边界重复、漏页和字符/字节单位。
4. 实时指标对照 `deployments/monitoring/README.md` 与项目口径，核查标签基数；单热点视频的分区瓶颈不能靠盲增消费者解决，须评估背压、慢连接及丢弃策略。

## 验证重点
- 事务回滚、重复/冲突 requestID、Outbox 启用/关闭、广播失败后的历史恢复。
- ClickHouse 成功但 Redis 失败后的重放、分区顺序、稳定游标、边界时间窗和分页上限。
- 票据过期、错误绑定、重复消费、慢连接和队列满；核对 Pod 局部量与全局去重量、queued 与真实发送、WebSocket 与 TCP admission 的指标区别。
