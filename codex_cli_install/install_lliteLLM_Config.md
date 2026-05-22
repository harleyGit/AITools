# Codex CLI + LiteLLM + 小米 MiMo 配置记录

本文记录将小米 MiMo 模型通过 LiteLLM 接入 Codex CLI，并让 `codex` 命令自动启动 LiteLLM 的配置过程。

## 当前结果

- Codex CLI 已升级：`0.130.0 -> 0.132.0`
- LiteLLM 已配置 8 个小米 MiMo 模型
- Codex CLI 已新增 `litellm` provider 和多个 MiMo profile
- `/usr/local/bin/codex` 已接管为自动启动 wrapper
- 原始 Codex binary 保留为 `/usr/local/bin/codex-bin`
- 已在项目 `/Users/harleyhuang/HGFiles/GitHub/GoProject/src/MLC_GO` 中验证可用

## 重要结论

Codex CLI 0.132.0 支持并要求自定义 provider 使用：

```toml
wire_api = "responses"
```

但小米 MiMo 当前提供的是 OpenAI Chat Completions 兼容接口：

```text
https://token-plan-cn.xiaomimimo.com/v1/chat/completions
```

直接让 Codex 调 LiteLLM 的 `/v1/responses` 会失败：

```text
unexpected status 404 Not Found
url: http://127.0.0.1:4000/v1/responses
```

原因是 LiteLLM 会继续把 `/v1/responses` 转发到小米上游，而小米上游没有 `/v1/responses`。因此本机保留了一个很薄的 Responses-to-Chat 兼容层：

```text
Codex CLI -> http://127.0.0.1:4001/v1/responses
Bridge   -> http://127.0.0.1:4000/v1/chat/completions
LiteLLM  -> https://token-plan-cn.xiaomimimo.com/v1/chat/completions
```

如果将来小米 MiMo 或 LiteLLM 原生支持 `/v1/responses -> /v1/chat/completions` 转换，再删除这个 bridge。

## Codex CLI 升级

升级命令：

```bash
codex-bin update
```

实际由 Homebrew cask 完成：

```text
codex 0.130.0 -> 0.132.0
```

验证：

```bash
codex --version
```

输出：

```text
codex-cli 0.132.0
```

## LiteLLM 配置

配置文件：

```text
/Users/harleyhuang/.config/litellm/config.yaml
```

当前模型：

```yaml
model_list:
  - model_name: mimo-v2.5-pro
    litellm_params:
      model: openai/mimo-v2.5-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2.5
    litellm_params:
      model: openai/mimo-v2.5
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2.5-tts-voiceclone
    litellm_params:
      model: openai/mimo-v2.5-tts-voiceclone
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2.5-tts-voicedesign
    litellm_params:
      model: openai/mimo-v2.5-tts-voicedesign
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2.5-tts
    litellm_params:
      model: openai/mimo-v2.5-tts
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2-pro
    litellm_params:
      model: openai/mimo-v2-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2-omni
    litellm_params:
      model: openai/mimo-v2-omni
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2-tts
    litellm_params:
      model: openai/mimo-v2-tts
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

litellm_settings:
  drop_params: true
  set_verbose: false

general_settings:
  proxy_batch_write_at: 60
```

注意：小米 MiMo 模型 ID 对大小写敏感，必须使用小写，例如 `mimo-v2.5-pro`，不能写成 `MiMo-V2.5-Pro`。

## Codex 配置

配置文件：

```text
/Users/harleyhuang/.codex/config.toml
```

新增 provider：

```toml
[model_providers.litellm]
name = "LiteLLM Local Proxy"
base_url = "http://127.0.0.1:4001/v1"
env_key = "LITELLM_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
```

新增 profiles：

