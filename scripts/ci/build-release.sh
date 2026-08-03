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
  linux-amd64|linux-arm64|darwin-arm64|darwin-amd64|windows-amd64) ;;
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
if [[ "$target" == darwin-* ]]; then
  export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
  export COPYFILE_DISABLE=1
fi

actual_version=$(bash scripts/ci/validate-release.sh "v$version")
[[ "$actual_version" == "$version" ]]

cjpm build
cjpm test --timeout-each=30s --no-progress --no-color

binary=target/release/bin/main
binary_name=hap
archive_extension=tar.gz
if [[ "$target" == windows-amd64 ]]; then
  binary=target/release/bin/main.exe
  binary_name=hap.exe
  archive_extension=zip
fi
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
cp "$binary" "$stage/$package/bin/$binary_name"
chmod 0755 "$stage/$package/bin/$binary_name"
cp LICENSE NOTICE README.md "$stage/$package/"

archive="$dist_dir/$package.$archive_extension"
python_bin=${PYTHON:-python3}
if [[ "$archive_extension" == zip ]]; then
  "$python_bin" - "$stage/$package" "$archive" <<'PY'
import pathlib
import sys
import zipfile

source = pathlib.Path(sys.argv[1])
archive = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted(source.rglob("*")):
        if path.is_file():
            bundle.write(path, path.relative_to(source.parent))
PY
else
  tar -czf "$archive" -C "$stage" "$package"
fi
bash "$hap_release_script_dir/write-sha256-sidecar.sh" "$archive"

verify=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/hap-smoke.XXXXXXXX")
if [[ "$archive_extension" == zip ]]; then
  "$python_bin" -m zipfile -e "$archive" "$verify"
else
  tar -xzf "$archive" -C "$verify"
fi
"$verify/$package/bin/$binary_name" version | grep -Fx "$version" >/dev/null
rm -rf "$verify"

printf 'Release asset ready: %s\n' "$archive"
