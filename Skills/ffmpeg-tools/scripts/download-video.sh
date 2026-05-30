#!/usr/bin/env bash
# =============================================================================
# 视频下载脚本 - download-video.sh
# =============================================================================
# 功能：从各种网站下载视频到本地磁盘
# 
# 工作原理：
# 1. 如果URL是直接的视频文件链接（.mp4/.m3u8），使用 ffmpeg 直接下载
# 2. 如果URL是网页链接（如YouTube、Bilibili），使用 yt-dlp 解析并下载
# 3. 默认将输出转换为 QuickTime 兼容的 H.264 + AAC 格式
#
# 依赖工具：
# - ffmpeg：视频处理工具，用于下载和转码视频
# - ffprobe：视频信息分析工具，用于检查视频编码格式
# - yt-dlp：视频网站下载工具，支持YouTube、Bilibili等网站
# =============================================================================

# set -euo pipefail：Shell脚本的安全选项
# -e：任何命令失败时立即退出脚本
# -u：使用未定义的变量时报错退出
# -o pipefail：管道中任何命令失败时，整个管道返回失败
set -euo pipefail

# =============================================================================
# 函数：usage()
# 功能：显示脚本的使用帮助信息
# 当用户输入 --help 或参数错误时调用
# =============================================================================
usage() {
  cat <<'EOF'
Usage:
  download-video.sh --url <video-url> [--output <path>] [--quicktime <on|off>] [--cookies-from-browser <browser>] [--cookies <path>]

Options:
  --url <url>         要下载的视频URL地址（必填）
  --output <path>     输出文件路径（默认：~/Desktop/video-YYYYmmdd-HHMMSS.mp4）
  --quicktime <mode>  on：确保输出兼容QuickTime（默认）
                      off：保持原始编码格式不转码
  --cookies-from-browser <browser>
                      从浏览器传递cookies给yt-dlp，例如：chrome, safari, firefox
                      用于下载需要登录的视频或获取更高画质
  --cookies <path>    传递Netscape格式的cookies.txt文件给yt-dlp
  -h, --help          显示帮助信息

Notes:
  - 直接的 .mp4/.m3u8 链接使用 ffmpeg 下载
  - 网页链接使用 yt-dlp 下载
  - 某些网站（如Bilibili）可能需要cookies才能获取更高画质或下载需要登录的视频
  - QuickTime兼容目标：H.264视频 + AAC音频，封装为.mp4格式
EOF
}

# =============================================================================
# 函数：require_cmd()
# 功能：检查系统中是否安装了指定的命令
# 参数：$1 = 命令名称（如 ffmpeg, yt-dlp）
# 如果命令不存在，显示错误信息并退出脚本
# =============================================================================
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Missing required command: $1" >&2
    exit 1
  }
}

# =============================================================================
# 函数：is_direct_media_url()
# 功能：判断URL是否是直接的媒体文件链接
# 参数：$1 = URL地址
# 返回值：如果是.mp4或.m3u8链接返回0（真），否则返回1（假）
# 
# 原理：
# - 将URL转换为小写
# - 检查是否以 .mp4 或 .m3u8 结尾（可能带有查询参数如 ?token=xxx）
# - 直接的媒体文件链接可以直接用 ffmpeg 下载，不需要解析网页
# =============================================================================
is_direct_media_url() {
  local u
  # tr '[:upper:]' '[:lower:]' 将大写字母转换为小写
  u="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  # 检查URL是否以 .mp4 或 .m3u8 结尾（包括带查询参数的情况）
  [[ "$u" == *.mp4 || "$u" == *.mp4\?* || "$u" == *.m3u8 || "$u" == *.m3u8\?* ]]
}

