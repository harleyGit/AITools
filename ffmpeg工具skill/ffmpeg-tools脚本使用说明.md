# ffmpeg 工具 skill 使用说明

这个文件用于说明 `/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts` 目录下脚本的使用方法，方便在 `ffmpeg工具skill` 分发文件夹中直接查看。

## 脚本路径

- 图片拼接脚本：`/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/compose-images.sh`
- 视频下载脚本：`/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh`
- A4 PDF 生成脚本：`/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/images-to-a4-pdf.sh`

## 依赖工具

- `ffmpeg`：图片拼接、视频下载和视频转码需要。
- `ffprobe`：读取图片尺寸、检查视频编码需要，通常随 `ffmpeg` 一起安装。
- `yt-dlp`：下载 YouTube、Bilibili 等网页视频链接需要。
- `python3` 和 Python 包 `Pillow`：将图片生成 A4 PDF 需要。

macOS 安装示例：

```bash
brew install ffmpeg
python3 -m pip install --user -U yt-dlp
python3 -m pip install --user -U Pillow
```

## 1. 图片拼接脚本 compose-images.sh

### 功能

`compose-images.sh` 用于把多张图片拼接成一张图片。支持网格拼接、水平拼接、垂直拼接。

### 命令格式

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/compose-images.sh [options] <image_or_dir> [image_or_dir ...]
```

### 常用参数

- `--mode <grid|h|v>`：拼接模式。`grid` 为网格，`h` 为水平，`v` 为垂直。默认是 `grid`。
- `--cols <N>`：网格模式下的列数，默认是 `2`。
- `--cell <WxH>`：每个单元格尺寸，例如 `1024x1024`。不指定时自动使用输入图片中的最大宽高。
- `--resize <none|contain>`：缩放方式。`none` 表示不缩放，只填充；`contain` 表示按比例缩小以适应单元格。
- `--compress <on|off|match>`：压缩方式。默认 `on`；`off` 尽量保持最高质量；`match` 尝试让输出大小接近输入总大小。
- `--jpg-quality <1-31>`：JPEG 输出质量，数值越小质量越好、文件越大，默认是 `3`。
- `--bg <color>`：背景填充颜色，默认是 `black`。
- `--output <path>`：输出图片路径，不指定时默认输出到桌面。
- `-h` / `--help`：查看帮助。

### 支持输入

- 单个图片文件，例如 `1.png 2.png 3.png`。
- 图片目录，例如 `~/Desktop/images`。
- 英文逗号分隔图片列表，例如 `1.png,2.png,3.png`。
- 中文逗号分隔图片列表，例如 `1.png，2.png，3.png`。

支持格式：JPG/JPEG、PNG、BMP、WebP、TIFF。

### 使用示例

网格拼接，两列输出到桌面：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/compose-images.sh \
  --mode grid \
  --cols 2 \
  --output ~/Desktop/result.png \
  ~/Desktop/input-images
```

水平拼接三张图片：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/compose-images.sh \
  --mode h \
  --output ~/Desktop/hstack.png \
  a.jpg b.jpg c.jpg
```

垂直拼接多张图片：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/compose-images.sh \
  --mode v \
  --output ~/Desktop/vstack.png \
  1.png 2.png 3.png 4.png
```

使用逗号列表拼接：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/compose-images.sh \
  --mode grid \
  --cols 2 \
  --output ~/Desktop/grid.png \
  1.png,2.png,3.png,4.png
```

输出 JPEG 并控制文件大小：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/compose-images.sh \
  --mode grid \
  --cols 2 \
  --compress match \
  --output ~/Desktop/output.jpg \
  ~/Desktop/input-images
```

### 注意事项

- 至少需要 2 张有效图片。
- 默认不会缩小图片，只会把较小图片填充到统一单元格中。
- 如果图片尺寸超过指定 `--cell`，可增大 `--cell` 或使用 `--resize contain`。
- PNG 是无损格式，质量高但文件可能较大；JPG 文件通常更小，但有损压缩。

## 2. 视频下载脚本 download-video.sh

### 功能

`download-video.sh` 用于从 URL 下载视频到本地。直接 `.mp4` / `.m3u8` 链接使用 `ffmpeg`，网页视频链接使用 `yt-dlp`。

