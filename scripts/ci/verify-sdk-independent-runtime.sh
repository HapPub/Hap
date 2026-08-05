#!/usr/bin/env bash
set -euo pipefail

forbidden_environment=(
  CANGJIE_HOME
  CANGJIE_STDX_PATH
  CJC_HOME
  CJPM_HOME
  LD_LIBRARY_PATH
  DYLD_LIBRARY_PATH
  LIBRARY_PATH
  CPATH
  C_INCLUDE_PATH
  CPLUS_INCLUDE_PATH
  SDKROOT
  DEVECO_CANGJIE_HOME
  DEVECO_OH_NATIVE_HOME
  OHOS_SDK_NATIVE
)

if [[ ${1:-} == --clean-child ]]; then
  [[ $# -eq 3 ]] || exit 2
  executable=$2
  expected_version=$3

  for name in "${forbidden_environment[@]}"; do
    if [[ -n ${!name+x} ]]; then
      printf 'forbidden SDK environment variable survived clean launch: %s\n' "$name" >&2
      exit 1
    fi
  done
  case ${PATH:-} in
    *[Cc]angjie*|*[Cc]jpm*|*[Cc]jc*)
      printf 'clean runtime PATH still contains an SDK-shaped entry: %s\n' "$PATH" >&2
      exit 1
      ;;
  esac

  actual_version=$("$executable" version)
  actual_version=${actual_version%$'\r'}
  [[ "$actual_version" == "$expected_version" ]] || {
    printf 'clean runtime version mismatch: expected=%s actual=%s\n' \
      "$expected_version" "$actual_version" >&2
    exit 1
  }
  printf '%s\n' "$actual_version"
  exit 0
fi

if [[ $# -ne 5 ]]; then
  printf 'usage: %s <target> <version> <executable> <archive> <receipt>\n' "$0" >&2
  exit 2
fi

target=$1
version=$2
executable=$3
archive=$4
receipt=$5

case "$target" in
  linux-amd64|linux-arm64|darwin-arm64|darwin-amd64|windows-amd64) ;;
  *)
    printf 'unsupported SDK-independent runtime smoke target: %s\n' "$target" >&2
    exit 2
    ;;
esac
[[ -x "$executable" ]] || {
  printf 'runtime smoke executable is missing: %s\n' "$executable" >&2
  exit 1
}
[[ -f "$archive" ]] || {
  printf 'runtime smoke archive is missing: %s\n' "$archive" >&2
  exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script_path="$script_dir/$(basename -- "$0")"
smoke_root=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/hap-clean-runtime.XXXXXXXX")
trap 'rm -rf "$smoke_root"' EXIT
output="$smoke_root/version.txt"

if [[ "$target" == windows-* ]]; then
  system_root=${SYSTEMROOT:-${SystemRoot:-C:\\Windows}}
  windows_dir=${WINDIR:-${windir:-$system_root}}
  command_shell=${COMSPEC:-$system_root\\System32\\cmd.exe}
  env -i \
    SYSTEMROOT="$system_root" \
    SystemRoot="$system_root" \
    WINDIR="$windows_dir" \
    COMSPEC="$command_shell" \
    TEMP="$smoke_root" \
    TMP="$smoke_root" \
    HOME="$smoke_root" \
    PATH=/usr/bin:/bin \
    LANG=C \
    LC_ALL=C \
    bash "$script_path" --clean-child "$executable" "$version" > "$output"
  allowed_environment='["SYSTEMROOT", "SystemRoot", "WINDIR", "COMSPEC", "TEMP", "TMP", "HOME", "PATH", "LANG", "LC_ALL"]'
else
  env -i \
    HOME="$smoke_root" \
    TMPDIR="$smoke_root" \
    PATH=/usr/bin:/bin \
    LANG=C \
    LC_ALL=C \
    bash "$script_path" --clean-child "$executable" "$version" > "$output"
  allowed_environment='["HOME", "TMPDIR", "PATH", "LANG", "LC_ALL"]'
fi

actual_version=$(tr -d '\r\n' < "$output")
[[ "$actual_version" == "$version" ]]

python_bin=${PYTHON:-python3}
mkdir -p "$(dirname -- "$receipt")"
"$python_bin" - \
  "$receipt" "$target" "$version" "$actual_version" \
  "$executable" "$archive" "$allowed_environment" <<'PY'
import hashlib
import json
import pathlib
import sys


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


receipt, target, version, actual, executable, archive, allowed = sys.argv[1:]
payload = {
    "schema": "happub-hap-native-runtime-portability-receipt-v1",
    "ok": True,
    "status": "sdk-independent-runtime-smoke-verified",
    "target": target,
    "version": version,
    "environmentMode": "empty-inherited-environment-with-minimal-os-baseline",
    "inheritedSdkEnvironment": False,
    "allowedEnvironmentVariables": json.loads(allowed),
    "clearedEnvironmentVariables": [
        "CANGJIE_HOME",
        "CANGJIE_STDX_PATH",
        "CJC_HOME",
        "CJPM_HOME",
        "LD_LIBRARY_PATH",
        "DYLD_LIBRARY_PATH",
        "LIBRARY_PATH",
        "CPATH",
        "C_INCLUDE_PATH",
        "CPLUS_INCLUDE_PATH",
        "SDKROOT",
        "DEVECO_CANGJIE_HOME",
        "DEVECO_OH_NATIVE_HOME",
        "OHOS_SDK_NATIVE",
    ],
    "archive": {
        "name": pathlib.Path(archive).name,
        "sha256": sha256(pathlib.Path(archive)),
    },
    "binary": {
        "name": pathlib.Path(executable).name,
        "sha256": sha256(pathlib.Path(executable)),
    },
    "smoke": {
        "command": "hap version",
        "expectedVersion": version,
        "actualVersion": actual,
        "exitCode": 0,
    },
    "nonPromises": [
        "version smoke does not verify every Hap command or external toolchain",
        "native runtime smoke does not widen cross-built OHOS runtime claims",
    ],
}
pathlib.Path(receipt).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

printf 'SDK-independent runtime smoke verified: %s\n' "$target"
