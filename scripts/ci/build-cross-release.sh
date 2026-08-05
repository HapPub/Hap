#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  printf 'usage: %s <target> <version> <cangjie-env-file> <ohos-native-root> <dist-dir>\n' "$0" >&2
  exit 2
fi

target=$1
version=$2
env_file=$3
ohos_native_root=$4
dist_dir=$5
phase=argument-validation

report_build_error() {
  status=$?
  trap - ERR
  printf 'Hap cross build failed during %s (exit %s)\n' "$phase" "$status" >&2
  if [[ ${GITHUB_ACTIONS:-} == true ]]; then
    printf '::error title=Hap cross build failed::phase=%s; exit=%s\n' "$phase" "$status"
  fi
  exit "$status"
}
trap report_build_error ERR

case "$target" in
  ohos-arm64)
    triple=aarch64-linux-ohos
    machine=aarch64
    ;;
  ohos-amd64)
    triple=x86_64-linux-ohos
    machine=x86_64
    ;;
  *)
    printf 'unsupported cross release target: %s\n' "$target" >&2
    exit 2
    ;;
esac

phase=load-sdk-environment
set +u
source "$env_file"
set -u
export OHOS_SDK_NATIVE=$ohos_native_root
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
temp_root=${RUNNER_TEMP:-${TMPDIR:-/tmp}}

phase=validate-sysroot
command -v python3 >/dev/null 2>&1 || {
  printf 'python3 is required to verify and package cross-built binaries\n' >&2
  exit 1
}
for required in \
  "$OHOS_SDK_NATIVE/sysroot/usr/lib/$triple/Scrt1.o" \
  "$OHOS_SDK_NATIVE/sysroot/usr/lib/$triple/crti.o" \
  "$OHOS_SDK_NATIVE/sysroot/usr/lib/$triple/crtn.o"
do
  [[ -f "$required" ]] || {
    printf 'OpenHarmony sysroot file is missing: %s\n' "$required" >&2
    exit 1
  }
done

phase=validate-release
actual_version=$(bash scripts/ci/validate-release.sh "v$version")
[[ "$actual_version" == "$version" ]]

phase=build
cjpm build --target "$triple"

phase=verify-architecture
binary="target/$triple/release/bin/main"
[[ -x "$binary" ]] || {
  printf 'cross-built binary is missing: %s\n' "$binary" >&2
  exit 1
}
python3 "$script_dir/verify-elf-target.py" --binary "$binary" --machine "$machine"

phase=package
stage=$(mktemp -d "$temp_root/hap-cross-release.XXXXXXXX")
trap 'rm -rf "$stage"' EXIT
package="hap-$version-$target"
mkdir -p "$stage/$package/bin" "$dist_dir"
cp "$binary" "$stage/$package/bin/hap"
chmod 0755 "$stage/$package/bin/hap"
cp LICENSE NOTICE README.md "$stage/$package/"
python3 - "$stage/$package/CROSS_BUILD_RECEIPT.json" "$target" "$triple" "$version" <<'PY'
import json
import pathlib
import sys

path, target, triple, version = sys.argv[1:]
receipt = {
    "schema": "happub-hap-cross-build-receipt-v1",
    "ok": True,
    "target": target,
    "compilerTarget": triple,
    "hapVersion": version,
    "status": "cross-built-link-verified",
    "runtimeSmokeVerified": False,
    "nonPromises": [
        "the binary was not executed on an OpenHarmony or HarmonyOS runtime",
        "the archive does not bundle a target Cangjie runtime or device signing proof",
    ],
}
pathlib.Path(path).write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
PY

archive="$dist_dir/$package.tar.gz"
tar -czf "$archive" -C "$stage" "$package"
bash "$script_dir/write-sha256-sidecar.sh" "$archive"

phase=archive-verify
verify=$(mktemp -d "$temp_root/hap-cross-verify.XXXXXXXX")
tar -xzf "$archive" -C "$verify"
python3 "$script_dir/verify-elf-target.py" \
  --binary "$verify/$package/bin/hap" --machine "$machine"
python3 - "$verify/$package/CROSS_BUILD_RECEIPT.json" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
assert receipt["ok"] is True
assert receipt["status"] == "cross-built-link-verified"
assert receipt["runtimeSmokeVerified"] is False
PY
rm -rf "$verify"

phase=complete
printf 'Cross release asset ready: %s\n' "$archive"
