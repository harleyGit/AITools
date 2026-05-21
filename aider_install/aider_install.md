# Aider + LiteLLM 安装与配置记录

本文记录本机安装 Aider CLI、LiteLLM CLI，以及将 Aider 通过本地 LiteLLM Proxy 使用小米 MiMo 模型的配置流程。

## 当前环境

- macOS: 10.15.7
- Python: 3.9.4 (`python3` 默认版本)
- Python 3.10+: 已安装 `/usr/local/bin/python3.14`，版本为 3.14.5
- Aider: 0.82.3
- LiteLLM: 1.83.7，pipx venv 使用 Python 3.14.5
- pipx: 1.11.1

## Homebrew 安装尝试与清理

最初尝试使用 Homebrew 安装：

```bash
brew install aider
```

结果：

- 第一次下载 PyPI 依赖时遇到 `LibreSSL SSL_connect: SSL_ERROR_SYSCALL`
- 重试后进入 `gcc 15.2.0` 源码编译
- 因 macOS 10.15 / Command Line Tools 版本较旧，Homebrew 不是 Tier 1 支持配置，`gcc` 编译失败
- `aider` 未安装成功

随后清理残留：

```bash
brew uninstall certifi
brew cleanup -s --prune=all aider gcc certifi python@3.12 jpeg-turbo libomp openblas
```

清理释放约 `557.5MB`。同时删除了残留的 Homebrew 构建日志和下载索引缓存。原本已有的 `nasm 2.15.05` 保留未动。

## 使用 pipx 安装 Aider

安装 pipx：

```bash
python3 -m pip install --user pipx
/Users/harleyhuang/Library/Python/3.9/bin/pipx ensurepath
```

安装 Aider：

```bash
/Users/harleyhuang/Library/Python/3.9/bin/pipx install aider-chat
```

验证：

```bash
/Users/harleyhuang/.local/bin/aider --version
```

输出：

```text
aider 0.82.3
```

## 使用 pipx 安装 LiteLLM

安装 LiteLLM：

```bash
/Users/harleyhuang/Library/Python/3.9/bin/pipx install litellm
```

安装后命令：

```bash
/Users/harleyhuang/.local/bin/litellm
/Users/harleyhuang/.local/bin/litellm-proxy
```

基础验证：

```bash
/Users/harleyhuang/.local/bin/litellm --version
/Users/harleyhuang/.local/bin/litellm-proxy --version
```

由于 `litellm[proxy]` 的完整 extras 中 `pyroscope-io` 在当前环境构建失败，已跳过该可选依赖，并补装主要 proxy 运行依赖：

```bash
/Users/harleyhuang/Library/Python/3.9/bin/pipx inject litellm websockets
/Users/harleyhuang/Library/Python/3.9/bin/pipx inject litellm httpx[socks]
/Users/harleyhuang/Library/Python/3.9/bin/pipx inject litellm \
  gunicorn==23.0.0 \
  uvicorn==0.33.0 \
  uvloop==0.21.0 \
  fastapi==0.124.4 \
  backoff==2.2.1 \
  pyyaml==6.0.3 \
  rq==2.7.0 \
  orjson==3.10.15 \
  apscheduler==3.11.2 \
  fastapi-sso==0.16.0 \
  pyjwt==2.11.0 \
  python-multipart==0.0.20 \
  cryptography==46.0.7 \
  pynacl==1.6.2 \
  boto3==1.42.59 \
  azure-identity==1.25.2 \
  azure-storage-blob==12.28.0 \
  litellm-proxy-extras==0.4.66 \
  litellm-enterprise==0.1.37 \
  restrictedpython==8.1 \
  rich==13.9.4 \
  soundfile==0.12.1
```

说明：LiteLLM 最初使用 Python 3.9.4，`litellm --version` 会在日志中出现 `javelin`、`aim` guardrail 的 `TypeError`。这是部分 guardrail 插件使用了 Python 3.10+ 类型语法导致的兼容警告。2026-05-21 已将 LiteLLM 的 pipx venv 迁移到 Python 3.14.5，迁移后该 guardrail 兼容警告不再出现。

## 2026-05-21 Python 3.10+ 与 LiteLLM pipx 迁移记录

