---
name: ffmpeg-tools
description: 使用媒体处理工具完成三类任务：(1) 将多张图片拼接成一张图片，(2) 从视频链接下载并保存视频到本地，(3) 将图片整理成适合 A4 打印的 PDF，尤其是一张图片占一页 A4。用户提到拼图、合并图片、拼接多图、视频链接下载、保存视频到本地/桌面、图片整理成 PDF、A4 打印、一张图片一页时触发。
---

# FFmpeg 工具

## 快速开始

优先使用本 skill 自带脚本，便于获得稳定、可复现的行为：

- 图片拼接：
`bash scripts/compose-images.sh --mode grid --cols 2 --output ~/Desktop/montage.png <image_or_dir>...`
- 视频下载：
`bash scripts/download-video.sh --url "<video-url>" --output ~/Desktop/video.mp4`
- A4 打印 PDF，一张图片一页：
`bash scripts/images-to-a4-pdf.sh --output ~/Desktop/images-a4.pdf <image_or_dir>...`

自然语言触发示例：
- `$ffmpeg-tools 1.png,2.png,3.png,4.png 拼接成一张图，输出到桌面`
- `$ffmpeg-tools 下载这个视频到桌面：<url>`
- `$ffmpeg-tools 将这个文件夹中的图片整理成一个PDF，一张图片占一张A4纸`

## 脚本阅读说明

这些脚本已经加入中文注释，适合初学者阅读和学习。阅读时可以按下面的思路理解：