# =============================================================================
# 函数：pick_ytdlp_cmd()
# 功能：查找可用的 yt-dlp 命令
# 返回值：设置全局变量 YTDLP_CMD 为找到的 yt-dlp 命令路径
#
# 查找顺序：
# 1. 系统PATH中的 yt-dlp（最常见）
# 2. macOS Python 3.9 的 pip --user 安装路径
# 3. 通过 python3 -m yt_dlp 模块方式调用
#
# yt-dlp 是 youtube-dl 的分支，支持更多网站，包括Bilibili
# =============================================================================
pick_ytdlp_cmd() {
  # 方法1：检查 yt-dlp 是否在系统PATH中
  if command -v yt-dlp >/dev/null 2>&1; then
    YTDLP_CMD=("yt-dlp")
    return 0
  fi
  # 方法2：检查 macOS Python 3.9 的 pip --user 安装路径
  if [[ -x "${HOME}/Library/Python/3.9/bin/yt-dlp" ]]; then
    YTDLP_CMD=("${HOME}/Library/Python/3.9/bin/yt-dlp")
    return 0
  fi
  # 方法3：通过 python3 模块方式调用
  if python3 -m yt_dlp --version >/dev/null 2>&1; then
    YTDLP_CMD=("python3" "-m" "yt_dlp")
    return 0
  fi
  # 如果都找不到，返回失败
  return 1
}

# =============================================================================
# 函数：probe_stream_field()
# 功能：使用 ffprobe 读取视频文件的某个流的某个字段值
# 参数：
#   $1 = 文件路径
#   $2 = 流选择器（如 "v:0" 表示第一个视频流，"a:0" 表示第一个音频流）
#   $3 = 字段名称（如 "codec_name" 表示编码名称，"pix_fmt" 表示像素格式）
# 返回值：字段的值（字符串）
#
# 示例：probe_stream_field "video.mp4" "v:0" "codec_name" 可能返回 "h264"
# =============================================================================
probe_stream_field() {
  local file="$1"
  local selector="$2"
  local field="$3"
  # ffprobe 参数说明：
  # -v error：只显示错误信息，不显示其他日志
  # -select_streams "$selector"：选择特定的流
  # -show_entries "stream=${field}"：只显示指定的字段
  # -of csv=p=0：输出为CSV格式，不显示前缀
  # 2>/dev/null：将错误信息重定向到空设备（不显示）
  # head -n 1：只取第一行（防止有多个流）
  ffprobe -v error -select_streams "$selector" -show_entries "stream=${field}" -of csv=p=0 "$file" 2>/dev/null | head -n 1
}

# =============================================================================
# 函数：is_quicktime_compatible()
# 功能：检查视频是否兼容 QuickTime 播放器
# 参数：$1 = 视频文件路径
# 返回值：兼容返回0（真），不兼容返回1（假）
#
# QuickTime 兼容要求：
# - 视频编码：H.264（最常见的MP4编码）
# - 像素格式：yuv420p 或 yuvj420p（标准的颜色空间）
# - 音频编码：AAC（最常用的音频编码）或无音频
#
# 为什么需要检查？
# - 某些视频使用 HEVC/H.265 编码，QuickTime 可能不支持
# - 某些视频使用非标准像素格式，可能导致播放问题
# =============================================================================
is_quicktime_compatible() {
  local file="$1"
  local vcodec pixfmt acodec
  # 读取视频编码名称
  vcodec="$(probe_stream_field "$file" "v:0" "codec_name" || true)"
  # 读取像素格式
  pixfmt="$(probe_stream_field "$file" "v:0" "pix_fmt" || true)"
  # 读取音频编码名称
  acodec="$(probe_stream_field "$file" "a:0" "codec_name" || true)"

  # 检查视频编码是否为 h264
  [[ "$vcodec" == "h264" ]] || return 1
  # 检查像素格式是否为标准格式
  [[ "$pixfmt" == "yuv420p" || "$pixfmt" == "yuvj420p" ]] || return 1
  # 如果有音频，检查音频编码是否为 aac
  if [[ -n "$acodec" && "$acodec" != "aac" ]]; then
    return 1
  fi
  return 0
}