本机系统：

```bash
sw_vers
```

输出：

```text
ProductName:    Mac OS X
ProductVersion: 10.15.7
BuildVersion:   19H1217
```

结论：

- macOS 10.15.7 可以运行 Python 3.10+。
- 本机已经安装 `/usr/local/bin/python3.14`，版本为 `Python 3.14.5`。
- `python3` 默认仍指向 Homebrew 的 Python 3.9.4；没有全局切换默认 `python3`，避免影响其他工具。

当前 Python 检查：

```bash
/usr/local/bin/python3.14 --version
/Users/harleyhuang/.local/pipx/venvs/litellm/bin/python --version
```

输出：

```text
Python 3.14.5
Python 3.14.5
```

迁移命令：

```bash
/Users/harleyhuang/Library/Python/3.9/bin/pipx reinstall litellm \
  --python /usr/local/bin/python3.14
```

迁移过程中的兼容处理：

- 原先注入依赖包含固定版本 `orjson==3.10.15`。
- 该版本不支持 Python 3.14，构建时报 `PyO3's maximum supported version (3.13)`。
- 已改为注入兼容 Python 3.14 的当前 `orjson` 版本，并补齐 LiteLLM proxy 依赖。

补齐依赖：

```bash
/Users/harleyhuang/Library/Python/3.9/bin/pipx inject litellm \
  websockets \
  orjson \
  python-multipart \
  pyjwt \
  pynacl \
  restrictedpython \
  rq \
  soundfile \
  uvicorn \
  uvloop
```

迁移后状态：

```bash
/Users/harleyhuang/Library/Python/3.9/bin/pipx list
```

关键信息：

```text
package aider-chat 0.82.3, installed using Python 3.9.4
package litellm 1.83.7, installed using Python 3.14.5
```

说明：

- Aider 继续保留在 Python 3.9.4 的 pipx venv 中，避免覆盖 `/Users/harleyhuang/.local/bin/aider` 这个自定义 wrapper。
- LiteLLM 已迁移到 Python 3.14.5，解决了 Python 3.9 下 guardrail 插件导入报错的问题。
- 当前没有把 `/usr/local/bin/python3` 默认指向 Python 3.14；如需全局切换，需要单独评估 Homebrew 旧环境兼容性。

迁移后验证：

```bash
/Users/harleyhuang/.local/bin/litellm --version
```

输出：

```text
LiteLLM: Current Version = 1.83.7
```

启动 LiteLLM：

```bash
/Users/harleyhuang/.local/bin/litellm \
  --config /Users/harleyhuang/.config/litellm/config.yaml \
  --host 127.0.0.1 \
  --port 4000
```

确认 4000 端口进程使用 Python 3.14：

```bash
lsof -nP -iTCP:4000 -sTCP:LISTEN
ps -p <PID_FROM_LSOF> -o pid,command
```

关键信息：

```text
/usr/local/Cellar/python@3.14/3.14.5/.../Python /Users/harleyhuang/.local/bin/litellm ...
```

验证 Aider：

```bash
/Users/harleyhuang/.local/bin/aider \
  --config /Users/harleyhuang/.aider/config.yaml \
  --message '只回答OK，不要编辑文件'
```

输出关键信息：

```text
Aider v0.82.3
Main model: openai/mimo-v2.5-pro with diff edit format
Weak model: openai/mimo-v2.5
ANSWER
OK
```

## LiteLLM 配置

配置文件：

```text
/Users/harleyhuang/.config/litellm/config.yaml
```

当前配置的小米 MiMo 模型：

- `mimo-v2.5-pro` -> `mimo-v2.5-pro`
- `mimo-v2.5` -> `mimo-v2.5`
- `mimo-v2-pro` -> `mimo-v2-pro`
- `mimo-v2-omni` -> `mimo-v2-omni`

Base URL：

```text
https://token-plan-cn.xiaomimimo.com/v1
```

LiteLLM 配置直接在 `config.yaml` 中填写小米 API key：

```yaml
api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"
```

把 `PASTE_YOUR_XIAOMI_API_KEY_HERE` 替换成你的真实小米 API key。当前不再依赖任何环境变量。