- `scripts/compose-images.sh`：Bash 脚本。它会收集图片路径，用 `ffprobe` 读取图片尺寸，构建 FFmpeg 的 `filter_complex` 滤镜图，然后用 `hstack`、`vstack` 或 `xstack` 拼接图片。
- `scripts/download-video.sh`：Bash 脚本。它有两条下载路线：直接 `.mp4` / `.m3u8` 链接使用 `ffmpeg`；网页链接使用 `yt-dlp` 解析和下载；最后可按需检查并转码为 QuickTime 兼容格式。
- `scripts/images-to-a4-pdf.sh`：Bash 外壳加内嵌 Python。Bash 负责帮助信息和依赖检查；Python 使用 Pillow 对图片自然排序、放到 A4 页面中，并保存为多页 PDF。
- Bash 多行命令中的注释应单独写在命令前面，不要写在行尾续行符 `\` 后面，否则可能破坏命令续行。
- `INPUTS=(...)`、`FF_ARGS=(...)`、`YTDLP_CMD=(...)` 这类 Bash 数组用于安全保存参数，避免带空格的路径或 URL 被错误拆分。
- 推荐阅读顺序：先读脚本顶部说明，再读辅助函数，再看默认变量，最后顺着主流程从参数解析读到最终输出。

## 任务

### 1. 将多张图片拼接成一张图片

使用脚本：`scripts/compose-images.sh`。

命令格式：
- `bash scripts/compose-images.sh [options] <image_or_dir> [image_or_dir ...]`

用途：
- 将两张或更多图片拼接成一张输出图片。
- 输入可以是图片文件、目录、逗号分隔的图片列表。
- 脚本会用 `ffprobe` 读取图片尺寸，构建 FFmpeg 滤镜图，然后用 `ffmpeg` 输出拼接结果。

支持的拼接模式：
- `grid`：网格布局，默认模式，可用 `--cols` 指定列数。
- `h`：水平拼接，所有图片排成一行。
- `v`：垂直拼接，所有图片排成一列。

参数说明：
- `--mode <grid|h|v>`：拼接模式，默认是 `grid`。
- `--cols <N>`：网格模式下的列数，默认是 `2`。
- `--cell <WxH>`：单元格尺寸，例如 `1280x720`。如果不指定，脚本会自动使用所有输入图片中的最大宽度和最大高度。
- `--resize <none|contain>`：缩放方式。`none` 表示不缩放，只把图片居中填充到单元格；`contain` 表示按比例缩小，让图片完整放进单元格。
- `--compress <on|off|match>`：压缩方式。`on` 是默认值；`off` 尽量保持最高质量；`match` 尝试让输出文件大小接近输入文件总大小。
- `--jpg-quality <1-31>`：JPEG 输出质量，只对 `.jpg` / `.jpeg` 输出有意义。数值越小质量越好、文件越大，默认是 `3`。
- `--bg <color>`：填充背景色，默认是 `black`。
- `--output <path>`：输出图片路径。未指定时默认保存到桌面，文件名类似 `hl_xxYxxMxxDxxs.png`。
- `-h` / `--help`：显示脚本帮助信息。

支持的输入方式：
- 目录路径：读取该目录第一层中的支持格式图片。
- 单个图片文件：例如 `a.jpg b.png c.webp`。
- 英文逗号分隔列表：例如 `1.png,2.png,3.png,4.png`。
- 中文逗号分隔列表：例如 `1.png，2.png，3.png`。
- 相对路径：基于当前工作目录解析。

支持的图片格式：
- JPG/JPEG、PNG、BMP、WebP、TIFF。

常用示例：
- `bash scripts/compose-images.sh --mode grid --cols 3 --output ~/Desktop/montage.png ~/Desktop/input-images`
- `bash scripts/compose-images.sh --mode h --output ~/Desktop/hstack.png a.jpg b.jpg c.jpg`
- `cd ~/Desktop/images && bash ~/.codex/skills/ffmpeg-tools/scripts/compose-images.sh --mode grid --cols 2 1.png,2.png,3.png,4.png`
- `bash scripts/compose-images.sh --mode v --output ~/Desktop/vstack.png 2.jpg,3.jpg,4.jpg`
- `bash scripts/compose-images.sh --mode v --output ~/Desktop/vstack.jpg --jpg-quality 3 2.jpg,3.jpg,4.jpg`
- `bash scripts/compose-images.sh --mode v --compress off 2.jpg,3.jpg,4.jpg`
- `bash scripts/compose-images.sh --mode v --compress match --output ~/Desktop/hl_match.jpg 2.jpg,3.jpg,4.jpg`

适合初学者的示例：
- `bash scripts/compose-images.sh --mode grid --cols 2 --output ~/Desktop/result.png ~/Desktop/input-images`
- `bash scripts/compose-images.sh --mode h --cell 1024x1024 a.jpg b.jpg c.jpg`
- `bash scripts/compose-images.sh --mode grid --cols 2 1.png,2.png,3.png,4.png`

使用规则：
- 至少需要 2 张有效图片。
- 不指定 `--output` 时，默认输出到桌面。
- 默认输出格式是 `.png`，属于无损格式。
- 默认不缩小图片，只把较小图片填充到最大图片尺寸。
- 只有明确需要“缩小以适配单元格”时才使用 `--resize contain`。
- 想要更小文件时，可以输出 `.jpg` 并配合 `--jpg-quality`。
- `--compress match` 会尝试让输出文件大小接近输入文件总大小，其中 JPG 更容易接近目标大小。

### 2. 从 URL 下载视频

使用脚本：`scripts/download-video.sh`。

命令格式：
- `bash scripts/download-video.sh --url <video-url> [--output <path>] [--quicktime <on|off>] [--cookies-from-browser <browser>] [--cookies <path>]`

用途：
- 将视频 URL 下载到本地磁盘。
- 直接 `.mp4` 和 `.m3u8` 媒体链接使用 `ffmpeg` 下载。
- YouTube、Bilibili 等网页链接使用 `yt-dlp` 解析和下载。
- 默认会在需要时把最终视频处理成 QuickTime 兼容格式。

参数说明：
- `--url <url>`：要下载的视频 URL，必填。
- `--output <path>`：输出文件路径。默认是 `~/Desktop/video-YYYYmmdd-HHMMSS.mp4`。
- `--quicktime <on|off>`：QuickTime 兼容模式。默认是 `on`；设置为 `off` 时保留原始下载编码，不做兼容性转码。
- `--cookies-from-browser <browser>`：把浏览器 cookies 传给 `yt-dlp`，例如 `chrome`、`safari`、`firefox`。
- `--cookies <path>`：把 Netscape 格式的 `cookies.txt` 文件传给 `yt-dlp`。
- `-h` / `--help`：显示脚本帮助信息。

下载行为：
- 直接 `.mp4` / `.m3u8` URL：优先尝试 `ffmpeg -c copy`，快速下载且不重新编码。
- 直接链接备选方案：如果 ffmpeg 直接复制失败，并且系统中有 `yt-dlp`，则尝试用 `yt-dlp` 下载。
- 网页 URL：使用 `yt-dlp` 解析真实视频/音频流，下载后合并为 MP4，并写入元数据。
- 格式选择优先使用 720p 及以下视频/音频：`bv*[height<=720]+ba/b[height<=720]/b`。
- 开启 `--quicktime on` 时，脚本会检查下载后的视频；如果不兼容 QuickTime，就转码为 H.264 视频 + AAC 音频。

cookies 使用场景：
- 视频需要登录才能访问时，可使用 `--cookies-from-browser chrome` 或其他浏览器。
- macOS 上如果登录状态在 Safari 中，可使用 `--cookies-from-browser safari`。
- 已手动导出 cookies 时，可使用 `--cookies /path/to/cookies.txt`。
- Bilibili 等网站可能需要 cookies 才能获取更高画质或下载登录可见内容。

常用示例：
- `bash scripts/download-video.sh --url "https://example.com/video.mp4" --output ~/Desktop/video.mp4`
- `bash scripts/download-video.sh --url "https://www.youtube.com/watch?v=..." --output ~/Desktop/youtube.mp4`
- `bash scripts/download-video.sh --url "https://example.com/video.mp4" --output ~/Desktop/video.mp4 --quicktime off`
- `bash scripts/download-video.sh --url "https://www.bilibili.com/video/..." --output ~/Desktop/bilibili.mp4 --cookies-from-browser chrome`
- `bash scripts/download-video.sh --url "https://example.com/stream.m3u8" --output ~/Desktop/stream.mp4`

使用规则：
- 直接 `.mp4` / `.m3u8` 链接应优先使用 `ffmpeg`。
- YouTube、Bilibili 等网页视频链接应使用 `yt-dlp` 解析和下载。
- 用户没有指定输出路径时，默认保存到桌面。
- 默认会尽量保证 QuickTime 兼容，需要时转码为 `H.264 + AAC`。
- 如果用户想保留原始编码并跳过转码，使用 `--quicktime off`。
- 只有在登录视频、受限视频或需要更高画质时才使用 cookies。

### 3. 将图片转换为 A4 打印 PDF

使用脚本：`scripts/images-to-a4-pdf.sh`。

默认行为：
- 一张图片占一页 A4。
- 默认竖版 A4，300 DPI。
- 图片居中显示，并按比例缩放到页边距以内。
- 图片不会被裁切，也不会被拉伸。
- 会尊重 EXIF 方向信息，所以手机照片可以正确旋转。
- 使用自然文件名排序，所以 `1.png`、`2.png`、`10.png` 会按数字顺序排列。

常用示例：
- `bash scripts/images-to-a4-pdf.sh --output ~/Desktop/cards.pdf ~/Downloads/cards`
- `bash scripts/images-to-a4-pdf.sh --output ~/Desktop/cards.pdf 1.png,2.png,3.png`
- `bash scripts/images-to-a4-pdf.sh --margin 80 --output ~/Desktop/cards.pdf ~/Downloads/cards`
- `bash scripts/images-to-a4-pdf.sh --orientation landscape --output ~/Desktop/cards-landscape.pdf ~/Downloads/cards`

参数说明：
- `--output <path>` / `-o <path>`：输出 PDF 路径。默认是 `./images-a4-one-per-page.pdf`。
- `--orientation <portrait|landscape>`：A4 页面方向，默认是 `portrait`。
- `--dpi <N>`：PDF 分辨率元数据和 A4 像素尺寸基准，默认是 `300`。
- `--margin <N>`：300 DPI 下的页边距像素值，会随 `--dpi` 缩放，默认是 `120`。
- `--bg <color>`：页面背景色，默认是 `white`。

支持的输入方式：
- 目录路径：读取该目录第一层中的支持格式图片。
- 单个图片文件。
- 逗号分隔图片列表，支持中文逗号，例如 `1.png，2.png，3.png`。

支持的图片格式：
- JPG/JPEG、PNG、WebP、BMP、TIFF。

使用规则：
- 用户要求“适合打印的 PDF”时使用此脚本。
- 用户说“一张图片占一张 A4 纸”时，保持默认的一图一页行为。
- 用户指定桌面、下载目录或其他目标位置时，应显式传入 `--output`。
- 除非用户明确要求满版裁切或裁切填充，否则不要裁切图片；此脚本设计上不会裁切。

## 执行清单

1. 检查依赖是否可用：图片拼接和视频任务需要 `ffmpeg`；A4 PDF 生成需要 Python 包 `Pillow`；网页视频链接推荐安装 `yt-dlp`。
2. 确认输入路径、输出路径，并创建输出父目录。
3. 使用明确参数运行对应脚本。
4. 完成后报告最终输出文件的绝对路径。

## 依赖说明

- 必需：`ffmpeg`
- 网页视频 URL 必需：`yt-dlp`
- A4 PDF 生成必需：Python 包 `Pillow`

macOS 安装示例：
- `brew install ffmpeg`
- `python3 -m pip install --user -U yt-dlp`
- `python3 -m pip install --user -U Pillow`
