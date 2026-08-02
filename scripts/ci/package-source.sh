#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <version> <dist-dir>\n' "$0" >&2
  exit 2
fi

version=$1
dist_dir=$2
mkdir -p "$dist_dir"
archive="$dist_dir/hap-$version-source.tar.gz"

git archive \
  --format=tar.gz \
  --prefix="hap-$version-source/" \
  --output="$archive" \
  HEAD
tar -tzf "$archive" >/dev/null

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$archive" > "$archive.sha256"
else
  shasum -a 256 "$archive" > "$archive.sha256"
fi

printf 'Source asset ready: %s\n' "$archive"
