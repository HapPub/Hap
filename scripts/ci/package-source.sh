#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <version> <dist-dir>\n' "$0" >&2
  exit 2
fi

version=$1
dist_dir=$2
hap_source_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$dist_dir"
archive="$dist_dir/hap-$version-source.tar.gz"

git archive \
  --format=tar.gz \
  --prefix="hap-$version-source/" \
  --output="$archive" \
  HEAD
tar -tzf "$archive" >/dev/null
bash "$hap_source_script_dir/write-sha256-sidecar.sh" "$archive"

printf 'Source asset ready: %s\n' "$archive"
