#!/usr/bin/env bash
# validate-harness.sh [--keep]
# End-to-end validation of the harness with a deterministic stand-in worker.
# No model is called and nothing outside a temp directory is touched.
#
# It proves, in order:
#   1. gate reports UNVERIFIED (exit 2) before the task is implemented
#   2. a worker run creates a scoped commit on agent/spatial
#   3. the same gate reports PASS (exit 0) after implementation
#   4. the integration gate PASSes with a measured convergence order
#   5. a wrong scheme is caught by verification (PASS -> FAIL)
#   6. an out-of-scope edit is caught by scope_check
set -uo pipefail
HOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

TMP="$(mktemp -d)"
REPO="$TMP/repo"
pass=0; fail=0
ok()   { printf '  ok    %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }
say()  { printf '\n== %s\n' "$1"; }

cleanup() { [ $KEEP -eq 1 ] && echo "kept: $TMP" || rm -rf "$TMP"; }
trap cleanup EXIT

cp -R "$HOME_DIR/examples/validation/target" "$REPO"
( cd "$REPO" && git init -q -b main && git add -A && git commit -q -m "validation target" ) >/dev/null

export WT_ROOT="$TMP/wt"
LAB="$HOME_DIR/bin/agentlab"

say "baseline: contracts, core and verification exist"
( cd "$REPO" && "$LAB" preflight spatial >/tmp/val-preflight.log 2>&1 )
[ $? -eq 0 ] && ok "preflight PASS" || { bad "preflight"; cat /tmp/val-preflight.log; }

say "1. gate before implementation reports UNVERIFIED"
( cd "$REPO" && "$LAB" gate spatial >/tmp/val-gate-before.log 2>&1 )
rc=$?
[ $rc -eq 2 ] && ok "exit 2 (UNVERIFIED)" || { bad "expected 2, got $rc"; tail -12 /tmp/val-gate-before.log; }
grep -q "GATE UNVERIFIED" /tmp/val-gate-before.log && ok "gate label is UNVERIFIED" || bad "missing UNVERIFIED label"
grep -q "S1 not implemented" /tmp/val-gate-before.log && ok "verification reports the real reason" || bad "missing real reason"

say "2. worker run produces a scoped commit"
cat > "$TMP/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
cat > modules/spatial/upwind.cpp <<'CPP'
#include "modules/spatial/upwind.hpp"

#include <cmath>

namespace cfd {
UpwindSpatial::UpwindSpatial(const Mesh& mesh, double speed) : mesh_(mesh), speed_(speed) {}

void UpwindSpatial::residual(const Field& U, double, Field& R) const {
  const int n = mesh_.nx();
  const std::size_t g = mesh_.ghostWidth();
  const double h = mesh_.dx();
  for (int i = 0; i < n; ++i) {
    const double self = U.data()[static_cast<std::size_t>(i) + g];
    const double left = U.data()[static_cast<std::size_t>(i) - 1 + g];
    R.data()[static_cast<std::size_t>(i) + g] = -speed_ * (self - left) / h;
  }
}

double UpwindSpatial::max_stable_dt(const Field&, double) const {
  return mesh_.dx() / std::fabs(speed_);
}
}  // namespace cfd
CPP

cat > tests/unit/spatial/upwind_test.cpp <<'CPP'
#include "core/field.hpp"
#include "core/mesh.hpp"
#include "modules/spatial/upwind.hpp"

#include <cmath>
#include <iostream>

int main() {
  const int n = 4;
  const double h = 0.25;
  cfd::Mesh mesh(n, h, true);
  const std::size_t g = mesh.ghostWidth();
  cfd::Field u(n + 2 * g), r(u.size());
  for (int i = -1; i <= n; ++i) u.data()[static_cast<std::size_t>(i) + g] = 1.0;
  cfd::UpwindSpatial op(mesh, 2.0);
  op.residual(u, 0.0, r);
  bool ok = true;
  for (int i = 0; i < n; ++i) ok = ok && std::abs(r.data()[static_cast<std::size_t>(i) + g]) < 1e-14;
  ok = ok && std::abs(op.max_stable_dt(u, 0.0) - h / 2.0) < 1e-14;
  u.data()[g] = 3.0;
  op.residual(u, 0.0, r);
  ok = ok && std::abs(r.data()[g] + 2.0 * (3.0 - 1.0) / h) < 1e-12;
  if (!ok) { std::cerr << "upwind_test: FAIL\n"; return 1; }
  std::cout << "upwind_test: ok\n";
  return 0;
}
CPP

python3 - <<'PY'
from pathlib import Path
p = Path('CMakeLists.txt')
s = p.read_text()
if 'upwind_test' not in s:
    p.write_text(s + '''
add_executable(upwind_test tests/unit/spatial/upwind_test.cpp)
target_link_libraries(upwind_test PRIVATE cfd_spatial)
add_test(NAME upwind_test COMMAND upwind_test)
set_tests_properties(upwind_test PROPERTIES LABELS unit)
''')
PY

printf '# Report: spatial\n\nstatus: ready\ncommit: %s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo pending)" > .agentlab/reports/spatial.md
git add -A
git commit -q -m "spatial: implement first-order upwind residual (S1)"
WORKER
chmod +x "$TMP/worker.sh"

( cd "$REPO" && PI_BIN="$TMP/worker.sh" "$LAB" run spatial >/tmp/val-run.log 2>&1 )
rc=$?
[ $rc -eq 0 ] && ok "worker exit 0" || { bad "worker exit $rc"; tail -12 /tmp/val-run.log; }
grep -q "scope: spatial OK" /tmp/val-run.log && ok "scope check passed" || bad "scope check did not run"
( cd "$REPO" && git rev-list --count main..agent/spatial | grep -qx '1' ) && ok "exactly one commit on agent/spatial" || bad "unexpected commit count"

say "3. gate after implementation reports PASS"
WT="$WT_ROOT/spatial"
[ -d "$WT" ] || { bad "worker worktree missing at $WT"; exit 1; }
( cd "$REPO" && "$LAB" gate spatial --worktree >/tmp/val-gate-after.log 2>&1 )
rc=$?
[ $rc -eq 0 ] && ok "exit 0 (PASS)" || { bad "expected 0, got $rc"; tail -12 /tmp/val-gate-after.log; }
grep -q "observed_order=0.9" /tmp/val-gate-after.log && ok "verification measured order ~1" || bad "no measured order in gate output"
( cd "$WT" && git add -A && git commit -q -m "spatial: record gate repro" ) >/dev/null 2>&1 || true

say "4. integration gate PASSes with real numbers"
( cd "$REPO" && "$LAB" integrate spatial >/tmp/val-integrate.log 2>&1 )
rc=$?
[ $rc -eq 0 ] && ok "integration gate PASS" || { bad "integration exit $rc"; tail -14 /tmp/val-integrate.log; }
grep -q "GATE PASS (mode: integration)" /tmp/val-integrate.log && ok "integration label PASS" || bad "missing integration PASS label"
( cd "$REPO" && git checkout -q main )

say "5. a wrong scheme is caught (central difference has order 2)"
( cd "$WT" && python3 - <<'PY'
from pathlib import Path
p = Path('modules/spatial/upwind.cpp')
s = p.read_text()
s = s.replace(
    'const double left = U.data()[static_cast<std::size_t>(i) - 1 + g];',
    'const double left = U.data()[static_cast<std::size_t>(i) - 1 + g];\n    const double right = U.data()[static_cast<std::size_t>(i) + 1 + g];')
s = s.replace(
    'R.data()[static_cast<std::size_t>(i) + g] = -speed_ * (self - left) / h;',
    'R.data()[static_cast<std::size_t>(i) + g] = -speed_ * (right - left) / (2.0 * h);')
p.write_text(s)
PY
git add -A && git commit -q -m "spatial: central difference (deliberately wrong)" ) >/dev/null
( cd "$WT" && "$LAB" gate spatial >/tmp/val-gate-wrong.log 2>&1 )
rc=$?
[ $rc -ne 0 ] && ok "gate refused the wrong scheme (exit $rc)" || bad "gate accepted a second-order scheme for a first-order contract"
# The unit tests catch the formula change first; check the numerical gate itself.
( cd "$WT" && bash .agentlab/verification/run_all.sh >/tmp/val-verify-wrong.log 2>&1 )
vrc=$?
[ $vrc -eq 1 ] && ok "verification FAILs on the wrong scheme (exit 1)" || bad "verification exit $vrc for a second-order scheme"
grep -q "expected order 1" /tmp/val-verify-wrong.log && ok "verification names the violated order" || bad "no order violation reported"

say "6. an out-of-scope edit is caught"
( cd "$WT" && printf '\n// tampered\n' >> core/field.hpp && git add -A && git commit -q -m "spatial: touch core" )
( cd "$WT" && "$HOME_DIR/platform/scripts/scope_check.sh" spatial main >/tmp/val-scope.log 2>&1 )
rc=$?
[ $rc -ne 0 ] && ok "scope_check refused core/ (exit $rc)" || bad "scope_check allowed a core/ edit"
grep -q "OUT OF SCOPE: core/field.hpp" /tmp/val-scope.log && ok "names the offending path" || bad "no offending path reported"

say "7. a detached worker keeps the terminal free"
DET="$TMP/detach"
DET_WT="$TMP/detach-wt"
mkdir -p "$DET"
cp -R "$HOME_DIR/examples/validation/target/." "$DET/"
( cd "$DET" && git init -q -b main && git add -A && git commit -q -m "detach target" ) >/dev/null
cat > "$TMP/slow-worker.sh" <<'SLOW'
#!/usr/bin/env bash
set -euo pipefail
sleep 2
mkdir -p .agentlab/reports
printf '# Report: spatial\n\nstatus: ready\n' > .agentlab/reports/spatial.md
git add -A && git commit -q -m "spatial: detached fake work"
SLOW
chmod +x "$TMP/slow-worker.sh"

set +e
( cd "$DET" && WT_ROOT="$DET_WT" PI_BIN="$TMP/slow-worker.sh" "$LAB" run spatial --detach >/tmp/val-detach.log 2>&1 )
rc=$?
set -e
[ $rc -eq 0 ] && ok "detach returns immediately (exit 0)" || { bad "detach exit $rc"; tail -8 /tmp/val-detach.log; }
grep -q "detached pid=" /tmp/val-detach.log && ok "prints the background pid" || bad "no pid line"
grep -q "progress:" /tmp/val-detach.log && ok "points at agentlab status" || bad "no follow-up hint"

( cd "$DET" && WT_ROOT="$DET_WT" "$LAB" status >/tmp/val-detach-status.log 2>&1 )
grep -q "Running in background" /tmp/val-detach-status.log && ok "status shows the running worker" || bad "status does not show the background worker"

sleep 4
( cd "$DET" && WT_ROOT="$DET_WT" "$LAB" status >/tmp/val-detach-done.log 2>&1 )
grep -q "ready" /tmp/val-detach-done.log && ok "detached work completed" || bad "detached work did not finish"
[ -f "$DET_WT/run/spatial.pid" ] && bad "pid file was not cleaned up" || ok "pid file cleaned up"
[ -f "$DET_WT/spatial/.agentlab/reports/spatial.md" ] && ok "worktree received the report" || bad "report missing"

say "8. interruption reports the worktree state"
INT="$TMP/interrupt"
INT_WT="$TMP/interrupt-wt"
mkdir -p "$INT"
cp -R "$HOME_DIR/examples/validation/target/." "$INT/"
( cd "$INT" && git init -q -b main && git add -A && git commit -q -m "interrupt target" ) >/dev/null
cat > "$TMP/sleep-worker.sh" <<'SLEEP'
#!/bin/sh
sleep 30
SLEEP
chmod +x "$TMP/sleep-worker.sh"

set +e
old_pwd="$PWD"
cd "$INT"
WT_ROOT="$INT_WT" PI_BIN="$TMP/sleep-worker.sh" "$LAB" run spatial >/tmp/val-interrupt.log 2>&1 &
interrupt_pid=$!
cd "$old_pwd"
sleep 3
kill -TERM "$interrupt_pid" 2>/dev/null
wait "$interrupt_pid" 2>/dev/null
rc=$?
set -e
[ $rc -eq 130 ] && ok "interrupted run exits 130" || bad "interrupted run exit $rc"
grep -q "run_worker: interrupted" /tmp/val-interrupt.log && ok "prints an interruption notice" || bad "no interruption notice"
grep -q "worktree state:" /tmp/val-interrupt.log && ok "reports commit/dirty state" || bad "no worktree state"
grep -q "nothing committed yet" /tmp/val-interrupt.log && ok "says how to continue" || bad "no continuation hint"

say "result"
printf 'validate-harness: %d passed, %d failed\n' "$pass" "$fail"
[ $fail -eq 0 ]
