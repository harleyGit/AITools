---
name: ffmpeg-tools
description: Use FFmpeg utilities to (1) stitch multiple images into one output image and (2) download/save a video from a URL to local disk. Trigger this skill when users ask to merge photos into a single picture (拼图、合并图片、拼接多图) or ask to download a video link (视频链接下载、保存视频到本地/桌面), especially when output location or FFmpeg command execution is required.
---

# FFmpeg Tools

## Quick Start

Use bundled scripts for deterministic behavior:

- Image montage:
`bash scripts/compose-images.sh --mode grid --cols 2 --output ~/Desktop/montage.png <image_or_dir>...`
- Video download:
`bash scripts/download-video.sh --url "<video-url>" --output ~/Desktop/video.mp4`

Natural-language trigger examples:
- `$ffmpeg-tools 1.png,2.png,3.png,4.png 拼接成一张图，输出到桌面`
- `$ffmpeg-tools 下载这个视频到桌面：<url>`

## Tasks

### 1) Stitch Multiple Images Into One

Use `scripts/compose-images.sh`.

Supported modes:
- `grid` (default): tiled layout with `--cols`
- `h`: horizontal stitching
- `v`: vertical stitching

Examples:
- `bash scripts/compose-images.sh --mode grid --cols 3 --output ~/Desktop/montage.png ~/Desktop/input-images`
- `bash scripts/compose-images.sh --mode h --output ~/Desktop/hstack.png a.jpg b.jpg c.jpg`
- `cd ~/Desktop/images && bash ~/.codex/skills/ffmpeg-tools/scripts/compose-images.sh --mode grid --cols 2 1.png,2.png,3.png,4.png`
- `bash scripts/compose-images.sh --mode v --output ~/Desktop/vstack.png 2.jpg,3.jpg,4.jpg`
- `bash scripts/compose-images.sh --mode v --output ~/Desktop/vstack.jpg --jpg-quality 3 2.jpg,3.jpg,4.jpg`
- `bash scripts/compose-images.sh --mode v --compress off 2.jpg,3.jpg,4.jpg`
- `bash scripts/compose-images.sh --mode v --compress match --output ~/Desktop/hl_match.jpg 2.jpg,3.jpg,4.jpg`

Rules:
- Require at least 2 images.
- Default output is on Desktop if `--output` is omitted.
- Default output format is `.png` (lossless), with default filename: `hl_xxYxxMxxDxxs.png`.
- Default behavior does not downscale images. It pads smaller images to match the largest input size.
- Accept comma-separated image list in one argument (e.g. `1.png,2.png,3.png,4.png`).
- Accept relative paths from current working directory.
- Use `--resize contain` only when you explicitly want shrink-to-fit behavior.
- For smaller output files, use `.jpg` output with `--jpg-quality` (1-31, lower = better quality/larger size).
- Use `--compress on|off|match` to control encoder compression (default `on`).
- `--compress match` will try to make output size close to total input size (JPG is most accurate).

### 2) Download Video from URL

Use `scripts/download-video.sh`.

Examples:
- `bash scripts/download-video.sh --url "https://example.com/video.mp4" --output ~/Desktop/video.mp4`
- `bash scripts/download-video.sh --url "https://www.youtube.com/watch?v=..." --output ~/Desktop/youtube.mp4`
- `bash scripts/download-video.sh --url "https://example.com/video.mp4" --output ~/Desktop/video.mp4 --quicktime off`

Rules:
- Direct `.mp4` / `.m3u8` links should use `ffmpeg`.
- Web/video-page URLs (YouTube, Bilibili, etc.) should use `yt-dlp` for parsing and downloading.
- Save to Desktop by default if `--output` is omitted.
- Default behavior ensures QuickTime compatibility by transcoding to `H.264 + AAC` when needed.
- Use `--quicktime off` to keep original codec and skip compatibility transcoding.

## Execution Checklist

1. Validate required dependencies (`ffmpeg` always; `yt-dlp` optional but recommended for webpage links).
2. Confirm input/output paths and create output parent directory.
3. Run bundled script with explicit options.
4. Report final output absolute path.

## Dependency Notes

- Required: `ffmpeg`
- Required for webpage URLs: `yt-dlp`

Install examples on macOS:
- `brew install ffmpeg`
- `python3 -m pip install --user -U yt-dlp`