```toml
[profiles.mimo-v25-pro]
model_provider = "litellm"
model = "mimo-v2.5-pro"
model_reasoning_effort = "high"

[profiles.mimo-v25]
model_provider = "litellm"
model = "mimo-v2.5"
model_reasoning_effort = "high"

[profiles.mimo-v2-pro]
model_provider = "litellm"
model = "mimo-v2-pro"
model_reasoning_effort = "high"

[profiles.mimo-v2-omni]
model_provider = "litellm"
model = "mimo-v2-omni"
model_reasoning_effort = "high"

[profiles.mimo-v25-tts]
model_provider = "litellm"
model = "mimo-v2.5-tts"

[profiles.mimo-v25-tts-voiceclone]
model_provider = "litellm"
model = "mimo-v2.5-tts-voiceclone"

[profiles.mimo-v25-tts-voicedesign]
model_provider = "litellm"
model = "mimo-v2.5-tts-voicedesign"

[profiles.mimo-v2-tts]
model_provider = "litellm"
model = "mimo-v2-tts"
```

说明：

- `mimo-v25-pro`、`mimo-v25`、`mimo-v2-pro`、`mimo-v2-omni` 适合 Codex 文本/代码任务。
- TTS 模型已加入 profile，但不建议作为 Codex coding agent 默认模型。

## 自动启动脚本

wrapper：

```text
/Users/harleyhuang/.local/bin/codex-litellm-wrapper
```

Responses-to-Chat bridge：

```text
/Users/harleyhuang/.local/bin/codex-litellm-responses-bridge.py
```

symlink：

```text
/usr/local/bin/codex     -> /Users/harleyhuang/.local/bin/codex-litellm-wrapper
/usr/local/bin/codex-bin -> /usr/local/Caskroom/codex/0.132.0/codex-x86_64-apple-darwin
```

wrapper 行为：

1. 跳过 `--help`、`--version`、`login`、`logout`、`update` 等不需要模型调用的命令。
2. 对实际 Codex 会话，检查 LiteLLM：

   ```text
   http://127.0.0.1:4000/v1/models
   ```

3. LiteLLM 未启动时自动后台启动：

   ```bash
   /Users/harleyhuang/.local/bin/litellm \
     --config /Users/harleyhuang/.config/litellm/config.yaml \
     --host 127.0.0.1 \
     --port 4000 \
     --telemetry False
   ```

4. 检查 bridge：

   ```text
   http://127.0.0.1:4001/healthz
   ```

5. bridge 未启动时自动后台启动：

   ```bash
   /Users/harleyhuang/.local/bin/codex-litellm-responses-bridge.py \
     --host 127.0.0.1 \
     --port 4001 \
     --upstream http://127.0.0.1:4000/v1 \
     --api-key sk-local-litellm
   ```

6. 最后执行原始 Codex：

   ```bash
   /usr/local/bin/codex-bin "$@"
   ```

日志：

```text
/Users/harleyhuang/.local/state/codex-litellm/litellm.log
/Users/harleyhuang/.local/state/codex-litellm/responses-bridge.log
```

PID：

```text
/Users/harleyhuang/.local/state/codex-litellm/litellm.pid
/Users/harleyhuang/.local/state/codex-litellm/responses-bridge.pid
```

## 使用方法

进入项目：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/GoProject/src/MLC_GO
```

使用 MiMo-V2.5-Pro：

```bash
codex -p mimo-v25-pro
```

使用 MiMo-V2.5：

```bash
codex -p mimo-v25
```

使用 MiMo-V2-Pro：

```bash
codex -p mimo-v2-pro
```

使用 MiMo-V2-Omni：

```bash
codex -p mimo-v2-omni
```

非交互验证命令：

```bash
codex -p mimo-v25-pro \
  -C /Users/harleyhuang/HGFiles/GitHub/GoProject/src/MLC_GO \
  -s read-only \
  -a never \
  exec --skip-git-repo-check \
  '只回答 OK，不要执行命令，不要修改文件。'
