#!/usr/bin/env bash
# =============================================================================
# 图片拼接脚本 - compose-images.sh
# =============================================================================
# 功能：将多张图片拼接成一张图片
#
# 支持的输入方式：
# - 目录：自动发现目录中的所有图片
# - 单个文件：直接指定图片文件路径
# - 逗号分隔的文件列表：如 "1.png,2.png,3.png,4.png"
# - 相对路径：基于当前工作目录
#
# 支持的拼接模式：
# - grid：网格布局（默认，可指定列数）
# - h：水平拼接（所有图片排成一行）
# - v：垂直拼接（所有图片排成一列）
#
# 支持的图片格式：
# - JPG/JPEG、PNG、BMP、WebP、TIFF
#
# 依赖工具：
# - ffmpeg：用于图片处理和拼接
# - ffprobe：用于读取图片尺寸信息
#
# 给初学者的阅读提示：
# - 这个脚本的核心是“先把每张图片变成同样大小的单元格，再用 ffmpeg 滤镜拼起来”。
# - hstack 用于横向拼接，vstack 用于纵向拼接，xstack 用于网格拼接。
# - Bash 数组用于安全保存包含空格的文件路径，例如 INPUTS=("a b.jpg" "c.png")。
# - 主要流程是：解析参数 -> 收集图片 -> 读取尺寸 -> 生成滤镜图 -> 调用 ffmpeg 输出。
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
  compose-images.sh [options] <image_or_dir> [image_or_dir ...]

Options:
  --mode <grid|h|v>     拼接模式（默认：grid）
                        grid：网格布局（可指定列数）
                        h：水平拼接（所有图片排成一行）
                        v：垂直拼接（所有图片排成一列）
  --cols <N>            网格模式下的列数（默认：2）
  --cell <WxH>          单元格尺寸（默认：自动检测输入图片的最大宽高）
                        格式：宽x高，如 1280x720
  --resize <none|contain>
                        none：不缩放，只填充（默认）
                        contain：按比例缩放以适应单元格
  --compress <on|off|match>
                        on：压缩文件大小（默认）
                        off：不压缩（最高质量）
                        match：尝试匹配输入文件的总大小
  --jpg-quality <1-31>  JPEG质量（值越小质量越好，默认：3）
  --bg <color>          填充背景颜色（默认：black）
  --output <path>       输出图片路径（默认：~/Desktop/hl_xxYxxMxxDxxs.png）
  -h, --help            显示帮助信息

Examples:
  # 将目录中的图片拼接成2列的网格
  compose-images.sh --mode grid --cols 2 --output ~/Desktop/result.png ~/Desktop/input-images

  # 将三张图片水平拼接，每张图片尺寸为1024x1024
  compose-images.sh --mode h --cell 1024x1024 a.jpg b.jpg c.jpg

  # 使用逗号分隔的文件列表
  compose-images.sh --mode grid --cols 2 1.png,2.png,3.png,4.png
EOF
}

# =============================================================================
# 函数：require_cmd()
# 功能：检查系统中是否安装了指定的命令
# 参数：$1 = 命令名称（如 ffmpeg, ffprobe）
# 如果命令不存在，显示错误信息并退出脚本
# =============================================================================
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Missing required command: $1" >&2
    exit 1
  }
}

# =============================================================================
# 函数：is_image_file()
# 功能：检查文件是否是支持的图片格式
# 参数：$1 = 文件路径
# 返回值：是图片返回0（真），不是返回1（假）
#
# 支持的格式：jpg, jpeg, png, bmp, webp, tif, tiff（不区分大小写）
# 使用正则表达式匹配文件扩展名
# =============================================================================
is_image_file() {
  local f="$1"
  # =~ 是 Bash 的正则匹配运算符
  # \.(jpg|jpeg|png|bmp|webp|tif|tiff)$ 匹配以这些扩展名结尾的文件名
  [[ "$f" =~ \.(jpg|jpeg|png|bmp|webp|tif|tiff)$ ]] || [[ "$f" =~ \.(JPG|JPEG|PNG|BMP|WEBP|TIF|TIFF)$ ]]
}

