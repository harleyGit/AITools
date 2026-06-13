#!/bin/zsh

set -euo pipefail

print_usage() {
  cat <<'EOF'
Usage:
  ./delete-mac-app.sh [AppName]

Examples:
  ./delete-mac-app.sh Chrome
  ./delete-mac-app.sh "Visual Studio Code"

If AppName is omitted, the script will ask for it.

What it removes after confirmation:
  - Matched .app bundle(s)
  - Related preferences, caches, saved state, logs, containers, group containers,
    application support files, crash reports, launch agents, and similar app data

Safety behavior:
  - Everything is moved to Trash, not permanently deleted.
  - Shared or broad matches that may affect other apps or system functionality are
    marked SKIPPED and are never deleted by this script.
  - After running, skipped items are listed with the reason they were preserved.
EOF
}

trim() {
  local value="$1"
  value="${value##[[:space:]]#}"
  value="${value%%[[:space:]]#}"
  printf '%s' "$value"
}

append_unique() {
  local item="$1"
  local existing

  [[ -n "$item" ]] || return
  for existing in "$@"; do
    [[ "$existing" == "$item" ]] && return
  done
  printf '%s\0' "$item"
}

# Move items to Trash instead of deleting permanently. Prefer the `trash` CLI
# when installed; otherwise use ~/.Trash directly so the script works without
# AppleScript permissions or a fully populated PATH.
move_to_trash() {
  local target="$1"
  local trash_dir="$HOME/.Trash"
  local target_name="${target:t}"
  local destination="$trash_dir/$target_name"
  local counter=1

  if command -v trash >/dev/null 2>&1; then
    trash "$target"
    return
  fi

  /bin/mkdir -p "$trash_dir"
  while [[ -e "$destination" ]]; do
    destination="$trash_dir/${target_name}.$counter"
    counter=$((counter + 1))
  done

  /bin/mv "$target" "$destination"
}

# Store a discovered path with its handling policy:
#   normal = safe enough to offer for deletion after user confirmation
#   skip   = may be shared with other apps or functionality, never delete here
add_existing_path() {
  local risk="$1"
  local path="$2"
  local reason="$3"

  [[ -e "$path" ]] || return 0
  item_paths+=("$path")
  item_risks+=("$risk")
  item_reasons+=("$reason")
}

# Collect broad name matches in user Library folders. These are useful for apps
# that do not use their bundle id as the on-disk directory name.
collect_name_matches() {
  local risk="$1"
  local dir="$2"
  local maxdepth="$3"
  local reason="$4"
  local base

  [[ -d "$dir" ]] || return

  while IFS= read -r -d '' path; do
    base="${path:t}"
    if [[ "${base:l}" == *"${app_name:l}"* ]]; then
      add_existing_path "$risk" "$path" "$reason"
    fi
  done < <(find "$dir" -maxdepth "$maxdepth" -mindepth 1 -print0 2>/dev/null)
}

# Collect files/directories whose names start with the bundle id, such as crash
# reports and helper tools that often append extra suffixes.
collect_prefix_matches() {
  local risk="$1"
  local dir="$2"
  local prefix="$3"
  local reason="$4"
  local base

  [[ -d "$dir" ]] || return

  while IFS= read -r -d '' path; do
    base="${path:t}"
    if [[ "$base" == "$prefix"* ]]; then
      add_existing_path "$risk" "$path" "$reason"
    fi
  done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
}

add_bundle_id_paths() {
  local bundle_id="$1"
  local app_base="$2"
  local safe_roots high_risk_roots root

  [[ -n "$bundle_id" ]] || return

  safe_roots=(
    "$HOME/Library/Preferences/$bundle_id.plist"
    "$HOME/Library/Preferences/ByHost/$bundle_id"
    "$HOME/Library/Caches/$bundle_id"
    "$HOME/Library/Saved Application State/$bundle_id.savedState"
    "$HOME/Library/Application Scripts/$bundle_id"
    "$HOME/Library/HTTPStorages/$bundle_id"
    "$HOME/Library/WebKit/$bundle_id"
    "$HOME/Library/Cookies/$bundle_id.binarycookies"
    "$HOME/Library/Logs/$bundle_id"
    "$HOME/Library/Containers/$bundle_id"
    "$HOME/Library/Application Support/$bundle_id"
    "$HOME/Library/LaunchAgents/$bundle_id.plist"
    "$HOME/Library/LaunchDaemons/$bundle_id.plist"
    "/Library/LaunchAgents/$bundle_id.plist"
    "/Library/LaunchDaemons/$bundle_id.plist"
  )

  # Group Containers are intentionally treated as shared. They can hold data for
  # companion apps, extensions, sync agents, or same-vendor tools, so the script
  # reports them but does not delete them.
  high_risk_roots=(
    "$HOME/Library/Group Containers/$bundle_id"
    "$HOME/Library/Group Containers/"*"$bundle_id"*
  )

  for root in "${safe_roots[@]}"; do
    add_existing_path "normal" "$root" "Bundle ID match: $bundle_id"
  done

  for root in "${high_risk_roots[@]}"; do
    for expanded in ${~root}(N); do
      add_existing_path "skip" "$expanded" "Shared container match: may affect other apps from the same vendor/account"
    done
  done

  collect_prefix_matches "normal" "$HOME/Library/Application Support/CrashReporter" "$bundle_id" "Crash report match: $bundle_id"
  collect_prefix_matches "normal" "/Library/PrivilegedHelperTools" "$bundle_id" "Privileged helper match: $bundle_id"
}

