# AI技能说明
- [PPT技能codex-primary-runtime](#PPT技能codex-primary-runtime)
- [开发通用技能dev_general_skill](#开发通用技能dev_general_skill)
- [视频、图片ffmpeg-tools](#视频、图片ffmpeg-tools)


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
- **AI：**
	- `ffmpeg-tools 下载这个视频到桌面：<url>`
- **脚本：**
	- 视频下载：

**视频链接：**

```sh
bash ~/.codex/skills/ffmpeg-tools/scripts/download-video.sh \
    --url "https://example.com/video.mp4" \
    --output ~/Desktop/video.mp4
```

<br/>

**网页中含有视频下载：**

```sh
bash ~/.codex/skills/ffmpeg-tools/scripts/download-video.sh \
    --url "https://www.youtube.com/watch?v=xxxx" \
    --output ~/Desktop/video.mp4
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

  如何使用（脚本）

  - 直链：

  bash ~/.codex/skills/ffmpeg-tools/scripts/download-video.sh \
    --url "https://example.com/video.mp4" \
    --output ~/Desktop/video.mp4

  - 网页链接：

```sh
  bash ~/.codex/skills/ffmpeg-tools/scripts/download-video.sh \
    --url "https://www.youtube.com/watch?v=xxxx" \
    --output ~/Desktop/video.mp4
```

  - 关闭 QuickTime 转码：

```sh
  bash ~/.codex/skills/ffmpeg-tools/scripts/download-video.sh \
    --url "<url>" \
    --output ~/Desktop/video.mp4 \
    --quicktime off
```

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
	