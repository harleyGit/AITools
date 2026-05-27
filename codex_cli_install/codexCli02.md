# Codex CLI + LiteLLM + MiMo/GPT 接入排障与使用流程

更新时间：2026-05-27

## 1. 当前目标

目标是让 Codex CLI 统一通过 LiteLLM 接入多种模型：

- 小米 MiMo 模型：上游是 OpenAI-compatible Chat Completions 接口，不支持 Responses API。
- 公司 GPT/Gemini/其他模型：上游是公司 OpenAI-compatible 网关。
- Codex CLI：默认使用 Responses API，因此需要本地 bridge 把 Codex 的 `/v1/responses` 转成 LiteLLM 的 `/v1/chat/completions`。

最终链路：

```text
codex
  -> /usr/local/bin/codex 包装脚本
  -> 本地 responses bridge: http://127.0.0.1:4001/v1
  -> 本地 LiteLLM proxy: http://127.0.0.1:4000/v1
  -> MiMo 或公司模型上游
```

相关文件：

```text
/Users/harleyhuang/.codex/config.toml
/Users/harleyhuang/.codex/auth.json
/Users/harleyhuang/.config/litellm/config.yaml
/usr/local/bin/codex
/Users/harleyhuang/.local/bin/codex-litellm-responses-bridge.py
/Users/harleyhuang/.local/state/codex-litellm/litellm.log
/Users/harleyhuang/.local/state/codex-litellm/responses-bridge.log
```

密钥不要写进文档或命令历史。当前配置文件里已有密钥，本记录只说明结构。

## 2. 已修复的问题

### 2.1 Codex provider 原来没有默认走 LiteLLM

原先全局 `model_provider = "litellm"` 被注释，导致不指定 profile 时 Codex 仍按 OpenAI/ChatGPT provider 检查。

已改为：

```toml
model_provider = "litellm"
model = "gpt-5.5"
model_reasoning_effort = "high"
```

效果：

- 直接运行 `codex` 默认就是 `provider: litellm`。
- 直接运行 `codex exec ...` 默认使用 `gpt-5.5`，并通过 LiteLLM。

### 2.2 Codex provider 原来指向公司网关，不是本地 bridge

Codex 的 active provider 现在指向本地 responses bridge：

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

原因：

- Codex 仍然按 Responses API 调用。
- MiMo 只支持 Chat Completions。
- `codex-litellm-responses-bridge.py` 负责把 Codex 的 `/v1/responses` 转成 LiteLLM 的 `/v1/chat/completions`。

### 2.3 MiMo 上游模型名实际使用小写

LiteLLM 中用户侧 alias 使用小写：

```yaml
model_name: mimo-v2.5
```

重启 LiteLLM 后实测，小米 OpenAI-compatible 接口实际接受的小写模型名：

```yaml
model: openai/mimo-v2.5
```

本次曾尝试按小米文档中的大小写写成 `MiMo-V2.5`，重启后上游返回：

```text
Not supported model MiMo-V2.5
```

所以当前 LiteLLM 配置中 MiMo 的 `litellm_params.model` 保持小写：

```text
openai/mimo-v2.5-pro
openai/mimo-v2.5
openai/mimo-v2.5-tts-voiceclone
openai/mimo-v2.5-tts-voicedesign
openai/mimo-v2.5-tts
openai/mimo-v2-pro
openai/mimo-v2-omni
openai/mimo-v2-tts
```

### 2.4 带点号的 Codex profile 必须加 TOML 引号

TOML 中：

```toml
[profiles.gpt-5.5]
```

会被解析成嵌套表，不是名为 `gpt-5.5` 的 profile，所以会出现：

```text
Error: config profile `gpt-5.5` not found
```

已修正为：

```toml
[profiles."gpt-5.5"]
[profiles."gpt-5.4"]
[profiles."gpt-5.4-mini"]
[profiles."gpt-5.2"]
[profiles."gpt-5.3-codex"]
[profiles."gpt-5.3-codex-spark"]
[profiles."gemini-3.1-pro-preview"]
[profiles."gemini-3.1-flash-lite-preview"]
```

凡是 profile 名含 `.`，都建议写成 `[profiles."..."]`。

