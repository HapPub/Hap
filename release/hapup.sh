#!/bin/sh
set -eu

VERSION="0.1.0-preview.2"

usage() {
  cat <<'EOF'
Usage:
  hapup version
  hapup help
  hapup install-from-manifest --manifest <path|file://...|https://...> --install-dir <dir> [--target auto|darwin-arm64|darwin-amd64|linux-amd64|linux-arm64] [--manifest-sha256 <sha256>] [--receipt <path>] [--review-token <token>] [--allow-system-dir] [--allow-unverified-manifest]
  hapup install-flagship --asset <path|file://...|https://...> --sha256 <sha256> --install-dir <dir> [--receipt <path>] [--review-token <token>] [--allow-system-dir]
  hapup restore-flagship --install-dir <dir> [--backup <path>] [--receipt <path>] [--review-token <token>] [--allow-system-dir]
  hapup install-cangjie-sdk --archive <path|file://...|https://...> --target ohos-arm64 --install-root <dir> [--version <version>] [--sha256 <sha256>|--allow-unverified] [--receipt <path>] [--review-token <token>] [--replace] [--binary-sign-tool <path>] [--no-sign-ohos-binaries]

Hapup is the thin bootstrap companion for HapCLI.
It installs a reviewed flagship asset only when asset path, checksum, install
directory, and review token are explicit. Reviewed SDK archive install is local
and receipt-backed; Hapup does not manage SDK versions, mutate project manifests,
or silently write shell rc files.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 64
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

secure_temp_dir() {
  purpose="$1"
  need_cmd mktemp
  base="${TMPDIR:-/tmp}"
  [ -d "$base" ] || fail "temporary directory root does not exist: $base"
  work=$(umask 077; mktemp -d "$base/hapup-$purpose.XXXXXXXX") || fail "cannot create secure temporary directory"
  [ -d "$work" ] || fail "secure temporary directory was not created"
  if command -v id >/dev/null 2>&1 && command -v ls >/dev/null 2>&1; then
    current_uid=$(id -u)
    work_uid=$(ls -dn "$work" | awk '{print $3}')
    if [ -n "$work_uid" ] && [ "$work_uid" != "$current_uid" ]; then
      rm -rf "$work"
      fail "temporary directory is not owned by the current user"
    fi
  fi
  printf '%s\n' "$work"
}

canonical_existing_dir() {
  dir="$1"
  [ -d "$dir" ] || fail "directory does not exist: $dir"
  (CDPATH= cd -- "$dir" && pwd -P) || fail "cannot resolve directory: $dir"
}

prepare_install_dir() {
  dir="$1"
  mkdir -p "$dir" || fail "cannot create install directory: $dir"
  canonical_existing_dir "$dir"
}

validate_tar_archive() {
  archive="$1"
  work="$2"
  allow_links="$3"
  members="$work/tar-members.txt"
  verbose="$work/tar-verbose.txt"

  tar -tzf "$archive" > "$members" 2>/dev/null || fail "archive is not a valid tar.gz"
  [ -s "$members" ] || fail "archive is empty"
  if ! awk '
    function safe_path(path, count, parts, i) {
      if (path == "" || path ~ /^\// || path ~ /\\/) return 0
      count = split(path, parts, "/")
      for (i = 1; i <= count; i++) {
        if (parts[i] == "..") return 0
      }
      return 1
    }
    !safe_path($0) { exit 1 }
  ' "$members"; then
    fail "archive contains an unsafe member path"
  fi

  tar -tvzf "$archive" > "$verbose" 2>/dev/null || fail "archive member metadata is unreadable"
  if ! awk -v allow_links="$allow_links" '
    function safe_path(path, count, parts, i) {
      if (path == "" || path ~ /^\// || path ~ /\\/) return 0
      count = split(path, parts, "/")
      for (i = 1; i <= count; i++) {
        if (parts[i] == "..") return 0
      }
      return 1
    }
    {
      type = substr($1, 1, 1)
      if (type == "b" || type == "c" || type == "p" || type == "s") exit 1
      if (type == "l" || type == "h") {
        if (allow_links != "true") exit 1
        marker = type == "l" ? " -> " : " link to "
        pos = index($0, marker)
        if (pos == 0) exit 1
        target = substr($0, pos + length(marker))
        if (!safe_path(target)) exit 1
      }
    }
  ' "$verbose"; then
    fail "archive contains an unsafe member type or link target"
  fi
}

verify_checksum() {
  file="$1"
  expected="$2"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    printf '%s  %s\n' "$expected" "$file" | shasum -a 256 -c - >/dev/null
    return
  fi
  fail "missing sha256sum or shasum"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

copy_asset() {
  asset="$1"
  output="$2"
  case "$asset" in
    http://*|https://*)
      if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$asset" -o "$output"
      elif command -v wget >/dev/null 2>&1; then
        wget -q "$asset" -O "$output"
      else
        fail "missing curl or wget for network asset"
      fi
      ;;
    file://*)
      /bin/cp "${asset#file://}" "$output"
      ;;
    *)
      /bin/cp "$asset" "$output"
      ;;
  esac
}

host_target() {
  os=$(uname -s 2>/dev/null || printf unknown)
  arch=$(uname -m 2>/dev/null || printf unknown)
  case "$os:$arch" in
    Darwin:arm64|Darwin:aarch64) printf '%s\n' "darwin-arm64" ;;
    Darwin:x86_64|Darwin:amd64) printf '%s\n' "darwin-amd64" ;;
    Linux:x86_64|Linux:amd64) printf '%s\n' "linux-amd64" ;;
    Linux:aarch64|Linux:arm64) printf '%s\n' "linux-arm64" ;;
    *) fail "unsupported host target: $os/$arch; pass --target explicitly" ;;
  esac
}

