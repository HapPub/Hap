#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)
HAPUP="$ROOT/release/hapup.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/hapup-security.XXXXXXXX")
trap 'rm -rf "$WORK"' 0 HUP INT TERM

fail_test() {
  printf 'hapup security test failed: %s\n' "$*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

mkdir -p "$WORK/valid/bin" "$WORK/install"
cat > "$WORK/valid/bin/hap" <<'EOF'
#!/bin/sh
case "${1:-}" in
  version) printf '%s\n' 'HapCLI test fixture' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$WORK/valid/bin/hap"
tar -czf "$WORK/valid.tar.gz" -C "$WORK/valid" bin/hap
VALID_SHA=$(sha256_file "$WORK/valid.tar.gz")

sh "$HAPUP" install-flagship \
  --asset "$WORK/valid.tar.gz" \
  --sha256 "$VALID_SHA" \
  --install-dir "$WORK/install" \
  --review-token reviewed >/dev/null
"$WORK/install/hap" version >/dev/null || fail_test "valid archive was not installed"

python3 - "$WORK/traversal.tar.gz" <<'PY'
import io
import tarfile
import sys

with tarfile.open(sys.argv[1], "w:gz") as archive:
    info = tarfile.TarInfo("../escape")
    payload = b"escape"
    info.size = len(payload)
    archive.addfile(info, io.BytesIO(payload))
PY
TRAVERSAL_SHA=$(sha256_file "$WORK/traversal.tar.gz")
if sh "$HAPUP" install-flagship \
  --asset "$WORK/traversal.tar.gz" \
  --sha256 "$TRAVERSAL_SHA" \
  --install-dir "$WORK/install" \
  --review-token reviewed >"$WORK/traversal.log" 2>&1; then
  fail_test "traversal archive was accepted"
fi
grep -q "unsafe member path" "$WORK/traversal.log" || fail_test "traversal rejection was not explicit"
[ ! -e "$WORK/escape" ] || fail_test "traversal archive escaped the extraction root"

mkdir -p "$WORK/duplicate/one" "$WORK/duplicate/two"
cp "$WORK/valid/bin/hap" "$WORK/duplicate/one/hap"
cp "$WORK/valid/bin/hap" "$WORK/duplicate/two/hap"
tar -czf "$WORK/duplicate.tar.gz" -C "$WORK/duplicate" one/hap two/hap
DUPLICATE_SHA=$(sha256_file "$WORK/duplicate.tar.gz")
if sh "$HAPUP" install-flagship \
  --asset "$WORK/duplicate.tar.gz" \
  --sha256 "$DUPLICATE_SHA" \
  --install-dir "$WORK/install" \
  --review-token reviewed >"$WORK/duplicate.log" 2>&1; then
  fail_test "ambiguous archive was accepted"
fi
grep -q "exactly one regular hap binary" "$WORK/duplicate.log" || fail_test "ambiguous archive rejection was not explicit"

mkdir -p "$WORK/symlink/bin"
ln -s /bin/sh "$WORK/symlink/bin/hap"
tar -czf "$WORK/symlink.tar.gz" -C "$WORK/symlink" bin/hap
SYMLINK_SHA=$(sha256_file "$WORK/symlink.tar.gz")
if sh "$HAPUP" install-flagship \
  --asset "$WORK/symlink.tar.gz" \
  --sha256 "$SYMLINK_SHA" \
  --install-dir "$WORK/install" \
  --review-token reviewed >"$WORK/symlink.log" 2>&1; then
  fail_test "symbolic-link flagship archive was accepted"
fi
grep -q "unsafe member type or link target" "$WORK/symlink.log" || fail_test "symbolic-link rejection was not explicit"

if sh "$HAPUP" install-flagship \
  --asset "$WORK/not-present" \
  --sha256 0000000000000000000000000000000000000000000000000000000000000000 \
  --install-dir /usr/local/bin/. \
  --review-token reviewed >"$WORK/system-dir.log" 2>&1; then
  fail_test "canonical system directory bypass was accepted"
fi
grep -q "unsafe install dir requires --allow-system-dir: /usr/local/bin" "$WORK/system-dir.log" || fail_test "system directory was not canonicalized before the gate"

printf '%s\n' "hapup security tests passed"
