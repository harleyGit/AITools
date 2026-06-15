#!/usr/bin/env bash
# =============================================================================
# A4 PDF生成脚本 - images-to-a4-pdf.sh
# =============================================================================
# 功能：将图片整理成适合A4打印的PDF
# 默认行为：一张图片占一张A4页面，居中显示，等比例缩放，不裁切
#
# 支持的输入方式：
# - 目录：自动发现目录第一层中的图片
# - 单个文件：直接指定图片文件路径
# - 逗号分隔的文件列表：如 "1.png,2.png,3.png"
# - 相对路径：基于当前工作目录
#
# 依赖工具：
# - python3
# - Python包 Pillow
#
# 给初学者的阅读提示：
# - 这个文件前半部分是 Bash，负责显示帮助、检查 python3、把参数交给 Python。
# - 第 63 行开始的 python3 - "$@" <<'PY' 是“内嵌 Python”写法：
#   Bash 会把下面 PY 标记之前的内容当作 Python 程序执行。
# - 真正的图片读取、缩放、排版、保存 PDF 都在 Python 代码里完成。
# - 脚本整体流程是：解析参数 -> 收集图片 -> 计算 A4 页面尺寸 -> 生成每页图片 -> 合并保存 PDF。
# =============================================================================

# set -euo pipefail：Shell脚本常用的安全选项
# -e：任意命令失败时立刻退出，避免继续执行产生错误结果
# -u：使用未定义变量时报错，便于发现拼写错误
# -o pipefail：管道中任何一步失败，都认为整个管道失败
set -euo pipefail

# =============================================================================
# 函数：usage()
# 功能：打印命令行帮助文本
# 说明：cat <<'EOF' 是 Here Document 写法，适合输出多行固定文本。
# =============================================================================
usage() {
  cat <<'EOF'
Usage:
  images-to-a4-pdf.sh [options] <image_or_dir> [image_or_dir ...]

Options:
  --output <path>, -o <path>
                        输出PDF路径（默认：./images-a4-one-per-page.pdf）
  --orientation <portrait|landscape>
                        A4方向（默认：portrait）
  --dpi <N>             PDF分辨率元数据和A4像素尺寸基准（默认：300）
  --margin <N>          300 DPI下的页边距像素值，会随 --dpi 缩放（默认：120）
  --bg <color>          页面背景颜色（默认：white）
  -h, --help            显示帮助信息

Examples:
  images-to-a4-pdf.sh ~/Downloads
  images-to-a4-pdf.sh --output ~/Desktop/cards.pdf ~/Downloads/cards
  images-to-a4-pdf.sh --margin 80 --orientation landscape 1.png,2.png,3.png
  images-to-a4-pdf.sh --dpi 300 --output ./print.pdf ./images

Notes:
  - 默认一张图片占一张A4纸。
  - 图片会居中并等比例缩放，不裁切、不拉伸。
  - 支持 JPG/JPEG、PNG、WebP、BMP、TIFF。
EOF
}

# =============================================================================
# 函数：require_cmd()
# 功能：检查系统里是否能找到指定命令
# 参数：$1 = 命令名，例如 python3
# 原理：command -v 会在 PATH 中查找命令；找不到就输出错误并退出。
# =============================================================================
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Missing required command: $1" >&2
    exit 1
  }
}

# 如果第一个参数是 -h 或 --help，只显示帮助，不继续生成 PDF。
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# 检查 python3 是否可用。Pillow 包在 Python 代码里再检查。
require_cmd python3

# =============================================================================
# 下面开始执行内嵌 Python 程序
# - python3 - 表示 Python 代码从标准输入读取，而不是从 .py 文件读取。
# - "$@" 会把用户传给 shell 脚本的所有参数原样传给 Python。
# - <<'PY' 到最后的 PY 之间都是 Python 代码。
# =============================================================================
python3 - "$@" <<'PY'
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


# 支持的图片扩展名集合。统一使用小写，后面会对文件扩展名调用 lower()。
SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}

# A4 在 300 DPI 下的常用像素尺寸。
# portrait 表示竖版 A4，landscape 表示横版 A4。
# 如果用户传入 --dpi，后面会按比例缩放这个尺寸。
A4_SIZES = {
    "portrait": (2480, 3508),
    "landscape": (3508, 2480),
}


def parse_args() -> argparse.Namespace:
    """解析命令行参数。

    argparse 是 Python 标准库，适合把 --output、--dpi 这类命令行选项
    转换成易用的 args.output、args.dpi 属性。
    """
    parser = argparse.ArgumentParser(
        prog="images-to-a4-pdf.sh",
        description="Create an A4 PDF from images, one image per page.",
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        help="Image files, directories, or comma-separated image lists.",
    )
    parser.add_argument(
        "--output",
        "-o",
        help="Output PDF path. Default: ./images-a4-one-per-page.pdf",
    )
    parser.add_argument(
        "--orientation",
        choices=sorted(A4_SIZES),
        default="portrait",
        help="A4 page orientation. Default: portrait.",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=300,
        help="PDF resolution metadata and A4 pixel size basis. Default: 300.",
    )
    parser.add_argument(
        "--margin",
        type=int,
        default=120,
        help="Page margin in pixels at 300 DPI. Scales with --dpi. Default: 120.",
    )
    parser.add_argument(
        "--bg",
        default="white",
        help="Page background color. Default: white.",
    )
    return parser.parse_args()


