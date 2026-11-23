#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/scan_app_junk.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/private/tmp}/app-junk-test.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
HOME_DIR="$TEST_ROOT/home"
APP_DIR="$TEST_ROOT/Applications"
mkdir -p "$APP_DIR/Example.app/Contents" \
  "$HOME_DIR/Library/Caches" "$HOME_DIR/Library/Logs" \
  "$HOME_DIR/Library/Application Support" "$HOME_DIR/Downloads"

cat > "$APP_DIR/Example.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.example.active</string></dict></plist>
PLIST
OLD_CACHE="$HOME_DIR/Library/Caches/com.example.old"
RECENT_CACHE="$HOME_DIR/Library/Caches/com.example.recent"
ACTIVE_DATA="$HOME_DIR/Library/Application Support/com.example.active"
OLD_DATA="$HOME_DIR/Library/Application Support/com.example.uninstalled"
INSTALLER="$HOME_DIR/Downloads/Example.dmg"
OUTSIDE="$TEST_ROOT/important"
REVIEW="$HOME_DIR/Library/Caches/CocoaPods"
printf 'old' > "$OLD_CACHE"
printf 'recent' > "$RECENT_CACHE"
printf 'active' > "$ACTIVE_DATA"
printf 'data' > "$OLD_DATA"
printf 'installer' > "$INSTALLER"
printf 'keep' > "$OUTSIDE"
printf 'offline dependency cache' > "$REVIEW"
ln -s "$OUTSIDE" "$HOME_DIR/Library/Caches/com.example.link"
touch -t 202001010000 "$OLD_CACHE" "$ACTIVE_DATA" "$OLD_DATA" "$INSTALLER"

scan() { /bin/bash "$SCRIPT" --home "$HOME_DIR" --app-root "$APP_DIR" "$@"; }

report="$(scan --days 30)"
[[ "$report" == *"$OLD_CACHE"* ]]
[[ "$report" == *"$OLD_DATA"* ]]
[[ "$report" == *"$INSTALLER"* ]]
[[ "$report" == *"[重要或大体积缓存/诊断（需人工核实）]"*"$REVIEW"* ]]
[[ "$report" != *"$ACTIVE_DATA"* ]]
[[ "$report" != *"$RECENT_CACHE"* ]]
[[ "$report" != *"com.example.link"* ]]
[[ -f "$OLD_CACHE" ]]

scan --days 30 --execute --yes > "$TEST_ROOT/output"
[[ ! -e "$OLD_CACHE" ]]
[[ -f "$RECENT_CACHE" && -f "$ACTIVE_DATA" && -f "$OLD_DATA" && -f "$INSTALLER" && -f "$REVIEW" ]]
[[ -f "$OUTSIDE" ]]

# No --days means all user caches/logs are eligible.
scan --execute --yes --select "$RECENT_CACHE" > "$TEST_ROOT/output"
[[ ! -e "$RECENT_CACHE" ]]
[[ -f "$OLD_DATA" && -f "$REVIEW" ]]

if scan --execute --yes --select "$REVIEW" > "$TEST_ROOT/output" 2>&1; then
  echo "ERROR: high-risk cache was accepted without explicit review" >&2
  exit 1
fi

if scan --execute --yes --include-data --select "$OLD_DATA" > "$TEST_ROOT/output" 2>&1; then
  echo "ERROR: unattended data deletion was accepted" >&2
  exit 1
fi
if scan --execute --include-downloads --select "$INSTALLER" > "$TEST_ROOT/output" 2>&1; then
  echo "ERROR: unattended installer deletion was accepted" >&2
  exit 1
fi
[[ -f "$OLD_DATA" && -f "$INSTALLER" ]]
echo "PASS: shell scanner, optional days, safe execution and review gates."