## Aider 配置

配置文件：

```text
/Users/harleyhuang/.aider/config.yaml
```

当前默认模型：

```yaml
model: openai/mimo-v2.5-pro
weak-model: openai/mimo-v2.5
editor-model: openai/mimo-v2.5-pro
openai-api-base: http://127.0.0.1:4000/v1
openai-api-key: sk-local-litellm
```

这里的 `openai-api-key` 是给本地 LiteLLM Proxy 的占位 key。LiteLLM 真正调用小米接口时使用的是 `/Users/harleyhuang/.config/litellm/config.yaml` 中直接填写的 `api_key`。

可用别名：

```yaml
mimo-pro -> openai/mimo-v2.5-pro
mimo -> openai/mimo-v2.5
mimo-v2-pro -> openai/mimo-v2-pro
mimo-omni -> openai/mimo-v2-omni
```

<br/><br/><br/>

***
<br/>

> <h1 id=""></h1>

# 自动启动 LiteLLM 的 Aider wrapper

已将：

```text
/Users/harleyhuang/.local/bin/aider
```

替换为 wrapper 脚本。真实 pipx Aider 入口保留在：

```text
/Users/harleyhuang/.local/pipx/venvs/aider-chat/bin/aider
```

备份软链接保留为：

```text
/Users/harleyhuang/.local/bin/aider-pipx
```

wrapper 行为：

1. 检查 `http://127.0.0.1:4000/v1/models`
2. 如果 LiteLLM 未启动，则后台启动：

   ```bash
   /Users/harleyhuang/.local/bin/litellm \
     --config /Users/harleyhuang/.config/litellm/config.yaml \
     --host 127.0.0.1 \
     --port 4000 \
     --telemetry False
   ```

3. 等待 LiteLLM ready
4. 调用真实 Aider，并自动带上：

   ```bash
   --config /Users/harleyhuang/.aider/config.yaml
   ```

日志文件：

```text
/Users/harleyhuang/.local/state/litellm/litellm.log
```

PID 文件：

```text
/Users/harleyhuang/.local/state/litellm/litellm.pid
```

***
<br/>

## 对上述自启动说明

是的。

你现在这套东西，本质上已经实现了：

```text
启动 aider
   ↓
自动检测 LiteLLM 是否运行
   ↓
没运行就自动启动 LiteLLM
   ↓
再启动真正的 aider
```

也就是：

> “Aider 自动托管 LiteLLM”

这是很多人本地多模型开发时会做的方案。

你看到的内容，本质是：

```text
aider 命令被“劫持”成了一个启动器(wrapper)
```

它不再直接是真正的 aider。

而是：

```text
你输入 aider
     ↓
wrapper shell 脚本先执行
     ↓
wrapper 再去调用真正 aider
```

下面我拆开解释。

---

# 1. 你现在的文件结构

你看到：

```text
/Users/harleyhuang/.local/bin/aider
```

这个：

```text
现在已经不是原始 aider
```

而是：

```text
wrapper 启动脚本
```

---

真正 pipx 安装的 aider 在：

```text
/Users/harleyhuang/.local/pipx/venvs/aider-chat/bin/aider
```

这个才是真实程序。

---

然后：

```text
/Users/harleyhuang/.local/bin/aider-pipx
```

是原来 aider 的备份软链接。

意思：

```text
aider-pipx = 原始 aider
aider       = wrapper
```

---

# 2. wrapper 是什么？

wrapper 就是：

```text
套壳启动器
```

相当于：

```bash
#!/bin/bash

先做一些事

再启动真正程序
```

你的 wrapper 做了三件事：

---

# 3. 第一步：检查 LiteLLM 是否已启动

它检查：

```text
http://127.0.0.1:4000/v1/models
```

这是：

```text
LiteLLM OpenAI API 地址
```

因为：

LiteLLM 会模拟：

```text
OpenAI API Server
```

所以：

```text
/v1/models
```

就像 OpenAI：

```text
https://api.openai.com/v1/models
```

一样。

---

wrapper 会：

```bash
curl http://127.0.0.1:4000/v1/models
```

如果：

* 能访问
* 返回模型列表