def natural_key(path: Path) -> list[object]:
    """生成“自然排序”用的 key。

    普通字符串排序会得到 1.png, 10.png, 2.png。
    自然排序会把文件名里的数字片段转成整数，所以结果是 1.png, 2.png, 10.png。
    """
    parts = re.split(r"(\d+)", path.name)
    return [int(part) if part.isdigit() else part.lower() for part in parts]


def expand_input_token(raw: str) -> list[Path]:
    """把一个输入参数拆成多个路径。

    用户可以传入：
    - 单个路径：1.png
    - 英文逗号列表：1.png,2.png
    - 中文逗号列表：1.png，2.png

    Path(...).expanduser() 会把 ~/Desktop 这种路径展开为真实用户目录。
    """
    normalized = raw.replace("，", ",")
    tokens = [part.strip() for part in normalized.split(",") if part.strip()]
    return [Path(token).expanduser() for token in tokens]


def collect_images(inputs: list[str]) -> list[Path]:
    """收集所有有效图片路径。

    支持目录、单个图片、逗号分隔列表。目录只读取第一层，不递归子目录，
    这样可以避免误把很多无关图片也放进 PDF。
    """
    files: list[Path] = []

    for raw in inputs:
        for path in expand_input_token(raw):
            if path.is_dir():
                # 目录输入：遍历目录第一层，保留支持格式的图片文件。
                files.extend(
                    child
                    for child in path.iterdir()
                    if child.is_file() and child.suffix.lower() in SUPPORTED_EXTS
                )
            elif path.is_file() and path.suffix.lower() in SUPPORTED_EXTS:
                # 文件输入：只有扩展名在支持列表中才加入。
                files.append(path)
            else:
                # 路径不存在或格式不支持时不终止脚本，只给出警告。
                print(f"[WARN] Skipping unsupported or missing input: {path}", file=sys.stderr)

    # set(files) 用来去重，sorted(..., key=natural_key) 用自然顺序排序。
    return sorted(set(files), key=natural_key)


def scaled_a4_size(orientation: str, dpi: int) -> tuple[int, int]:
    """根据页面方向和 DPI 计算最终页面像素尺寸。"""
    base_w, base_h = A4_SIZES[orientation]
    scale = dpi / 300
    return round(base_w * scale), round(base_h * scale)


def create_page(image_path: Path, page_size: tuple[int, int], margin: int, bg: str):
    """为单张图片创建一页 A4 画布。

    处理步骤：
    1. 新建一张 A4 大小的 RGB 背景图。
    2. 打开原图，并根据 EXIF 信息自动纠正手机照片方向。
    3. 使用 thumbnail 等比例缩小图片，让它放进页边距以内。
    4. 计算居中坐标，把图片粘贴到页面中央。
    """
    from PIL import Image, ImageOps

    page_w, page_h = page_size
    # 可用区域 = 页面尺寸减去左右/上下页边距。
    max_w = page_w - 2 * margin
    max_h = page_h - 2 * margin
    if max_w <= 0 or max_h <= 0:
        raise ValueError("Margin is too large for the page size")

    # 创建空白页面。PDF 保存时需要 RGB 模式，避免透明通道带来兼容问题。
    page = Image.new("RGB", page_size, bg)
    with Image.open(image_path) as image:
        # ImageOps.exif_transpose 会读取 EXIF 方向信息，修正手机照片横竖方向。
        # convert("RGB") 会统一颜色模式，便于保存到 PDF。
        image = ImageOps.exif_transpose(image).convert("RGB")
        # thumbnail 会保持宽高比缩小图片，不会裁切，也不会拉伸。
        image.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
        # 计算居中粘贴的位置。
        x = (page_w - image.width) // 2
        y = (page_h - image.height) // 2
        page.paste(image, (x, y))
    return page


def main() -> int:
    """脚本主流程入口。返回 0 表示成功，返回 1 表示失败。"""
    args = parse_args()

    try:
        # 这里只检查 Pillow 是否安装；真正用到 Image 时在 create_page 中导入。
        import PIL  # noqa: F401
    except ImportError:
        print("[ERROR] Missing Python package: Pillow", file=sys.stderr)
        print("Install with: python3 -m pip install --user -U Pillow", file=sys.stderr)
        return 1

    # 根据用户输入收集图片；没有图片就报错退出。
    images = collect_images(args.inputs)
    if not images:
        print("[ERROR] No supported image files found.", file=sys.stderr)
        return 1

    # 计算页面尺寸、页边距、输出路径。
    page_size = scaled_a4_size(args.orientation, args.dpi)
    margin = round(args.margin * args.dpi / 300)
    output = Path(args.output).expanduser() if args.output else Path.cwd() / "images-a4-one-per-page.pdf"
    # parents=True 表示父目录不存在时一并创建；exist_ok=True 表示目录已存在也不报错。
    output.parent.mkdir(parents=True, exist_ok=True)

    # 为每张图片生成一页，然后把第一页作为主 PDF，后续页面追加进去。
    pages = [create_page(path, page_size, margin, args.bg) for path in images]
    pages[0].save(output, save_all=True, append_images=pages[1:], resolution=args.dpi)

    print(f"[OK] Created: {output}")
    print(f"[OK] Images: {len(images)}")
    print(f"[OK] Pages: {len(pages)}")
    return 0


raise SystemExit(main())
PY
