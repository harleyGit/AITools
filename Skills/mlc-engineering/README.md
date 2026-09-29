# MLC 工程技能

本目录由 AITools 仓库统一维护，供 MLC_GO、MLC_React 和 MLC 按任务复用。不复制公共技能到项目，不使用 `instructions` 强制加载技能正文。

## 三层职责

| 入口 | 职责 | 加载方式 |
| --- | --- | --- |
| 项目根 `AGENTS.md` | 项目说明、实际版本、目录、架构、命名、禁止事项、测试与启动入口、关键依赖 | OpenCode 项目规则 |
| 项目根 `opencode.json` | 声明公共技能搜索路径，不承载工程规则正文 | 启动时读取配置 |
| 本目录 `**/SKILL.md` | 通用或技术专题的操作方法，按描述匹配当前任务 | 先发现技能元数据，命中任务后调用 skill 加载正文 |

项目特有约束以当前项目 `AGENTS.md` 为准；公共技能不得改变项目技术栈。不要为所有任务预先读取全部技能。

## 目录

```text
mlc-engineering/
├── README.md
├── common/
│   ├── engineering-workflow/SKILL.md
│   ├── code-review/SKILL.md
│   ├── security/SKILL.md
│   └── testing/SKILL.md
├── go/
│   ├── SKILL.md
│   ├── development/SKILL.md
│   ├── api/SKILL.md
│   ├── concurrency/SKILL.md
│   ├── redis/SKILL.md
│   ├── mysql/SKILL.md
│   ├── kafka/SKILL.md
│   ├── clickhouse/SKILL.md
│   ├── statistic/SKILL.md
│   └── danmaku/SKILL.md
├── react/SKILL.md
└── ios/SKILL.md
```

共 16 个技能，`name` 与所在末级目录相同且在本目录唯一。`statistic`、`danmaku` 仅用于 MLC_GO 对应业务；其他技能遵循自身任务触发描述。HTTP 接口方法统一归 `api`，统计统一归 `statistic`，不建立重复 `http`、`static` 或第二份 ClickHouse 技能。

## OpenCode 配置

三个工程各自保留以下项目配置；合并时保留已有 provider、权限及其他无关字段：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": {
    "paths": ["~/HGFiles/GitHub/AITools/Skills/mlc-engineering"]
  }
}
```

`skills` 是对象，不是数组。OpenCode 递归扫描该路径下的 `**/SKILL.md`；不需要为子目录逐一配置路径。其他机器应按实际仓库位置调整路径。

输出与提交约定复用相邻的 `../dev_general_skill/SKILL.md`。若该技能未在当前客户端注册，涉及交付或提交时按此路径读取；不在各语言技能复制一套提交规范。

MLC 的 Claude、Cursor、Antigravity 规则入口引用项目 `AGENTS.md`，仅在相关任务读取 iOS 技能。其他客户端不保证识别 OpenCode 配置，需要独立验证其加载方式。

## 维护

- 本技能库不需要独立 `AGENTS.md`；维护说明集中在本文，项目硬约束仍由三个工程各自的 `AGENTS.md` 承载。
- 技能文件固定为 `SKILL.md`，frontmatter 包含与末级目录一致的小写连字符 `name` 和具体任务触发 `description`；项目专用技能在描述中限定范围。
- 项目事实变更只更新对应项目规则；方法变更只更新其所属技能。通用安全、工作流、测试及审查方法统一维护在 `common/`。
- 新增前先确认现有专题不能承接；合并或删除前确认独有约束的归属，不保留重复副本或悬空引用。
- 项目版本以实际 manifest、锁文件或工程配置为准；本目录只有 Markdown，无独立构建或服务启动命令。

## 验证

1. 检查三个 `opencode.json` 可解析且仅通过 `skills.paths` 注册公共技能，没有强载技能正文的 `instructions`。
2. 检查每个技能 frontmatter 的 `name`、`description`、名称唯一性以及引用目标存在。
3. 从各项目运行 `opencode debug skill`，确认上述 16 个技能的名称及实际路径可发现；全局其他技能不计入该数量。
4. 退出并重启 OpenCode，在新会话验证项目 `AGENTS.md` 生效，再调用匹配任务的 skill。技能发现、正文加载、业务测试是三种不同验证，不能互相代替。
5. 执行相关仓库的 `git diff --check`。规则或配置变更不等于业务构建已通过；如运行业务测试，记录实际命令、环境和结果。

公共技能更新会影响所有引用它的新会话。保留已有工作区和暂存区改动，不自动提交、推送或修改用户全局配置。
