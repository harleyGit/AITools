#!/usr/bin/env bash
# Download a video to local disk.
# Strategy:
# 1) Use ffmpeg for direct media URLs (.mp4/.m3u8)
# 2) Use yt-dlp for webpage URLs (YouTube/Bilibili/etc.)
# 3) By default, normalize output to QuickTime-compatible H.264 + AAC
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  download-video.sh --url <video-url> [--output <path>] [--quicktime <on|off>]

Options:
  --url <url>         Video URL to download
  --output <path>     Output file path (default: ~/Desktop/video-YYYYmmdd-HHMMSS.mp4)
  --quicktime <mode>  on: ensure QuickTime-compatible output (default)
                      off: keep original codec after download
  -h, --help          Show help

Notes:
  - Direct .mp4/.m3u8 links are downloaded with ffmpeg.
  - Webpage links are downloaded with yt-dlp.
  - QuickTime compatibility target: H.264 video + AAC audio in .mp4.
EOF
}

# Exit early with a clear error if required command is missing.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Missing required command: $1" >&2
    exit 1
  }
}

# Detect whether URL is a direct media path supported by ffmpeg copy.
is_direct_media_url() {
  local u
  u="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  [[ "$u" == *.mp4 || "$u" == *.mp4\?* || "$u" == *.m3u8 || "$u" == *.m3u8\?* ]]
}

# Find an executable yt-dlp command.
# Supports:
# - yt-dlp in PATH
# - pip --user install default path on macOS Python 3.9
# - python module invocation fallback
pick_ytdlp_cmd() {
  if command -v yt-dlp >/dev/null 2>&1; then
    YTDLP_CMD=("yt-dlp")
    return 0
  fi
  if [[ -x "${HOME}/Library/Python/3.9/bin/yt-dlp" ]]; then
    YTDLP_CMD=("${HOME}/Library/Python/3.9/bin/yt-dlp")
    return 0
  fi
  if python3 -m yt_dlp --version >/dev/null 2>&1; then
    YTDLP_CMD=("python3" "-m" "yt_dlp")
    return 0
  fi
  return 1
}

# Read first value of a stream field via ffprobe.
probe_stream_field() {
  local file="$1"
  local selector="$2"
  local field="$3"
  ffprobe -v error -select_streams "$selector" -show_entries "stream=${field}" -of csv=p=0 "$file" 2>/dev/null | head -n 1
}

# Check if a video is likely QuickTime-friendly on older macOS:
# - Video codec: h264
# - Pixel format: yuv420p/yuvj420p
# - Audio codec: aac (or no audio stream)
is_quicktime_compatible() {
  local file="$1"
  local vcodec pixfmt acodec
  vcodec="$(probe_stream_field "$file" "v:0" "codec_name" || true)"
  pixfmt="$(probe_stream_field "$file" "v:0" "pix_fmt" || true)"
  acodec="$(probe_stream_field "$file" "a:0" "codec_name" || true)"

  [[ "$vcodec" == "h264" ]] || return 1
  [[ "$pixfmt" == "yuv420p" || "$pixfmt" == "yuvj420p" ]] || return 1
  if [[ -n "$acodec" && "$acodec" != "aac" ]]; then
    return 1
  fi
  return 0
}

# Move/transcode into final output according to quicktime mode.
finalize_output() {
  local src="$1"
  local dst="$2"

  if [[ "$QUICKTIME_MODE" == "off" ]]; then
    if [[ "$src" != "$dst" ]]; then
      mv -f "$src" "$dst"
    fi
    echo "[OK] Video downloaded: $dst"
    return 0
  fi

  if is_quicktime_compatible "$src"; then
    echo "[INFO] Source is already QuickTime-compatible."
    if [[ "$src" != "$dst" ]]; then
      mv -f "$src" "$dst"
    fi
    echo "[OK] Video downloaded: $dst"
    return 0
  fi

  echo "[INFO] Transcoding to QuickTime-compatible MP4 (H.264 + AAC)..."
  local has_audio
  has_audio="$(probe_stream_field "$src" "a:0" "codec_name" || true)"
  if [[ -n "$has_audio" ]]; then
    ffmpeg -y -i "$src" \
      -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
      -c:a aac -b:a 192k \
      "$dst"
  else
    ffmpeg -y -i "$src" \
      -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
      -an \
      "$dst"
  fi

  if [[ "$src" != "$dst" ]]; then
    rm -f "$src"
  fi
  echo "[OK] Video downloaded: $dst"
}