canonical_install_target() {
  case "$1" in
    ""|auto) host_target ;;
    darwin-arm64|macos-arm64|mac-arm64) printf '%s\n' "darwin-arm64" ;;
    darwin-amd64|darwin-x64|macos-amd64|macos-x64|mac-x64) printf '%s\n' "darwin-amd64" ;;
    linux-amd64|linux-x64|x86_64-unknown-linux-gnu) printf '%s\n' "linux-amd64" ;;
    linux-arm64|linux-aarch64|aarch64-unknown-linux-gnu) printf '%s\n' "linux-arm64" ;;
    *) fail "unsupported install target: $1" ;;
  esac
}

canonical_sdk_target() {
  case "$1" in
    ""|ohos-arm64|ohos-aarch64|aarch64-linux-ohos|aarch64-linux-ohos-cjnative|linux_ohos_aarch64_cjnative)
      printf '%s\n' "ohos-arm64"
      ;;
    ohos-amd64|ohos-x64|x86_64-linux-ohos|linux_ohos_x86_64_cjnative)
      printf '%s\n' "ohos-amd64"
      ;;
    *)
      fail "unsupported cangjie sdk target: $1"
      ;;
  esac
}

sdk_platform_for_target() {
  case "$1" in
    ohos-arm64) printf '%s\n' "ohos-aarch64" ;;
    ohos-amd64) printf '%s\n' "ohos-x64" ;;
    *) fail "unsupported cangjie sdk target: $1" ;;
  esac
}

