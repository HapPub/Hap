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
    "linux-x64-ohos": ".tar.gz",
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
stdx_name = f"cangjie-stdx-ohos-aarch64-{tag}.1.zip"
assets.append({
    "name": stdx_name,
    "classification": "stdx",
    "size": 2048,
    "mirrorUrl": f"https://github.com/HapPub/CangjieSDK-Mirror/releases/download/{quote(tag, safe='')}/{quote(stdx_name, safe='')}",
    "sha256": f"{len(assets) + 1:064x}",
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

for platform in linux-x64 linux-aarch64 mac-aarch64 mac-x64 windows-x64 linux-x64-ohos; do
  python3 "$ROOT/scripts/ci/resolve-nightly-sdk.py" \
    --manifest "$WORK/manifest.v1.json" --platform "$platform" \
    > "$WORK/$platform.json"
  grep -q 'selected-from-complete-mirror-manifest' "$WORK/$platform.json" || {
    fail_test "SDK selector did not accept $platform"
  }
done
python3 "$ROOT/scripts/ci/resolve-nightly-sdk.py" \
  --manifest "$WORK/manifest.v1.json" \
  --asset-name "cangjie-stdx-ohos-aarch64-1.3.0-alpha.20260803010032.1.zip" \
  > "$WORK/exact-stdx.json"
grep -q '"classification": "stdx"' "$WORK/exact-stdx.json" || {
  fail_test "exact mirrored asset selector did not resolve stdx"
}
python3 "$ROOT/scripts/ci/render-sdk-coverage.py" \
  --manifest "$WORK/manifest.v1.json" \
  --output "$WORK/cangjie-sdk-coverage.v1.json"

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
printf 'ohos-arm64\n' > "$WORK/dist/hap-0.1.0-ohos-arm64.tar.gz"
printf 'ohos-amd64\n' > "$WORK/dist/hap-0.1.0-ohos-amd64.tar.gz"
python3 "$ROOT/scripts/ci/render-nightly-manifest.py" \
  --dist "$WORK/dist" \
  --sdk-manifest "$WORK/manifest.v1.json" \
  --sdk-coverage "$WORK/cangjie-sdk-coverage.v1.json" \
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
assert status["ohos-arm64"] == "cross-built-link-verified"
assert status["ohos-amd64"] == "cross-built-link-verified"
assert status["windows-arm64"] == "unsupported-upstream-host-sdk"
assert status["windows-x86"] == "unsupported-upstream-host-sdk"
assert manifest["cangjieSdk"]["coveredAssetCount"] == manifest["cangjieSdk"]["assetCount"]
assert any(item["kind"] == "sdk-coverage-receipt" for item in manifest["assets"])
PY

python3 - "$WORK/cangjie-sdk-coverage.v1.json" <<'PY'
import json
import sys

coverage = json.load(open(sys.argv[1], encoding="utf-8"))
assert coverage["assetCount"] == coverage["coveredAssetCount"]
assert len(coverage["assets"]) == coverage["assetCount"]
assert {item["target"] for item in coverage["upstreamTargetGaps"]} == {
    "windows-arm64", "windows-x86"
}
assert all(item["matchedAssetNames"] == [] for item in coverage["upstreamTargetGaps"])
PY

workflow="$ROOT/.github/workflows/nightly.yml"
grep -q '"src/\*\*"' "$workflow" || fail_test "source push trigger is missing"
grep -q 'ubuntu-24.04-arm' "$workflow" || fail_test "Linux ARM64 hosted runner is missing"
grep -q 'macos-15-intel' "$workflow" || fail_test "macOS Intel hosted runner is missing"
grep -q 'windows-2025' "$workflow" || fail_test "Windows AMD64 hosted runner is missing"
grep -q 'openharmony-rs/setup-ohos-sdk@eb82b94ef522b07269679195c2512f22e922ef3b' "$workflow" || {
  fail_test "checksum-verifying OpenHarmony SDK action is not commit-pinned"
}
grep -q 'build-cross-release.sh' "$workflow" || fail_test "OHOS cross-build job is missing"
grep -q 'cangjie-sdk-coverage.v1.json' "$workflow" || fail_test "full SDK coverage artifact is missing"
grep -q 'continue-on-error:.*matrix.experimental' "$workflow" || fail_test "experimental target boundary is missing"
grep -q 'cross-built-link-verified' "$ROOT/scripts/ci/render-nightly-manifest.py" || fail_test "cross-build status is missing"
grep -q 'cygpath -u' "$ROOT/scripts/ci/install-cangjie-sdk.sh" || fail_test "Windows runner path normalization is missing"
grep -q 'Cangjie SDK install failed::phase=' "$ROOT/scripts/ci/install-cangjie-sdk.sh" || fail_test "SDK install phase annotation is missing"
grep -q 'hashlib.sha256' "$ROOT/scripts/ci/install-cangjie-sdk.sh" || fail_test "portable SDK checksum implementation is missing"
grep -q 'Hap release build failed::phase=' "$ROOT/scripts/ci/build-release.sh" || fail_test "release build phase annotation is missing"
grep -q 'run_logged_phase build cjpm build' "$ROOT/scripts/ci/build-release.sh" || fail_test "CJPM build phase capture is missing"
grep -q 'env_file=$(cygpath -u' "$ROOT/scripts/ci/build-release.sh" || fail_test "Windows environment path normalization is missing"
grep -q 'FAILED|ERROR' "$ROOT/scripts/ci/build-release.sh" || fail_test "test failure case extraction is missing"
bash -n "$ROOT/scripts/ci/build-cross-release.sh"
grep -q 'runtimeSmokeVerified.*False' "$ROOT/scripts/ci/build-cross-release.sh" || {
  fail_test "cross-build runtime non-claim is missing"
}

python3 - "$WORK/aarch64.elf" "$WORK/x86_64.elf" <<'PY'
import pathlib
import struct
import sys

for path, machine in ((sys.argv[1], 183), (sys.argv[2], 62)):
    header = bytearray(64)
    header[:6] = b"\x7fELF\x02\x01"
    header[18:20] = struct.pack("<H", machine)
    pathlib.Path(path).write_bytes(header)
PY
python3 "$ROOT/scripts/ci/verify-elf-target.py" \
  --binary "$WORK/aarch64.elf" --machine aarch64 >/dev/null
python3 "$ROOT/scripts/ci/verify-elf-target.py" \
  --binary "$WORK/x86_64.elf" --machine x86_64 >/dev/null
if python3 "$ROOT/scripts/ci/verify-elf-target.py" \
  --binary "$WORK/aarch64.elf" --machine x86_64 >/dev/null 2>&1; then
  fail_test "ELF target verifier accepted the wrong architecture"
fi

printf '%s\n' "nightly workflow tests passed"
