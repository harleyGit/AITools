---
name: dev_general_skill
description: Apply shared development conventions for final responses and git commits across Codex CLI and OpenCode CLI. Trigger after code or file changes, when producing final output, committing code, drafting commit messages, or checking repository contribution rules.
---

# Dev General Skill

## Final Output Convention

Every final response after code or file changes must include these 1-7 items:

1. 修改了哪些文件
2. 做了什么改动
3. 为什么这样改
4. 准确性检查结果
5. 潜在影响
6. 格式化/编译/测试说明
7. 后续优化建议（可选，按收益排序）

Requirements:

- 写真实文件路径；无改动写"未修改文件"
- 写实际执行的检查和结果；未执行写原因
- 输出必须真实、具体、可核对
- 不得把理论可行说成已验证通过

## Git Commit Convention

When committing code to a git remote repository or creating local commits intended for sharing, use this commit message format:

```text
<type>: <emoji> <description>
```

Type and emoji mapping:

- `feat`: 🍒 New feature
- `fix`: 💯 Bug fix
- `docs`: 🍎🧩 Documentation change
- `style`: 🍄 Code formatting change that does not affect runtime behavior
- `refactor`: 🍀 Refactor that is neither a new feature nor a bug fix
- `test`: ☔️ Add or update tests

Examples:

```text
feat: 🍒 新增用户登录功能
fix: 💯 修复登录验证逻辑错误
docs: 🍎🧩 更新API文档
style: 🍄 格式化代码缩进
refactor: 🍀 重构用户服务层
test: ☔️ 添加用户模块单元测试
```

## Commit Checklist

1. Inspect `git status` before staging or committing.
2. Review staged and unstaged diffs before writing the commit message.
3. Do not commit secrets, credentials, `.env` files, tokens, or generated artifacts unless the user explicitly approves and the repository expects them.
4. Prefer the smallest accurate commit type.
5. Keep the description concise and focused on the purpose of the change.
6. Do not push to remote unless the user explicitly asks.
