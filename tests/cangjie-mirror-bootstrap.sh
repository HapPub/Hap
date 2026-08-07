#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/hap-cangjie-bootstrap-test.XXXXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

fail_test() {
  printf 'cangjie mirror bootstrap test failed: %s\n' "$1" >&2
  exit 1
}

manifest="$WORK/manifest.json"
fake_installer="$WORK/fake-installer.sh"
install_root="$WORK/install"
env_output="$WORK/env.sh"
receipt="$WORK/receipt.json"

python3 - "$manifest" <<'PY'
import json
import sys

tag = "1.3.0-alpha.fixture"
name = f"cangjie-sdk-linux-x64-{tag}.tar.gz"
manifest = {
    "schema": "happub-cangjie-sdk-mirror-manifest-v1",
    "ok": True,
    "status": "mirrored-verbatim",
    "checksumPolicy": {"authority": "mirror-computed-sha256"},
    "upstream": {"tag": tag},
    "mirror": {"tag": tag},
    "assetCount": 1,
    "assets": [{
        "name": name,
        "classification": "sdk",
        "sha256": "a" * 64,
        "mirrorUrl": f"https://github.com/HapPub/CangjieSDK-Mirror/releases/download/{tag}/{name}",
    }],
}
with open(sys.argv[1], "w", encoding="utf-8") as destination:
    json.dump(manifest, destination)
PY

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'printf "fake installer: %s %s %s %s\n" "$1" "$2" "$3" "$4"' \
  'mkdir -p "$3"' \
  'printf "export CANGJIE_HOME=%s\n" "$3" > "$4"' \
  > "$fake_installer"
chmod +x "$fake_installer"

HAP_INSTALL_CANGJIE_SDK="$fake_installer" \
  "$ROOT/scripts/ci/bootstrap-cangjie-from-mirror.sh" \
  "$manifest" linux-x64 "$install_root" "$env_output" "$receipt" > "$WORK/stdout"

grep -q 'Cangjie SDK bootstrap complete' "$WORK/stdout" || fail_test "completion output missing"
grep -q 'export CANGJIE_HOME=' "$env_output" || fail_test "environment output missing"
python3 - "$receipt" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
assert receipt["status"] == "verified-and-installed"
assert receipt["sdkSha256"] == "a" * 64
assert receipt["downloadActionTaken"] is True
assert receipt["environmentOutputWritten"] is True
PY

if HAP_INSTALL_CANGJIE_SDK="$fake_installer" \
  "$ROOT/scripts/ci/bootstrap-cangjie-from-mirror.sh" \
  "$manifest" unsupported "$install_root" "$env_output" "$receipt" >/dev/null 2>&1; then
  fail_test "unsupported platform did not fail closed"
fi

if HAP_INSTALL_CANGJIE_SDK="$fake_installer" \
  "$ROOT/scripts/ci/bootstrap-cangjie-from-mirror.sh" \
  "http://example.invalid/manifest.json" linux-x64 "$install_root" "$env_output" "$receipt" >/dev/null 2>&1; then
  fail_test "insecure manifest URL did not fail closed"
fi

printf '%s\n' 'cangjie mirror bootstrap tests passed'
