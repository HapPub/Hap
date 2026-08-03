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
phase=argument-validation

report_build_error() {
  status=$?
  trap - ERR
  printf 'Hap release build failed during %s (exit %s)\n' "$phase" "$status" >&2
  if [[ ${GITHUB_ACTIONS:-} == true ]]; then
    printf '::error title=Hap release build failed::phase=%s; exit=%s\n' \
      "$phase" "$status"
  fi
  exit "$status"
}
trap report_build_error ERR

temp_root=${RUNNER_TEMP:-${TMPDIR:-/tmp}}
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    command -v cygpath >/dev/null 2>&1 || {
      printf 'cygpath is required by the Windows Bash runner\n' >&2
      exit 1
    }
    temp_root=$(cygpath -u "$temp_root")
    env_file=$(cygpath -u "$env_file")
    ;;
esac

run_logged_phase() {
  phase=$1
  shift
  log="$temp_root/hap-release-$phase.log"
  set +e
  "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    detail=$(tail -n 4 "$log" | tr '\r\n' '  ' | cut -c1-800)
    printf 'Hap release build failed during %s (exit %s): %s\n' \
      "$phase" "$status" "$detail" >&2
    if [[ ${GITHUB_ACTIONS:-} == true ]]; then
      detail=${detail//'%'/'%25'}
      detail=${detail//$'\r'/'%0D'}
      detail=${detail//$'\n'/'%0A'}
      printf '::error title=Hap release build failed::phase=%s; exit=%s; detail=%s\n' \
        "$phase" "$status" "$detail"
    fi
    exit "$status"
  fi
}

case "$target" in
  linux-amd64|linux-arm64|darwin-arm64|darwin-amd64|windows-amd64) ;;
  *)
    printf 'unsupported release target: %s\n' "$target" >&2
    exit 2
    ;;
esac

# The official envsetup scripts may read optional variables before assigning
# them, so nounset is suspended only while the reviewed SDK environment loads.
phase=load-sdk-environment
set +u
source "$env_file"
set -u
hap_release_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [[ "$target" == darwin-* ]]; then
  export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
  export COPYFILE_DISABLE=1
fi

phase=validate-release
actual_version=$(bash scripts/ci/validate-release.sh "v$version")
[[ "$actual_version" == "$version" ]]

run_logged_phase build cjpm build
run_logged_phase test cjpm test --timeout-each=30s --no-progress --no-color

phase=locate-binary
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

phase=package
stage=$(mktemp -d "$temp_root/hap-release.XXXXXXXX")
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

phase=archive-smoke
verify=$(mktemp -d "$temp_root/hap-smoke.XXXXXXXX")
if [[ "$archive_extension" == zip ]]; then
  "$python_bin" -m zipfile -e "$archive" "$verify"
else
  tar -xzf "$archive" -C "$verify"
fi
"$verify/$package/bin/$binary_name" version | grep -Fx "$version" >/dev/null
rm -rf "$verify"

phase=complete
printf 'Release asset ready: %s\n' "$archive"
