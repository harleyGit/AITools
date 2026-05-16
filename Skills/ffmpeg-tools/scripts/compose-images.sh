#!/usr/bin/env bash
# Compose multiple images into one image using FFmpeg.
# Supports:
# - directories (auto-discover images)
# - individual files
# - comma-separated file lists (e.g. 1.png,2.png,3.png,4.png)
# - relative paths from current working directory
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  compose-images.sh [options] <image_or_dir> [image_or_dir ...]

Options:
  --mode <grid|h|v>     Stitch mode (default: grid)
  --cols <N>            Grid columns when --mode=grid (default: 2)
  --cell <WxH>          Target cell size. Default: auto-detect max input WxH
  --resize <none|contain>
                        none: do not scale, only pad (default)
                        contain: shrink-to-fit cell if needed, keep ratio
  --compress <on|off|match>
                        on: smaller file size (default)
                        off: no encoder compression
                        match: try to match total input size
  --jpg-quality <1-31>  JPEG quality (lower is better, default: 3)
  --bg <color>          Pad background color (default: black)
  --output <path>       Output image path (default: ~/Desktop/hl_xxYxxMxxDxxs.png)
  -h, --help            Show help

Examples:
  compose-images.sh --mode grid --cols 2 --output ~/Desktop/hl_custom.png ~/Desktop/input-images
  compose-images.sh --mode h --cell 1024x1024 a.jpg b.jpg c.jpg
  compose-images.sh --mode grid --cols 2 1.png,2.png,3.png,4.png
EOF
}

# Exit early with a clear error if required commands are missing.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Missing required command: $1" >&2
    exit 1
  }
}

# Lightweight image-extension check.
is_image_file() {
  local f="$1"
  [[ "$f" =~ \.(jpg|jpeg|png|bmp|webp|tif|tiff)$ ]] || [[ "$f" =~ \.(JPG|JPEG|PNG|BMP|WEBP|TIF|TIFF)$ ]]
}

# Trim leading/trailing whitespace from an argument token.
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Expand one raw argument into one or many paths.
# Accept both English comma "," and Chinese comma "，".
expand_arg_tokens() {
  local raw="$1"
  local normalized="${raw//，/,}"
  local t

  if [[ "$normalized" == *","* ]]; then
    IFS=',' read -r -a _parts <<< "$normalized"
    for t in "${_parts[@]}"; do
      t="$(trim "$t")"
      [[ -n "$t" ]] && printf '%s\n' "$t"
    done
  else
    t="$(trim "$normalized")"
    [[ -n "$t" ]] && printf '%s\n' "$t"
  fi
}

# Read width/height of an image using ffprobe, output as "W H".
probe_size() {
  local f="$1"
  local wh
  wh="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$f" 2>/dev/null || true)"
  if [[ -z "$wh" ]] || [[ "$wh" != *x* ]]; then
    return 1
  fi
  printf '%s %s\n' "${wh%x*}" "${wh#*x}"
}

# Return file size in bytes (macOS/Linux compatible).
file_size_bytes() {
  local f="$1"
  if stat -f %z "$f" >/dev/null 2>&1; then
    stat -f %z "$f"
  else
    stat -c %s "$f"
  fi
}

# Return absolute difference between two integers.
abs_diff() {
  local a="$1"
  local b="$2"
  if (( a >= b )); then
    echo $((a - b))
  else
    echo $((b - a))
  fi
}

# Defaults: output to Desktop if user does not specify --output.
MODE="grid"
COLS=2
CELL=""
RESIZE_MODE="none"
COMPRESS_MODE="on"
JPG_QUALITY=3
BG="black"
OUTPUT="${HOME}/Desktop/hl_$(date +%yY%mM%dD%Ss).png"

ARGS=()
# Parse command-line options and collect positional inputs.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --cols)
      COLS="${2:-}"
      shift 2
      ;;
    --cell)
      CELL="${2:-}"
      shift 2
      ;;
    --resize)
      RESIZE_MODE="${2:-}"
      shift 2
      ;;
    --compress)
      COMPRESS_MODE="${2:-}"
      shift 2
      ;;
    --jpg-quality)
      JPG_QUALITY="${2:-}"
      shift 2
      ;;
    --bg)
      BG="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        ARGS+=("$1")
        shift
      done
      ;;
    -*)
      echo "[ERROR] Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

require_cmd ffmpeg
require_cmd ffprobe

if [[ "${#ARGS[@]}" -eq 0 ]]; then
  echo "[ERROR] Provide at least one image path or directory." >&2
  usage
  exit 1
fi

if ! [[ "$MODE" =~ ^(grid|h|v)$ ]]; then
  echo "[ERROR] --mode must be one of: grid, h, v" >&2
  exit 1
fi

if ! [[ "$COLS" =~ ^[0-9]+$ ]] || [[ "$COLS" -lt 1 ]]; then
  echo "[ERROR] --cols must be a positive integer." >&2
  exit 1
fi

