#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/hap-release-contract.XXXXXXXX")
trap 'rm -rf "$WORK"' 0 HUP INT TERM

fail_test() {
  printf 'release workflow test failed: %s\n' "$*" >&2
  exit 1
}

for script in \
  "$ROOT/scripts/ci/install-cangjie-sdk.sh" \
  "$ROOT/scripts/ci/validate-release.sh" \
  "$ROOT/scripts/ci/build-release.sh" \
  "$ROOT/scripts/ci/package-source.sh"
do
  bash -n "$script"
done
python3 - "$ROOT/scripts/ci/render-release-manifest.py" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
compile(source, sys.argv[1], "exec")
PY

for readme in "$ROOT/README.md" "$ROOT/README.zh-CN.md" "$ROOT/README.ru.md"; do
  fence_count=$(grep -c '^```' "$readme")
  [ $((fence_count % 2)) -eq 0 ] || fail_test "unbalanced code fence in $(basename "$readme")"
done

grep -q 'tags:' "$ROOT/.github/workflows/release.yml" || fail_test "tag trigger is missing"
grep -q 'ubuntu-24.04-arm' "$ROOT/.github/workflows/release.yml" || fail_test "Linux ARM64 runner is missing"
grep -q 'macos-14' "$ROOT/.github/workflows/release.yml" || fail_test "macOS ARM64 runner is missing"
grep -q 'contents: write' "$ROOT/.github/workflows/release.yml" || fail_test "release write permission is missing"
grep -q 'gh release create' "$ROOT/.github/workflows/release.yml" || fail_test "GitHub release publication is missing"
if grep -R -E 'uses:[[:space:]]+actions/(checkout|upload-artifact|download-artifact)@v[0-9]+' "$ROOT/.github/workflows"; then
  fail_test "official release actions must be pinned to commit SHAs"
fi

(cd "$ROOT" && bash scripts/ci/validate-release.sh v0.1.0 >/dev/null)
if (cd "$ROOT" && bash scripts/ci/validate-release.sh v0.1.1 >/dev/null 2>&1); then
  fail_test "mismatched tag was accepted"
fi

mkdir -p "$WORK/dist"
printf 'fixture\n' > "$WORK/dist/hapup.sh"
printf 'fixture\n' > "$WORK/dist/hap-0.1.0-source.tar.gz"
for target in darwin-arm64 linux-amd64 linux-arm64; do
  printf 'fixture-%s\n' "$target" > "$WORK/dist/hap-0.1.0-$target.tar.gz"
done
python3 "$ROOT/scripts/ci/render-release-manifest.py" \
  --dist "$WORK/dist" \
  --version 0.1.0 \
  --tag v0.1.0 \
  --repository HapPub/Hap \
  --output "$WORK/manifest.json" \
  --notes-output "$WORK/notes.md"

python3 - "$WORK/manifest.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
targets = {
    item["target"]
    for item in manifest["downloadableAssets"]
    if item["kind"] == "flagship-binary"
}
assert targets == {"darwin-arm64", "linux-amd64", "linux-arm64"}
assert manifest["channel"] == "stable"
assert manifest["plannedAssets"] == []
assert all(len(item["sha256"]) == 64 for item in manifest["downloadableAssets"])
PY

printf '%s\n' "release workflow tests passed"
