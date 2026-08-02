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
archive="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/cangjie-sdk.tar.gz"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

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

mkdir -p "$install_root" "$(dirname "$env_output")"
curl --proto '=https' --tlsv1.2 --location --fail --show-error --silent \
  "$sdk_url" --output "$archive"

if command -v sha256sum >/dev/null 2>&1; then
  actual_sha=$(sha256sum "$archive" | awk '{print $1}')
else
  actual_sha=$(shasum -a 256 "$archive" | awk '{print $1}')
fi
[[ "$actual_sha" == "$expected_sha" ]] || {
  printf 'SDK checksum mismatch: expected %s, got %s\n' "$expected_sha" "$actual_sha" >&2
  exit 1
}

python3 "$script_dir/safe-extract-tar.py" "$archive" "$install_root"

envsetup=$(find "$install_root" -maxdepth 5 -type f -name envsetup.sh -print | head -n 1)
[[ -n "$envsetup" ]] || {
  printf 'SDK archive did not contain envsetup.sh\n' >&2
  exit 1
}

printf 'source %q\n' "$envsetup" > "$env_output"
printf 'Cangjie SDK ready: %s\n' "$envsetup"
