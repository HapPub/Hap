#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: %s <file>\n' "$0" >&2
  exit 2
fi

input=$1
[[ -f "$input" ]] || {
  printf 'checksum input is missing: %s\n' "$input" >&2
  exit 1
}

name=$(basename "$input")
if command -v sha256sum >/dev/null 2>&1; then
  digest=$(sha256sum "$input" | awk '{print $1}')
else
  digest=$(shasum -a 256 "$input" | awk '{print $1}')
fi

printf '%s  %s\n' "$digest" "$name" > "$input.sha256"