```

## 验证结果

验证 Codex 版本：

```bash
codex --version
```

输出：

```text
codex-cli 0.132.0
```

验证 LiteLLM 模型列表：

```bash
curl http://127.0.0.1:4000/v1/models
```

返回包含：

```text
mimo-v2.5-pro
mimo-v2.5
mimo-v2.5-tts-voiceclone
mimo-v2.5-tts-voicedesign
mimo-v2.5-tts
mimo-v2-pro
mimo-v2-omni
mimo-v2-tts
```

验证端口：

```bash
lsof -nP -iTCP:4000 -sTCP:LISTEN
lsof -nP -iTCP:4001 -sTCP:LISTEN
```

结果：

```text
127.0.0.1:4000 -> LiteLLM
127.0.0.1:4001 -> Codex LiteLLM Responses bridge
```

验证 MiMo-V2.5-Pro：

```text
OpenAI Codex v0.132.0
workdir: /Users/harleyhuang/HGFiles/GitHub/GoProject/src/MLC_GO
model: mimo-v2.5-pro
provider: litellm
approval: never
sandbox: read-only
...
OK
```

验证 MiMo-V2.5：

```text
OpenAI Codex v0.132.0
workdir: /Users/harleyhuang/HGFiles/GitHub/GoProject/src/MLC_GO
model: mimo-v2.5
provider: litellm
approval: never
sandbox: read-only
...
OK
```

## Codex profile 与 LiteLLM model_name 映射规则

Codex CLI 的 profile 名称只在 Codex 本地生效，不会直接传给 LiteLLM。例如：

```toml
[profiles.mimo-v25-pro-v1]
model_provider = "litellm"
model = "mimo-v2.5-pro"
model_reasoning_effort = "high"
```

这里真正会被 Codex 发送给 LiteLLM 的是：

```text
model = "mimo-v2.5-pro"
```

因此 LiteLLM 的 `/Users/harleyhuang/.config/litellm/config.yaml` 里必须存在完全同名的 `model_name`：

```yaml
model_list:
  - model_name: mimo-v2.5-pro
    litellm_params:
      model: openai/mimo-v2.5-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"
```

四层名称关系如下：

```text
codex -p mimo-v25-pro-v1
        -> 读取 Codex profile: [profiles.mimo-v25-pro-v1]
        -> Codex 请求模型名: model = "mimo-v2.5-pro"
        -> LiteLLM 匹配: model_name: mimo-v2.5-pro
        -> LiteLLM 调上游: litellm_params.model: openai/mimo-v2.5-pro
```

如果 Codex profile 写成下面这样：

```toml
[profiles.mimo-v25-pro]
model_provider = "litellm"
model = "gpt-5.5"
model_reasoning_effort = "high"
```

那么 LiteLLM 需要有一个同名的兼容别名：

```yaml
model_list:
  - model_name: gpt-5.5
    litellm_params:
      model: openai/mimo-v2.5-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"
```

这不是 Codex 自动把 `gpt-5.5` 识别成 MiMo，而是 LiteLLM 把本地模型名 `gpt-5.5` 映射到了上游 `openai/mimo-v2.5-pro`。

推荐同时保留两个 LiteLLM 条目：

```yaml
model_list:
  - model_name: mimo-v2.5-pro
    litellm_params:
      model: openai/mimo-v2.5-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: gpt-5.5
    litellm_params:
      model: openai/mimo-v2.5-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"