manifest_object_value() {
  object_file="$1"
  key="$2"
  awk -v key="\"$key\"" '
    index($0, key) {
      value = $0
      sub(/^[^:]*:[ \t]*/, "", value)
      sub(/,[ \t]*$/, "", value)
      sub(/^[ \t]*"/, "", value)
      sub(/"[ \t]*$/, "", value)
      print value
      exit
    }
  ' "$object_file"
}

select_manifest_asset_object() {
  manifest="$1"
  target="$2"
  output="$3"
  awk -v target_value="$target" '
    BEGIN {
      target = "\"target\": \"" target_value "\""
    }
    /^[ \t]*\{/ {
      in_object = 1
      buf = $0 "\n"
      next
    }
    in_object {
      buf = buf $0 "\n"
      if ($0 ~ /^[ \t]*\}/) {
        if (index(buf, "\"kind\": \"flagship-binary\"") && index(buf, target) && index(buf, "\"downloadable\": true")) {
          printf "%s", buf
          found = 1
          exit
        }
        in_object = 0
        buf = ""
      }
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$manifest" > "$output"
}

manifest_local_base_dir() {
  manifest="$1"
  case "$manifest" in
    http://*|https://*) printf '%s\n' "" ;;
    file://*) dirname -- "${manifest#file://}" ;;
    /*) dirname -- "$manifest" ;;
    *) dirname -- "$manifest" ;;
  esac
}

resolve_manifest_asset_url() {
  manifest="$1"
  asset="$2"
  case "$asset" in
    http://*|https://*|file://*|/*) printf '%s\n' "$asset" ;;
    *)
      base=$(manifest_local_base_dir "$manifest")
      [ -n "$base" ] || fail "relative asset URL is not allowed for network manifest: $asset"
      printf '%s\n' "$base/$asset"
      ;;
  esac
}

write_receipt() {
  receipt="$1"
  ok="$2"
  asset="$3"
  install_dir="$4"
  installed_bin="$5"
  backup_path="$6"
  backup_created="$7"
  mkdir -p "$(dirname "$receipt")"
  asset_json=$(printf '%s' "$asset" | sed 's/\\/\\\\/g; s/"/\\"/g')
  install_dir_json=$(printf '%s' "$install_dir" | sed 's/\\/\\\\/g; s/"/\\"/g')
  installed_bin_json=$(printf '%s' "$installed_bin" | sed 's/\\/\\\\/g; s/"/\\"/g')
  backup_path_json=$(printf '%s' "$backup_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
  install_source_json=$(printf '%s' "${HAPUP_INSTALL_SOURCE:-direct-asset}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  manifest_path_json=$(printf '%s' "${HAPUP_MANIFEST_PATH:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  resolved_target_json=$(printf '%s' "${HAPUP_RESOLVED_TARGET:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  asset_id_json=$(printf '%s' "${HAPUP_ASSET_ID:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"schema":"happub-hapup-install-receipt-v0","ok":%s,"installSource":"%s","manifestPath":"%s","resolvedTarget":"%s","assetId":"%s","asset":"%s","installDir":"%s","installedBin":"%s","backupPath":"%s","backupCreated":%s,"installActionTaken":true,"atomicReplace":true,"canonMutation":false}\n' "$ok" "$install_source_json" "$manifest_path_json" "$resolved_target_json" "$asset_id_json" "$asset_json" "$install_dir_json" "$installed_bin_json" "$backup_path_json" "$backup_created" > "$receipt"
}

write_restore_receipt() {
  receipt="$1"
  ok="$2"
  install_dir="$3"
  restored_bin="$4"
  backup_path="$5"
  current_backup_path="$6"
  current_backup_created="$7"
  mkdir -p "$(dirname "$receipt")"
  install_dir_json=$(printf '%s' "$install_dir" | sed 's/\\/\\\\/g; s/"/\\"/g')
  restored_bin_json=$(printf '%s' "$restored_bin" | sed 's/\\/\\\\/g; s/"/\\"/g')
  backup_path_json=$(printf '%s' "$backup_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
  current_backup_path_json=$(printf '%s' "$current_backup_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"schema":"happub-hapup-restore-receipt-v0","ok":%s,"installDir":"%s","restoredBin":"%s","backupPath":"%s","currentBackupPath":"%s","currentBackupCreated":%s,"restoreActionTaken":true,"atomicReplace":true,"canonMutation":false}\n' "$ok" "$install_dir_json" "$restored_bin_json" "$backup_path_json" "$current_backup_path_json" "$current_backup_created" > "$receipt"
}

write_cangjie_sdk_receipt() {
  receipt="$1"
  archive="$2"
  target="$3"
  platform="$4"
  version="$5"
  install_root="$6"
  sdk_root="$7"
  cangjie_root="$8"
  envsetup_path="$9"
  checksum_verified="${10}"
  allow_unverified="${11}"
  repair_action_taken="${12}"
  envsetup_repaired="${13}"
  executable_repair_count="${14}"
  sign_count="${15}"
  sign_tool_status="${16}"
  ld_lld_materialized="${17}"
  backup_path="${18}"
  backup_created="${19}"
  mkdir -p "$(dirname "$receipt")"
  printf '{"schema":"happub-hapup-cangjie-sdk-install-receipt-v0","ok":true,"archive":"%s","target":"%s","downloadPlatform":"%s","version":"%s","installRoot":"%s","sdkRoot":"%s","cangjieRoot":"%s","envsetupPath":"%s","checksumVerified":%s,"allowUnverified":%s,"repairActionTaken":%s,"envsetupShebangRepaired":%s,"executablePermissionRepairCount":%s,"sharedObjectSignCount":%s,"signToolStatus":"%s","ldLldMaterialized":%s,"backupPath":"%s","backupCreated":%s,"installActionTaken":true,"rcMutationActionTaken":false,"manifestMutationActionTaken":false,"sourceCommand":"source %s","canonMutation":false}\n' \
    "$(json_escape "$archive")" \
    "$(json_escape "$target")" \
    "$(json_escape "$platform")" \
    "$(json_escape "$version")" \
    "$(json_escape "$install_root")" \
    "$(json_escape "$sdk_root")" \
    "$(json_escape "$cangjie_root")" \
    "$(json_escape "$envsetup_path")" \
    "$checksum_verified" \
    "$allow_unverified" \
    "$repair_action_taken" \
    "$envsetup_repaired" \
    "$executable_repair_count" \
    "$sign_count" \
    "$(json_escape "$sign_tool_status")" \
    "$ld_lld_materialized" \
    "$(json_escape "$backup_path")" \
    "$backup_created" \
    "$(json_escape "$envsetup_path")" > "$receipt"
}

unsafe_install_dir() {
  dir="${1%/}"
  case "$dir" in
    /|/bin|/sbin|/usr/bin|/usr/sbin|/usr/local/bin|/usr/local/sbin|/opt/homebrew/bin|/opt/homebrew/sbin|/opt/local/bin|/snap/bin|/System/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

install_from_manifest() {
  MANIFEST=""
  MANIFEST_SHA256=""
  TARGET="auto"
  INSTALL_DIR=""
  RECEIPT=""
  REVIEW_TOKEN="${HAP_REVIEW_TOKEN:-}"
  ALLOW_SYSTEM_DIR=false
  ALLOW_UNVERIFIED_MANIFEST=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --manifest)
        MANIFEST="${2:-}"
        shift 2
        ;;
      --manifest=*)
        MANIFEST="${1#--manifest=}"
        shift
        ;;
      --manifest-sha256)
        MANIFEST_SHA256="${2:-}"
        shift 2
        ;;
      --manifest-sha256=*)
        MANIFEST_SHA256="${1#--manifest-sha256=}"
        shift
        ;;
      --target)
        TARGET="${2:-}"
        shift 2
        ;;
      --target=*)
        TARGET="${1#--target=}"
        shift
        ;;
      --install-dir)
        INSTALL_DIR="${2:-}"
        shift 2
        ;;
      --install-dir=*)
        INSTALL_DIR="${1#--install-dir=}"
        shift
        ;;
      --receipt)
        RECEIPT="${2:-}"
        shift 2
        ;;
      --receipt=*)
        RECEIPT="${1#--receipt=}"
        shift
        ;;
      --review-token)
        REVIEW_TOKEN="${2:-}"
        shift 2
        ;;
      --review-token=*)
        REVIEW_TOKEN="${1#--review-token=}"
        shift
        ;;
      --allow-system-dir)
        ALLOW_SYSTEM_DIR=true
        shift
        ;;
      --allow-unverified-manifest)
        ALLOW_UNVERIFIED_MANIFEST=true
        shift
        ;;
      *)
        fail "unknown install-from-manifest option: $1"
        ;;
    esac
  done

  [ -n "$MANIFEST" ] || fail "missing --manifest"
  [ -n "$INSTALL_DIR" ] || fail "missing --install-dir"
  [ -n "$REVIEW_TOKEN" ] || fail "missing --review-token or HAP_REVIEW_TOKEN"
  need_cmd mkdir
  INSTALL_DIR=$(prepare_install_dir "$INSTALL_DIR")
  if unsafe_install_dir "$INSTALL_DIR" && [ "$ALLOW_SYSTEM_DIR" != true ]; then
    fail "unsafe install dir requires --allow-system-dir: $INSTALL_DIR"
  fi
  case "$MANIFEST" in
    http://*|https://*)
      if [ -z "$MANIFEST_SHA256" ] && [ "$ALLOW_UNVERIFIED_MANIFEST" != true ]; then
        fail "network manifest requires --manifest-sha256 or --allow-unverified-manifest"
      fi
      ;;
  esac

  RESOLVED_TARGET=$(canonical_install_target "$TARGET")
  WORK=$(secure_temp_dir manifest)
  MANIFEST_FILE="$WORK/manifest.json"
  ASSET_OBJECT="$WORK/asset.json"
  trap 'rm -rf "$WORK"' EXIT HUP INT TERM

  copy_asset "$MANIFEST" "$MANIFEST_FILE"
  if [ -n "$MANIFEST_SHA256" ]; then
    verify_checksum "$MANIFEST_FILE" "$MANIFEST_SHA256"
  fi
  select_manifest_asset_object "$MANIFEST_FILE" "$RESOLVED_TARGET" "$ASSET_OBJECT" || fail "no downloadable flagship asset for target: $RESOLVED_TARGET"

  ASSET_ID=$(manifest_object_value "$ASSET_OBJECT" "id")
  ASSET_URL=$(manifest_object_value "$ASSET_OBJECT" "url")
  ASSET_SHA256=$(manifest_object_value "$ASSET_OBJECT" "sha256")
  [ -n "$ASSET_ID" ] || fail "selected asset is missing id"
  [ -n "$ASSET_URL" ] || fail "selected asset is missing url"
  [ -n "$ASSET_SHA256" ] || fail "selected asset is missing sha256"
  ASSET_URL=$(resolve_manifest_asset_url "$MANIFEST" "$ASSET_URL")

  HAPUP_INSTALL_SOURCE="manifest"
  HAPUP_MANIFEST_PATH="$MANIFEST"
  HAPUP_RESOLVED_TARGET="$RESOLVED_TARGET"
  HAPUP_ASSET_ID="$ASSET_ID"
  export HAPUP_INSTALL_SOURCE HAPUP_MANIFEST_PATH HAPUP_RESOLVED_TARGET HAPUP_ASSET_ID

  set -- install-flagship \
    --asset "$ASSET_URL" \
    --sha256 "$ASSET_SHA256" \
    --install-dir "$INSTALL_DIR" \
    --review-token "$REVIEW_TOKEN"
  if [ -n "$RECEIPT" ]; then
    set -- "$@" --receipt "$RECEIPT"
  fi
  if [ "$ALLOW_SYSTEM_DIR" = true ]; then
    set -- "$@" --allow-system-dir
  fi
  rm -rf "$WORK"
  trap - 0 HUP INT TERM
  shift
  install_flagship "$@"
}

install_flagship() {
  ASSET=""
  SHA256=""
  INSTALL_DIR=""
  RECEIPT=""
  REVIEW_TOKEN="${HAP_REVIEW_TOKEN:-}"
  ALLOW_SYSTEM_DIR=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --asset)
        ASSET="${2:-}"
        shift 2
        ;;
      --asset=*)
        ASSET="${1#--asset=}"
        shift
        ;;
      --sha256)
        SHA256="${2:-}"
        shift 2
        ;;
      --sha256=*)
        SHA256="${1#--sha256=}"
        shift
        ;;
      --install-dir)
        INSTALL_DIR="${2:-}"
        shift 2
        ;;
      --install-dir=*)
        INSTALL_DIR="${1#--install-dir=}"
        shift
        ;;
      --receipt)
        RECEIPT="${2:-}"
        shift 2
        ;;
      --receipt=*)
        RECEIPT="${1#--receipt=}"
        shift
        ;;
      --review-token)
        REVIEW_TOKEN="${2:-}"
        shift 2
        ;;
      --review-token=*)
        REVIEW_TOKEN="${1#--review-token=}"
        shift
        ;;
      --allow-system-dir)
        ALLOW_SYSTEM_DIR=true
        shift
        ;;
      *)
        fail "unknown install-flagship option: $1"
        ;;
    esac
  done

  [ -n "$ASSET" ] || fail "missing --asset"
  [ -n "$SHA256" ] || fail "missing --sha256"
  [ -n "$INSTALL_DIR" ] || fail "missing --install-dir"
  [ -n "$REVIEW_TOKEN" ] || fail "missing --review-token or HAP_REVIEW_TOKEN"
  need_cmd mkdir
  need_cmd chmod
  INSTALL_DIR=$(prepare_install_dir "$INSTALL_DIR")
  if unsafe_install_dir "$INSTALL_DIR" && [ "$ALLOW_SYSTEM_DIR" != true ]; then
    fail "unsafe install dir requires --allow-system-dir: $INSTALL_DIR"
  fi

  WORK=$(secure_temp_dir install)
  ASSET_FILE="$WORK/asset"
  EXTRACT_DIR="$WORK/extract"
  mkdir -p "$EXTRACT_DIR"
  trap 'rm -rf "$WORK"' EXIT HUP INT TERM

  copy_asset "$ASSET" "$ASSET_FILE"
  verify_checksum "$ASSET_FILE" "$SHA256"

  if tar -tzf "$ASSET_FILE" >/dev/null 2>&1; then
    validate_tar_archive "$ASSET_FILE" "$WORK" false
    tar -xzf "$ASSET_FILE" -C "$EXTRACT_DIR"
    find "$EXTRACT_DIR" -type f -name hap > "$WORK/hap-files.txt"
    HAP_FILE_COUNT=$(wc -l < "$WORK/hap-files.txt" | tr -d ' ')
    [ "$HAP_FILE_COUNT" = "1" ] || fail "tarball must contain exactly one regular hap binary"
    SOURCE_BIN=$(sed -n '1p' "$WORK/hap-files.txt")
  else
    SOURCE_BIN="$ASSET_FILE"
  fi

  INSTALLED_BIN="$INSTALL_DIR/hap"
  TMP_BIN="$INSTALL_DIR/.hap.tmp.$$"
  BACKUP_BIN="$INSTALL_DIR/hap.prev"
  BACKUP_CREATED=false
  /bin/cp "$SOURCE_BIN" "$TMP_BIN"
  chmod +x "$TMP_BIN"
  "$TMP_BIN" version >/dev/null 2>&1 || fail "asset did not pass hap version smoke"
  if [ -e "$INSTALLED_BIN" ]; then
    /bin/cp "$INSTALLED_BIN" "$BACKUP_BIN"
    BACKUP_CREATED=true
  fi
  /bin/mv "$TMP_BIN" "$INSTALLED_BIN"
  if [ -n "$RECEIPT" ]; then
    write_receipt "$RECEIPT" true "$ASSET" "$INSTALL_DIR" "$INSTALLED_BIN" "$BACKUP_BIN" "$BACKUP_CREATED"
  fi
  printf 'hap installed: %s\n' "$INSTALLED_BIN"
}

find_cangjie_root() {
  root="$1"
  find "$root" -type f -name envsetup.sh | while IFS= read -r envsetup; do
    dir=$(dirname -- "$envsetup")
    case "$dir" in
      */cangjie|*/cangjie/)
        printf '%s\n' "$dir"
        exit 0
        ;;
    esac
  done | sed -n '1p'
}

repair_envsetup_shebang() {
  envsetup="$1"
  [ -f "$envsetup" ] || return 1
  first_line=$(sed -n '1p' "$envsetup")
  if [ "$first_line" = "#!/bin/bash" ]; then
    tmp="$envsetup.hap-tmp"
    {
      printf '%s\n' "#!/bin/sh"
      sed -n '2,$p' "$envsetup"
    } > "$tmp"
    /bin/mv "$tmp" "$envsetup"
    return 0
  fi
  return 1
}

repair_sdk_executable_bits() {
  cangjie_root="$1"
  list="$2"
  : > "$list"
  for dir in "$cangjie_root/tools/bin" "$cangjie_root/compiler/bin" "$cangjie_root/third_party/llvm/bin"; do
    if [ -d "$dir" ]; then
      find "$dir" -type f >> "$list"
    fi
  done
  count=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    chmod u+x "$file"
    count=$((count + 1))
  done < "$list"
  printf '%s\n' "$count"
}

repair_ld_lld_symlink() {
  cangjie_root="$1"
  lld_dir="$cangjie_root/third_party/llvm/bin"
  ld_lld="$lld_dir/ld.lld"
  lld="$lld_dir/lld"
  if [ -L "$ld_lld" ] && [ -f "$lld" ]; then
    /bin/cp "$lld" "$ld_lld.hap-tmp"
    chmod u+x "$ld_lld.hap-tmp"
    /bin/mv "$ld_lld.hap-tmp" "$ld_lld"
    return 0
  fi
  return 1
}

sign_sdk_shared_objects() {
  cangjie_root="$1"
  sign_tool="$2"
  list="$3"
  if [ -z "$sign_tool" ]; then
    if command -v binary-sign-tool >/dev/null 2>&1; then
      sign_tool=$(command -v binary-sign-tool)
    else
      printf '%s\n' "missing:0"
      return 0
    fi
  fi
  [ -x "$sign_tool" ] || fail "binary-sign-tool is not executable: $sign_tool"
  if ! command -v file >/dev/null 2>&1; then
    printf '%s\n' "missing-file-command:0"
    return 0
  fi
  : > "$list"
  find "$cangjie_root" -type f | while IFS= read -r file; do
    if file "$file" | grep "shared object" >/dev/null 2>&1; then
      printf '%s\n' "$file"
    fi
  done > "$list"
  count=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    chmod u+x "$file"
    "$sign_tool" sign -inFile "$file" -outFile "$file" -selfSign 1 >/dev/null
    count=$((count + 1))
  done < "$list"
  printf '%s:%s\n' "signed" "$count"
}

install_cangjie_sdk() {
  ARCHIVE=""
  TARGET="ohos-arm64"
  VERSION=""
  SHA256=""
  INSTALL_ROOT=""
  RECEIPT=""
  REVIEW_TOKEN="${HAP_REVIEW_TOKEN:-}"
  ALLOW_UNVERIFIED=false
  REPLACE=false
  SIGN_OHOS_BINARIES=true
  BINARY_SIGN_TOOL=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --archive)
        ARCHIVE="${2:-}"
        shift 2
        ;;
      --archive=*)
        ARCHIVE="${1#--archive=}"
        shift
        ;;
      --target)
        TARGET="${2:-}"
        shift 2
        ;;
      --target=*)
        TARGET="${1#--target=}"
        shift
        ;;
      --version)
        VERSION="${2:-}"
        shift 2
        ;;
      --version=*)
        VERSION="${1#--version=}"
        shift
        ;;
      --sha256)
        SHA256="${2:-}"
        shift 2
        ;;
      --sha256=*)
        SHA256="${1#--sha256=}"
        shift
        ;;
      --install-root)
        INSTALL_ROOT="${2:-}"
        shift 2
        ;;
      --install-root=*)
        INSTALL_ROOT="${1#--install-root=}"
        shift
        ;;
      --receipt)
        RECEIPT="${2:-}"
        shift 2
        ;;
      --receipt=*)
        RECEIPT="${1#--receipt=}"
        shift
        ;;
      --review-token)
        REVIEW_TOKEN="${2:-}"
        shift 2
        ;;
      --review-token=*)
        REVIEW_TOKEN="${1#--review-token=}"
        shift
        ;;
      --binary-sign-tool)
        BINARY_SIGN_TOOL="${2:-}"
        shift 2
        ;;
      --binary-sign-tool=*)
        BINARY_SIGN_TOOL="${1#--binary-sign-tool=}"
        shift
        ;;
      --allow-unverified)
        ALLOW_UNVERIFIED=true
        shift
        ;;
      --replace)
        REPLACE=true
        shift
        ;;
      --no-sign-ohos-binaries)
        SIGN_OHOS_BINARIES=false
        shift
        ;;
      *)
        fail "unknown install-cangjie-sdk option: $1"
        ;;
    esac
  done

  [ -n "$ARCHIVE" ] || fail "missing --archive"
  [ -n "$INSTALL_ROOT" ] || fail "missing --install-root"
  [ -n "$REVIEW_TOKEN" ] || fail "missing --review-token or HAP_REVIEW_TOKEN"
  if [ -z "$SHA256" ] && [ "$ALLOW_UNVERIFIED" != true ]; then
    fail "missing --sha256 or --allow-unverified"
  fi

  RESOLVED_TARGET=$(canonical_sdk_target "$TARGET")
  PLATFORM=$(sdk_platform_for_target "$RESOLVED_TARGET")
  ARCHIVE_NAME=$(basename -- "${ARCHIVE#file://}")
  if [ -z "$VERSION" ]; then
    VERSION="$ARCHIVE_NAME"
    VERSION="${VERSION#cangjie-sdk-$PLATFORM-}"
    VERSION="${VERSION%.tar.gz}"
    VERSION="${VERSION%.tgz}"
  fi
  FINAL_NAME="cangjie-sdk-$PLATFORM-$VERSION"
  SDK_ROOT="$INSTALL_ROOT/$FINAL_NAME"
  BACKUP_PATH="$SDK_ROOT.prev.$(date +%Y%m%d%H%M%S)"
  BACKUP_CREATED=false

  need_cmd mkdir
  need_cmd tar
  need_cmd chmod

  WORK=$(secure_temp_dir cangjie-sdk)
  ARCHIVE_FILE="$WORK/sdk.tar.gz"
  EXTRACT_DIR="$WORK/extract"
  mkdir -p "$EXTRACT_DIR" "$INSTALL_ROOT"
  trap 'rm -rf "$WORK"' EXIT HUP INT TERM

  copy_asset "$ARCHIVE" "$ARCHIVE_FILE"
  CHECKSUM_VERIFIED=false
  if [ -n "$SHA256" ]; then
    verify_checksum "$ARCHIVE_FILE" "$SHA256"
    CHECKSUM_VERIFIED=true
  fi
  validate_tar_archive "$ARCHIVE_FILE" "$WORK" true
  tar -xzf "$ARCHIVE_FILE" -C "$EXTRACT_DIR"
  CANGJIE_ROOT=$(find_cangjie_root "$EXTRACT_DIR")
  [ -n "$CANGJIE_ROOT" ] || fail "SDK archive did not contain cangjie/envsetup.sh"
  SDK_PARENT=$(dirname -- "$CANGJIE_ROOT")

  if [ -e "$SDK_ROOT" ]; then
    if [ "$REPLACE" != true ]; then
      fail "SDK target already exists; pass --replace after review: $SDK_ROOT"
    fi
    /bin/mv "$SDK_ROOT" "$BACKUP_PATH"
    BACKUP_CREATED=true
  fi
  mkdir -p "$SDK_ROOT"
  /bin/cp -R "$SDK_PARENT"/. "$SDK_ROOT"/

  INSTALLED_CANGJIE_ROOT="$SDK_ROOT/cangjie"
  ENVSETUP_PATH="$INSTALLED_CANGJIE_ROOT/envsetup.sh"
  chmod u+x "$ENVSETUP_PATH" 2>/dev/null || true
  ENVSETUP_REPAIRED=false
  if repair_envsetup_shebang "$ENVSETUP_PATH"; then
    ENVSETUP_REPAIRED=true
  fi
  EXECUTABLE_REPAIR_COUNT=$(repair_sdk_executable_bits "$INSTALLED_CANGJIE_ROOT" "$WORK/chmod-files")
  LD_LLD_MATERIALIZED=false
  if repair_ld_lld_symlink "$INSTALLED_CANGJIE_ROOT"; then
    LD_LLD_MATERIALIZED=true
  fi
  SIGN_TOOL_STATUS="skipped-by-flag"
  SIGN_COUNT=0
  if [ "$SIGN_OHOS_BINARIES" = true ]; then
    sign_result=$(sign_sdk_shared_objects "$INSTALLED_CANGJIE_ROOT" "$BINARY_SIGN_TOOL" "$WORK/shared-objects")
    SIGN_TOOL_STATUS="${sign_result%:*}"
    SIGN_COUNT="${sign_result##*:}"
  fi

  if [ -n "$RECEIPT" ]; then
    write_cangjie_sdk_receipt "$RECEIPT" "$ARCHIVE" "$RESOLVED_TARGET" "$PLATFORM" "$VERSION" "$INSTALL_ROOT" "$SDK_ROOT" "$INSTALLED_CANGJIE_ROOT" "$ENVSETUP_PATH" "$CHECKSUM_VERIFIED" "$ALLOW_UNVERIFIED" true "$ENVSETUP_REPAIRED" "$EXECUTABLE_REPAIR_COUNT" "$SIGN_COUNT" "$SIGN_TOOL_STATUS" "$LD_LLD_MATERIALIZED" "$BACKUP_PATH" "$BACKUP_CREATED"
  fi
  printf 'cangjie sdk installed: %s\n' "$SDK_ROOT"
  printf 'source %s\n' "$ENVSETUP_PATH"
}