# =============================================================================
# 函数：finalize_output()
# 功能：根据 QuickTime 模式处理最终输出
# 参数：
#   $1 = 源文件路径（下载的临时文件）
#   $2 = 目标文件路径（最终输出位置）
#
# 处理逻辑：
# 1. 如果 quicktime 模式为 off，直接移动文件（不转码）
# 2. 如果视频已经兼容 QuickTime，直接移动文件
# 3. 如果视频不兼容，使用 ffmpeg 转码为 H.264 + AAC
# =============================================================================
finalize_output() {
  local src="$1"
  local dst="$2"

  # 模式1：不转码，直接使用原始编码
  if [[ "$QUICKTIME_MODE" == "off" ]]; then
    # 如果源文件和目标文件路径不同，移动文件
    if [[ "$src" != "$dst" ]]; then
      mv -f "$src" "$dst"
    fi
    echo "[OK] Video downloaded: $dst"
    return 0
  fi

  # 模式2：检查是否已经兼容 QuickTime
  if is_quicktime_compatible "$src"; then
    echo "[INFO] Source is already QuickTime-compatible."
    if [[ "$src" != "$dst" ]]; then
      mv -f "$src" "$dst"
    fi
    echo "[OK] Video downloaded: $dst"
    return 0
  fi

  # 模式3：需要转码为 QuickTime 兼容格式
  echo "[INFO] Transcoding to QuickTime-compatible MP4 (H.264 + AAC)..."
  
  # 检查是否有音频流
  local has_audio
  has_audio="$(probe_stream_field "$src" "a:0" "codec_name" || true)"
  
  if [[ -n "$has_audio" ]]; then
    # 有音频：转码视频为 H.264，音频为 AAC
    # ffmpeg 参数说明：
    # -y：覆盖输出文件（如果存在）
    # -i "$src"：输入文件
    # -c:v libx264：使用 libx264 编码器编码视频（H.264）
    # -pix_fmt yuv420p：设置像素格式为 yuv420p（兼容性最好）
    # -movflags +faststart：将元数据移到文件开头，便于网络流式播放
    # -c:a aac：使用 AAC 编码器编码音频
    # -b:a 192k：音频码率 192kbps（高质量）
    # "$dst"：输出文件路径
    ffmpeg -y -i "$src" \
      -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
      -c:a aac -b:a 192k \
      "$dst"
  else
    # 无音频：只转码视频，删除音频流
    ffmpeg -y -i "$src" \
      -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
      -an \
      "$dst"
  fi

  # 删除源文件（如果和目标文件不同）
  if [[ "$src" != "$dst" ]]; then
    rm -f "$src"
  fi
  echo "[OK] Video downloaded: $dst"
}

# =============================================================================
# 变量初始化：设置默认值
# =============================================================================
# URL：要下载的视频地址（必填，初始为空）
URL=""
# OUTPUT：输出文件路径，默认保存到桌面，文件名包含时间戳
# $(date +%Y%m%d-%H%M%S) 生成格式如：20240101-120000
OUTPUT="${HOME}/Desktop/video-$(date +%Y%m%d-%H%M%S).mp4"
# QUICKTIME_MODE：QuickTime 兼容模式，on=转码（默认），off=保持原格式
QUICKTIME_MODE="on"
# DOWNLOAD_OUTPUT：实际下载的文件路径（可能与OUTPUT不同，用于临时文件）
DOWNLOAD_OUTPUT="$OUTPUT"
# TEMP_OUTPUT：临时文件路径（用于QuickTime模式下的中间文件）
TEMP_OUTPUT=""
# COOKIES_FROM_BROWSER：从浏览器读取cookies（用于需要登录的视频）
COOKIES_FROM_BROWSER=""
# COOKIES_FILE：cookies文件路径（Netscape格式）
COOKIES_FILE=""