说明：

```text
LiteLLM 已运行
```

---

# 4. 第二步：没启动则自动启动 LiteLLM

如果访问失败：

wrapper 就执行：

```bash
/Users/harleyhuang/.local/bin/litellm \
  --config /Users/harleyhuang/.config/litellm/config.yaml \
  --host 127.0.0.1 \
  --port 4000 \
  --telemetry False
```

意思：

---

## litellm

启动 LiteLLM Server。

---

## --config

指定配置文件：

```text
~/.config/litellm/config.yaml
```

里面定义：

* 模型
* API key
* provider
* 路由

例如：

```yaml
model_list:
  - model_name: deepseek
    litellm_params:
      model: deepseek/deepseek-chat
      api_key: sk-xxx
```

---

## --host 127.0.0.1

只允许本机访问。

即：

```text
localhost
```

安全些。

---

## --port 4000

LiteLLM 开在：

```text
http://127.0.0.1:4000
```

---

## --telemetry False

关闭匿名遥测。

防止上传统计信息。

---

# 5. 第三步：等待 LiteLLM Ready

因为：

LiteLLM 启动需要几秒。

所以 wrapper 会：

```bash
循环检查 /v1/models
```

直到：

```text
HTTP 200
```

才继续。

否则：

```text
Aider 会先启动
但 API 还没 ready
```

就会报错：

```text
Connection refused
```

---

# 6. 第四步：启动真正 aider

最后：

wrapper 调：

```bash
/Users/harleyhuang/.local/pipx/venvs/aider-chat/bin/aider
```

并自动带：

```bash
--config ~/.aider/config.yaml
```

意思：

```text
以后你不用手动写：

aider --config xxx
```

wrapper 自动帮你加了。

---

# 7. 现在整体工作流

你现在：

只需要：

```bash
aider
```

背后实际发生：

```text
aider(wrapper)
    ↓
检查 LiteLLM
    ↓
自动启动 LiteLLM
    ↓
等待 API ready
    ↓
启动真正 aider
```

---

# 8. 为什么这是很好的方案

因为以前：

你每次要：

---

## 手动开 LiteLLM

```bash
litellm --config ...
```

开一个 terminal。

---

## 再开 aider

```bash
aider
```

很烦。

---

现在：

```text
只需要 aider
```

即可。

这就是：

```text
自动依赖启动
```

---

# 9. 你现在的架构

你现在实际上已经是：

```text
          aider(wrapper)
                 ↓
            LiteLLM
                 ↓
    DeepSeek / MiniMax / Qwen
```

这是很合理的。

---

# 10. 你还缺什么？

你现在其实已经接近完整生产方案了。

下一步通常会做：

---

# 11. 给 LiteLLM 配多个模型

例如：

```yaml
model_list:
  - model_name: deepseek
    litellm_params:
      model: deepseek/deepseek-chat
      api_key: os.environ/DEEPSEEK_API_KEY

  - model_name: minimax
    litellm_params:
      model: openai/MiniMax-M1-80k
      api_key: os.environ/MINIMAX_API_KEY

  - model_name: qwen
    litellm_params:
      model: ollama/qwen3-coder
      api_base: http://127.0.0.1:11434
```

然后：

```bash
aider --model openai/deepseek
```

或者：

```bash
aider --model openai/minimax
```

---

# 12. 为什么 aider 里经常看到 openai/xxx

因为：

LiteLLM 会：

```text
把所有 provider 统一伪装成 OpenAI
```

所以：

Aider 认为：

```text
它永远在访问 OpenAI
```

实际上：

后面可能是：

* DeepSeek
* Claude
* Gemini
* Ollama

---

# 13. 这个 wrapper 有没有风险？

有两个常见问题。

---

## 问题1：LiteLLM 崩了

wrapper 只能：

```text
启动
```

不能：

```text
守护
```

所以：

如果 LiteLLM 运行中崩了。

你得重新：

```bash
aider
```

它才会重启。

---

## 问题2：后台进程残留

有时：

```text
LiteLLM 已经启动多个
```

导致：

```text
4000 端口占用
```

所以建议：

定期：

```bash
lsof -i :4000
```