# Defaults: output to Desktop if user does not specify --output.
URL=""
OUTPUT="${HOME}/Desktop/video-$(date +%Y%m%d-%H%M%S).mp4"
QUICKTIME_MODE="on"
DOWNLOAD_OUTPUT="$OUTPUT"
TEMP_OUTPUT=""

cleanup() {
  if [[ -n "${TEMP_OUTPUT:-}" && -f "$TEMP_OUTPUT" ]]; then
    rm -f "$TEMP_OUTPUT"
  fi
}
trap cleanup EXIT

# Parse command-line options.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      URL="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --quicktime)
      QUICKTIME_MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$URL" ]]; then
  echo "[ERROR] --url is required." >&2
  usage
  exit 1
fi

require_cmd ffmpeg
require_cmd ffprobe
# Create output parent directory when needed.
mkdir -p "$(dirname "$OUTPUT")"

if ! [[ "$QUICKTIME_MODE" =~ ^(on|off)$ ]]; then
  echo "[ERROR] --quicktime must be one of: on, off" >&2
  exit 1
fi

if [[ "$QUICKTIME_MODE" == "on" ]]; then
  TEMP_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/ffmpeg-tools-video-XXXXXX.mp4")"
  DOWNLOAD_OUTPUT="$TEMP_OUTPUT"
fi

# Direct-media path:
# ffmpeg handles direct mp4/m3u8 links efficiently.
if is_direct_media_url "$URL" || [[ -f "$URL" ]]; then
  echo "[INFO] Using ffmpeg for direct media URL/path..."
  if ffmpeg -y -i "$URL" -c copy "$DOWNLOAD_OUTPUT"; then
    finalize_output "$DOWNLOAD_OUTPUT" "$OUTPUT"
    exit 0
  fi
  # If direct download failed and yt-dlp is available, try yt-dlp once.
  if pick_ytdlp_cmd; then
    echo "[WARN] ffmpeg direct copy failed; trying yt-dlp fallback..."
    "${YTDLP_CMD[@]}" \
      --no-playlist \
      --no-part \
      -f "bv*+ba/b" \
      --merge-output-format mp4 \
      -o "$DOWNLOAD_OUTPUT" \
      "$URL"
    finalize_output "$DOWNLOAD_OUTPUT" "$OUTPUT"
    exit 0
  fi
  echo "[ERROR] ffmpeg failed downloading direct URL/path: $URL" >&2
  exit 1
fi

# Webpage path:
# yt-dlp parses webpage and fetches actual media streams.
if pick_ytdlp_cmd; then
  echo "[INFO] Using yt-dlp for webpage URL..."
  "${YTDLP_CMD[@]}" \
    --no-playlist \
    --no-part \
    -f "bv*+ba/b" \
    --merge-output-format mp4 \
    -o "$DOWNLOAD_OUTPUT" \
    "$URL"
  finalize_output "$DOWNLOAD_OUTPUT" "$OUTPUT"
  exit 0
fi

# If fallback failed, provide actionable guidance.
cat >&2 <<'EOF'
[ERROR] This URL is not a direct .mp4/.m3u8 stream and yt-dlp was not found.
Install yt-dlp, then retry:
  python3 -m pip install --user -U yt-dlp
If installed via pip --user, ensure this path is in PATH:
  export PATH="$HOME/Library/Python/3.9/bin:$PATH"
EOF
exit 1
