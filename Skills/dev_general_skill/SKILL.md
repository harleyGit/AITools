---
name: dev_general_skill
description: Apply shared development conventions for git commits across Codex CLI and OpenCode CLI. Trigger when committing code, drafting commit messages, or checking repository contribution rules.
---

# Dev General Skill

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