# =============================================================================
# 函数：trim()
# 功能：去除字符串开头和结尾的空白字符（空格、制表符等）
# 参数：$1 = 输入字符串
# 返回值：去除空白后的字符串
#
# 原理：
# ${s#"${s%%[![:space:]]*}"} 去除开头的空白
# ${s%"${s##*[![:space:]]}"} 去除结尾的空白
# =============================================================================
trim() {
  local s="$1"
  # 去除开头的空白字符
  s="${s#"${s%%[![:space:]]*}"}"
  # 去除结尾的空白字符
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# =============================================================================
# 函数：expand_arg_tokens()
# 功能：将一个参数展开为一个或多个路径
# 参数：$1 = 原始参数（可能是逗号分隔的列表）
# 输出：每行一个路径
#
# 支持：
# - 英文逗号 "," 分隔
# - 中文逗号 "，" 分隔（自动转换为英文逗号）
# - 去除每个路径的前后空白
#
# 示例：
# expand_arg_tokens "1.png,2.png,3.png" 输出：
# 1.png
# 2.png
# 3.png
# =============================================================================
expand_arg_tokens() {
  local raw="$1"
  # 将中文逗号替换为英文逗号
  local normalized="${raw//，/,}"
  local t

  # 如果包含逗号，按逗号分割
  if [[ "$normalized" == *","* ]]; then
    # IFS=',' 设置分隔符为逗号
    # read -r -a _parts 将分割后的结果存入数组 _parts
    IFS=',' read -r -a _parts <<< "$normalized"
    for t in "${_parts[@]}"; do
      # 去除空白
      t="$(trim "$t")"
      # 如果非空，输出
      [[ -n "$t" ]] && printf '%s\n' "$t"
    done
  else
    # 单个路径，直接输出
    t="$(trim "$normalized")"
    [[ -n "$t" ]] && printf '%s\n' "$t"
  fi
}

# =============================================================================
# 函数：probe_size()
# 功能：使用 ffprobe 读取图片的宽度和高度
# 参数：$1 = 图片文件路径
# 输出："宽度 高度"（如 "1920 1080"）
# 返回值：成功返回0，失败返回1
#
# ffprobe 参数说明：
# -v error：只显示错误信息
# -select_streams v:0：选择第一个视频流（图片被视为单帧视频）
# -show_entries stream=width,height：只显示宽度和高度字段
# -of csv=p=0:s=x：输出为CSV格式，分隔符为x，不显示前缀
# =============================================================================
probe_size() {
  local f="$1"
  local wh
  # 读取图片尺寸，格式如 "1920x1080"
  wh="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$f" 2>/dev/null || true)"
  # 检查是否成功获取到尺寸
  if [[ -z "$wh" ]] || [[ "$wh" != *x* ]]; then
    return 1
  fi
  # 将 "1920x1080" 转换为 "1920 1080" 输出
  printf '%s %s\n' "${wh%x*}" "${wh#*x}"
}

# =============================================================================
# 函数：file_size_bytes()
# 功能：获取文件的大小（字节数）
# 参数：$1 = 文件路径
# 返回值：文件大小（字节）
#
# 兼容 macOS 和 Linux：
# - macOS 使用 stat -f %z
# - Linux 使用 stat -c %s
# =============================================================================
file_size_bytes() {
  local f="$1"
  # 尝试 macOS 的 stat 命令
  if stat -f %z "$f" >/dev/null 2>&1; then
    stat -f %z "$f"
  else
    # 使用 Linux 的 stat 命令
    stat -c %s "$f"
  fi
}

# =============================================================================
# 函数：abs_diff()
# 功能：计算两个整数的绝对差值
# 参数：$1 = 第一个数，$2 = 第二个数
# 返回值：|a - b|
#
# 用于比较文件大小差异
# =============================================================================
abs_diff() {
  local a="$1"
  local b="$2"
  if (( a >= b )); then
    echo $((a - b))
  else
    echo $((b - a))
  fi
}

# =============================================================================
# 变量初始化：设置默认值
# =============================================================================

