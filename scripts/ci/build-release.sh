#!/usr/bin/env bash
set -Eeuo pipefail

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
  if "$@" 2>&1 | tee "$log"; then
    status=0
  else
    status=${PIPESTATUS[0]}
    # Preserve a logging failure when the command itself succeeded.
    [[ $status -ne 0 ]] || status=1
  fi
  if [[ $status -ne 0 ]]; then
    if [[ $phase == test ]]; then
      detail=$(grep -m 1 -A 18 -E '\[[[:space:]]*(FAILED|ERROR)[[:space:]]*\][[:space:]]+CASE:' "$log" \
        | tr '\r\n' '  ' | cut -c1-6000 || true)
    else
      detail=$(grep -E '(^|[[:space:]])(error:|undefined symbol:|ld[^:]*: error:)' "$log" \
        | tail -n 8 | tr '\r\n' '  ' | cut -c1-1600 || true)
    fi
    if [[ -z $detail ]]; then
      detail=$(tail -n 6 "$log" | tr '\r\n' '  ' | cut -c1-1600)
    fi
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

phase=verify-build-toolchain
if [[ -n ${HAP_EXPECTED_SDK_VERSION:-} ]]; then
  compiler_version=$(cjc --version)
  printf '%s\n' "$compiler_version" | grep -F "Cangjie Compiler: $HAP_EXPECTED_SDK_VERSION " >/dev/null
fi

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
if [[ "$target" != windows-amd64 ]]; then
  run_logged_phase toolchain-get python3 tests/cangjie-toolchain-get.py "$binary"
  run_logged_phase sdk-toolchain-get python3 tests/sdk-toolchain-get.py "$binary"
fi
phase=sdk-environment-binary-smoke
actual_binary_version=$("$binary" version)
actual_binary_version=${actual_binary_version%$'\r'}
[[ "$actual_binary_version" == "$version" ]] || {
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
mkdir -p "$stage/$package/docs"
cp docs/INSTALLATION.md docs/SDK_TOOLCHAINS.md docs/HOST_TOOLS.md "$stage/$package/docs/"
phase=bundle-native-runtime
python_bin=${PYTHON:-python3}
"$python_bin" "$hap_release_script_dir/bundle-native-runtime.py" \
  --target "$target" --sdk-root "$CANGJIE_HOME" \
  --binary "$stage/$package/bin/$binary_name"

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

phase=archive-extract
verify=$(mktemp -d "$temp_root/hap-smoke.XXXXXXXX")
if [[ "$archive_extension" == zip ]]; then
  "$python_bin" -m zipfile -e "$archive" "$verify"
else
  tar -xzf "$archive" -C "$verify"
fi
phase=sdk-independent-runtime-smoke
runtime_receipt="$dist_dir/$package.runtime-portability.json"
bash "$hap_release_script_dir/verify-sdk-independent-runtime.sh" \
  "$target" \
  "$version" \
  "$verify/$package/bin/$binary_name" \
  "$archive" \
  "$runtime_receipt"
rm -rf "$verify"

phase=complete
printf 'Release asset ready: %s\n' "$archive"