## 3. `/usr/local/bin/codex` 自动启动逻辑

当前 `/usr/local/bin/codex` 不是原始 Codex 二进制，而是包装脚本。

原始 Codex 二进制：

```text
/usr/local/bin/codex-bin
```

包装脚本做了这些事：

1. 设置本地 LiteLLM 地址：`http://127.0.0.1:4000`
2. 设置本地 bridge 地址：`http://127.0.0.1:4001`
3. 检查 LiteLLM 是否 ready：请求 `http://127.0.0.1:4000/v1/models`
4. 如果 LiteLLM 没启动，则执行：

```bash
litellm \
  --config /Users/harleyhuang/.config/litellm/config.yaml \
  --host 127.0.0.1 \
  --port 4000 \
  --telemetry False
```

5. 检查 bridge 是否 ready：请求 `http://127.0.0.1:4001/healthz`
6. 如果 bridge 没启动，则执行：

```bash
/Users/harleyhuang/.local/bin/codex-litellm-responses-bridge.py \
  --host 127.0.0.1 \
  --port 4001 \
  --upstream http://127.0.0.1:4000/v1 \
  --api-key "$LITELLM_API_KEY"
```

7. 最后执行真正的 Codex：

```bash
/usr/local/bin/codex-bin "$@"
```

### 3.1 直接进入 MLC_React 后运行 `codex` 会不会检查并启动 LiteLLM？

会。

在这个目录：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
codex
```

包装脚本会先检查：

```text
http://127.0.0.1:4000/v1/models
http://127.0.0.1:4001/healthz
```

如果没有启动，就会自动启动 LiteLLM 和 bridge。

不会自动启动的情况：

```text
codex --help
codex -h
codex --version
codex -V
codex help
codex completion
codex update
codex login
codex logout
```

这些命令在包装脚本里被认为不需要模型服务，会跳过自动启动。

也可以手动禁止自动启动：

```bash
CODEX_LITELLM_AUTOSTART=0 codex
```

## 4. 在 MLC_React 目录的验证结果

验证目录：

```text
/Users/harleyhuang/HGFiles/GitHub/MLC_React
```

### 4.1 Codex doctor 验证

执行：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
codex doctor --json
```

关键结果：

```text
overallStatus: ok
cwd: /Users/harleyhuang/HGFiles/GitHub/MLC_React
model: gpt-5.5
model provider: litellm
litellm API base URL: http://127.0.0.1:4001/v1 reachable
wire API: responses
```

说明：

- Codex 在该项目目录能读取配置。
- 当前默认 provider 是 `litellm`。
- Codex 能访问本地 bridge。
- bridge 后面能接到 LiteLLM。

### 4.2 默认模型验证

执行：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
codex exec -s read-only --skip-git-repo-check '只回复 OK，不要运行命令。'
```

关键输出：

```text
model: gpt-5.5
provider: litellm
OK
```

说明默认 `codex` 走 `gpt-5.5`，并通过 LiteLLM。

### 4.3 用 profile 切换到 MiMo 验证

执行：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
codex exec -p mimo-v25 -s read-only --skip-git-repo-check '只回复 OK，不要运行命令。'
```

关键输出：

```text
model: mimo-v2.5
provider: litellm
OK
```

说明 `mimo-v25` profile 可用。

### 4.4 用 `-m` 临时切换模型验证

执行：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
codex exec -m gpt-5.4 -s read-only --skip-git-repo-check '只回复 OK，不要运行命令。'
```

关键输出：

```text
model: gpt-5.4
provider: litellm
OK
```

说明 `-m` 可以直接指定 LiteLLM 中的 `model_name`。

### 4.5 交互式 Codex 验证

执行：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
codex --no-alt-screen
```

启动页显示：

```text
model: gpt-5.5 high   /model to change
directory: ~/HGFiles/GitHub/MLC_React
```

说明：

- 交互式 `codex` 默认进入 `gpt-5.5 high`。
- Codex CLI 界面提供 `/model` 入口用于切换模型。
- 自动化终端不适合完整操作全屏模型选择菜单，因此本次只确认了 `/model to change` 入口出现；已完整验证的可靠切换方式是启动时使用 `-p` 或 `-m`。