查看。

---

# 14. 更高级方案（以后）

高级用户会：

---

## 用 launchd(macOS)

真正后台守护：

```text
LiteLLM 永久后台运行
```

系统启动自动拉起。

---

## 或 Docker

```bash
docker compose up -d
```

长期运行 LiteLLM。

---

# 15. 你现在这套适合吗？

非常适合。

尤其你现在：

* Mac
* 多模型
* aider
* DeepSeek
* MiniMax
* 本地模型

这是很舒服的开发流。

---

# 16. 最后一句总结

你现在实际上已经完成了：

```text
Aider 一键启动 AI 开发环境
```

即：

```text
输入 aider
=
自动启动 LiteLLM
+
自动连接模型
+
自动加载 aider 配置
```

这是正确且成熟的做法。


***
<br/><br/>
## 使用方法

新开一个终端，让 `pipx ensurepath` 写入的 PATH 生效。

第一次使用前，先编辑 LiteLLM 配置，把 `PASTE_YOUR_XIAOMI_API_KEY_HERE` 替换成真实小米 API key：

```bash
vi ~/.config/litellm/config.yaml
```

启动默认模型：

```bash
aider
```

切换到小米 MiMo-V2.5：

```bash
aider --model mimo
```

切换到小米 MiMo-V2.5-Pro：

```bash
aider --model mimo-pro
```

切换到小米 MiMo-V2-Pro：

```bash
aider --model mimo-v2-pro
```

切换到小米 MiMo-V2-Omni：

```bash
aider --model mimo-omni
```

也可以直接使用 LiteLLM/OpenAI 风格模型名：

```bash
aider --model openai/mimo-v2.5-pro
aider --model openai/mimo-v2.5
aider --model openai/mimo-v2-pro
aider --model openai/mimo-v2-omni
```

查看 LiteLLM 模型列表：

```bash
curl http://127.0.0.1:4000/v1/models
```

停止后台 LiteLLM：

```bash
kill "$(cat ~/.local/state/litellm/litellm.pid)"
```

下次执行 `aider` 时会自动重新启动。

## 验证结果

已验证：

```bash
/Users/harleyhuang/.local/bin/aider --version
```

输出：

```text
aider 0.82.3
```

已验证 Aider 可以加载配置：

```bash
/Users/harleyhuang/.local/bin/aider --exit --no-git
```

输出关键信息：

```text
Aider v0.82.3
Main model: openai/mimo-v2.5-pro with diff edit format
Weak model: openai/mimo-v2.5
Git repo: none
Repo-map: disabled
```

已验证 LiteLLM 可以读取配置并加载模型，日志中显示：

```text
LiteLLM: Proxy initialized with Config, Set models:
    mimo-v2.5-pro
    mimo-v2.5
    mimo-v2-pro
    mimo-v2-omni
```

当前配置文件中仍是占位 API key，因此没有执行真实小米模型调用。把 `/Users/harleyhuang/.config/litellm/config.yaml` 里的 `PASTE_YOUR_XIAOMI_API_KEY_HERE` 替换为真实 key 后，再执行 `aider` 即可进行实际调用验证。

## 2026-05-21 Aider + LiteLLM 模型名修复记录

故障现象：

```text
litellm.BadRequestError: OpenAIException - litellm.BadRequestError: OpenAIException - Param Incorrect.
Received Model Group=mimo-v2.5-pro
Available Model Group Fallbacks=None
```

根因：

- Aider 通过本地 LiteLLM Proxy 请求 `mimo-v2.5-pro`。
- LiteLLM Proxy 的 model group `mimo-v2.5-pro` 本身存在，但 `litellm_params.model` 转发到小米 MiMo 上游时写成了 `openai/MiMo-V2.5-Pro`。
- 小米 MiMo `/v1/models` 返回的真实模型 ID 是小写：`mimo-v2.5-pro`、`mimo-v2.5`、`mimo-v2-pro`、`mimo-v2-omni`。
- 上游对模型 ID 大小写敏感，因此返回 `Not supported model MiMo-V2.5-Pro`。

修复：

