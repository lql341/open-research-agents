#!/usr/bin/env bash
# Usage (inside target repo): repro_snapshot.sh <label> <gate_mode> <gate_status> <gate_rc>
# Writes .agentlab/repro/<label>-<UTC timestamp>.json
set -uo pipefail
LABEL="${1:-snapshot}"
MODE="${2:-worker}"
STATUS="${3:-unknown}"
GATE_RC="${4:-NA}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "repro: not inside a git repository"; exit 0; }
cd "$ROOT"
OUT=".agentlab/repro"
mkdir -p "$OUT"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
PYTHON="${PYTHON:-python3}"; "$PYTHON" - "$OUT/$LABEL-$TS.json" "$LABEL" "$MODE" "$STATUS" "$GATE_RC" <<'PY'
import json, subprocess, sys, platform, os, datetime
out, label, mode, status, gate_rc = sys.argv[1:6]

def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()
    except Exception as e:
        return "error: %s" % e

pi_bin = os.environ.get("PI_BIN", "pi")
rec = {
  "label": label,
  "gate_mode": mode,
  "gate_status": status,
  "gate_exit_code": gate_rc,
  "time_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
  "git_commit": sh("git rev-parse HEAD"),
  "git_branch": sh("git rev-parse --abbrev-ref HEAD"),
  "git_dirty": bool(sh("git status --porcelain")),
  "host": platform.node(),
  "kernel": platform.release(),
  "os": platform.platform(),
  "cpu": sh("lscpu 2>/dev/null | grep 'Model name' | head -1 | cut -d: -f2- | xargs")
         or sh("sysctl -n machdep.cpu.brand_string 2>/dev/null")
         or sh("wmic cpu get name 2>/dev/null | sed -n 2p | xargs"),
  "cpu_threads": os.cpu_count(),
  "gpu": sh("nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null"),
  "toolchain": {
    "cxx": sh("${CXX:-c++} --version 2>/dev/null | head -1"),
    "cmake": sh("cmake --version 2>/dev/null | head -1"),
    "mpi": sh("mpirun --version 2>/dev/null | head -1"),
    "pi": sh("%s --version 2>/dev/null | head -1" % pi_bin),
  },
  "model": os.environ.get("AGENTLAB_MODEL", os.environ.get("PI_MODEL", "")),
  "commands": [line for line in os.environ.get("AGENTLAB_COMMANDS", "").splitlines() if line.strip()],
  "case": os.environ.get("AGENTLAB_CASE", ""),
  "env": {k: os.environ.get(k, "") for k in ("OMP_NUM_THREADS", "CXXFLAGS", "PI_ARGS", "GATE_MODE")},
  "note": "Domain-specific fields (mesh, CFL, iterations, residual history, timing) are written by verification cases to *.case.json; see .agentlab/repro_fields.yaml",
}
with open(out, "w") as f:
    json.dump(rec, f, indent=2, ensure_ascii=False)
print("repro record:", out)
PY