### 4.6 未启动时自动启动验证

为了验证“LiteLLM/bridge 没有启动时，运行 Codex 会自动启动”，做了受控测试：

1. 先确认原端点可用：

```text
http://127.0.0.1:4000/v1/models -> litellm-ready
http://127.0.0.1:4001/healthz   -> bridge-ready
```

2. 临时停止当前监听进程。

3. 再确认端点不可用：

```text
http://127.0.0.1:4000/v1/models -> connection refused
http://127.0.0.1:4001/healthz   -> connection refused
```

4. 在 `MLC_React` 目录运行：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
codex doctor --summary --no-color --ascii
```

5. 结果：

```text
13 ok | 1 idle | 1 notes | 0 warn | 0 fail ok
```

6. 日志中能看到 LiteLLM 和 bridge 被拉起并接受请求：

```text
LiteLLM: Uvicorn running on http://127.0.0.1:4000
LiteLLM: GET /v1/models 200 OK
bridge: listening on http://127.0.0.1:4001
bridge: GET /healthz 200
bridge: GET /v1/models 200
```

说明：

- 包装脚本的自动启动逻辑已验证。
- 在当前 Codex 自动化执行环境里，后台进程在命令结束后不一定可靠保持监听；这属于本次工具环境的进程管理差异。
- 在真实终端里直接运行 `codex`，仍会按 `/usr/local/bin/codex` 包装脚本先检查、未启动则启动。

### 4.7 修正 MiMo 小写模型名后的最终 bridge 验证

重启 LiteLLM 并使用当前配置后，直接通过 bridge 测试：

```bash
curl -sS http://127.0.0.1:4001/v1/responses \
  -H 'Authorization: Bearer sk-local-litellm' \
  -H 'Content-Type: application/json' \
  -d '{"model":"mimo-v2.5","input":"只回复 OK，不要解释。","max_output_tokens":64,"stream":false}'
```

结果：

```text
model: mimo-v2.5
output_text: OK
```

同样测试公司 GPT：

```bash
curl -sS http://127.0.0.1:4001/v1/responses \
  -H 'Authorization: Bearer sk-local-litellm' \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-5.5","input":"只回复 OK，不要解释。","max_output_tokens":64,"stream":false}'
```

结果：

```text
model: gpt-5.5
output_text: OK
```

## 5. 如何切换模型

### 5.1 默认进入 Codex

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
codex
```

当前默认：

```text
provider: litellm
model: gpt-5.5
reasoning effort: high
```

### 5.2 启动时用 profile 切换

推荐方式：用 `-p` 指定 `~/.codex/config.toml` 中的 profile。

示例：

```bash
codex -p gpt-5.5
codex -p gpt-5.4
codex -p gpt-5.4-mini
codex -p gpt-5.3-codex
codex -p mimo-v25-pro
codex -p mimo-v25
codex -p mimo-v2-pro
codex -p mimo-v2-omni
```

非交互验证可以用：

```bash
codex exec -p mimo-v25 -s read-only --skip-git-repo-check '只回复 OK，不要运行命令。'
```

### 5.3 启动时用模型名临时切换

也可以直接用 `-m` 指定 LiteLLM 的 `model_name`：

```bash
codex -m gpt-5.5
codex -m gpt-5.4
codex -m gpt-5.4-mini
codex -m mimo-v2.5
codex -m mimo-v2.5-pro
codex -m mimo-v2-pro
codex -m mimo-v2-omni
```

非交互验证：

```bash
codex exec -m gpt-5.4 -s read-only --skip-git-repo-check '只回复 OK，不要运行命令。'
```

`-m` 适合临时测试；`-p` 适合常用模型，因为 profile 里可以一起固定 provider、reasoning effort 等参数。

### 5.4 在交互式 Codex 内切换

进入：

```bash
codex
```

界面提示：

```text
/model to change
```

理论流程：

```text
1. 在 Codex 输入框输入 /model
2. 选择目标模型
3. 继续对话
```

实际建议：