# MODE：拼接模式，grid=网格，h=水平，v=垂直
MODE="grid"
# COLS：网格模式下的列数
COLS=2
# CELL：单元格尺寸（宽x高），为空则自动检测
CELL=""
# RESIZE_MODE：缩放模式，none=不缩放，contain=按比例缩放
RESIZE_MODE="none"
# COMPRESS_MODE：压缩模式，on=压缩，off=不压缩，match=匹配输入大小
COMPRESS_MODE="on"
# JPG_QUALITY：JPEG质量（1-31，值越小质量越好）
JPG_QUALITY=3
# BG：填充背景颜色
BG="black"
# OUTPUT：输出文件路径，默认保存到桌面
OUTPUT="${HOME}/Desktop/hl_$(date +%yY%mM%dD%Ss).png"

# ARGS：存储位置参数（图片路径或目录）
ARGS=()

# =============================================================================
# 命令行参数解析
# while 循环遍历所有参数
# $# 表示参数的数量，-gt 0 表示大于0
# =============================================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    # --mode 参数：拼接模式
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    # --cols 参数：网格列数
    --cols)
      COLS="${2:-}"
      shift 2
      ;;
    # --cell 参数：单元格尺寸
    --cell)
      CELL="${2:-}"
      shift 2
      ;;
    # --resize 参数：缩放模式
    --resize)
      RESIZE_MODE="${2:-}"
      shift 2
      ;;
    # --compress 参数：压缩模式
    --compress)
      COMPRESS_MODE="${2:-}"
      shift 2
      ;;
    # --jpg-quality 参数：JPEG质量
    --jpg-quality)
      JPG_QUALITY="${2:-}"
      shift 2
      ;;
    # --bg 参数：背景颜色
    --bg)
      BG="${2:-}"
      shift 2
      ;;
    # --output 参数：输出路径
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    # -h 或 --help 参数：显示帮助
    -h|--help)
      usage
      exit 0
      ;;
    # -- 参数：后面的都是位置参数
    --)
      shift
      while [[ $# -gt 0 ]]; do
        ARGS+=("$1")
        shift
      done
      ;;
    # 以 - 开头的未知选项：报错
    -*)
      echo "[ERROR] Unknown option: $1" >&2
      usage
      exit 1
      ;;
    # 其他参数：作为位置参数（图片路径）
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

# =============================================================================
# 检查依赖工具
# =============================================================================
require_cmd ffmpeg
require_cmd ffprobe

# =============================================================================
# 参数验证：检查是否有输入图片
# =============================================================================
if [[ "${#ARGS[@]}" -eq 0 ]]; then
  echo "[ERROR] Provide at least one image path or directory." >&2
  usage
  exit 1
fi

# 验证 MODE 参数
if ! [[ "$MODE" =~ ^(grid|h|v)$ ]]; then
  echo "[ERROR] --mode must be one of: grid, h, v" >&2
  exit 1
fi

# 验证 COLS 参数（必须是正整数）
if ! [[ "$COLS" =~ ^[0-9]+$ ]] || [[ "$COLS" -lt 1 ]]; then
  echo "[ERROR] --cols must be a positive integer." >&2
  exit 1
fi

# 验证 CELL 参数（必须是 宽x高 格式）
if ! [[ "$CELL" =~ ^[0-9]+x[0-9]+$ ]]; then
  if [[ -n "$CELL" ]]; then
    echo "[ERROR] --cell must be in WxH format, e.g. 1280x720." >&2
    exit 1
  fi
fi

# 验证 RESIZE_MODE 参数
if ! [[ "$RESIZE_MODE" =~ ^(none|contain)$ ]]; then
  echo "[ERROR] --resize must be one of: none, contain" >&2
  exit 1
fi

# 验证 COMPRESS_MODE 参数
if ! [[ "$COMPRESS_MODE" =~ ^(on|off|match)$ ]]; then
  echo "[ERROR] --compress must be one of: on, off, match" >&2
  exit 1
fi

# 验证 JPG_QUALITY 参数（必须是1-31的整数）
if ! [[ "$JPG_QUALITY" =~ ^[0-9]+$ ]] || (( JPG_QUALITY < 1 || JPG_QUALITY > 31 )); then
  echo "[ERROR] --jpg-quality must be an integer in [1, 31]." >&2
  exit 1
fi

# =============================================================================
# 解析输入参数：将目录、文件、逗号分隔列表转换为具体的图片文件路径
# =============================================================================
# INPUTS 数组：存储所有要拼接的图片文件路径
INPUTS=()

for raw in "${ARGS[@]}"; do
  # expand_arg_tokens 将逗号分隔的列表展开为多行
  while IFS= read -r p; do
    if [[ -d "$p" ]]; then
      # 如果是目录：查找目录中的所有图片文件
      # find 命令说明：
      # "$p"：搜索的目录
      # -maxdepth 1：只搜索当前目录，不递归子目录
      # -type f：只查找文件
      # \( -iname '*.jpg' ... \)：匹配图片扩展名（-iname 不区分大小写）
      # -print0：用空字符分隔文件名（处理包含空格的文件名）
      # sort -z：用空字符分隔排序
      while IFS= read -r -d '' f; do
        INPUTS+=("$f")
      done < <(find "$p" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.bmp' -o -iname '*.webp' -o -iname '*.tif' -o -iname '*.tiff' \) -print0 | sort -z)
    elif [[ -f "$p" ]]; then
      # 如果是文件：检查是否是图片
      if is_image_file "$p"; then
        INPUTS+=("$p")
      else
        echo "[WARN] Skip non-image file: $p" >&2
      fi
    else
      # 路径不存在
      echo "[WARN] Path not found, skip: $p" >&2
    fi
  done < <(expand_arg_tokens "$raw")
done

# 至少需要2张图片才能拼接
if [[ "${#INPUTS[@]}" -lt 2 ]]; then
  echo "[ERROR] Need at least 2 valid images. Found: ${#INPUTS[@]}" >&2
  exit 1
fi

# =============================================================================
# 检测所有输入图片的尺寸，找出最大的宽度和高度
# 用于默认的单元格尺寸（如果不指定 --cell）
# =============================================================================
# MAX_W, MAX_H：所有图片中的最大宽度和高度
MAX_W=0
MAX_H=0
# INPUT_W, INPUT_H：存储每张图片的宽度和高度
declare -a INPUT_W
declare -a INPUT_H

for i in "${!INPUTS[@]}"; do
  # 读取图片尺寸
  if ! read -r iw ih < <(probe_size "${INPUTS[$i]}"); then
    echo "[ERROR] Failed to read image dimensions: ${INPUTS[$i]}" >&2
    exit 1
  fi
  # 存储尺寸
  INPUT_W[$i]="$iw"
  INPUT_H[$i]="$ih"
  # 更新最大尺寸
  (( iw > MAX_W )) && MAX_W="$iw"
  (( ih > MAX_H )) && MAX_H="$ih"
done

# =============================================================================
# 确定单元格尺寸
# 如果未指定 --cell，使用所有图片中的最大尺寸
# =============================================================================
if [[ -z "$CELL" ]]; then
  # 未指定单元格尺寸，使用最大输入尺寸
  CELL_W="$MAX_W"
  CELL_H="$MAX_H"
else
  # 指定了单元格尺寸，解析 "宽x高" 格式
  CELL_W="${CELL%x*}"   # 提取宽度（x之前的部分）
  CELL_H="${CELL#*x}"   # 提取高度（x之后的部分）
fi

# =============================================================================
# 验证：在不缩放模式下，检查图片是否超过单元格尺寸
# =============================================================================
if [[ "$RESIZE_MODE" == "none" ]]; then
  for i in "${!INPUTS[@]}"; do
    iw="${INPUT_W[$i]}"
    ih="${INPUT_H[$i]}"
    # 如果图片尺寸超过单元格，报错
    if (( iw > CELL_W || ih > CELL_H )); then
      echo "[ERROR] Input larger than --cell with --resize none: ${INPUTS[$i]} (${iw}x${ih}) > ${CELL_W}x${CELL_H}" >&2
      echo "        Use a larger --cell or set --resize contain." >&2
      exit 1
    fi
  done
fi

# 创建输出目录（如果不存在）
# dirname "$OUTPUT" 会取出输出文件所在目录，例如 /tmp/out.png -> /tmp。
mkdir -p "$(dirname "$OUTPUT")"

# =============================================================================
# 构建 ffmpeg 输入参数
# 格式：-i img1 -i img2 -i img3 ...
# =============================================================================
# FF_ARGS 数组：存储 ffmpeg 的输入参数
FF_ARGS=(-y)  # -y：覆盖输出文件
for f in "${INPUTS[@]}"; do
  FF_ARGS+=(-i "$f")  # 添加每个输入文件
done

# =============================================================================
# 构建 ffmpeg 滤镜图（Filter Graph）
# 滤镜图用于处理和组合多个输入图像
# =============================================================================
# FILTER 字符串：存储完整的滤镜图
# ffmpeg 的 filter_complex 可以把多个输入流串联处理。
# 本脚本会先生成 [v0]、[v1] 这样的中间结果，再把它们交给 hstack/vstack/xstack。
FILTER=""

for i in "${!INPUTS[@]}"; do
  if [[ "$RESIZE_MODE" == "contain" ]]; then
    # contain 模式：按比例缩放以适应单元格，然后填充
    # 滤镜说明：
    # scale=w=iw*min(1,min(W/iw,H/ih)):h=ih*min(1,min(W/iw,H/ih))
    #   - 计算缩放比例，保持宽高比，确保不超过单元格尺寸
    #   - min(1,...) 确保不会放大（只缩小）
    # pad=W:H:(W-iw)/2:(H-ih)/2:color=bg
    #   - 将缩放后的图片放在单元格中心
    #   - 用指定颜色填充空白区域
    # setsar=1
    #   - 设置像素宽高比为1:1（正方形像素）
    FILTER+="[${i}:v]scale=w=iw*min(1\\,min(${CELL_W}/iw\\,${CELL_H}/ih)):h=ih*min(1\\,min(${CELL_W}/iw\\,${CELL_H}/ih)),pad=${CELL_W}:${CELL_H}:(${CELL_W}-iw)/2:(${CELL_H}-ih)/2:color=${BG},setsar=1[v${i}];"
  else
    # none 模式：不缩放，只填充（图片居中，空白用背景色填充）
    FILTER+="[${i}:v]pad=${CELL_W}:${CELL_H}:(${CELL_W}-iw)/2:(${CELL_H}-ih)/2:color=${BG},setsar=1[v${i}];"
  fi
done

# N：输入图片数量
N="${#INPUTS[@]}"

# STACK_IN：构建堆叠滤镜的输入引用，如 [v0][v1][v2][v3]
# ffmpeg 滤镜里的 [v0] 不是 Bash 变量，而是 ffmpeg 内部给视频流起的标签。
STACK_IN=""
for i in "${!INPUTS[@]}"; do
  STACK_IN+="[v${i}]"
done

# =============================================================================
# 根据拼接模式，添加组合滤镜
# =============================================================================
case "$MODE" in
  h)
    # 水平拼接：hstack 滤镜将多个输入水平排列
    FILTER+="${STACK_IN}hstack=inputs=${N}[out]"
    ;;
  v)
    # 垂直拼接：vstack 滤镜将多个输入垂直排列
    FILTER+="${STACK_IN}vstack=inputs=${N}[out]"
    ;;
  grid)
    # 网格拼接：xstack 滤镜将多个输入按指定布局排列
    # 需要计算每个图片在网格中的位置
    LAYOUT=""
    for i in "${!INPUTS[@]}"; do
      # 计算当前图片所在的列和行
      col=$(( i % COLS ))  # 列号 = 索引 % 列数
      row=$(( i / COLS ))  # 行号 = 索引 / 列数（整除）

      # 计算 x 坐标（水平位置）
      if [[ "$col" -eq 0 ]]; then
        x="0"           # 第一列：x=0
      elif [[ "$col" -eq 1 ]]; then
        x="w0"          # 第二列：x=第一个单元格的宽度
      else
        x="${col}*w0"   # 其他列：x=列号*单元格宽度
      fi

      # 计算 y 坐标（垂直位置）
      if [[ "$row" -eq 0 ]]; then
        y="0"           # 第一行：y=0
      elif [[ "$row" -eq 1 ]]; then
        y="h0"          # 第二行：y=第一个单元格的高度
      else
        y="${row}*h0"   # 其他行：y=行号*单元格高度
      fi

      # 构建位置字符串，格式：x_y
      pos="${x}_${y}"
      if [[ -z "$LAYOUT" ]]; then
        LAYOUT="$pos"
      else
        LAYOUT="${LAYOUT}|${pos}"  # 用 | 分隔多个位置
      fi
    done
    # xstack 滤镜：按布局排列所有输入
    FILTER+="${STACK_IN}xstack=inputs=${N}:layout=${LAYOUT}[out]"
    ;;