if ! [[ "$CELL" =~ ^[0-9]+x[0-9]+$ ]]; then
  if [[ -n "$CELL" ]]; then
    echo "[ERROR] --cell must be in WxH format, e.g. 1280x720." >&2
    exit 1
  fi
fi

if ! [[ "$RESIZE_MODE" =~ ^(none|contain)$ ]]; then
  echo "[ERROR] --resize must be one of: none, contain" >&2
  exit 1
fi

if ! [[ "$COMPRESS_MODE" =~ ^(on|off|match)$ ]]; then
  echo "[ERROR] --compress must be one of: on, off, match" >&2
  exit 1
fi

if ! [[ "$JPG_QUALITY" =~ ^[0-9]+$ ]] || (( JPG_QUALITY < 1 || JPG_QUALITY > 31 )); then
  echo "[ERROR] --jpg-quality must be an integer in [1, 31]." >&2
  exit 1
fi

# Resolve positional inputs into concrete image files:
# - directory => include all supported image files (top-level only)
# - file => include if it is an image
# - comma-separated list => split first, then resolve each entry
INPUTS=()
for raw in "${ARGS[@]}"; do
  while IFS= read -r p; do
    if [[ -d "$p" ]]; then
      while IFS= read -r -d '' f; do
        INPUTS+=("$f")
      done < <(find "$p" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.webp' -o -iname '*.tif' -o -iname '*.tiff' \) -print0 | sort -z)
    elif [[ -f "$p" ]]; then
      if is_image_file "$p"; then
        INPUTS+=("$p")
      else
        echo "[WARN] Skip non-image file: $p" >&2
      fi
    else
      echo "[WARN] Path not found, skip: $p" >&2
    fi
  done < <(expand_arg_tokens "$raw")
done

if [[ "${#INPUTS[@]}" -lt 2 ]]; then
  echo "[ERROR] Need at least 2 valid images. Found: ${#INPUTS[@]}" >&2
  exit 1
fi

# Detect max input dimensions. Used for default no-scale behavior.
MAX_W=0
MAX_H=0
declare -a INPUT_W
declare -a INPUT_H
for i in "${!INPUTS[@]}"; do
  if ! read -r iw ih < <(probe_size "${INPUTS[$i]}"); then
    echo "[ERROR] Failed to read image dimensions: ${INPUTS[$i]}" >&2
    exit 1
  fi
  INPUT_W[$i]="$iw"
  INPUT_H[$i]="$ih"
  (( iw > MAX_W )) && MAX_W="$iw"
  (( ih > MAX_H )) && MAX_H="$ih"
done

# If --cell is omitted, preserve quality by not scaling:
# choose the max input size and pad smaller images.
if [[ -z "$CELL" ]]; then
  CELL_W="$MAX_W"
  CELL_H="$MAX_H"
else
  CELL_W="${CELL%x*}"
  CELL_H="${CELL#*x}"
fi

# In no-resize mode, reject too-small cells to avoid hidden downscaling.
if [[ "$RESIZE_MODE" == "none" ]]; then
  for i in "${!INPUTS[@]}"; do
    iw="${INPUT_W[$i]}"
    ih="${INPUT_H[$i]}"
    if (( iw > CELL_W || ih > CELL_H )); then
      echo "[ERROR] Input larger than --cell with --resize none: ${INPUTS[$i]} (${iw}x${ih}) > ${CELL_W}x${CELL_H}" >&2
      echo "        Use a larger --cell or set --resize contain." >&2
      exit 1
    fi
  done
fi

# Ensure output parent directory exists.
mkdir -p "$(dirname "$OUTPUT")"

# Build ffmpeg input argument list: -i img1 -i img2 ...
FF_ARGS=(-y)
for f in "${INPUTS[@]}"; do
  FF_ARGS+=(-i "$f")
done

# Build filter graph:
# 1) normalize each image into fixed WxH cell by scale+pad
# 2) combine cells using hstack/vstack/xstack depending on --mode
FILTER=""
for i in "${!INPUTS[@]}"; do
  if [[ "$RESIZE_MODE" == "contain" ]]; then
    FILTER+="[${i}:v]scale=w=iw*min(1\\,min(${CELL_W}/iw\\,${CELL_H}/ih)):h=ih*min(1\\,min(${CELL_W}/iw\\,${CELL_H}/ih)),pad=${CELL_W}:${CELL_H}:(${CELL_W}-iw)/2:(${CELL_H}-ih)/2:color=${BG},setsar=1[v${i}];"
  else
    FILTER+="[${i}:v]pad=${CELL_W}:${CELL_H}:(${CELL_W}-iw)/2:(${CELL_H}-ih)/2:color=${BG},setsar=1[v${i}];"
  fi
done

N="${#INPUTS[@]}"
STACK_IN=""
for i in "${!INPUTS[@]}"; do
  STACK_IN+="[v${i}]"
done

case "$MODE" in
  h)
    FILTER+="${STACK_IN}hstack=inputs=${N}[out]"
    ;;
  v)
    FILTER+="${STACK_IN}vstack=inputs=${N}[out]"
    ;;
  grid)
    LAYOUT=""
    for i in "${!INPUTS[@]}"; do
      col=$(( i % COLS ))
      row=$(( i / COLS ))

      if [[ "$col" -eq 0 ]]; then
        x="0"
      elif [[ "$col" -eq 1 ]]; then
        x="w0"
      else
        x="${col}*w0"
      fi

      if [[ "$row" -eq 0 ]]; then
        y="0"
      elif [[ "$row" -eq 1 ]]; then
        y="h0"
      else
        y="${row}*h0"
      fi

      pos="${x}_${y}"
      if [[ -z "$LAYOUT" ]]; then
        LAYOUT="$pos"
      else
        LAYOUT="${LAYOUT}|${pos}"
      fi
    done
    FILTER+="${STACK_IN}xstack=inputs=${N}:layout=${LAYOUT}[out]"
    ;;
