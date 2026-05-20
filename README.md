# AI技能说明
- [PPT技能codex-primary-runtime](#PPT技能codex-primary-runtime)
- [开发通用技能dev_general_skill](#开发通用技能dev_general_skill)
- [视频、图片ffmpeg-tools](#视频、图片ffmpeg-tools)
- [笔记整理技能study-note-cleanup](#笔记整理技能study-note-cleanup)  
  - [StudyNotes 自然语言触发配置](#StudyNotes自然语言触发配置)
	- [触发方式](#触发方式)
	- [配置要点](#配置要点)
- **资料**
	- [张雪峰Skill](https://github.com/alchaincyf/zhangxuefeng-skill?tab=readme-ov-file#安装)
	- [Pus-skill](https://pua-skill.pages.dev/#install)


<br/><br/><br/>

***
<br/>

> <h1 id="PPT技能codex-primary-runtime">PPT技能codex-primary-runtime</h1>

**`codex-primary-runtime`** 是 Codex 自带的全局运行时技能包，不是你这个项目里的代码。

它当前包含两类内置 skill：
- slides
	- skill 名称：PowerPoint
	- 用途：创建、编辑、渲染、验证、导出 .pptx 演示文稿。
	- 依赖 Codex 自带的 @oai/artifact-tool。
- spreadsheets
	- skill 名称：Excel
	- 用途：创建、修改、分析、可视化 .xlsx、.xls、.csv、.tsv 表格文件。
	- 同样依赖 Codex 自带的 @oai/artifact-tool。

**目录结构大致是：**

```sh
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/codex-primary-runtime/
├── slides/
│   ├── SKILL.md
│   ├── agents/openai.yaml
│   ├── scripts/
│   ├── templates/
│   └── assets/
└── spreadsheets/
    ├── SKILL.md
    ├── agents/openai.yaml
    ├── templates/
    ├── assets/
    └── style_guidelines.md
```
它的作用是让 Codex 在用户要求做 PPT 或 Excel 文件时，自动加载对应专业 workflow 和工具约束。
- **结论：**
	- 不是你手写的业务 skill。
	- 不是 MLC_React 项目的一部分。
	- 不建议删除。
	
	
<br/><br/><br/>

***
<br/>

> <h1 id="开发通用技能dev_general_skill">开发通用技能dev_general_skill</h1>

## 功能：
- 代码提交
- 代码输出


***
<br/>

## 使用方式：
- 提交代码：直接对AI说**`提交代码`** 或者 **使用`dev_general_skill`**提交代码
- 输出配置，在工程中加入如下：

```sh
最终输出规范：
- 遵循 `/Users/ganghuang/HGFiles/GitHub/AITools/Skills/dev_general_skill/SKILL.md` 中的 `Final Output Convention`
- 如 skill 未自动加载，也必须按该规范输出
```

但是最好不要这样干，因为**该技能**还包括其他技能，若是通过这个可能会把其他文案都加载进来，增加token消耗。


<br/><br/><br/>

***
<br/>

> <h1 id="视频、图片ffmpeg-tools">视频、图片ffmpeg-tools</h1>

## 功能：
- 多张图片拼接；
- 视频下载；

## 使用：
### **AI：**

- `ffmpeg-tools 下载这个视频到桌面：<url>`

<br/>

### 脚本：
- **增加参数：**

```sh
--cookies-from-browser <browser>
--cookies <path>
```

- **视频下载：**

**视频链接：**

```sh
bash ~/.codex/skills/ffmpeg-tools/scripts/download-video.sh \
    --url "https://example.com/video.mp4" \
    --output ~/Desktop/video.mp4
```

<br/>

**网页中含有视频下载：**

B站视频链接【点击列表中某个视频，然后详情在浏览器中播放的url】：`https://www.bilibili.com/video/BV1ED5u6cEXG/?t=9&spm_id_from=333.1007.tianma.5-3-17.click&vd_source=a7fe275f0ee54c4d2f691a823f8876b8‌`

```sh
bash "/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh" \
  --url "https://www.bilibili.com/video/BV1ED5u6cEXG/" \
  --output "$HOME/Desktop/BV1ED5u6cEXG.mp4"
```

<br/>

**在 Chrome 登录了 B 站，建议这样：**

```sh
bash "/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh" \
  --url "https://www.bilibili.com/video/BV1ED5u6cEXG/" \
  --output "$HOME/Desktop/BV1ED5u6cEXG.mp4" \
  --cookies-from-browser chrome
```

<br/>

**如果你用 Safari 登录：**

- 视频链接是从Safari登录并拷贝的：`https://www.bilibili.com/video/BV1ED5u6cEXG/?t=9&spm_id_from=333.1007.tianma.5-3-17.click&vd_source=a7fe275f0ee54c4d2f691a823f8876b8‌`
- 只有当你需要 B 站登录态，比如高画质、会员、受限视频时，才需要加。
- 你前面的日志已经提示高画质缺登录态，所以建议加。
	- 日志已经提示：

```sh
Format(s) 1080P 高清, 720P 准高清 are missing; you have to become a premium member to download them.
Use --cookies-from-browser or --cookies for the authentication.
```

所以用：

```sh
bash "/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh" \
  --url "https://www.bilibili.com/video/BV1ED5u6cEXG/" \
  --output "$HOME/Desktop/BV1ED5u6cEXG.mp4" \
  --cookies-from-browser safari
```

<br/>

**只想先快速下载，不转码，速度更快：**

```sh
bash "/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh" \
  --url "https://www.bilibili.com/video/BV1ED5u6cEXG/" \
  --output "$HOME/Desktop/BV1ED5u6cEXG.mp4" \
  --quicktime off \
  --cookies-from-browser chrome
```

<br/>

**关闭 QuickTime 转码：**

```sh
  bash ~/.codex/skills/ffmpeg-tools/scripts/download-video.sh \
    --url "<url>" \
    --output ~/Desktop/video.mp4 \
    --quicktime off
```



***
<br/>

- `yt-dlp` 已安装（`pip --user`）：
  - 可用：`python3 -m yt_dlp --version -> 2025.10.14`
- 更新下载脚本 `.codex/skills/ffmpeg-tools/scripts/download-video.sh`：
  - 直链 `.mp4/.m3u8：走 ffmpeg`
  - 网页链接：走 `yt-dlp`
  - 默认 `--quicktime on`：下载后自动转为 QuickTime 兼容 H.264 + AAC（必要时）
  - 可选 `--quicktime off`：保留原编码
- 更新说明 .codex/skills/ffmpeg-tools/SKILL.md

***
<br/>

  **测试结果**

  - 直链路径：ffmpeg -> 自动转码 -> 输出 h264+aac
      - `Desktop/hl_direct_quicktime.mp4`
  - 网页路径：yt-dlp -> 自动转码 -> 输出 h264+aac
      - `Desktop/hl_web_quicktime.mp4`

  如何使用（Skill）

  - $ffmpeg-tools 下载这个视频到桌面：<url>
  - 默认会做 QuickTime 兼容处理。
  - 若不想转码：$ffmpeg-tools ... 并使用 --quicktime off

***
<br/>

  **给其他人使用**

  - 最新包已更新：
    `Desktop/ffmpeg-tools-skill.zip`
  - 一键安装脚本（之前已做）：
   ` Desktop/install_ffmpeg_tools_skill.sh`

  对方执行：

```sh
  bash ~/Desktop/install_ffmpeg_tools_skill.sh ~/Desktop/ffmpeg-tools-skill.zip
```

  然后重启 Codex。
  
  
  <br/><br/><br/>

***
<br/>

> <h1 id="笔记整理技能study-note-cleanup">笔记整理技能study-note-cleanup</h1>
<br/>

> <h2 id="StudyNotes 自然语言触发配置">StudyNotes 自然语言触发配置</h2>

`study-note-cleanup` skill 支持自然语言触发，无需每次手动写 `使用 study-note-cleanup`。只需说"整理下 xxx.md"即可自动匹配。

<br/>

> <h3 id="触发方式">触发方式</h3>

| 用法 | 示例 |
|------|------|
| **最短触发** | `整理下 xxx.md` |
| **指定输出文件** | `整理下 old.md，输出成 new.md` |
| **明确 StudyNotes 风格** | `把 xxx.md 整理成 StudyNotes 风格` |
| **覆盖原文件** | `整理下 xxx.md，直接覆盖原文件` |
| **压缩整理** | `压缩 xxx.md 为清晰笔记` |
| **显式调用 skill** | `使用 study-note-cleanup 整理 xxx.md`（最稳，但不常用） |

常用自然语言触发词：

- `整理 xxx.md`
- `整理下 xxx.md`
- `整理笔记`
- `优化 md`
- `整理成 StudyNotes 风格`

<br/>

> <h3 id="配置要点">配置要点</h3>

**两处配置缺一不可：**

**1. `.ai_skill/study-note-cleanup/SKILL.md` 的 description**

需包含中文自然语言触发词，例如：

```yaml
description: 当用户说"整理下 xxx.md"、"整理笔记"、"优化 Markdown 笔记"、"压缩 AI 生成的中文笔记"、"整理成 StudyNotes 风格"时使用。把冗长中文 Markdown 整理成 StudyNotes 风格笔记，包含目录、HTML heading anchors、核心代码优先、压缩解释、保留示例和技术准确性。
```

**2. `AGENTS.md` 的 Available Skills 里补触发规则**

```markdown
- 当用户说"整理下 xxx.md"、"整理笔记"、"优化 md"、"压缩笔记"、"整理成 StudyNotes 风格"时，默认使用 `.ai_skill/study-note-cleanup/SKILL.md`。
```

改完后，Codex/OpenCode 看到"整理下 xxx.md"这类请求会自动使用该 skill。


	