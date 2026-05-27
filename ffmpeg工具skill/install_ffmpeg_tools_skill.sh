#!/usr/bin/env bash
set -euo pipefail

# One-click installer for ffmpeg-tools Codex skill.
# Usage:
#   bash install_ffmpeg_tools_skill.sh [zip_path]
# Example:
#   bash install_ffmpeg_tools_skill.sh ~/Desktop/ffmpeg-tools-skill.zip

ZIP_PATH="${1:-$HOME/Desktop/ffmpeg-tools-skill.zip}"
SKILLS_HOME="${CODEX_HOME:-$HOME/.codex}/skills"
TARGET_SKILL_DIR="${SKILLS_HOME}/ffmpeg-tools"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "[INFO] Installing ffmpeg-tools skill..."
echo "[INFO] ZIP: $ZIP_PATH"
echo "[INFO] Skill dir: $TARGET_SKILL_DIR"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "[ERROR] ZIP not found: $ZIP_PATH" >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "[ERROR] unzip is required but not found." >&2
  exit 1
fi

mkdir -p "$SKILLS_HOME"
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

if [[ ! -f "$TMP_DIR/ffmpeg-tools/SKILL.md" ]]; then
  echo "[ERROR] Invalid package: missing ffmpeg-tools/SKILL.md" >&2
  exit 1
fi

if [[ -d "$TARGET_SKILL_DIR" ]]; then
  backup="${TARGET_SKILL_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
  mv "$TARGET_SKILL_DIR" "$backup"
  echo "[INFO] Existing skill backed up to: $backup"
fi

cp -R "$TMP_DIR/ffmpeg-tools" "$TARGET_SKILL_DIR"
echo "[OK] Skill installed: $TARGET_SKILL_DIR"

if ! command -v ffmpeg >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "[INFO] ffmpeg not found. Installing with Homebrew..."
    brew install ffmpeg
  else
    echo "[WARN] ffmpeg not found, and Homebrew is unavailable."
    echo "       Please install ffmpeg manually."
  fi
else
  echo "[OK] ffmpeg already installed."
fi

if command -v yt-dlp >/dev/null 2>&1 || python3 -m yt_dlp --version >/dev/null 2>&1; then
  echo "[OK] yt-dlp already installed."
else
  echo "[INFO] yt-dlp not found. Installing with pip --user..."
  python3 -m pip install --user -U yt-dlp
  echo "[INFO] If 'yt-dlp' command is still not found, add this to your shell profile:"
  echo "       export PATH=\"\$HOME/Library/Python/3.9/bin:\$PATH\""
fi

echo "[DONE] ffmpeg-tools skill is ready."
echo "       Restart Codex to pick up the new/updated skill."
