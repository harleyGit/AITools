---
name: ios
description: 当任务涉及 iOS、UIKit、Swift、Objective-C 混编、SnapKit、Frame layout、Xcode 工程、并发或生命周期时使用。
---

# iOS 与 Swift 专项规则

## 适用边界
- 项目事实与硬约束以目标仓库 `AGENTS.md`、Xcode 配置和依赖锁文件为准。
- 通用方法按需引用 `common/` 下的 `engineering-workflow`、`security`、`testing`、`code-review`；输出与提交参照 `dev_general_skill`。

## 工程核查
- 区分 Swift language mode、Xcode 版本和 Swift 编译器工具链版本；不默认升级语言模式、Xcode、依赖管理方式或并发模型。
- 沿用项目已经使用的架构、日志、网络、布局和并发设施。UIKit 项目不要默认改用 SwiftUI；SnapKit 和 Frame layout 与目标模块现状保持一致。

## Swift 与 Objective-C
- 遵循 Swift API Design Guidelines：操作用动词、属性用名词，枚举类型大驼峰、case 小驼峰；优先不可变值，用 `guard` 收敛失败路径，避免强制解包。
- 修改公开 API 前检查所有调用方、协议实现、生成接口和错误契约，不扩大无必要的 `public` 或 `@objc` 暴露。
- Objective-C 保持现有前缀和命名，核对 `nullable`/`nonnull`、`NS_ASSUME_NONNULL_BEGIN`、集合映射、`NSError` 和回调签名。
- 涉及 KVO、delegate、运行时或 bridging header 时，确认动态派发、观察者清理和跨语言可见性。

## UI、并发与生命周期
- UI 更新必须回到主线程或主 Actor；重计算和阻塞 IO 不放在主线程。
- 标明调用与回调队列，沿用既有 GCD、Operation、Actor 或锁；避免同步派发到当前串行队列，不用不安全标注掩盖数据竞争。
- 使用 Swift Concurrency 前检查 deployment target、API availability、隔离与 `Sendable` 要求。
- 异步任务检查取消、错误传播和过期结果覆盖；请求、任务、计时器和观察者在适当生命周期取消或移除。
- 只有在生命周期确实安全时使用 `[unowned self]`，否则按需使用 `[weak self]` 并定义对象释放后的行为。
- 无副作用的简单派生状态优先用计算属性；复杂、有明显开销或需显式执行的逻辑使用方法。

## 验证
- 按项目 `AGENTS.md` 选择设备和工具。
- 核对 workspace、scheme、Testables/TestPlans 和签名；通用 iOS 目标的编译不等于具体设备运行或 XCTest 执行。
- 在 `testing` 流程下重点验证 Objective-C/Swift 类型与错误映射、页面退出后的释放、异步取消和 UI 回调线程；性能问题用 Instruments 等实际测量定位。
- 构建时区分既有、工具链和本次变更的 warning，避免引入新 warning，不为清零做无关修改。