- 如果只是切换到已配置模型，优先用 `codex -p <profile>` 或 `codex -m <model_name>` 启动新会话。
- 如果 `/model` 菜单没有列出自定义 LiteLLM alias，就用 `-m` 或新增 profile。
- 这点和 opencode CLI 的模型切换体验类似，但 Codex 的自定义 provider/model 展示受 Codex CLI 版本和模型目录影响；命令行 `-p`、`-m` 是最稳定的方式。

## 6. 当前可用 profile

来自 `/Users/harleyhuang/.codex/config.toml`：

```text
gpt-5.5
gpt-5.4
gpt-5.4-mini
gpt-5.2
gpt-5.3-codex
gpt-5.3-codex-spark
codex-auto-review
gpt-image-2
gemini-3.1-pro-preview
gemini-3.1-flash-lite-preview
gemini-3-pro-preview
gemini-3-flash-preview
gemini-2-5-pro
gemini-2-5-flash
gemini-2-5-flash-lite
mimo-v25-pro
mimo-v25
mimo-v2-pro
mimo-v2-omni
mimo-v25-tts
mimo-v25-tts-voiceclone
mimo-v25-tts-voicedesign
mimo-v2-tts
```

注意：

- TTS 模型通常不是 Codex 编码对话模型，不建议直接用于 Codex agent。
- Codex 编码建议优先使用 GPT/Codex/Gemini/MiMo chat 类模型。

## 7. 当前 LiteLLM model_name

来自 `/Users/harleyhuang/.config/litellm/config.yaml`：

```text
mimo-v2.5-pro
mimo-v2.5
mimo-v2.5-tts-voiceclone
mimo-v2.5-tts-voicedesign
mimo-v2.5-tts
mimo-v2-pro
mimo-v2-omni
mimo-v2-tts
gpt-5.5
gpt-5.4
gpt-5.4-mini
gpt-5.2
gpt-5.3-codex
gpt-5.3-codex-spark
codex-auto-review
gpt-image-2
gemini-3.1-pro-preview
gemini-3.1-flash-lite-preview
gemini-3-pro-preview
gemini-3-flash-preview
gemini-2.5-pro
gemini-2.5-flash
gemini-2.5-flash-lite
```

`codex -m <model_name>` 使用的是这里的 `model_name`，不是上游真实模型名。

## 8. 新增模型流程

### 8.1 先加 LiteLLM 模型

编辑：

```text
/Users/harleyhuang/.config/litellm/config.yaml
```

增加：

```yaml
  - model_name: your-model-alias
    litellm_params:
      model: openai/上游真实模型名
      api_base: https://上游地址/v1
      api_key: "你的 key"
```

建议：

- `model_name` 用小写、短横线、稳定 alias。
- `model` 用上游要求的真实模型名，大小写按上游文档。
- OpenAI-compatible 上游一般用 `openai/<model>`。

### 8.2 再加 Codex profile

编辑：

```text
/Users/harleyhuang/.codex/config.toml
```

增加：

```toml
[profiles."your-model-alias"]
model_provider = "litellm"
model = "your-model-alias"
model_reasoning_effort = "high"
```

如果 profile 名不含点号，也可以不加引号；为了统一，建议都加引号。

### 8.3 验证

```bash
codex doctor --summary --no-color --ascii
codex exec -p your-model-alias -s read-only --skip-git-repo-check '只回复 OK，不要运行命令。'
```

## 9. 常用健康检查命令

检查 LiteLLM：

```bash
curl -sS http://127.0.0.1:4000/v1/models \
  -H 'Authorization: Bearer sk-local-litellm'
```

检查 bridge：

```bash
curl -sS http://127.0.0.1:4001/healthz
```

通过 bridge 测试 MiMo：

```bash
curl -sS http://127.0.0.1:4001/v1/responses \
  -H 'Authorization: Bearer sk-local-litellm' \
  -H 'Content-Type: application/json' \
  -d '{"model":"mimo-v2.5","input":"只回复 OK，不要解释。","max_output_tokens":64,"stream":false}'
```

通过 bridge 测试公司 GPT：

```bash
curl -sS http://127.0.0.1:4001/v1/responses \
  -H 'Authorization: Bearer sk-local-litellm' \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-5.5","input":"只回复 OK，不要解释。","max_output_tokens":64,"stream":false}'
```

