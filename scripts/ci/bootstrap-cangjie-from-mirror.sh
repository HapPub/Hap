#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s <manifest-url-or-path> <sdk-platform> <install-root> <env-output> [resolution-output]\n' "$0" >&2
}

if [[ $# -lt 4 || $# -gt 5 ]]; then
  usage
  exit 2
fi

manifest_source=$1
sdk_platform=$2
install_root=$3
env_output=$4
resolution_output=${5:-$install_root/cangjie-sdk-resolution.json}
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python_bin=${PYTHON:-python3}
resolver=${HAP_RESOLVE_NIGHTLY_SDK:-$script_dir/resolve-nightly-sdk.py}
installer=${HAP_INSTALL_CANGJIE_SDK:-$script_dir/install-cangjie-sdk.sh}
temp_root=${RUNNER_TEMP:-${TMPDIR:-/tmp}}

case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    command -v cygpath >/dev/null 2>&1 || {
      printf 'cygpath is required by the Windows Bash runner\n' >&2
      exit 1
    }
    temp_root=$(cygpath -u "$temp_root")
    install_root=$(cygpath -u "$install_root")
    env_output=$(cygpath -u "$env_output")
    resolution_output=$(cygpath -u "$resolution_output")
    case "$manifest_source" in
      https://*|http://*|file://*) ;;
      *) manifest_source=$(cygpath -u "$manifest_source") ;;
    esac
    ;;
esac

work=$(mktemp -d "$temp_root/hap-cangjie-bootstrap.XXXXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

manifest="$work/manifest.v1.json"
selection="$work/sdk-selection.json"

case "$manifest_source" in
  https://*)
    curl --proto '=https' --tlsv1.2 --location --fail --show-error --silent \
      --retry 3 --retry-delay 2 --retry-all-errors \
      "$manifest_source" --output "$manifest"
    ;;
  http://*)
    printf 'refusing insecure manifest URL: %s\n' "$manifest_source" >&2
    exit 1
    ;;
  file://*)
    cp "${manifest_source#file://}" "$manifest"
    ;;
  *)
    cp "$manifest_source" "$manifest"
    ;;
esac

[[ -s "$manifest" ]] || {
  printf 'mirror manifest is empty: %s\n' "$manifest_source" >&2
  exit 1
}
[[ -f "$resolver" ]] || {
  printf 'missing mirror resolver: %s\n' "$resolver" >&2
  exit 1
}
[[ -x "$installer" ]] || {
  printf 'missing executable Cangjie SDK installer: %s\n' "$installer" >&2
  exit 1
}

"$python_bin" "$resolver" \
  --manifest "$manifest" \
  --platform "$sdk_platform" > "$selection"

sdk_url=$("$python_bin" - "$selection" <<'PY'
import json
import sys

selection = json.load(open(sys.argv[1], encoding="utf-8"))
if selection.get("status") != "selected-from-complete-mirror-manifest":
    raise SystemExit("mirror resolver did not return a complete selection")
print(selection["sdkUrl"])
PY
)
sdk_sha256=$("$python_bin" - "$selection" <<'PY'
import json
import sys

selection = json.load(open(sys.argv[1], encoding="utf-8"))
print(selection["sdkSha256"])
PY
)

"$installer" "$sdk_url" "$sdk_sha256" "$install_root" "$env_output"

mkdir -p "$(dirname -- "$resolution_output")"
"$python_bin" - "$selection" "$resolution_output" "$install_root" "$env_output" <<'PY'
import json
import pathlib
import sys

selection_path, output_path, install_root, env_output = sys.argv[1:]
selection = json.loads(pathlib.Path(selection_path).read_text(encoding="utf-8"))
selection.update({
    "schema": "happub-hapcli-cangjie-mirror-bootstrap-receipt-v1",
    "status": "verified-and-installed",
    "installRoot": install_root,
    "envOutput": env_output,
    "resolveActionTaken": True,
    "downloadActionTaken": True,
    "installActionTaken": True,
    "environmentOutputWritten": True,
})
pathlib.Path(output_path).write_text(json.dumps(selection, indent=2) + "\n", encoding="utf-8")
PY

printf 'Cangjie SDK bootstrap complete: platform=%s root=%s env=%s receipt=%s\n' \
  "$sdk_platform" "$install_root" "$env_output" "$resolution_output"
