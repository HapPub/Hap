#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

fail_test() {
  printf 'public surface test failed: %s\n' "$*" >&2
  exit 1
}

require_text() {
  file=$1
  text=$2
  message=$3
  grep -Fq -- "$text" "$file" || fail_test "$message"
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

for readme in README.md README.zh-CN.md README.ru.md; do
  require_text "$ROOT/$readme" 'hap install cangjie@nightly' \
    "$readme does not expose dynamic nightly installation"
  require_text "$ROOT/$readme" 'https://cli.hap.pub/manifests/cangjie-install-v1.json' \
    "$readme does not state the schema-gated supplementary dictionary"
  require_text "$ROOT/$readme" '1.0.5' \
    "$readme does not state the pinned LTS"
  require_text "$ROOT/$readme" '1.1.3' \
    "$readme does not state the exact STS"
done

require_text "$ROOT/docs/COMMAND_REFERENCE.md" 'nightly` dynamically resolves the newest' \
  "command reference does not explain dynamic nightly resolution"
require_text "$ROOT/docs/STDX_RUNTIME_EXECUTION_BOUNDARY.md" 'explicit `hap install cangjie*` request' \
  "stdx/runtime boundary does not distinguish explicit package installation"
require_text "$ROOT/src/cli_runtime.cj" 'nightly resolves dynamically' \
  "CLI help does not expose dynamic nightly behavior"
require_text "$ROOT/src/cangjie_dynamic_catalog.cj" 'https://cli.hap.pub/manifests/cangjie-install-v1.json' \
  "dynamic catalog source and public dictionary URL have drifted"

if grep -Fq -- 'no hidden runtime/stdx install inside flagship' "$ROOT/docs/STDX_RUNTIME_EXECUTION_BOUNDARY.md"; then
  fail_test "stdx/runtime boundary still denies the explicit package install surface"
fi

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
  --exclude='*.pyc' \
  --exclude-dir=.git \
  --exclude-dir=target \
  --exclude-dir=__pycache__ \
  --exclude-dir=.cache \
  --exclude-dir=.vscode \
  "$ROOT"; then
  fail_test "private or internal fixture text is present"
fi

printf '%s\n' "public surface tests passed"