检查 Codex 当前 provider：

```bash
codex doctor --json
```

重点看：

```text
overallStatus
model provider
litellm API base URL
wire API
```

## 10. 日志位置

LiteLLM 日志：

```text
/Users/harleyhuang/.local/state/codex-litellm/litellm.log
```

Responses bridge 日志：

```text
/Users/harleyhuang/.local/state/codex-litellm/responses-bridge.log
```

Codex 自身状态和日志：

```text
/Users/harleyhuang/.codex/log
/Users/harleyhuang/.codex/logs_2.sqlite
/Users/harleyhuang/.codex/history.jsonl
```

## 11. 常见问题

### 11.1 `profile not found`

检查 profile 名是否含点号。

错误写法：

```toml
[profiles.gpt-5.5]
```

正确写法：

```toml
[profiles."gpt-5.5"]
```

### 11.2 Codex 仍然走 OpenAI/ChatGPT，不走 LiteLLM

检查：

```toml
model_provider = "litellm"
```

必须在全局配置中启用，不能注释掉。

再检查：

```toml
[model_providers.litellm]
base_url = "http://127.0.0.1:4001/v1"
wire_api = "responses"
```

### 11.3 MiMo 返回 400/404 或模型不存在

检查 LiteLLM 中 MiMo 的上游模型名。

用户侧 alias 可以是：

```yaml
model_name: mimo-v2.5
```

当前实测可用写法是小写：

```yaml
model: openai/mimo-v2.5
```

如果写成 `openai/MiMo-V2.5`，重启 LiteLLM 后实测会上游报错：

```text
Not supported model MiMo-V2.5
```

### 11.4 请求成功但 output 为空

本次测试发现，如果 `max_output_tokens` 太小，模型可能只生成 `reasoning_content`，普通 `content` 为空。

解决：

```text
把 max_output_tokens 从 8 提高到 64 或更高
```

### 11.5 `operation not permitted` 或本地端口绑定失败

在受限沙箱中启动本地服务可能失败，例如绑定 `127.0.0.1:4000` 或 `4001` 被拒绝。

在真实终端直接运行：

```bash
codex doctor --summary --no-color --ascii
```

或者直接：

```bash
codex
```

包装脚本会自动启动所需服务。

### 11.6 如何确认是包装脚本而不是原始 Codex

```bash
head -40 /usr/local/bin/codex
ls -la /usr/local/bin/codex-bin
```

当前结构：

```text
/usr/local/bin/codex      包装脚本，负责自动启动 LiteLLM 和 bridge
/usr/local/bin/codex-bin  原始 Codex 二进制
```

## 12. 推荐日常用法

进入项目：

```bash
cd /Users/harleyhuang/HGFiles/GitHub/MLC_React
```

默认 GPT：

```bash
codex
```

指定 MiMo：

```bash
codex -p mimo-v25
```

指定公司 GPT：

```bash
codex -p gpt-5.5
codex -p gpt-5.4
```

临时测试任意 LiteLLM alias：

```bash
codex -m mimo-v2.5
codex -m gpt-5.4
```

验证某个模型是否能被 Codex 调用：

```bash
codex exec -p mimo-v25 -s read-only --skip-git-repo-check '只回复 OK，不要运行命令。'
```

结论：

```text
在 /Users/harleyhuang/HGFiles/GitHub/MLC_React 中直接运行 codex，会默认检查 LiteLLM/bridge；
如果没有启动，会自动启动；
该自动启动逻辑已经通过停止端点后运行 codex doctor 验证；
默认模型是 gpt-5.5；
已验证可以通过 -p profile 和 -m model_name 切换到不同 LiteLLM 模型；
交互式界面也显示 /model to change，但最稳定的切换方式仍是启动时使用 -p 或 -m。
```

***
<br/><br/><br/>
> <h2 id="">最终配置</h2>

`Codex cli`配置**`config.toml`**

