#!/bin/bash
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/private/tmp}/cocoapods-prune-test.XXXXXX")"
trap 'rm -rf -- "$TEMP"' EXIT
CACHE="$TEMP/Pods"
mkdir -p "$CACHE/Release/Foo" "$CACHE/Release/New" "$CACHE/External/Bar" \
  "$CACHE/Specs/Release/Foo" "$CACHE/Specs/External/Bar"

for entry in "1.0-aaaa:202501010000" "2.0-bbbb:202502010000" \
             "3.0-cccc:202503010000" "4.0-dddd:202504010000"; do
  version="${entry%%:*}"
  date="${entry#*:}"
  mkdir "$CACHE/Release/Foo/$version"
  printf 'cache' > "$CACHE/Release/Foo/$version/file"
  printf '{}' > "$CACHE/Specs/Release/Foo/$version.podspec.json"
  touch -t "$date" "$CACHE/Release/Foo/$version/file" "$CACHE/Release/Foo/$version" \
    "$CACHE/Specs/Release/Foo/$version.podspec.json"
done
mkdir "$CACHE/Release/Foo/5.0-eeee"
printf 'recent' > "$CACHE/Release/Foo/5.0-eeee/file"
touch -t 202401010000 "$CACHE/Release/Foo/5.0-eeee"
touch "$CACHE/Release/Foo/5.0-eeee/file"
for item in a b c d; do
  mkdir "$CACHE/Release/New/1.0-$item"
  printf 'recent' > "$CACHE/Release/New/1.0-$item/file"
done

for item in a b c d; do
  mkdir "$CACHE/External/Bar/hash-$item"
  printf 'external' > "$CACHE/External/Bar/hash-$item/file"
  printf '{}' > "$CACHE/Specs/External/Bar/hash-$item.podspec.json"
  touch -t 202501010000 "$CACHE/External/Bar/hash-$item/file" \
    "$CACHE/External/Bar/hash-$item" "$CACHE/Specs/External/Bar/hash-$item.podspec.json"
done
touch -t 202504010000 "$CACHE/External/Bar/hash-d"
touch -t 202503010000 "$CACHE/External/Bar/hash-c"
touch -t 202502010000 "$CACHE/External/Bar/hash-b"
OUTSIDE="$TEMP/important"
printf 'keep' > "$OUTSIDE"
ln -s "$OUTSIDE" "$CACHE/Release/Foo/0.0-symlink"
printf 'version-marker' > "$CACHE/VERSION"
REPORT="$TEMP/report.log"
script="$ROOT/scripts/prune_cocoapods_cache.sh"

/bin/bash "$script" --cache "$CACHE" --report "$REPORT" > /dev/null
[[ -d "$CACHE/Release/Foo/1.0-aaaa" && -f "$OUTSIDE" && -f "$CACHE/VERSION" ]]
grep -q '待删.*1.0-aaaa' "$REPORT"
grep -q '待删.*2.0-bbbb' "$REPORT"

/bin/bash "$script" --cache "$CACHE" --report "$REPORT" --execute --yes > /dev/null
[[ ! -e "$CACHE/Release/Foo/1.0-aaaa" && ! -e "$CACHE/Release/Foo/2.0-bbbb" ]]
[[ -d "$CACHE/Release/Foo/3.0-cccc" && -d "$CACHE/Release/Foo/4.0-dddd" ]]
[[ -d "$CACHE/Release/Foo/5.0-eeee" && ! -e "$CACHE/External/Bar/hash-a" ]]
for item in a b c d; do
  [[ -d "$CACHE/Release/New/1.0-$item" ]]
done
[[ -f "$CACHE/Specs/Release/Foo/3.0-cccc.podspec.json" ]]
[[ ! -e "$CACHE/Specs/Release/Foo/1.0-aaaa.podspec.json" ]]
[[ -f "$OUTSIDE" && -f "$CACHE/VERSION" ]]
grep -q '执行汇总：删除 3 项缓存和 3 个对应 podspec' "$REPORT"
/bin/bash "$script" --cache "$CACHE" --report "$REPORT" --keep 2 --execute --yes > /dev/null
[[ ! -e "$CACHE/Release/Foo/3.0-cccc" ]]
[[ -d "$CACHE/Release/Foo/4.0-dddd" && -d "$CACHE/Release/Foo/5.0-eeee" ]]
for item in a b c d; do
  [[ -d "$CACHE/Release/New/1.0-$item" ]]
done
echo "PASS: CocoaPods 15-day priority, 2/3-item floors, recent surplus, spec pairing and real deletion."
