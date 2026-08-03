#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  printf 'usage: %s <target> <version> <env-file> <dist-dir>\n' "$0" >&2
  exit 2
fi

target=$1
version=$2
env_file=$3
dist_dir=$4

case "$target" in
  linux-amd64|linux-arm64|darwin-arm64) ;;
  *)
    printf 'unsupported release target: %s\n' "$target" >&2
    exit 2
    ;;
esac

# The official envsetup scripts may read optional variables before assigning
# them, so nounset is suspended only while the reviewed SDK environment loads.
set +u
source "$env_file"
set -u
hap_release_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [[ "$target" == darwin-arm64 ]]; then
  export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
  export COPYFILE_DISABLE=1
fi

actual_version=$(bash scripts/ci/validate-release.sh "v$version")
[[ "$actual_version" == "$version" ]]

cjpm build
cjpm test --timeout-each=30s --no-progress --no-color

binary=target/release/bin/main
[[ -x "$binary" ]] || {
  printf 'release binary is missing: %s\n' "$binary" >&2
  exit 1
}
[[ "$("$binary" version)" == "$version" ]] || {
  printf 'release binary version smoke failed\n' >&2
  exit 1
}

stage=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/hap-release.XXXXXXXX")
trap 'rm -rf "$stage"' EXIT
package="hap-$version-$target"
mkdir -p "$stage/$package/bin" "$dist_dir"
cp "$binary" "$stage/$package/bin/hap"
chmod 0755 "$stage/$package/bin/hap"
cp LICENSE NOTICE README.md "$stage/$package/"

archive="$dist_dir/$package.tar.gz"
tar -czf "$archive" -C "$stage" "$package"
bash "$hap_release_script_dir/write-sha256-sidecar.sh" "$archive"

verify=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/hap-smoke.XXXXXXXX")
tar -xzf "$archive" -C "$verify"
"$verify/$package/bin/hap" version | grep -Fx "$version" >/dev/null
rm -rf "$verify"

printf 'Release asset ready: %s\n' "$archive"
