#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/hap-nightly-contract.XXXXXXXX")
trap 'rm -rf "$WORK"' 0 HUP INT TERM

fail_test() {
  printf 'nightly workflow test failed: %s\n' "$*" >&2
  exit 1
}

python3 - "$WORK/manifest.v1.json" <<'PY'
import json
import pathlib
import sys
from urllib.parse import quote

tag = "1.3.0-alpha.20260803010032"
platforms = {
    "linux-x64": ".tar.gz",
    "linux-aarch64": ".tar.gz",
    "mac-aarch64": ".tar.gz",
    "mac-x64": ".tar.gz",
    "windows-x64": ".zip",
}
assets = []
for index, (platform, extension) in enumerate(platforms.items(), start=1):
    name = f"cangjie-sdk-{platform}-{tag}{extension}"
    assets.append({
        "name": name,
        "classification": "sdk",
        "mirrorUrl": f"https://github.com/HapPub/CangjieSDK-Mirror/releases/download/{quote(tag, safe='')}/{quote(name, safe='')}",
        "sha256": f"{index:064x}",
    })
manifest = {
    "schema": "happub-cangjie-sdk-mirror-manifest-v1",
    "ok": True,
    "status": "mirrored-verbatim",
    "upstream": {"tag": tag},
    "mirror": {
        "tag": tag,
        "manifestUrl": f"https://github.com/HapPub/CangjieSDK-Mirror/releases/download/{tag}/manifest.v1.json",
    },
    "assetCount": len(assets),
    "checksumPolicy": {"authority": "mirror-computed-sha256"},
    "assets": assets,
}
pathlib.Path(sys.argv[1]).write_text(json.dumps(manifest), encoding="utf-8")
PY

for platform in linux-x64 linux-aarch64 mac-aarch64 mac-x64 windows-x64; do
  python3 "$ROOT/scripts/ci/resolve-nightly-sdk.py" \
    --manifest "$WORK/manifest.v1.json" --platform "$platform" \
    > "$WORK/$platform.json"
  grep -q 'selected-from-complete-mirror-manifest' "$WORK/$platform.json" || {
    fail_test "SDK selector did not accept $platform"
  }
done

python3 - "$WORK/safe.zip" "$WORK/escape.zip" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w") as archive:
    archive.writestr("cangjie/bin/cjpm.exe", b"fixture")
with zipfile.ZipFile(sys.argv[2], "w") as archive:
    archive.writestr("../../outside", b"escape")
PY
python3 "$ROOT/scripts/ci/safe-extract-sdk.py" "$WORK/safe.zip" "$WORK/safe-root"
[ -f "$WORK/safe-root/cangjie/bin/cjpm.exe" ] || fail_test "safe SDK zip was not extracted"
if python3 "$ROOT/scripts/ci/safe-extract-sdk.py" "$WORK/escape.zip" "$WORK/escape-root" >/dev/null 2>&1; then
  fail_test "unsafe SDK zip member was accepted"
fi

mkdir -p "$WORK/dist"
printf 'source\n' > "$WORK/dist/hap-0.1.0-source.tar.gz"
printf 'linux\n' > "$WORK/dist/hap-0.1.0-linux-amd64.tar.gz"
python3 "$ROOT/scripts/ci/render-nightly-manifest.py" \
  --dist "$WORK/dist" \
  --sdk-manifest "$WORK/manifest.v1.json" \
  --hap-version 0.1.0 \
  --release-tag nightly-1.3.0-alpha.20260803010032 \
  --repository HapPub/Hap \
  --output "$WORK/nightly-manifest.v1.json" \
  --notes-output "$WORK/notes.md"
python3 - "$WORK/nightly-manifest.v1.json" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
status = {row["target"]: row["status"] for row in manifest["targetStatus"]}
assert manifest["channel"] == "nightly"
assert status["linux-amd64"] == "built-and-smoke-verified"
assert status["windows-amd64"] == "runner-build-not-produced"
assert status["ohos-arm64"] == "sdk-mirrored-only"
assert status["windows-arm64"] == "unsupported-upstream-host-sdk"
PY

workflow="$ROOT/.github/workflows/nightly.yml"
grep -q '"src/\*\*"' "$workflow" || fail_test "source push trigger is missing"
grep -q 'ubuntu-24.04-arm' "$workflow" || fail_test "Linux ARM64 hosted runner is missing"
grep -q 'macos-15-intel' "$workflow" || fail_test "macOS Intel hosted runner is missing"
grep -q 'windows-2025' "$workflow" || fail_test "Windows AMD64 hosted runner is missing"
grep -q 'continue-on-error:.*matrix.experimental' "$workflow" || fail_test "experimental target boundary is missing"
grep -q 'sdk-mirrored-only' "$ROOT/scripts/ci/render-nightly-manifest.py" || fail_test "mirror-only status is missing"

printf '%s\n' "nightly workflow tests passed"