```yaml
model_list:
  - model_name: mimo-v2.5-pro
    litellm_params:
      model: openai/mimo-v2.5-pro

  - model_name: mimo-v2.5
    litellm_params:
      model: openai/mimo-v2.5

  - model_name: mimo-v2-pro
    litellm_params:
      model: openai/mimo-v2-pro

  - model_name: mimo-v2-omni
    litellm_params:
      model: openai/mimo-v2-omni
```

验证：

```bash
curl http://127.0.0.1:4000/v1/models

curl http://127.0.0.1:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-local-litellm' \
  -d '{"model":"mimo-v2.5-pro","messages":[{"role":"user","content":"只回答 OK"}],"max_tokens":10}'

/Users/harleyhuang/.local/bin/aider \
  --config /Users/harleyhuang/.aider/config.yaml \
  --message '只回答OK，不要编辑文件'
```

验证结果：

- LiteLLM `/v1/models` 能列出 `mimo-v2.5-pro` 等模型。
- LiteLLM `/v1/chat/completions` 返回 `200 OK`。
- Aider 能正常通过 `openai/mimo-v2.5-pro` 调用本地 LiteLLM Proxy。

注意：

- Aider 配置中继续使用 `openai/mimo-v2.5-pro` 是正确的；这是 Aider/LiteLLM 客户端侧 provider 写法。
- LiteLLM `config.yaml` 里的 `model_name` 是本地代理暴露的模型组名。
- LiteLLM `litellm_params.model` 里的 `openai/mimo-v2.5-pro` 会转发为小米上游实际支持的模型 ID `mimo-v2.5-pro`，必须保持小写。

## 后续添加其他厂商模型

新增模型时，在 LiteLLM 配置中增加一段：

```yaml
- model_name: your-model-alias
  litellm_params:
    model: openai/provider-model-name
    api_base: https://provider.example.com/v1
    api_key: "provider-api-key"
```

然后在 Aider 中使用：

```bash
aider --model openai/your-model-alias
```

如果想使用短别名，在 `/Users/harleyhuang/.aider/config.yaml` 的 `alias` 中新增：

```yaml
alias:
  - short-name:openai/your-model-alias
```

然后运行：

```bash
aider --model short-name
```

## 当前 LiteLLM config.yaml 完整内容

路径：

```text
/Users/harleyhuang/.config/litellm/config.yaml
```

内容：

```yaml
model_list:
  - model_name: mimo-v2.5-pro
    litellm_params:
      model: openai/mimo-v2.5-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      // api_key: os.environ/XIAOMI_API_KEY， 这个读取的环境变量中的小米apiKey
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2.5
    litellm_params:
      model: openai/mimo-v2.5
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      // api_key: os.environ/XIAOMI_API_KEY， 这个读取的环境变量中的小米apiKey
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2-pro
    litellm_params:
      model: openai/mimo-v2-pro
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      // api_key: os.environ/XIAOMI_API_KEY， 这个读取的环境变量中的小米apiKey
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

  - model_name: mimo-v2-omni
    litellm_params:
      model: openai/mimo-v2-omni
      api_base: https://token-plan-cn.xiaomimimo.com/v1
      // api_key: os.environ/XIAOMI_API_KEY， 这个读取的环境变量中的小米apiKey
      api_key: "PASTE_YOUR_XIAOMI_API_KEY_HERE"

litellm_settings:
  drop_params: true
  set_verbose: false

general_settings:
  proxy_batch_write_at: 60
```

## 当前 Aider config.yaml 完整内容

路径：

```text
/Users/harleyhuang/.aider/config.yaml
```

内容：

```yaml
model: openai/mimo-v2.5-pro
weak-model: openai/mimo-v2.5
editor-model: openai/mimo-v2.5-pro

openai-api-base: http://127.0.0.1:4000/v1
openai-api-key: sk-local-litellm

show-model-warnings: false
check-model-accepts-settings: false
edit-format: diff
auto-commits: true
dirty-commits: true
check-update: false
show-release-notes: false

alias:
  - mimo-pro:openai/mimo-v2.5-pro
  - mimo:openai/mimo-v2.5
  - mimo-v2-pro:openai/mimo-v2-pro
  - mimo-omni:openai/mimo-v2-omni
```