```toml
# ======================
# 全局默认模型
# ======================
model_provider = "litellm"
model = "gpt-5.5"
model_reasoning_effort = "high"
# ======================
# LiteLLM / 小米 MiMo Provider
# ======================
[model_providers.litellm]
name = "LiteLLM Local Proxy"
base_url = "http://127.0.0.1:4001/v1"
#base_url = "https://open-bigmodel-dev.imilab.com:7799/v1"
env_key = "LITELLM_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 5
stream_idle_timeout_ms = 300000
#brew upgrade --cask codex

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

[profiles.gpt-image-2]
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


# ======================
# 项目信任配置
# ======================
[projects."/Users/harleyhuang"] # [xxx] 必须写在一行，不能换行
trust_level = "trusted"

[projects."/Users/harleyhuang/Desktop"]
trust_level = "trusted"

[projects."/Users/harleyhuang/HGFiles/GitHub/GoProject/src/MLC_GO"]
trust_level = "trusted"

[projects."/Users/harleyhuang/HGFiles/GitHub/MLC_React"]
trust_level = "trusted"

[projects."/Users/harleyhuang/HGFiles/GitHub/AITools"]
trust_level = "trusted"

[notice]
hide_rate_limit_model_nudge = true

# ======================
# 升级提醒
# ======================
[notice.model_migrations]
"gpt-5.3-codex" = "gpt-5.4"

[tui.model_availability_nux]
"gpt-5.5" = 4

[features]
apps = false
```

<br/>
***

**`liteLLM`**配置`config.yaml`

```yaml
model_list:
  - model_name: mimo-v2.5-pro
    litellm_params:
      model: openai/mimo-v2.5-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "tp-c4pfix000xxx"

  - model_name: mimo-v2.5
    litellm_params:
      model: openai/mimo-v2.5
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "tp-c4pfix000xxx"

  - model_name: mimo-v2.5-tts-voiceclone
    litellm_params:
      model: openai/mimo-v2.5-tts-voiceclone
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "tp-c4pfix000xxx"

  - model_name: mimo-v2.5-tts-voicedesign
    litellm_params:
      model: openai/mimo-v2.5-tts-voicedesign
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "tp-c4pfix000xxx"

  - model_name: mimo-v2.5-tts
    litellm_params:
      model: openai/mimo-v2.5-tts
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "tp-c4pfix000xxx"

  - model_name: mimo-v2-pro
    litellm_params:
      model: openai/mimo-v2-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "tp-c4pfix000xxx"

  - model_name: mimo-v2-omni
    litellm_params:
      model: openai/mimo-v2-omni
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "tp-c4pfix000xxx"

  - model_name: mimo-v2-tts
    litellm_params:
      model: openai/mimo-v2-tts
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      api_key: "tp-c4pfix000xxx"

  - model_name: gpt-5.5
    litellm_params:
      model: openai/gpt-5.5
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gpt-5.4
    litellm_params:
      model: openai/gpt-5.4
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gpt-5.4-mini
    litellm_params:
      model: openai/gpt-5.4-mini
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gpt-5.2
    litellm_params:
      model: openai/gpt-5.2
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gpt-5.3-codex
    litellm_params:
      model: openai/gpt-5.3-codex
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gpt-5.3-codex-spark
    litellm_params:
      model: openai/gpt-5.3-codex-spark
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: codex-auto-review
    litellm_params:
      model: openai/codex-auto-review
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gpt-image-2
    litellm_params:
      model: openai/gpt-image-2
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gemini-3.1-pro-preview
    litellm_params:
      model: openai/gemini-3.1-pro-preview
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gemini-3.1-flash-lite-preview
    litellm_params:
      model: openai/gemini-3.1-flash-lite-preview
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gemini-3-pro-preview
    litellm_params:
      model: openai/gemini-3-pro-preview
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gemini-3-flash-preview
    litellm_params:
      model: openai/gemini-3-flash-preview
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gemini-2.5-pro
    litellm_params:
      model: openai/gemini-2.5-pro
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gemini-2.5-flash
    litellm_params:
      model: openai/gemini-2.5-flash
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

  - model_name: gemini-2.5-flash-lite
    litellm_params:
      model: openai/gemini-2.5-flash-lite
      api_base: https://open-bigmodel-dev.imilab.com:7799/v1
      api_key: "sk-xxxx"

litellm_settings:
  drop_params: true
  set_verbose: false

general_settings:
  proxy_batch_write_at: 60
```