esac

# =============================================================================
# 确定输出格式并执行拼接
# =============================================================================
# 获取输出文件的扩展名（小写）
# 不同格式对应不同编码参数：PNG 可无损压缩，JPG 文件更小但有损。
OUTPUT_EXT="${OUTPUT##*.}"
OUTPUT_EXT="$(printf '%s' "$OUTPUT_EXT" | tr '[:upper:]' '[:lower:]')"

# =============================================================================
# 计算输入文件的总大小（字节）
# 用于 --compress match 模式
# =============================================================================
TARGET_BYTES=0
for f in "${INPUTS[@]}"; do
  sz="$(file_size_bytes "$f")"
  TARGET_BYTES=$((TARGET_BYTES + sz))
done

# =============================================================================
# 计算像素比例
# 用于估算输出文件的预期大小
# 原理：如果输出像素是输入的4倍，文件大小也应该大约是4倍
# =============================================================================
# TOTAL_INPUT_PIXELS：所有输入图片的像素总数
TOTAL_INPUT_PIXELS=0
for i in "${!INPUTS[@]}"; do
  iw="${INPUT_W[$i]}"
  ih="${INPUT_H[$i]}"
  TOTAL_INPUT_PIXELS=$((TOTAL_INPUT_PIXELS + iw * ih))
