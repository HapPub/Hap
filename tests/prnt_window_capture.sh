#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hapcli-prnt-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

FAKE_BIN="$TMP_ROOT/bin"
OUT_DIR="$TMP_ROOT/out"
LOG_PATH="$TMP_ROOT/commands.log"
mkdir -p "$FAKE_BIN" "$OUT_DIR"

cat > "$FAKE_BIN/hdc" <<'SH'
#!/bin/sh
set -eu
printf 'hdc %s\n' "$*" >> "$HAP_PRNT_FAKE_LOG"

parent_command="$(ps -p "$PPID" -o comm= 2>/dev/null || true)"
case "$parent_command" in
  sh|*/sh)
    printf 'fake hdc refuses background timeout-shell parent: %s\n' "$parent_command" >&2
    exit 88
    ;;
esac

if [ "${1:-}" = "list" ] && [ "${2:-}" = "targets" ]; then
  printf 'FAKE001\n'
  exit 0
fi
if [ "${1:-}" = "-t" ]; then
  shift 2
fi
if [ "${1:-}" = "shell" ] && [ "${2:-}" = "aa" ] && [ "${3:-}" = "force-stop" ]; then
  printf 'force stop process successfully.\n'
  exit 0
fi
if [ "${1:-}" = "shell" ] && [ "${2:-}" = "aa" ] && [ "${3:-}" = "start" ]; then
  printf 'start ability successfully.\n'
  exit 0
fi
if [ "${1:-}" = "shell" ] && [ "${2:-}" = "pidof" ]; then
  printf '18359\n'
  exit 0
fi
if [ "${1:-}" = "shell" ] && [ "${2:-}" = "hidumper" ]; then
  cat <<'WMS'
WindowName DisplayId Pid WinId Type Mode Flag ZOrd Orientation [ x y w h ]
corePlayer0 0 18359 724 1 1 1 3 0 [ 11 22 640 360 ]
Focus window: 724
WMS
  exit 0
fi
if [ "${1:-}" = "shell" ] && [ "${2:-}" = "snapshot_display" ]; then
  printf 'success\n'
  exit 0
fi
if [ "${1:-}" = "file" ] && [ "${2:-}" = "recv" ]; then
  printf 'fake-display-bytes\n' > "$4"
  exit 0
fi
if [ "${1:-}" = "shell" ] && [ "${2:-}" = "rm" ]; then
  exit 0
fi
printf 'unexpected fake hdc command: %s\n' "$*" >&2
exit 9
SH

cat > "$FAKE_BIN/magick" <<'SH'
#!/bin/sh
set -eu
printf 'magick %s\n' "$*" >> "$HAP_PRNT_FAKE_LOG"
input="$1"
output=""
for arg in "$@"; do
  output="$arg"
done
cp "$input" "$output"
SH

chmod +x "$FAKE_BIN/hdc" "$FAKE_BIN/magick"

BIN="$ROOT/target/release/bin/main"
if [ ! -x "$BIN" ]; then
  (cd "$ROOT" && cjpm build)
fi

HAP_PRNT_FAKE_LOG="$LOG_PATH" \
PATH="$FAKE_BIN:$PATH" \
  "$BIN" prnt \
    --hdc "$FAKE_BIN/hdc" \
    --device FAKE001 \
    --bundle cc.c2l.corePlayer \
    --ability ProductAbility \
    --module product \
    --layoutType Tablet/16:9 \
    --left 40 --top 50 \
    --wait-ms 0 \
    --output-dir "$OUT_DIR" > "$TMP_ROOT/result.json"

grep -q '"status": "window-capture-complete"' "$TMP_ROOT/result.json"
grep -q '"requestedRect": {"left": 40, "top": 50, "width": 1600, "height": 900}' "$TMP_ROOT/result.json"
grep -q '"actualWindow": {"name": "corePlayer0", "pid": "18359", "windowId": 724, "displayId": 0, "left": 11, "top": 22, "width": 640, "height": 360}' "$TMP_ROOT/result.json"
grep -q '"wmsVerified": true' "$TMP_ROOT/result.json"
grep -q '"displayCaptureTaken": true' "$TMP_ROOT/result.json"
grep -q '"cropActionTaken": true' "$TMP_ROOT/result.json"
grep -q '"cropper": "magick"' "$TMP_ROOT/result.json"
grep -q '"remoteCleanupSucceeded": true' "$TMP_ROOT/result.json"
grep -q '"hdcExecutionMode": "foreground-fixed-argv"' "$TMP_ROOT/result.json"
grep -q '"hdcTimeoutSecondsRequested": 15' "$TMP_ROOT/result.json"
grep -q '"hdcTimeoutEnforced": false' "$TMP_ROOT/result.json"
grep -q '"appRestartRequested": true' "$TMP_ROOT/result.json"
grep -q '"appForceStopTaken": true' "$TMP_ROOT/result.json"
grep -q -- 'shell aa force-stop cc.c2l.corePlayer' "$LOG_PATH"
grep -q -- 'shell aa start -a ProductAbility -b cc.c2l.corePlayer -m product --wl 40 --wt 50 --ww 1600 --wh 900' "$LOG_PATH"
grep -q -- 'shell snapshot_display -i 0 -f /data/local/tmp/hapcli-prnt-18359.jpeg' "$LOG_PATH"
grep -q -- 'magick .* -crop 640x360+11+22 +repage ' "$LOG_PATH"

stop_line="$(grep -n 'shell aa force-stop' "$LOG_PATH" | cut -d: -f1)"
launch_line="$(grep -n 'shell aa start' "$LOG_PATH" | cut -d: -f1)"
wms_line="$(grep -n 'WindowManagerService' "$LOG_PATH" | cut -d: -f1)"
snapshot_line="$(grep -n 'snapshot_display' "$LOG_PATH" | cut -d: -f1)"
crop_line="$(grep -n '^magick ' "$LOG_PATH" | cut -d: -f1)"
test "$stop_line" -lt "$launch_line"
test "$launch_line" -lt "$wms_line"
test "$wms_line" -lt "$snapshot_line"
test "$snapshot_line" -lt "$crop_line"
test -s "$OUT_DIR/display.jpeg"
test -s "$OUT_DIR/window.png"
test -s "$OUT_DIR/receipt.json"

python3 - "$TMP_ROOT/result.json" "$OUT_DIR/receipt.json" <<'PY'
import json
import pathlib
import sys

stdout_receipt = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
file_receipt = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
assert stdout_receipt == file_receipt
assert stdout_receipt["actualMatchesRequested"] is False
assert stdout_receipt["windowOwnership"] == "bundle-pid-wms-bound"
assert stdout_receipt["installedArtifactIdentityVerified"] is False
assert stdout_receipt["visualAcceptance"] is False
assert stdout_receipt["ownerAcceptance"] is False
assert len(stdout_receipt["screenshotSha256"]) == 64
PY

printf 'prnt window capture smoke passed\n'