### 命令格式

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh --url <video-url> [options]
```

### 常用参数

- `--url <url>`：视频 URL，必填。
- `--output <path>`：输出文件路径，默认保存到桌面。
- `--quicktime <on|off>`：是否确保 QuickTime 兼容。默认是 `on`；`off` 表示保留原始编码，不转码。
- `--cookies-from-browser <browser>`：从浏览器读取 cookies，例如 `chrome`、`safari`、`firefox`。
- `--cookies <path>`：使用 Netscape 格式的 `cookies.txt`。
- `-h` / `--help`：查看帮助。

### 下载逻辑

- 如果 URL 是直接 `.mp4` 或 `.m3u8` 链接，脚本优先使用 `ffmpeg -c copy` 下载。
- 如果 URL 是网页链接，例如 YouTube、Bilibili，脚本使用 `yt-dlp` 解析真实视频流并下载。
- 默认 `--quicktime on` 时，脚本会检查输出视频是否兼容 QuickTime。
- 如果视频不兼容 QuickTime，会转码为 H.264 视频 + AAC 音频。

### 使用示例

下载直接 MP4 链接：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh \
  --url "https://example.com/video.mp4" \
  --output ~/Desktop/video.mp4
```

下载网页视频链接：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh \
  --url "https://www.youtube.com/watch?v=xxxx" \
  --output ~/Desktop/youtube.mp4
```

下载 Bilibili 视频并使用浏览器 cookies：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh \
  --url "https://www.bilibili.com/video/BVxxxx" \
  --output ~/Desktop/bilibili.mp4 \
  --cookies-from-browser chrome
```

保持原始编码，不做 QuickTime 转码：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh \
  --url "https://example.com/video.mp4" \
  --output ~/Desktop/video-original.mp4 \
  --quicktime off
```

下载 m3u8 流：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/download-video.sh \
  --url "https://example.com/stream.m3u8" \
  --output ~/Desktop/stream.mp4
```

### cookies 说明

- 视频需要登录时，通常需要 `--cookies-from-browser chrome` 或 `--cookies-from-browser safari`。
- 某些网站需要 cookies 才能获取更高画质。
- 如果你已经导出了 `cookies.txt`，可以使用 `--cookies /path/to/cookies.txt`。

### 注意事项

- `yt-dlp` 不是所有直链都必需，但网页链接通常需要。
- 如果不想转码，使用 `--quicktime off`。
- 如果下载失败，先确认 URL 是否能在浏览器访问，再确认 `ffmpeg`、`yt-dlp` 是否安装。

## 3. A4 PDF 生成脚本 images-to-a4-pdf.sh

### 功能

`images-to-a4-pdf.sh` 用于把图片整理成适合 A4 打印的 PDF。默认一张图片占一页 A4，居中显示，等比例缩放，不裁切、不拉伸。

### 命令格式

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/images-to-a4-pdf.sh [options] <image_or_dir> [image_or_dir ...]
```

### 常用参数

- `--output <path>` / `-o <path>`：输出 PDF 路径，默认是当前目录下的 `images-a4-one-per-page.pdf`。
- `--orientation <portrait|landscape>`：A4 方向，默认 `portrait`。
- `--dpi <N>`：PDF 分辨率和 A4 像素尺寸基准，默认 `300`。
- `--margin <N>`：页边距，按 300 DPI 像素值理解，默认 `120`。
- `--bg <color>`：页面背景颜色，默认 `white`。
- `-h` / `--help`：查看帮助。

### 使用示例

将文件夹内图片生成 A4 PDF：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/images-to-a4-pdf.sh \
  --output ~/Desktop/images-a4.pdf \
  ~/Desktop/images
```

使用逗号列表指定图片：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/images-to-a4-pdf.sh \
  --output ~/Desktop/cards.pdf \
  1.png,2.png,3.png
```

横向 A4 输出：

```bash
/Users/ganghuang/HGFiles/GitHub/AITools/Skills/ffmpeg-tools/scripts/images-to-a4-pdf.sh \
  --orientation landscape \
  --output ~/Desktop/cards-landscape.pdf \
  ~/Desktop/cards
```

### 注意事项

- 图片会按自然文件名排序，例如 `1.png`、`2.png`、`10.png`。
- 支持 JPG/JPEG、PNG、WebP、BMP、TIFF。
- 目录输入只读取第一层，不递归子目录。
- 需要安装 Python 包 `Pillow`。

## 一键安装 skill

当前文件夹中包含安装脚本：

```bash
bash /Users/ganghuang/HGFiles/GitHub/AITools/ffmpeg工具skill/install_ffmpeg_tools_skill.sh ~/Desktop/ffmpeg-tools-skill.zip
```

安装完成后，重启 Codex/OpenCode 以加载更新后的 skill。