```

这样可以同时支持：

```bash
codex -p mimo-v25-pro-v1
codex -p mimo-v25-pro
```

判断配置是否正确的规则很简单：Codex profile 里的 `model = "..."` 必须能在 LiteLLM 的 `model_list[].model_name` 中找到同名条目；`model_name` 再通过 `litellm_params.model` 指向真实上游模型。

端口关系不冲突：

```text
Codex CLI -> http://127.0.0.1:4001/v1/responses
4001 bridge -> http://127.0.0.1:4000/v1/chat/completions
LiteLLM 4000 -> https://token-plan-cn.xiaomimimo.com/v1/chat/completions
```

Codex 使用 `4001` 是因为当前需要 Responses-to-Chat bridge；Aider 可以直接使用 LiteLLM 的 `4000/v1` Chat Completions 兼容接口。两者同时开启时，一个监听 `4000`，一个监听 `4001`，不会因为端口相同而冲突。

## 回退方法

绕过 wrapper，直接运行原始 Codex：

```bash
codex-bin --version
codex-bin -p mimo-v25-pro
```

恢复 Homebrew 原始 symlink：

```bash
ln -sfn /usr/local/Caskroom/codex/0.132.0/codex-x86_64-apple-darwin /usr/local/bin/codex
```

重新启用自动启动 wrapper：

```bash
ln -sfn /usr/local/Caskroom/codex/0.132.0/codex-x86_64-apple-darwin /usr/local/bin/codex-bin
ln -sfn /Users/harleyhuang/.local/bin/codex-litellm-wrapper /usr/local/bin/codex
```


***
<br/><br/><br/>
> <h2 id=""></h2>


切换模型在codex cli + LLiteLLM通过：

```sh
codex -p mimo-v25
```


方案 A（推荐）：用“合法 model + LiteLLM 映射”
Step 1：改 Codex model（关键）

把：

model = "gpt-5.5"

改成：

model = "gpt-4o-mini"

👉 这一步是为了绕过 Codex 校验层

Step 2：保留 LiteLLM 映射（你现在是对的）
[profiles.mimo-v25-pro]
model_provider = "litellm"
model = "gpt-4o-mini"   # ⚠️ 改这里，不要用 mimo 名字
model_reasoning_effort = "high"
Step 3：LiteLLM config 才做映射
model_list:
  - model_name: gpt-4o-mini
    litellm_params:
      model: openai/mimo-v2.5-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
🎯 关键思想（一定要理解）

你现在的问题本质是：

Codex CLI 不允许“未知 model name”

所以必须做到：

Codex sees: gpt-4o-mini   ✔ allowed
LiteLLM maps: mimo-v2.5-pro ✔ real model

## HGCM_AI 配置补充

HGCM_AI 是 OpenAI-compatible provider。Codex CLI 仍然走本机 LiteLLM Responses bridge：

```text
Codex CLI -> http://127.0.0.1:4001/v1/responses
4001 bridge -> http://127.0.0.1:4000/v1/chat/completions
LiteLLM 4000 -> https://open-xxxxx:7799/v1/chat/completions
```

注意：`https://open-xxxx:7799/v1` 只有在指定局域网内可访问。不在该网络时，本地 Codex/LiteLLM 配置可以加载成功，但实际模型调用会因为无法连接 HGCM_AI 上游而失败。

### LiteLLM config.yaml

配置文件：

```text
/Users/harleyhuang/.config/litellm/config.yaml
```

追加到 `model_list` 中。示例里不要提交真实 key，个人机器上替换为实际 HGCM_AI API key：

```yaml
  - model_name: gpt-5.5
    litellm_params:
      model: openai/gpt-5.5
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gpt-5.4
    litellm_params:
      model: openai/gpt-5.4
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gpt-5.4-mini
    litellm_params:
      model: openai/gpt-5.4-mini
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gpt-5.2
    litellm_params:
      model: openai/gpt-5.2
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gpt-5.3-codex
    litellm_params:
      model: openai/gpt-5.3-codex
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gpt-5.3-codex-spark
    litellm_params:
      model: openai/gpt-5.3-codex-spark
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: codex-auto-review
    litellm_params:
      model: openai/codex-auto-review
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gpt-image-2
    litellm_params:
      model: openai/gpt-image-2
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gemini-3.1-pro-preview
    litellm_params:
      model: openai/gemini-3.1-pro-preview
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gemini-3.1-flash-lite-preview
    litellm_params:
      model: openai/gemini-3.1-flash-lite-preview
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gemini-3-pro-preview
    litellm_params:
      model: openai/gemini-3-pro-preview
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gemini-3-flash-preview
    litellm_params:
      model: openai/gemini-3-flash-preview
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gemini-2.5-pro
    litellm_params:
      model: openai/gemini-2.5-pro
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gemini-2.5-flash
    litellm_params:
      model: openai/gemini-2.5-flash
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"

  - model_name: gemini-2.5-flash-lite
    litellm_params:
      model: openai/gemini-2.5-flash-lite
      api_base: https://open-xxxx:7799/v1
      api_key: "PASTE_YOUR_HGCM_AI_API_KEY_HERE"
```

### Codex config.toml

配置文件：

```text
/Users/harleyhuang/.codex/config.toml
```

全局默认继续指向 LiteLLM provider：