done
# OUTPUT_PIXELS：输出图片的像素总数
OUTPUT_PIXELS=$((CELL_W * CELL_H * N))

# =============================================================================
# 根据输出格式和压缩模式执行拼接
# =============================================================================
if [[ "$OUTPUT_EXT" == "png" ]]; then
  # ==================== PNG 格式输出 ====================
  if [[ "$COMPRESS_MODE" == "on" ]]; then
    # 压缩模式：使用压缩级别6（平衡大小和速度）
    # ffmpeg 参数说明：
    # "${FF_ARGS[@]}"：输入文件参数
    # -filter_complex "$FILTER"：应用滤镜图
    # -map "[out]"：选择滤镜图的输出流
    # -frames:v 1：只输出一帧（因为是静态图片）
    # -c:v png：使用PNG编码器
    # -compression_level 6：压缩级别（0=无压缩，9=最大压缩）
    # "$OUTPUT"：输出文件路径
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -c:v png -compression_level 6 "$OUTPUT"
  elif [[ "$COMPRESS_MODE" == "off" ]]; then
    # 不压缩模式：使用压缩级别0（最快，文件最大）
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -c:v png -compression_level 0 "$OUTPUT"
  else
    # match 模式：尝试所有压缩级别，选择最接近目标大小的
    # PNG 是无损格式，文件大小由内容和压缩级别决定
    tmp_dir="$(mktemp -d)"  # 创建临时目录
    best_level=6
    best_diff=-1
    best_size=0
    # 尝试压缩级别 0-9
    for level in 0 1 2 3 4 5 6 7 8 9; do
      tmp_out="${tmp_dir}/l${level}.png"
      # 使用指定压缩级别生成临时文件
      ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -c:v png -compression_level "$level" "$tmp_out" >/dev/null 2>&1
      # 获取文件大小
      current_size="$(file_size_bytes "$tmp_out")"
      # 计算与目标的差异
      current_diff="$(abs_diff "$current_size" "$TARGET_BYTES")"
      # 如果是目前最接近的，记录
      if (( best_diff == -1 || current_diff < best_diff )); then
        best_level="$level"
        best_diff="$current_diff"
        best_size="$current_size"
      fi
    done
    # 复制最佳结果到输出路径
    cp "${tmp_dir}/l${best_level}.png" "$OUTPUT"
    rm -rf "$tmp_dir"  # 清理临时目录
    echo "[INFO] match mode (PNG) picked compression_level=${best_level}, output=${best_size} bytes, input_total=${TARGET_BYTES} bytes." >&2
    # 如果输出大于输入，显示比例
    if (( best_size > TARGET_BYTES )); then
      ratio=$((best_size * 100 / TARGET_BYTES))
      echo "[INFO] Output is ${ratio}% of input total (pixel ratio: ${OUTPUT_PIXELS}/${TOTAL_INPUT_PIXELS})." >&2
    fi
  fi