restore_flagship() {
  INSTALL_DIR=""
  BACKUP_PATH=""
  RECEIPT=""
  REVIEW_TOKEN="${HAP_REVIEW_TOKEN:-}"
  ALLOW_SYSTEM_DIR=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        INSTALL_DIR="${2:-}"
        shift 2
        ;;
      --install-dir=*)
        INSTALL_DIR="${1#--install-dir=}"
        shift
        ;;
      --backup)
        BACKUP_PATH="${2:-}"
        shift 2
        ;;
      --backup=*)
        BACKUP_PATH="${1#--backup=}"
        shift
        ;;
      --receipt)
        RECEIPT="${2:-}"
        shift 2
        ;;
      --receipt=*)
        RECEIPT="${1#--receipt=}"
        shift
        ;;
      --review-token)
        REVIEW_TOKEN="${2:-}"
        shift 2
        ;;
      --review-token=*)
        REVIEW_TOKEN="${1#--review-token=}"
        shift
        ;;
      --allow-system-dir)
        ALLOW_SYSTEM_DIR=true
        shift
        ;;
      *)
        fail "unknown restore-flagship option: $1"
        ;;
    esac
  done

  [ -n "$INSTALL_DIR" ] || fail "missing --install-dir"
  [ -n "$REVIEW_TOKEN" ] || fail "missing --review-token or HAP_REVIEW_TOKEN"
  INSTALL_DIR=$(canonical_existing_dir "$INSTALL_DIR")
  if unsafe_install_dir "$INSTALL_DIR" && [ "$ALLOW_SYSTEM_DIR" != true ]; then
    fail "unsafe install dir requires --allow-system-dir: $INSTALL_DIR"
  fi

  need_cmd chmod
  [ -n "$BACKUP_PATH" ] || BACKUP_PATH="$INSTALL_DIR/hap.prev"
  [ -f "$BACKUP_PATH" ] || fail "backup not found: $BACKUP_PATH"
  chmod +x "$BACKUP_PATH"
  "$BACKUP_PATH" version >/dev/null 2>&1 || fail "backup did not pass hap version smoke"

  INSTALLED_BIN="$INSTALL_DIR/hap"
  TMP_BIN="$INSTALL_DIR/.hap.restore.$$"
  CURRENT_BACKUP="$INSTALL_DIR/hap.restore-prev"
  CURRENT_BACKUP_CREATED=false
  /bin/cp "$BACKUP_PATH" "$TMP_BIN"
  chmod +x "$TMP_BIN"
  if [ -e "$INSTALLED_BIN" ]; then
    /bin/cp "$INSTALLED_BIN" "$CURRENT_BACKUP"
    CURRENT_BACKUP_CREATED=true
  fi
  /bin/mv "$TMP_BIN" "$INSTALLED_BIN"
  if [ -n "$RECEIPT" ]; then
    write_restore_receipt "$RECEIPT" true "$INSTALL_DIR" "$INSTALLED_BIN" "$BACKUP_PATH" "$CURRENT_BACKUP" "$CURRENT_BACKUP_CREATED"
  fi
  printf 'hap restored: %s\n' "$INSTALLED_BIN"
}

case "${1:-help}" in
  version|--version|-V)
    printf 'hapup %s\n' "$VERSION"
    ;;
  help|--help|-h)
    usage
    ;;
  install|install-flagship)
    shift
    install_flagship "$@"
    ;;
  install-from-manifest)
    shift
    install_from_manifest "$@"
    ;;
  install-cangjie-sdk)
    shift
    install_cangjie_sdk "$@"
    ;;
  restore|restore-flagship)
    shift
    restore_flagship "$@"
    ;;
  *)
    usage
    exit 2
    ;;
esac