esac

# Render one output frame as the final montage image.
# Default output is PNG (lossless). For JPG output, use highest quality.
OUTPUT_EXT="${OUTPUT##*.}"
OUTPUT_EXT="$(printf '%s' "$OUTPUT_EXT" | tr '[:upper:]' '[:lower:]')"

# Calculate total source bytes for --compress match.
TARGET_BYTES=0
for f in "${INPUTS[@]}"; do
  sz="$(file_size_bytes "$f")"
  TARGET_BYTES=$((TARGET_BYTES + sz))
done

if [[ "$OUTPUT_EXT" == "png" ]]; then
  if [[ "$COMPRESS_MODE" == "on" ]]; then
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -c:v png -compression_level 9 "$OUTPUT"
  elif [[ "$COMPRESS_MODE" == "off" ]]; then
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -c:v png -compression_level 0 "$OUTPUT"
  else
    # PNG is lossless; only limited size tuning is possible via compression level.
    # Try both ends and keep the one closer to source total bytes.
    tmp_dir="$(mktemp -d)"
    tmp_l0="${tmp_dir}/l0.png"
    tmp_l9="${tmp_dir}/l9.png"
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -c:v png -compression_level 0 "$tmp_l0" >/dev/null 2>&1
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -c:v png -compression_level 9 "$tmp_l9" >/dev/null 2>&1
    size_l0="$(file_size_bytes "$tmp_l0")"
    size_l9="$(file_size_bytes "$tmp_l9")"
    diff_l0="$(abs_diff "$size_l0" "$TARGET_BYTES")"
    diff_l9="$(abs_diff "$size_l9" "$TARGET_BYTES")"
    if (( diff_l9 <= diff_l0 )); then
      cp "$tmp_l9" "$OUTPUT"
      picked="9"
      picked_size="$size_l9"
    else
      cp "$tmp_l0" "$OUTPUT"
      picked="0"
      picked_size="$size_l0"
    fi
    rm -rf "$tmp_dir"
    echo "[INFO] match mode (PNG) picked compression_level=${picked}, output=${picked_size} bytes, input_total=${TARGET_BYTES} bytes." >&2
    echo "[WARN] PNG is lossless; for tighter size matching, output as .jpg with --compress match." >&2
  fi
elif [[ "$OUTPUT_EXT" == "jpg" || "$OUTPUT_EXT" == "jpeg" ]]; then
  if [[ "$COMPRESS_MODE" == "on" ]]; then
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -q:v "$JPG_QUALITY" "$OUTPUT"
  elif [[ "$COMPRESS_MODE" == "off" ]]; then
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -q:v 1 "$OUTPUT"
    echo "[WARN] JPG is always lossy. --compress off uses highest JPEG quality (q=1)." >&2
  else
    # For JPEG, sweep quality 1..31 and pick the closest file size to input total.
    tmp_dir="$(mktemp -d)"
    best_q=1
    best_diff=-1
    best_size=0
    for q in $(seq 1 31); do
      tmp_out="${tmp_dir}/q${q}.jpg"
      ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -q:v "$q" "$tmp_out" >/dev/null 2>&1
      current_size="$(file_size_bytes "$tmp_out")"
      current_diff="$(abs_diff "$current_size" "$TARGET_BYTES")"
      if (( best_diff == -1 || current_diff < best_diff )); then
        best_q="$q"
        best_diff="$current_diff"
        best_size="$current_size"
      fi
    done
    cp "${tmp_dir}/q${best_q}.jpg" "$OUTPUT"
    rm -rf "$tmp_dir"
    echo "[INFO] match mode (JPG) picked q=${best_q}, output=${best_size} bytes, input_total=${TARGET_BYTES} bytes." >&2
  fi
  echo "[WARN] JPG is lossy. Use .png output for lossless quality." >&2
else
  if [[ "$COMPRESS_MODE" == "match" ]]; then
    echo "[WARN] --compress match is optimized for png/jpg outputs; applying default encoding for .$OUTPUT_EXT." >&2
  fi
  ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 "$OUTPUT"
fi
echo "[OK] Image montage saved: $OUTPUT"
