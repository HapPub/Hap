#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  printf 'usage: %s <sdk-url> <sha256> <install-root> <env-output>\n' "$0" >&2
  exit 2
fi

sdk_url=$1
expected_sha=$2
install_root=$3
env_output=$4
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python_bin=${PYTHON:-python3}
phase=argument-validation

report_install_error() {
  status=$?
  trap - ERR
  printf 'Cangjie SDK install failed during %s (exit %s)\n' "$phase" "$status" >&2
  if [[ ${GITHUB_ACTIONS:-} == true ]]; then
    printf '::error title=Cangjie SDK install failed::phase=%s; exit=%s\n' \
      "$phase" "$status"
  fi
  exit "$status"
}
trap report_install_error ERR

# GitHub's Bash runner exposes RUNNER_TEMP as a Windows drive path. Normalize
# it before mixing native Python with MSYS tools so every process sees one root.
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
    ;;
esac
archive="$temp_root/cangjie-sdk.archive"

case "$expected_sha" in
  *[!0-9a-fA-F]*|'')
    printf 'invalid SDK SHA-256: %s\n' "$expected_sha" >&2
    exit 2
    ;;
esac
[[ ${#expected_sha} -eq 64 ]] || {
  printf 'invalid SDK SHA-256 length\n' >&2
  exit 2
}

phase=prepare-destination
mkdir -p "$install_root" "$(dirname "$env_output")"
phase=download
curl --proto '=https' --tlsv1.2 --location --fail --show-error --silent \
  "$sdk_url" --output "$archive"
[[ -s "$archive" ]]

phase=checksum
actual_sha=$("$python_bin" - "$archive" <<'PY'
import hashlib
import pathlib
import sys

digest = hashlib.sha256()
with pathlib.Path(sys.argv[1]).open("rb") as source:
    for chunk in iter(lambda: source.read(1024 * 1024), b""):
        digest.update(chunk)
print(digest.hexdigest())
PY
)
[[ "$actual_sha" == "$expected_sha" ]] || {
  printf 'SDK checksum mismatch: expected %s, got %s\n' "$expected_sha" "$actual_sha" >&2
  exit 1
}

phase=extract
"$python_bin" "$script_dir/safe-extract-sdk.py" "$archive" "$install_root"

phase=discover-environment
envsetup=$(find "$install_root" -maxdepth 5 -type f -name envsetup.sh -print | head -n 1)
if [[ -n "$envsetup" ]]; then
  printf 'source %q\n' "$envsetup" > "$env_output"
  phase=complete
  printf 'Cangjie SDK ready: %s\n' "$envsetup"
  exit 0
fi

cjpm_exe=$(find "$install_root" -maxdepth 7 -type f -iname cjpm.exe -print | head -n 1)
[[ -n "$cjpm_exe" ]] || {
  printf 'SDK archive did not contain envsetup.sh or cjpm.exe\n' >&2
  exit 1
}
cangjie_bin=$(dirname "$cjpm_exe")
cangjie_home=$(dirname "$cangjie_bin")
{
  printf 'export CANGJIE_HOME=%q\n' "$cangjie_home"
  printf 'export PATH=%q:"$PATH"\n' "$cangjie_bin"
} > "$env_output"
phase=complete
printf 'Cangjie SDK ready: %s\n' "$cjpm_exe"