# =============================================================================
# 函数：cleanup()
# 功能：脚本退出时清理临时文件
# 这是一个清理函数，确保即使脚本异常退出也能删除临时文件
# =============================================================================
cleanup() {
  # 如果临时文件存在，删除它
  if [[ -n "${TEMP_OUTPUT:-}" && -f "$TEMP_OUTPUT" ]]; then
    rm -f "$TEMP_OUTPUT"
  fi
}
# trap 命令：注册退出时的清理函数
# EXIT 是一个特殊的信号，在脚本退出时触发
trap cleanup EXIT

# =============================================================================
# 命令行参数解析
# while 循环遍历所有参数
# $# 表示参数的数量，-gt 0 表示大于0
# =============================================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    # --url 参数：指定视频URL
    --url)
      URL="${2:-}"  # ${2:-} 获取第二个参数，如果不存在则为空
      shift 2       # 移除已处理的两个参数（--url 和 URL值）
      ;;
    # --output 参数：指定输出文件路径
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    # --quicktime 参数：指定QuickTime兼容模式
    --quicktime)
      QUICKTIME_MODE="${2:-}"
      shift 2
      ;;
    # --cookies-from-browser 参数：从浏览器读取cookies
    --cookies-from-browser)
      COOKIES_FROM_BROWSER="${2:-}"
      shift 2
      ;;
    # --cookies 参数：指定cookies文件路径
    --cookies)
      COOKIES_FILE="${2:-}"
      shift 2
      ;;
    # -h 或 --help 参数：显示帮助
    -h|--help)
      usage
      exit 0
      ;;
    # 未知参数：显示错误和帮助
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# =============================================================================
# 参数验证：检查必填参数
# =============================================================================
# 如果URL为空，显示错误并退出
if [[ -z "$URL" ]]; then
  echo "[ERROR] --url is required." >&2
  usage
  exit 1
fi

# =============================================================================
# 检查依赖工具
# =============================================================================
# 检查 ffmpeg 是否安装
require_cmd ffmpeg
# 检查 ffprobe 是否安装（通常和 ffmpeg 一起安装）
require_cmd ffprobe

# 创建输出文件的父目录（如果不存在）
# dirname 获取文件的目录部分，如 ~/Desktop/video.mp4 -> ~/Desktop
mkdir -p "$(dirname "$OUTPUT")"

# 验证 QUICKTIME_MODE 参数值
if ! [[ "$QUICKTIME_MODE" =~ ^(on|off)$ ]]; then
  echo "[ERROR] --quicktime must be one of: on, off" >&2
  exit 1
fi

# =============================================================================
# QuickTime 模式处理：创建临时文件
# =============================================================================
if [[ "$QUICKTIME_MODE" == "on" ]]; then
  # mktemp 创建一个临时文件，文件名包含随机字符
  # ${TMPDIR:-/tmp} 使用系统的临时目录，如果没有则使用 /tmp
  TEMP_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/ffmpeg-tools-video-XXXXXX.mp4")"
  # 删除临时文件（因为yt-dlp会跳过已存在的文件）
  # 我们只需要这个唯一的路径
  rm -f "$TEMP_OUTPUT"
  # 设置下载输出路径为临时文件
  DOWNLOAD_OUTPUT="$TEMP_OUTPUT"
fi

# =============================================================================
# 构建 yt-dlp 的额外参数（cookies相关）
# =============================================================================
# YTDLP_EXTRA_ARGS 是一个数组，用于存储额外的 yt-dlp 参数
YTDLP_EXTRA_ARGS=()
# 如果指定了浏览器cookies，添加到参数数组
if [[ -n "$COOKIES_FROM_BROWSER" ]]; then
  YTDLP_EXTRA_ARGS+=(--cookies-from-browser "$COOKIES_FROM_BROWSER")
