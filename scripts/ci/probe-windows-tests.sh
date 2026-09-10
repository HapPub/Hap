#!/usr/bin/env bash
# Compare compiler/runtime behavior before diagnosing the project test runner.
set -euo pipefail
set +u
source "$1"
set -u
probe_root=$(mktemp -d)
trap 'rm -rf "$probe_root"' EXIT
cat > "$probe_root/smoke.cj" <<'CJ'
package windows_smoke
import std.unittest.*
import std.unittest.testmacro.*
@Test
public class WindowsSmoke {
    @TestCase
    public func runsArithmetic(): Unit {
        @Assert(Int64(2) + Int64(2), Int64(4))
    }
}
main(): Unit { println("runtime-smoke") }
CJ
for linkage in static dynamic; do
  flags=(--dy-std)
  if [[ "$linkage" == static ]]; then flags=(--static --static-std); fi
  cjc --test "${flags[@]}" "$probe_root/smoke.cj" -o "$probe_root/smoke-$linkage.exe"
  for timeout in none 30s; do
    args=(--no-color)
    if [[ "$timeout" != none ]]; then args+=(--timeout-each="$timeout"); fi
    if "$probe_root/smoke-$linkage.exe" "${args[@]}" > "$probe_root/output" 2>&1; then status=0; else status=$?; fi
    detail=$(tail -n 12 "$probe_root/output" | tr '\r\n' '  ' | cut -c1-2500)
    printf '::notice title=Windows test probe::linkage=%s; timeout=%s; exit=%s; output=%s\n' "$linkage" "$timeout" "$status" "$detail"
  done
done
