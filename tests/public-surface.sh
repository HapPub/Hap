#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

fail_test() {
  printf 'public surface test failed: %s\n' "$*" >&2
  exit 1
}

[ -f "$ROOT/LICENSE" ] || fail_test "LICENSE is missing"
[ -f "$ROOT/README.md" ] || fail_test "English README is missing"
[ -f "$ROOT/README.zh-CN.md" ] || fail_test "Chinese README is missing"
[ -f "$ROOT/README.ru.md" ] || fail_test "Russian README is missing"

grep -q 'Apache License' "$ROOT/LICENSE" || fail_test "LICENSE is not Apache License 2.0"
grep -q 'license = "Apache-2.0"' "$ROOT/cjpm.toml" || fail_test "CJPM license metadata is not Apache-2.0"
grep -q '\[简体中文\](README.zh-CN.md)' "$ROOT/README.md" || fail_test "English README does not link Chinese"
grep -q '\[Русский\](README.ru.md)' "$ROOT/README.md" || fail_test "English README does not link Russian"
grep -q '\[English\](README.md)' "$ROOT/README.zh-CN.md" || fail_test "Chinese README does not link English"
grep -q '\[English\](README.md)' "$ROOT/README.ru.md" || fail_test "Russian README does not link English"

sh -n "$ROOT/release/hapup.sh"

python3 - "$ROOT/release/manifest.v0.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert manifest["schema"] == "happub-release-manifest-v0"
assert manifest["channel"] == "preview"
assert all("sha256" in asset for asset in manifest["downloadableAssets"])
PY

if command -v sha256sum >/dev/null 2>&1; then
  HAPUP_SHA=$(sha256sum "$ROOT/release/hapup.sh" | awk '{print $1}')
else
  HAPUP_SHA=$(shasum -a 256 "$ROOT/release/hapup.sh" | awk '{print $1}')
fi
python3 - "$ROOT/release/manifest.v0.json" "$ROOT/src/release_manifest.cj" "$HAPUP_SHA" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
source = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
actual = sys.argv[3]
asset = next(item for item in manifest["downloadableAssets"] if item["id"] == "hapup-sh")
assert asset["sha256"] == actual
assert actual in source
PY

if grep -R -n -E \
  'ExplorerX|CinPadA12X|4VF[0-9A-Z]+|5E8E1D23-1104-5A06-BA18-940124D86DDF|00008027-000925093422002E|/Users/cinyu|cela@vip\.qq\.com|Haomo|EveMind|WhyMind|HC[0-9]{3}|H036C|hapcli-(hc|h)[0-9]{3}' \
  --exclude=public-surface.sh \
  --exclude-dir=.git \
  --exclude-dir=target \
  --exclude-dir=.cache \
  --exclude-dir=.vscode \
  "$ROOT"; then
  fail_test "private or internal fixture text is present"
fi

printf '%s\n' "public surface tests passed"