fi
# 如果指定了cookies文件，添加到参数数组
if [[ -n "$COOKIES_FILE" ]]; then
  YTDLP_EXTRA_ARGS+=(--cookies "$COOKIES_FILE")
fi

# =============================================================================
# 下载路径1：直接媒体文件链接
# 如果URL是直接的 .mp4 或 .m3u8 链接，使用 ffmpeg 直接下载
# =============================================================================
if is_direct_media_url "$URL" || [[ -f "$URL" ]]; then
  echo "[INFO] Using ffmpeg for direct media URL/path..."
  # ffmpeg 直接下载：
  # -y：覆盖输出文件
  # -i "$URL"：输入URL
  # -c copy：直接复制流（不重新编码，速度最快）
  if ffmpeg -y -i "$URL" -c copy "$DOWNLOAD_OUTPUT"; then
    # 下载成功，处理最终输出
    finalize_output "$DOWNLOAD_OUTPUT" "$OUTPUT"
    exit 0
  fi
  
  # 如果 ffmpeg 直接下载失败，尝试使用 yt-dlp 作为备选方案
  if pick_ytdlp_cmd; then
    echo "[WARN] ffmpeg direct copy failed; trying yt-dlp fallback..."
    "${YTDLP_CMD[@]}" \
      --no-playlist \                    # 不下载播放列表，只下载单个视频
      --no-part \                        # 不使用分段下载
      -f "bv*[height<=720]+ba/b[height<=720]/b" \  # 格式选择：720p或更低的视频+最佳音频
      --merge-output-format mp4 \        # 合并后输出为MP4格式
      --embed-metadata \                 # 嵌入元数据（标题、作者等）
      --no-check-certificates \          # 跳过SSL证书检查
      "${YTDLP_EXTRA_ARGS[@]+"${YTDLP_EXTRA_ARGS[@]}"}" \  # 传递cookies参数
      -o "$DOWNLOAD_OUTPUT" \            # 输出文件路径
      "$URL"                             # 输入URL
    finalize_output "$DOWNLOAD_OUTPUT" "$OUTPUT"
    exit 0
  fi
  
  # 如果两种方法都失败，显示错误
  echo "[ERROR] ffmpeg failed downloading direct URL/path: $URL" >&2
  exit 1
fi

# =============================================================================
# 下载路径2：网页链接
# 如果URL是网页（如YouTube、Bilibili），使用 yt-dlp 解析并下载
# =============================================================================
if pick_ytdlp_cmd; then
  echo "[INFO] Using yt-dlp for webpage URL..."
  "${YTDLP_CMD[@]}" \
    --no-playlist \                      # 不下载播放列表，只下载单个视频
    --no-part \                          # 不使用分段下载
    -f "bv*[height<=720]+ba/b[height<=720]/b" \  # 格式选择：720p或更低的视频+最佳音频
    --merge-output-format mp4 \          # 合并后输出为MP4格式
    --embed-metadata \                   # 嵌入元数据（标题、作者等）
    --no-check-certificates \            # 跳过SSL证书检查
    "${YTDLP_EXTRA_ARGS[@]+"${YTDLP_EXTRA_ARGS[@]}"}" \  # 传递cookies参数
    -o "$DOWNLOAD_OUTPUT" \              # 输出文件路径
    "$URL"                               # 输入URL
  finalize_output "$DOWNLOAD_OUTPUT" "$OUTPUT"
  exit 0
fi

# =============================================================================
# 错误处理：如果所有方法都失败
# =============================================================================
# 显示详细的错误信息和安装指导
cat >&2 <<'EOF'
[ERROR] This URL is not a direct .mp4/.m3u8 stream and yt-dlp was not found.
Install yt-dlp, then retry:
  python3 -m pip install --user -U yt-dlp
If installed via pip --user, ensure this path is in PATH:
  export PATH="$HOME/Library/Python/3.9/bin:$PATH"
EOF
exit 1