# The same path can be found by bundle id and by name matching. Keep the first
# classification and reason so the final prompt stays readable.
dedupe_items() {
  local paths=() risks=() reasons=()
  local i seen_key
  typeset -A seen

  for i in {1..${#item_paths[@]}}; do
    seen_key="${item_paths[$i]}"
    [[ -n "${seen[$seen_key]:-}" ]] && continue
    seen[$seen_key]=1
    paths+=("${item_paths[$i]}")
    risks+=("${item_risks[$i]}")
    reasons+=("${item_reasons[$i]}")
  done

  item_paths=("${paths[@]}")
  item_risks=("${risks[@]}")
  item_reasons=("${reasons[@]}")
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

app_name="${*:-}"
if [[ -z "$app_name" ]]; then
  printf "Enter app name to delete: "
  read -r app_name || app_name=""
fi

app_name="$(trim "$app_name")"
if [[ -z "$app_name" ]]; then
  echo "No app name provided."
  exit 1
fi

search_dirs=(
  "/Applications"
  "$HOME/Applications"
)

app_matches=()
for dir in "${search_dirs[@]}"; do
  [[ -d "$dir" ]] || continue

  while IFS= read -r -d '' app_path; do
    app_base="${app_path:t:r}"
    if [[ "${app_base:l}" == *"${app_name:l}"* ]]; then
      app_matches+=("$app_path")
    fi
  done < <(find "$dir" -maxdepth 2 -type d -name "*.app" -print0 2>/dev/null)
done

if (( ${#app_matches[@]} == 0 )); then
  echo "No app matched: $app_name"
  echo "Searched: ${search_dirs[*]}"
  exit 1
fi

echo "Matched app(s):"
for i in {1..${#app_matches[@]}}; do
  echo "  [$i] ${app_matches[$i]}"
done

item_paths=()
item_risks=()
item_reasons=()

# Use CFBundleIdentifier when available because macOS app data is commonly
# stored under the bundle id rather than the visible app name.
bundle_ids=()
app_bases=()
for app_path in "${app_matches[@]}"; do
  app_base="${app_path:t:r}"
  bundle_id="$(defaults read "$app_path/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  bundle_id="$(trim "$bundle_id")"

  app_bases+=("$app_base")
  [[ -n "$bundle_id" ]] && bundle_ids+=("$bundle_id")

  add_existing_path "normal" "$app_path" "Application bundle"
  add_bundle_id_paths "$bundle_id" "$app_base"
done

collect_name_matches "normal" "$HOME/Library/Application Support" 2 "Name match in Application Support"
collect_name_matches "normal" "$HOME/Library/Caches" 1 "Name match in Caches"
collect_name_matches "normal" "$HOME/Library/Logs" 2 "Name match in Logs"
collect_name_matches "normal" "$HOME/Library/Saved Application State" 1 "Name match in Saved Application State"
collect_name_matches "normal" "$HOME/Library/Preferences" 1 "Name match in Preferences"
collect_name_matches "skip" "$HOME/Library/Group Containers" 1 "Name match in shared Group Containers; may affect other apps"

dedupe_items

# Present the complete plan before making any changes. SKIPPED items are listed
# so the user knows what was preserved and why.
echo
echo "Items selected for removal:"
normal_count=0
skip_count=0
for i in {1..${#item_paths[@]}}; do
  risk_label="NORMAL"
  if [[ "${item_risks[$i]}" == "skip" ]]; then
    risk_label="SKIPPED"
    skip_count=$((skip_count + 1))
  else
    normal_count=$((normal_count + 1))
  fi
  echo "  [$i] [$risk_label] ${item_paths[$i]}"
  echo "      ${item_reasons[$i]}"
done

echo
echo "Summary: $normal_count removable item(s), $skip_count skipped item(s)."
echo "Removable items will be moved to Trash, not permanently deleted."
if (( skip_count > 0 )); then
  echo "Skipped items may affect other apps or system functionality, so this script will not delete them."
fi

printf "Move NORMAL items to Trash? [y/N] "
read -r normal_answer || normal_answer=""
case "${normal_answer:l}" in
  y|yes) delete_normal=true ;;
  *) delete_normal=false ;;
esac

if [[ "$delete_normal" != true ]]; then
  echo "Nothing selected for deletion."
  if (( skip_count > 0 )); then
    echo
    echo "Skipped items preserved because they may affect other apps or functionality:"
    for i in {1..${#item_paths[@]}}; do
      if [[ "${item_risks[$i]}" == "skip" ]]; then
        echo "  - ${item_paths[$i]}"
        echo "    ${item_reasons[$i]}"
      fi
    done
  fi
  exit 0
fi

echo
for i in {1..${#item_paths[@]}}; do
  should_delete=false
  if [[ "${item_risks[$i]}" != "skip" && "$delete_normal" == true ]]; then
    should_delete=true
  fi

  # SKIPPED items are never deleted, even after the user confirms deletion of
  # normal items. They are preserved to avoid breaking other apps or features.
  if [[ "$should_delete" != true ]]; then
    echo "Preserved: ${item_paths[$i]}"
    echo "  Reason: ${item_reasons[$i]}"
    continue
  fi

  if [[ ! -e "${item_paths[$i]}" ]]; then
    echo "Skipped missing path: ${item_paths[$i]}"
    continue
  fi

  echo "Moving to Trash: ${item_paths[$i]}"
  move_to_trash "${item_paths[$i]}"
done

if (( skip_count > 0 )); then
  echo
  echo "Skipped items preserved because they may affect other apps or functionality:"
  for i in {1..${#item_paths[@]}}; do
    if [[ "${item_risks[$i]}" == "skip" ]]; then
      echo "  - ${item_paths[$i]}"
      echo "    ${item_reasons[$i]}"
    fi
  done
fi

echo "Finished. Open Trash if you want to restore or permanently delete the removed item(s)."