```toml
model_provider = "litellm"
model = "gpt-5.5"
model_reasoning_effort = "high"
```

LiteLLM provider 保持走本机 bridge：

```toml
[model_providers.litellm]
name = "LiteLLM Local Proxy"
base_url = "http://127.0.0.1:4001/v1"
env_key = "LITELLM_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
```

新增 HGCM_AI profiles：

```toml
[profiles."gpt-5.5"]
model_provider = "litellm"
model = "gpt-5.5"
model_reasoning_effort = "high"

[profiles."gpt-5.4"]
model_provider = "litellm"
model = "gpt-5.4"
model_reasoning_effort = "high"

[profiles."gpt-5.4-mini"]
model_provider = "litellm"
model = "gpt-5.4-mini"
model_reasoning_effort = "high"

[profiles."gpt-5.2"]
model_provider = "litellm"
model = "gpt-5.2"
model_reasoning_effort = "high"

[profiles."gpt-5.3-codex"]
model_provider = "litellm"
model = "gpt-5.3-codex"
model_reasoning_effort = "high"

[profiles."gpt-5.3-codex-spark"]
model_provider = "litellm"
model = "gpt-5.3-codex-spark"
model_reasoning_effort = "high"

[profiles.codex-auto-review]
model_provider = "litellm"
model = "codex-auto-review"
model_reasoning_effort = "high"

[profiles."gpt-image-2"]
model_provider = "litellm"
model = "gpt-image-2"

[profiles."gemini-3.1-pro-preview"]
model_provider = "litellm"
model = "gemini-3.1-pro-preview"
model_reasoning_effort = "high"

[profiles."gemini-3.1-flash-lite-preview"]
model_provider = "litellm"
model = "gemini-3.1-flash-lite-preview"
model_reasoning_effort = "high"

[profiles.gemini-3-pro-preview]
model_provider = "litellm"
model = "gemini-3-pro-preview"
model_reasoning_effort = "high"

[profiles.gemini-3-flash-preview]
model_provider = "litellm"
model = "gemini-3-flash-preview"
model_reasoning_effort = "high"

[profiles.gemini-2-5-pro]
model_provider = "litellm"
model = "gemini-2.5-pro"
model_reasoning_effort = "high"

[profiles.gemini-2-5-flash]
model_provider = "litellm"
model = "gemini-2.5-flash"
model_reasoning_effort = "high"

[profiles.gemini-2-5-flash-lite]
model_provider = "litellm"
model = "gemini-2.5-flash-lite"
model_reasoning_effort = "high"
```

### 验证

只验证本地配置是否正确加载：

```bash
codex --strict-config doctor --json
```

看到下面信息即可说明 Codex 本地配置链路正确：

```text
model provider = litellm
provider auth env var = LITELLM_API_KEY (present)
litellm API base URL = http://127.0.0.1:4001/v1 reachable
```

在指定局域网内可做端到端模型调用：

```bash
codex exec -p gpt-5.4-mini --skip-git-repo-check "只输出 HGCM_OK"
```

不在指定局域网内时，LiteLLM 能启动并加载模型列表，但实际调用会在上游连接阶段失败；这不是 Codex profile 或 LiteLLM model_list 配置错误。

### 个人操作范围

如果机器上已经完成过本文前面的 LiteLLM、bridge、wrapper 和 symlink 安装，个人日常新增或切换模型通常只需要改两个文件：

```text
/Users/harleyhuang/.config/litellm/config.yaml
/Users/harleyhuang/.codex/config.toml
```

判断规则：Codex profile 里的 `model = "..."` 必须能在 LiteLLM 的 `model_list[].model_name` 中找到同名条目。

如果是全新机器或 Homebrew 升级后破坏了入口链路，还需要额外确认这些内容：

```text
/Users/harleyhuang/.local/bin/codex-litellm-wrapper
/Users/harleyhuang/.local/bin/codex-litellm-responses-bridge.py
/usr/local/bin/codex     -> /Users/harleyhuang/.local/bin/codex-litellm-wrapper
/usr/local/bin/codex-bin -> 当前 Codex 原始 binary
```
