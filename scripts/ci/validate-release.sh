#!/usr/bin/env bash
set -euo pipefail

tag=${1:-${GITHUB_REF_NAME:-}}
[[ -n "$tag" ]] || {
  printf 'release tag is required\n' >&2
  exit 2
}

version=$(awk '
  /^\[package\]/ { package = 1; next }
  /^\[/ { package = 0 }
  package && /^[[:space:]]*version[[:space:]]*=/ {
    value = $0
    sub(/^[^=]*=[[:space:]]*"/, "", value)
    sub(/"[[:space:]]*$/, "", value)
    print value
    exit
  }
' cjpm.toml)

[[ -n "$version" ]] || {
  printf 'could not read package version from cjpm.toml\n' >&2
  exit 1
}
[[ "$tag" == "v$version" ]] || {
  printf 'tag %s does not match package version v%s\n' "$tag" "$version" >&2
  exit 1
}
grep -Fq "HapCliVersion: String = \"$version\"" src/hapcli.cj || {
  printf 'src/hapcli.cj version does not match %s\n' "$version" >&2
  exit 1
}

printf '%s\n' "$version"