elif [[ "$OUTPUT_EXT" == "jpg" || "$OUTPUT_EXT" == "jpeg" ]]; then
  # ==================== JPEG 格式输出 ====================
  if [[ "$COMPRESS_MODE" == "on" ]]; then
    # 压缩模式：使用指定的质量值
    # -q:v $JPG_QUALITY：JPEG质量（1=最好，31=最差）
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -q:v "$JPG_QUALITY" "$OUTPUT"
  elif [[ "$COMPRESS_MODE" == "off" ]]; then
    # 不压缩模式：使用最高质量（q=1）
    ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -q:v 1 "$OUTPUT"
    echo "[WARN] JPG is always lossy. --compress off uses highest JPEG quality (q=1)." >&2
  else
    # match 模式：根据像素比例调整目标大小
    # 原理：如果输出像素是输入的4倍，目标大小也应该是4倍
    if (( TOTAL_INPUT_PIXELS > 0 )); then
      SCALED_TARGET=$((TARGET_BYTES * OUTPUT_PIXELS / TOTAL_INPUT_PIXELS))
    else
      SCALED_TARGET="$TARGET_BYTES"
    fi
    echo "[INFO] match mode (JPG) scaled target: ${SCALED_TARGET} bytes (pixel ratio: ${OUTPUT_PIXELS}/${TOTAL_INPUT_PIXELS})." >&2

    # 尝试质量值 1-31，选择最接近目标的
    tmp_dir="$(mktemp -d)"
    best_q=1
    best_diff=-1
    best_size=0
    for q in $(seq 1 31); do
      tmp_out="${tmp_dir}/q${q}.jpg"
      # 使用指定质量生成临时文件
      ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 -q:v "$q" "$tmp_out" >/dev/null 2>&1
      current_size="$(file_size_bytes "$tmp_out")"
      current_diff="$(abs_diff "$current_size" "$SCALED_TARGET")"
      if (( best_diff == -1 || current_diff < best_diff )); then
        best_q="$q"
        best_diff="$current_diff"
        best_size="$current_size"
      fi
    done
    # 复制最佳结果到输出路径
    cp "${tmp_dir}/q${best_q}.jpg" "$OUTPUT"
    rm -rf "$tmp_dir"  # 清理临时目录
    echo "[INFO] match mode (JPG) picked q=${best_q}, output=${best_size} bytes, scaled_target=${SCALED_TARGET} bytes." >&2
  fi
  echo "[WARN] JPG is lossy. Use .png output for lossless quality." >&2
else
  # ==================== 其他格式输出 ====================
  if [[ "$COMPRESS_MODE" == "match" ]]; then
    echo "[WARN] --compress match is optimized for png/jpg outputs; applying default encoding for .$OUTPUT_EXT." >&2
  fi
  # 使用默认编码
  ffmpeg "${FF_ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -frames:v 1 "$OUTPUT"
fi

echo "[OK] Image montage saved: $OUTPUT"
